-- A floating diamond with distance over the current objective, so players never need to read
-- long text to know where to go next.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared:WaitForChild("QuestData"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Goals = require(Shared:WaitForChild("Goals"))
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local UPDATE_INTERVAL = 0.2
local HIDE_DISTANCE = 9

local Waypoint = {}

-- Where the guide arrow points right now (nil while it is hidden); the mini map marks it too.
local shownGoal: Vector3? = nil

function Waypoint.goal(): Vector3?
	return shownGoal
end

local function nearestUnfound(ids: { string }, lookup: (string) -> { number }?, from: Vector3): Vector3?
	local found = Attrs.set("QuestFound")
	local best, bestDistance = nil, math.huge
	for _, id in ids do
		local point = lookup(id)
		if point and not found[id] then
			local position = WorldData.vector(point)
			local distance = (position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = position, distance
			end
		end
	end
	return best
end

-- The creature zone that best fits the player's level (closest level range, then distance).
local function nearestCreatureZone(from: Vector3): (Vector3?, number)
	local level = Attrs.get("Level", 1)
	local best, bestScore, bestRadius = nil, math.huge, 0
	for _, area in WorldData.areas do
		local levels = area.levels
		if levels then
			local gap = if level < levels[1] then (levels[1] - level) * 2 elseif level > levels[2] then level - levels[2] else 0
			local center = WorldData.vector(area.center)
			local score = gap * 1000 + (center - from).Magnitude
			if score < bestScore then
				best, bestScore, bestRadius = center, score, area.radius
			end
		end
	end
	return best, bestRadius
end

-- Returns the world point to guide to and how close counts as "arrived".
local function currentGoal(from: Vector3): (Vector3?, number)
	-- Inside the Shadow Tower nothing in the valley is reachable: no arrow.
	if Attrs.get("TowerFloor", 0) > 0 then
		return nil, 0
	end
	local state = player:GetAttribute("QuestState")
	-- A full crystal pouch comes first: bring it to the Great Lantern.
	if Attrs.get("Crystals", 0) >= Attrs.stats().pouchCapacity then
		return WorldData.vector(WorldData.plaza), HIDE_DISTANCE
	end
	if state == "available" then
		-- The next quest may belong to another giver (e.g. Ranger Wren).
		local nextQuest = QuestData.quests[player:GetAttribute("QuestId") or ""]
		return WorldData.vector(WorldData.npcs[(nextQuest and nextQuest.giver) or "Elder"].position), HIDE_DISTANCE
	elseif state == "level" then
		-- Guide to the nearest creature zone so players know where to grow stronger.
		return nearestCreatureZone(from)
	elseif state == "done" then
		-- After the story: an affordable upgrade at Smith, otherwise creatures for XP and coins.
		local goal = Goals.next(Attrs.get("XP", 0), Attrs.get("Coins", 0), Attrs.get("StaffTier", 0))
		if goal.kind == "staff" and goal.affordable then
			return WorldData.vector(WorldData.npcs.Smith.position), HIDE_DISTANCE
		elseif goal.kind ~= "done" then
			return nearestCreatureZone(from)
		end
		return nil, 0
	elseif state ~= "active" then
		return nil, 0
	end
	local def = QuestData.quests[player:GetAttribute("QuestId") or ""]
	if not def then
		return nil, 0
	end
	local objective = def.objective
	if objective.kind == "purify" then
		local area = WorldData.areas[objective.area]
		return WorldData.vector(area.center), area.radius * 0.6
	elseif objective.kind == "collect" then
		return nearestUnfound(objective.ids, function(id)
			return WorldData.flowers[id]
		end, from), 6
	elseif objective.kind == "explore" then
		return nearestUnfound(objective.ids, function(id)
			local landmark = WorldData.landmarks[id]
			return landmark and landmark.position
		end, from), 0
	elseif objective.kind == "upgrade" then
		return WorldData.vector(WorldData.npcs[objective.npc].position), HIDE_DISTANCE
	elseif objective.kind == "vine" then
		return WorldData.vector(WorldData.areas.gate.center), 6
	end
	return nil, 0
end

function Waypoint.start()
	local anchor = Instance.new("Part")
	anchor.Name = "WaypointAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Parent = workspace

	local gui = UiKit.create("BillboardGui", {
		Size = UDim2.fromOffset(90, 80),
		StudsOffset = Vector3.new(0, 7, 0),
		AlwaysOnTop = true,
		Adornee = anchor,
		Enabled = false,
		LightInfluence = 0,
	}, player:WaitForChild("PlayerGui"))
	local diamond = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Rotation = 45,
		BackgroundColor3 = UiKit.colors.accent,
		BorderSizePixel = 0,
	}, gui)
	UiKit.corner(diamond, 6)
	UiKit.create("UIStroke", { Color = Color3.fromRGB(120, 70, 20), Thickness = 3 }, diamond)
	local distanceLabel = UiKit.label({
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 30),
		TextSize = 22,
		TextStrokeTransparency = 0.2,
	}, gui)

	task.spawn(function()
		while true do
			task.wait(UPDATE_INTERVAL)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local goal, arriveDistance = nil, 0
			if root then
				goal, arriveDistance = currentGoal(root.Position)
			end
			if goal and root then
				local distance = Vector3.new(goal.X - root.Position.X, 0, goal.Z - root.Position.Z).Magnitude
				anchor.Position = goal
				gui.Enabled = distance > math.max(arriveDistance, 4)
				shownGoal = if gui.Enabled then goal else nil
				distanceLabel.Text = string.format("%dm", math.floor(distance + 0.5))
			else
				gui.Enabled = false
				shownGoal = nil
			end
		end
	end)
end

return Waypoint
