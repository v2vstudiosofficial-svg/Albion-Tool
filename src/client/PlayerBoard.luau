-- "Players": who is on this server, with their level, rebirths and best Shadow Tower floor,
-- highest level first. The top three get medals and every level sits in a badge whose colour grows
-- with it (a gold ring after a rebirth). Everything shown comes from attributes the server already replicates to
-- everyone (Level, Rebirths, TowerBest, Title), so it needs no saved data. Open it with the button under
-- Emotes or the Tab key.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local TitleData = require(Shared:WaitForChild("TitleData"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local colors = UiKit.colors

local ROW_HEIGHT = 40
local MAX_ROWS = 12
local REFRESH_SECONDS = 1
local MEDAL_KEYS = { "players_rank_1", "players_rank_2", "players_rank_3" }
-- Badge colours: the first tier the level reaches, highest first.
local LEVEL_TIERS = {
	{ level = 50, color = Color3.fromRGB(235, 180, 60) },
	{ level = 25, color = Color3.fromRGB(160, 110, 230) },
	{ level = 10, color = Color3.fromRGB(80, 150, 230) },
	{ level = 1, color = Color3.fromRGB(90, 170, 110) },
}

local PlayerBoard = {}

function PlayerBoard.badgeColor(level: number): Color3
	for _, tier in LEVEL_TIERS do
		if level >= tier.level then
			return tier.color
		end
	end
	return LEVEL_TIERS[#LEVEL_TIERS].color
end

local function nameOf(other: Player): string
	local display = (other :: any).DisplayName
	return if type(display) == "string" and display ~= "" then display else other.Name
end

-- Players sorted by level (highest first), then by name so the order never jumps around.
function PlayerBoard.sorted(list: { Player }): { Player }
	local copy = table.clone(list)
	table.sort(copy, function(a, b)
		local levelA, levelB = a:GetAttribute("Level") or 1, b:GetAttribute("Level") or 1
		if levelA ~= levelB then
			return levelA > levelB
		end
		return nameOf(a) < nameOf(b)
	end)
	return copy
end

function PlayerBoard.start()
	local gui = UiKit.create("ScreenGui", { Name = "PlayerBoard", ResetOnSpawn = false, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))
	local buttonRegion = UiKit.region(gui, Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, 64), Vector2.new(120, 40))
	local panelRegion = UiKit.region(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(480, 40 + MAX_ROWS * ROW_HEIGHT))
	local panel = UiKit.panel({ Size = UDim2.fromOffset(480, 100), Visible = false, Corner = 16 }, panelRegion)
	UiKit.label({ Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 30), Text = Strings.get("players_title"), TextSize = 24, TextColor3 = colors.accent }, panel)
	local list = UiKit.create("Frame", { Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 1, -56), BackgroundTransparency = 1 }, panel)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local function refresh()
		for _, child in list:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local everyone = PlayerBoard.sorted(Players:GetPlayers())
		for index, other in everyone do
			if index > MAX_ROWS then
				break
			end
			local row = UiKit.create("Frame", { LayoutOrder = index, Size = UDim2.new(1, 0, 0, ROW_HEIGHT - 4), BackgroundColor3 = if other == player then colors.panelLight else colors.panel, BorderSizePixel = 0 }, list)
			UiKit.corner(row, 10)
			if other == player then
				UiKit.create("UIStroke", { Color = colors.accent, Thickness = 2, Transparency = 0.3 }, row)
			end
			local medal = MEDAL_KEYS[index]
			UiKit.label({
				Name = "Rank",
				Position = UDim2.fromOffset(4, 0),
				Size = UDim2.new(0, 30, 1, 0),
				Text = if medal then Strings.get(medal) else Strings.get("players_rank", index),
				TextSize = if medal then 20 else 14,
				TextColor3 = colors.muted,
			}, row)
			local level = other:GetAttribute("Level") or 1
			local badge = UiKit.label({
				Name = "LevelBadge",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 38, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
				BackgroundColor3 = PlayerBoard.badgeColor(level),
				BackgroundTransparency = 0,
				Text = tostring(level),
				TextSize = if level >= 100 then 12 else 15,
			}, row)
			UiKit.corner(badge, 15)
			if (other:GetAttribute("Rebirths") or 0) > 0 then
				UiKit.create("UIStroke", { Color = Color3.fromRGB(255, 220, 110), Thickness = 2 }, badge)
			end
			local title = PlayerBoard.titleOf(other)
			UiKit.label({ Position = UDim2.fromOffset(76, if title ~= "" then 1 else 0), Size = UDim2.new(0.42, 0, if title ~= "" then 0.6 else 1, 0), Text = nameOf(other), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)
			if title ~= "" then
				UiKit.label({ Position = UDim2.new(0, 76, 0.55, 0), Size = UDim2.new(0.42, 0, 0.4, 0), Text = title, TextSize = 12, TextColor3 = colors.accent, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, row)
			end
			UiKit.label({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), Text = PlayerBoard.summary(other), TextSize = 15, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Right }, row)
		end
		panel.Size = UDim2.fromOffset(480, 56 + math.min(#everyone, MAX_ROWS) * ROW_HEIGHT)
	end

	local function toggle()
		panel.Visible = not panel.Visible
		if panel.Visible then
			refresh()
			UiKit.pop(panel)
		end
		Audio.play("ui")
	end
	UiKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(36, 36),
		Text = "X",
		TextSize = 18,
		BackgroundColor3 = colors.panelLight,
		TextColor3 = colors.text,
		Corner = 18,
	}, panel, toggle)
	local playersButton = UiKit.button({ Size = UDim2.fromScale(1, 1), Text = Strings.get("players_button"), TextSize = 18, BackgroundColor3 = colors.panelLight, TextColor3 = colors.text }, buttonRegion, toggle)
	UiKit.withSideIcon(playersButton, Strings.get("icon_players"))
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			toggle()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if panel.Visible then
			refresh()
		end
	end)
	Players.PlayerRemoving:Connect(function()
		if panel.Visible then
			task.defer(refresh)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(REFRESH_SECONDS)
			if panel.Visible then
				refresh()
			end
		end
	end)
end

-- The title a player chose (their Title attribute), or "" when none is shown.
function PlayerBoard.titleOf(other: Player): string
	local title = TitleData.titles[other:GetAttribute("Title") or ""]
	return if title then Strings.get(title.nameKey) else ""
end

-- "Rebirth 2   Tower 17" (parts that are zero are left out; the level is in the badge).
function PlayerBoard.summary(other: Player): string
	local parts = {}
	local rebirths = other:GetAttribute("Rebirths") or 0
	if rebirths > 0 then
		table.insert(parts, Strings.get("rebirth_hud", rebirths))
	end
	local tower = other:GetAttribute("TowerBest") or 0
	if tower > 0 then
		table.insert(parts, Strings.get("players_tower", tower))
	end
	return table.concat(parts, "   ")
end

return PlayerBoard
