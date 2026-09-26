local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local PANEL_COLOR = Color3.fromRGB(45, 40, 70)
local TEXT_COLOR = Color3.fromRGB(255, 248, 230)
local ACCENT_COLOR = Color3.fromRGB(255, 215, 110)

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function panel(props: { [string]: any }, parent: Instance): Frame
	props.BackgroundColor3 = PANEL_COLOR
	props.BackgroundTransparency = 0.15
	local frame = create("Frame", props, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, frame)
	create("UIStroke", { Color = ACCENT_COLOR, Thickness = 2, Transparency = 0.3 }, frame)
	return frame
end

local function label(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = 1
	props.Font = Enum.Font.FredokaOne
	props.TextColor3 = props.TextColor3 or TEXT_COLOR
	props.TextSize = props.TextSize or 22
	return create("TextLabel", props, parent)
end

local Hud = {}

function Hud.start()
	local gui = create("ScreenGui", { Name = "Hud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	local stats = panel({
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(150, 72),
	}, gui)
	local coinsLabel = label({
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = ACCENT_COLOR,
	}, stats)
	local xpLabel = label({
		Position = UDim2.fromOffset(14, 36),
		Size = UDim2.new(1, -28, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, stats)

	local quest = panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(320, 52),
	}, gui)
	local questLabel = label({ Size = UDim2.fromScale(1, 1), TextWrapped = true }, quest)

	local toasts = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 80),
		Size = UDim2.fromOffset(420, 120),
		BackgroundTransparency = 1,
	}, gui)
	create("UIListLayout", {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
	}, toasts)

	local dialog = panel({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(440, 80),
		Visible = false,
	}, gui)
	local dialogLabel = label({
		Position = UDim2.fromOffset(14, 0),
		Size = UDim2.new(1, -28, 1, 0),
		TextWrapped = true,
		TextSize = 20,
	}, dialog)

	local function refreshStats()
		coinsLabel.Text = Strings.get("hud_coins", player:GetAttribute("Coins") or 0)
		xpLabel.Text = Strings.get("hud_xp", player:GetAttribute("XP") or 0)
	end

	local function refreshQuest()
		local state = player:GetAttribute("QuestState")
		local def = QuestData.quests[player:GetAttribute("QuestId") or ""]
		if state == "active" and def then
			questLabel.Text = Strings.get(
				def.objectiveKey,
				player:GetAttribute("QuestCount") or 0,
				player:GetAttribute("QuestGoal") or 0
			)
		elseif state == "available" then
			questLabel.Text = Strings.get("quest_talk_to_elder")
		elseif state == "done" then
			questLabel.Text = Strings.get("quest_all_done")
		else
			questLabel.Text = ""
		end
	end

	local function showToast(text: string)
		local toast = label({
			Size = UDim2.fromOffset(420, 36),
			Text = text,
			TextSize = 26,
			TextColor3 = ACCENT_COLOR,
			TextStrokeTransparency = 0.3,
		}, toasts)
		task.delay(2.5, function()
			local fade = TweenService:Create(toast, TweenInfo.new(0.5), { TextTransparency = 1, TextStrokeTransparency = 1 })
			fade.Completed:Connect(function()
				toast:Destroy()
			end)
			fade:Play()
		end)
	end

	local dialogToken = 0
	local function showDialog(lineKey: string)
		dialogToken += 1
		local token = dialogToken
		dialogLabel.Text = Strings.get("npc_elder_name") .. ": " .. Strings.get(lineKey)
		dialog.Visible = true
		task.delay(5, function()
			if dialogToken == token then
				dialog.Visible = false
			end
		end)
	end

	for _, name in { "Coins", "XP" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	for _, name in { "QuestState", "QuestId", "QuestCount", "QuestGoal" } do
		player:GetAttributeChangedSignal(name):Connect(refreshQuest)
	end
	refreshStats()
	refreshQuest()

	Remotes:WaitForChild("RewardGranted").OnClientEvent:Connect(function(reason, xp, coins)
		local key = if reason == "quest" then "reward_quest" else "reward_purify"
		showToast(Strings.get(key, xp, coins))
	end)
	Remotes:WaitForChild("NpcSay").OnClientEvent:Connect(function(lineKey)
		if typeof(lineKey) == "string" then
			showDialog(lineKey)
		end
	end)
end

return Hud
