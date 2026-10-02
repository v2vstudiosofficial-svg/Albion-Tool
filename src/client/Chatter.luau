-- Villagers talk to themselves now and then: when the player walks past one (near, but not close
-- enough to talk), a speech bubble with a short line pops over their name. Local only and nothing
-- to do with quests; quiet during story scenes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Cinematic = require(script.Parent.Cinematic)
local UiKit = require(script.Parent.UiKit)
local World = require(script.Parent.World)

local player = Players.LocalPlayer

local CHECK_SECONDS = 0.5
-- Passing by: closer than NEAR the talk prompt is up instead (it opens at 10 studs).
local NEAR, FAR = 11, 28
local SHOW_SECONDS = 4.5
local FIRST_GAP = 2
local MIN_GAP, MAX_GAP = 9, 16 -- seconds between lines
local BUBBLE_COLOR = Color3.fromRGB(255, 250, 235)

local LINES = {
	Elder = { "chatter_elder_1", "chatter_elder_2", "chatter_elder_3" },
	Smith = { "chatter_smith_1", "chatter_smith_2", "chatter_smith_3" },
	Wren = { "chatter_wren_1", "chatter_wren_2", "chatter_wren_3" },
	Kael = { "chatter_kael_1", "chatter_kael_2", "chatter_kael_3" },
}

local Chatter = {}

-- The villager the player is passing by (nearest first), and the part to speak from.
local function passingBy(): (string?, BasePart?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local map = workspace:FindFirstChild("LanternValleyMap")
	local village = map and map:FindFirstChild("Village")
	if not root or not village then
		return nil, nil
	end
	local best, bestBody, bestDistance = nil, nil, math.huge
	for name in WorldData.npcs do
		local model = village:FindFirstChild(name)
		local body = model and model:FindFirstChild("Body") :: BasePart?
		-- Kael is hidden (his prompt switched off) for players who have not met him yet.
		local prompt = body and body:FindFirstChildOfClass("ProximityPrompt")
		if body and (not prompt or prompt.Enabled) then
			local offset = body.Position - root.Position
			local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
			if distance >= NEAR and distance <= FAR and distance < bestDistance then
				best, bestBody, bestDistance = name, body, distance
			end
		end
	end
	return best, bestBody
end

function Chatter.start()
	local random = Random.new()
	local bubble: BillboardGui? = nil
	local lastLine: string? = nil

	local function say(name: string, body: BasePart)
		local lines = LINES[name]
		local key = lines[random:NextInteger(1, #lines)]
		if key == lastLine then
			key = lines[(table.find(lines, key) :: number) % #lines + 1]
		end
		lastLine = key
		-- Centred on the name tag (same offset), the bubble sits above and to the right of it, clear
		-- of the waypoint pin and "!" that stand straight above. Made on this screen only, so other
		-- players never see it.
		local gui = UiKit.create("BillboardGui", {
			Name = "LvChatter",
			Size = UDim2.fromOffset(560, 120),
			StudsOffset = Vector3.new(0, 4.4, 0),
			LightInfluence = 0,
			MaxDistance = 60,
		}, body)
		local pill = UiKit.panel({
			Name = "Bubble",
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0.5, 24, 0.5, -20),
			Size = UDim2.fromOffset(250, 46),
			BackgroundColor3 = BUBBLE_COLOR,
			BackgroundTransparency = 0.04,
			Corner = 14,
		}, gui)
		local text = UiKit.label({
			Position = UDim2.fromOffset(10, 3),
			Size = UDim2.new(1, -20, 1, -6),
			Text = Strings.get(key),
			TextSize = 15,
			TextWrapped = true,
			TextColor3 = UiKit.colors.panel,
		}, pill)
		local tail = UiKit.label({
			Position = UDim2.new(0, 8, 1, -6),
			Size = UDim2.fromOffset(20, 16),
			Text = "▼",
			TextSize = 16,
			TextColor3 = BUBBLE_COLOR,
		}, pill)
		UiKit.pop(pill)
		World.greet(name)
		bubble = gui
		task.delay(SHOW_SECONDS, function()
			if bubble ~= gui then
				return
			end
			for _, item in { text, tail } do
				UiKit.tween(item, 0.3, { TextTransparency = 1 })
			end
			UiKit.tween(pill, 0.3, { BackgroundTransparency = 1 }).Completed:Connect(function()
				gui:Destroy()
				if bubble == gui then
					bubble = nil
				end
			end)
		end)
	end

	task.spawn(function()
		local untilNext = FIRST_GAP
		while true do
			task.wait(CHECK_SECONDS)
			untilNext -= CHECK_SECONDS
			if Cinematic.blocking() then
				if bubble then
					bubble:Destroy()
					bubble = nil
				end
			elseif untilNext <= 0 and not bubble then
				local name, body = passingBy()
				if name and body then
					say(name, body)
					untilNext = random:NextNumber(MIN_GAP, MAX_GAP)
				end
			end
		end
	end)
end

return Chatter
