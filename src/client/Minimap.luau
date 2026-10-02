-- A small map under the top-right buttons: creature zones by level band, the village, other
-- players, the guide goal and an arrow for you. Tap it to switch between "near" (around you) and
-- the whole valley. Everything is drawn from data the client already has; it can be turned off in
-- Settings > Interface (Mini map).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MapLogic = require(Shared:WaitForChild("MapLogic"))
local MusicLogic = require(Shared:WaitForChild("MusicLogic"))
local Strings = require(Shared:WaitForChild("Strings"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Audio = require(script.Parent.Audio)
local Cinematic = require(script.Parent.Cinematic)
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)
local Waypoint = require(script.Parent.Waypoint)

local player = Players.LocalPlayer
local colors = UiKit.colors

local SIZE = 132
-- Below the top-right buttons (216 tall, up to 1.15 times bigger at the "large" interface size).
local TOP_OFFSET = 272
local GIFT_GAP = 8
local GIFT_WIDTH = 96
local REFRESH_SECONDS = 0.1
local MAX_OTHERS = 12
local MAX_RIFTS = 4
-- Place names by MusicLogic theme.
local PLACE_KEYS = {
	village = "place_village",
	wilds = "place_wilds",
	marsh = "place_marsh",
	peaks = "place_peaks",
	citadel = "place_citadel",
	boss = "place_boss",
	tower = "place_tower",
}
local EDGE_MARGIN = 7

-- Zone tint by the first level of the zone's range (the same bands the story follows).
local BANDS = {
	{ upTo = 7, color = Color3.fromRGB(110, 200, 110) },
	{ upTo = 25, color = Color3.fromRGB(120, 170, 120) },
	{ upTo = 50, color = Color3.fromRGB(140, 200, 240) },
	{ upTo = 75, color = Color3.fromRGB(170, 130, 220) },
	{ upTo = 100, color = Color3.fromRGB(230, 110, 110) },
}

local Minimap = {}

-- The region the map lives in (set by start); the daily gift button sits at its left edge.
Minimap.region = nil :: Frame?
Minimap.giftWidth = GIFT_WIDTH

local function bandColor(level: number): Color3
	for _, band in BANDS do
		if level <= band.upTo then
			return band.color
		end
	end
	return BANDS[#BANDS].color
end

local function dot(parent: Instance, size: number, color: Color3, order: number): Frame
	local frame = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = order,
	}, parent)
	UiKit.corner(frame, size)
	return frame
end

