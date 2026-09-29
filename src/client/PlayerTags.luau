-- Tags over other players' heads: their chosen title, name and level (with rebirths). Built here
-- from the attributes the server already replicates (Title, Level, Rebirths), only on this screen.
-- Turn them off in Settings > Interface (Player tags); the default Roblox name tag comes back then.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local PlayerBoard = require(script.Parent.PlayerBoard)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local colors = UiKit.colors

local REFRESH_SECONDS = 0.5
local TAG_NAME = "PlayerTag"

local PlayerTags = {}

local function nameOf(other: Player): string
	local display = (other :: any).DisplayName
	return if type(display) == "string" and display ~= "" then display else other.Name
end

-- "Lv 42" or "Lv 100  Rebirth 2".
function PlayerTags.levelLine(other: Player): string
	local line = Strings.get("hud_level", other:GetAttribute("Level") or 1)
	local rebirths = other:GetAttribute("Rebirths") or 0
	if rebirths > 0 then
		line ..= "  " .. Strings.get("rebirth_hud", rebirths)
	end
	return line
end

-- The chosen title's text, or "" when none is shown (the same text as the Players panel).
function PlayerTags.titleLine(other: Player): string
	return PlayerBoard.titleOf(other)
end

local function build(head: BasePart): BillboardGui
	local gui = UiKit.create("BillboardGui", {
		Name = TAG_NAME,
		Size = UDim2.fromOffset(160, 62),
		StudsOffset = Vector3.new(0, 3, 0),
		AlwaysOnTop = false,
		MaxDistance = 70,
		LightInfluence = 0,
		Adornee = head,
	}, head)
	UiKit.label({ Name = "TitleLine", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 16), TextSize = 13, TextColor3 = colors.accent, TextStrokeTransparency = 0.3 }, gui)
	UiKit.label({ Name = "NameLine", Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextStrokeTransparency = 0.3, TextTruncate = Enum.TextTruncate.AtEnd }, gui)
	UiKit.label({ Name = "LevelLine", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 18), TextSize = 14, TextColor3 = colors.muted, TextStrokeTransparency = 0.3 }, gui)
	return gui
end

local function refresh()
	local wanted = Settings.get("playerTags") == true
	for _, other in Players:GetPlayers() do
		if other == player then
			continue
		end
		local character = other.Character
		local head = character and character:FindFirstChild("Head") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local tag = head and head:FindFirstChild(TAG_NAME) :: BillboardGui?
		if not wanted then
			if tag then
				tag:Destroy()
			end
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
			end
		elseif head then
			if not tag then
				tag = build(head)
			end
			local gui = tag :: BillboardGui
			local title = PlayerTags.titleLine(other)
			gui.TitleLine.Text = title
			gui.TitleLine.Visible = title ~= ""
			gui.NameLine.Text = nameOf(other)
			gui.LevelLine.Text = PlayerTags.levelLine(other)
			if humanoid then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		end
	end
end

function PlayerTags.start()
	task.spawn(function()
		while true do
			refresh()
			task.wait(REFRESH_SECONDS)
		end
	end)
end

return PlayerTags