function Minimap.start()
	local gui = UiKit.create("ScreenGui", { Name = "Minimap", ResetOnSpawn = false, DisplayOrder = 3 }, player:WaitForChild("PlayerGui"))
	-- One region for the map and the daily gift button beside it, so they scale together and never
	-- overlap; it starts below the top-right button grid even at the largest interface size.
	local region = UiKit.region(gui, Vector2.new(1, 0), UDim2.new(1, -12, 0, TOP_OFFSET), Vector2.new(SIZE + GIFT_GAP + GIFT_WIDTH, SIZE + 22))
	Minimap.region = region
	local mode = "near"
	local map = UiKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(SIZE, SIZE),
		Text = "",
		BackgroundColor3 = Color3.fromRGB(24, 30, 44),
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Corner = 12,
	}, region, function()
		mode = if mode == "near" then "world" else "near"
		Audio.play("ui")
	end)
	map.Name = "Map"
	UiKit.create("UIStroke", { Color = colors.accent, Thickness = 2, Transparency = 0.3 }, map)

	-- Static things, moved every refresh: zone discs, the village and the Shadow Tower.
	local zones = {}
	for _, area in WorldData.areas do
		if area.levels then
			local disc = UiKit.create("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = bandColor(area.levels[1]),
				BackgroundTransparency = 0.6,
				BorderSizePixel = 0,
				ZIndex = 1,
			}, map)
			UiKit.corner(disc, 1000)
			table.insert(zones, { disc = disc, area = area })
		end
	end
	local landmarks = {
		{ dot = dot(map, 9, colors.accent, 2), point = WorldData.plaza },
		{ dot = dot(map, 8, Color3.fromRGB(180, 120, 230), 2), point = WorldData.areas.tower.center },
	}
	-- North is always up; a small N on the top edge says so.
	UiKit.label({
		Name = "North",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 2),
		Size = UDim2.fromOffset(16, 14),
		Text = Strings.get("map_north"),
		TextSize = 12,
		TextColor3 = colors.accent,
		TextStrokeTransparency = 0.3,
		ZIndex = 6,
	}, map)
	-- Open Shadow Rifts: purple dots that pulse.
	local rifts = {}
	for index = 1, MAX_RIFTS do
		rifts[index] = dot(map, 9, Color3.fromRGB(170, 90, 255), 3)
		rifts[index].Name = "Rift"
		UiKit.create("UIStroke", { Color = Color3.fromRGB(240, 210, 255), Thickness = 1.5 }, rifts[index])
	end
	-- Where you are, under the map.
	local placeLabel = UiKit.label({
		Name = "Place",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, SIZE + 2),
		Size = UDim2.fromOffset(SIZE, 18),
		TextSize = 14,
		TextColor3 = colors.text,
		TextStrokeTransparency = 0.4,
	}, region)
	-- Walking into a new place shows its name in the middle banner for a moment.
	local shownPlace: string? = nil
	local function enterPlace(theme: string)
		local name = Strings.get(PLACE_KEYS[theme] or "place_village")
		placeLabel.Text = name
		-- Boss arenas announce their boss instead.
		if shownPlace ~= nil and shownPlace ~= theme and theme ~= "boss" and not Cinematic.playing() then
			Hud.banner(name, nil, "place")
		end
		shownPlace = theme
	end
	local others = {}
	for index = 1, MAX_OTHERS do
		others[index] = dot(map, 5, Color3.fromRGB(240, 240, 240), 3)
		others[index].Name = "OtherPlayer"
	end
	local goalDot = dot(map, 8, Color3.fromRGB(255, 200, 60), 4)
	goalDot.Name = "Goal"
	UiKit.create("UIStroke", { Color = Color3.fromRGB(120, 70, 20), Thickness = 1.5 }, goalDot)
	local arrow = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(20, 20),
		Text = "▲",
		TextSize = 16,
		TextColor3 = Color3.fromRGB(90, 230, 255),
		TextStrokeTransparency = 0.3,
		ZIndex = 5,
	}, map)
	arrow.Name = "You"

	local function place(item: GuiObject, view: MapLogic.View, x: number, z: number, keepInside: boolean)
		local px, py = MapLogic.toMap(view, SIZE, x, z)
		local outside = false
		if keepInside then
			px, py, outside = MapLogic.clamp(SIZE, px, py, EDGE_MARGIN)
		else
			outside = not MapLogic.inside(SIZE, px, py, -4)
		end
		item.Position = UDim2.fromOffset(px, py)
		item.Visible = keepInside or not outside
	end

	local function refresh()
		map.Visible = Settings.get("minimap") == true and player:GetAttribute("DataState") == "ready" and not Cinematic.playing()
		placeLabel.Visible = map.Visible
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and player:GetAttribute("DataState") == "ready" then
			local theme = MusicLogic.theme(root.Position.X, root.Position.Z)
			if theme ~= shownPlace then
				enterPlace(theme)
			end
		end
		if not map.Visible or not root then
			return
		end
		local position = root.Position
		local view = MapLogic.view(mode, position.X, position.Z, SIZE)
		for _, zone in zones do
			local center = zone.area.center
			local radius = zone.area.radius / view.studsPerPixel
			local px, py = MapLogic.toMap(view, SIZE, center[1], center[3])
			zone.disc.Position = UDim2.fromOffset(px, py)
			zone.disc.Size = UDim2.fromOffset(radius * 2, radius * 2)
			zone.disc.Visible = MapLogic.circleVisible(SIZE, px, py, radius)
		end
		for _, landmark in landmarks do
			place(landmark.dot, view, landmark.point[1], landmark.point[3], false)
		end
		local used = 0
		for _, other in Players:GetPlayers() do
			local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if otherRoot and used < MAX_OTHERS then
				used += 1
				place(others[used], view, otherRoot.Position.X, otherRoot.Position.Z, false)
			end
		end
		for index = used + 1, MAX_OTHERS do
			others[index].Visible = false
		end
		local riftCenters = Effects.activeRifts()
		local beat = 9 + 3 * math.sin(os.clock() * 5)
		for index, rift in rifts do
			local center = riftCenters[index]
			if center then
				place(rift, view, center.X, center.Z, true)
				rift.Size = UDim2.fromOffset(beat, beat)
			else
				rift.Visible = false
			end
		end
		local goal = Waypoint.goal()
		if goal then
			place(goalDot, view, goal.X, goal.Z, true)
		else
			goalDot.Visible = false
		end
		local px, py = MapLogic.toMap(view, SIZE, position.X, position.Z)
		arrow.Position = UDim2.fromOffset(px, py)
		local look = root.CFrame.LookVector
		arrow.Rotation = MapLogic.heading(look.X, look.Z)
	end

	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return Minimap
