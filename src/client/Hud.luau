local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Balance = require(Shared:WaitForChild("Balance"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Progression = require(Shared:WaitForChild("Progression"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local colors = UiKit.colors

local Hud = {}

local toastFunction: ((string, Color3?) -> ())? = nil

-- Lets other client modules show a short toast once the HUD exists.
function Hud.toast(text: string, color: Color3?)
	if toastFunction then
		toastFunction(text, color)
	end
end

-- Notice arguments that are string keys (e.g. a charm name key) are translated before formatting.
local function translateArgs(...: any): { any }
	local args = { ... }
	for index, value in args do
		if typeof(value) == "string" and Strings.has(value) then
			args[index] = Strings.get(value)
		end
	end
	return args
end

function Hud.start()
	local gui = UiKit.create("ScreenGui", { Name = "Hud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	-- Player card ---------------------------------------------------------------------------
	local isTouch = UiKit.isTouch()
	local topLeft = UiKit.region(gui, Vector2.new(0, 0), UDim2.fromOffset(12, 12), Vector2.new(240, 90))
	local topCenter = UiKit.region(gui, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), Vector2.new(440, 300))
	local middle = UiKit.region(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.36), Vector2.new(460, 110))
	local bottom = UiKit.region(gui, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, if isTouch then -130 else -24), Vector2.new(460, 86))

	local card = UiKit.panel({ Size = UDim2.fromOffset(232, 80) }, topLeft)
	local badge = UiKit.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = colors.accent,
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(badge, 30)
	local levelLabel = UiKit.label({ Size = UDim2.fromScale(1, 1), TextColor3 = colors.panel, TextSize = 22 }, badge)
	local xpBack = UiKit.create("Frame", {
		Position = UDim2.fromOffset(80, 14),
		Size = UDim2.fromOffset(140, 14),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(xpBack, 7)
	local xpFill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.xp, BorderSizePixel = 0 }, xpBack)
	UiKit.corner(xpFill, 7)
	local xpLabel = UiKit.label({
		Position = UDim2.fromOffset(80, 29),
		Size = UDim2.fromOffset(140, 18),
		TextSize = 15,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local coinIcon = UiKit.create("Frame", {
		Position = UDim2.fromOffset(80, 50),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = colors.coin,
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(coinIcon, 10)
	UiKit.create("UIStroke", { Color = Color3.fromRGB(170, 110, 20), Thickness = 2 }, coinIcon)
	local coinsLabel = UiKit.label({
		Position = UDim2.fromOffset(106, 47),
		Size = UDim2.fromOffset(110, 26),
		TextColor3 = colors.coin,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	-- Quest panel ---------------------------------------------------------------------------
	local quest = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(340, 64),
	}, topCenter)
	local questTitle = UiKit.label({
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 16,
		TextColor3 = colors.accent,
	}, quest)
	local questLabel = UiKit.label({
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -24, 0, 34),
		TextSize = 20,
		TextWrapped = true,
	}, quest)

	-- Boss bar ------------------------------------------------------------------------------
	local bossPanel = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 72),
		Size = UDim2.fromOffset(420, 46),
		Visible = false,
	}, topCenter)
	local bossName = UiKit.label({ Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -24, 0, 20), TextSize = 17, TextColor3 = colors.boss }, bossPanel)
	local bossBack = UiKit.create("Frame", {
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -24, 0, 14),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, bossPanel)
	UiKit.corner(bossBack, 7)
	local bossFill = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.boss, BorderSizePixel = 0 }, bossBack)
	UiKit.corner(bossFill, 7)

	-- Toasts, banner, dialog ----------------------------------------------------------------
	local toasts = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		Size = UDim2.fromOffset(440, 170),
		BackgroundTransparency = 1,
	}, topCenter)
	UiKit.create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6) }, toasts)

	local banner = UiKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, middle)
	local bannerTitle = UiKit.label({
		Size = UDim2.new(1, 0, 0, 58),
		TextSize = 46,
		TextColor3 = colors.accent,
		TextStrokeTransparency = 0.1,
		TextStrokeColor3 = Color3.fromRGB(90, 50, 20),
	}, banner)
	local bannerSub = UiKit.label({
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 0, 34),
		TextSize = 24,
		TextStrokeTransparency = 0.2,
	}, banner)

	local dialog = UiKit.panel({
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	}, bottom)
	local dialogName = UiKit.label({
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -32, 0, 20),
		TextSize = 17,
		TextColor3 = colors.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, dialog)
	local dialogLabel = UiKit.label({
		Position = UDim2.fromOffset(16, 26),
		Size = UDim2.new(1, -32, 1, -32),
		TextWrapped = true,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, dialog)

	-- Behaviour -----------------------------------------------------------------------------
	local function refreshStats()
		local xp = player:GetAttribute("XP") or 0
		local level, into, span = Progression.levelProgress(xp)
		levelLabel.Text = Strings.get("hud_level", level)
		if span then
			xpLabel.Text = Strings.get("hud_xp", into, span)
			UiKit.tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(into / span, 0, 1), 1) })
		else
			xpLabel.Text = Strings.get("hud_xp_max")
			xpFill.Size = UDim2.fromScale(1, 1)
		end
		coinsLabel.Text = Strings.get("hud_coins", player:GetAttribute("Coins") or 0)
	end

	local lastQuestText = ""
	local function refreshQuest()
		local ready = player:GetAttribute("DataState") == "ready"
		quest.Visible = ready
		card.Visible = ready
		local state = player:GetAttribute("QuestState")
		local def = QuestData.quests[player:GetAttribute("QuestId") or ""]
		local title, text = "", ""
		if state == "active" and def then
			title = Strings.get(def.titleKey)
			text = Strings.get(def.objectiveKey, player:GetAttribute("QuestCount") or 0, player:GetAttribute("QuestGoal") or 0)
		elseif state == "available" and def then
			title = Strings.get(def.titleKey)
			text = Strings.get("quest_talk_to_elder")
		elseif state == "level" then
			title = if def then Strings.get(def.titleKey) else ""
			text = Strings.get("quest_need_level", player:GetAttribute("QuestNeedLevel") or 0)
		elseif state == "done" then
			text = Strings.get("quest_all_done")
		end
		questTitle.Text = title
		questLabel.Text = text
		if text ~= lastQuestText and lastQuestText ~= "" then
			UiKit.pop(quest)
		end
		lastQuestText = text
	end

	local function showToast(text: string, color: Color3?)
		local toast = UiKit.label({
			Size = UDim2.fromOffset(440, 34),
			Text = text,
			TextSize = 24,
			TextColor3 = color or colors.accent,
			TextStrokeTransparency = 0.25,
		}, toasts)
		UiKit.pop(toast)
		task.delay(2.6, function()
			UiKit.tween(toast, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Connect(function()
				toast:Destroy()
			end)
		end)
	end

	-- Small coins fly from the middle of the screen into the coin counter.
	local function flyCoins(amount: number)
		if amount <= 0 then
			return
		end
		local target = coinIcon.AbsolutePosition + coinIcon.AbsoluteSize / 2
		local viewport = gui.AbsoluteSize
		for index = 1, math.clamp(math.ceil(amount / 5), 1, 8) do
			task.delay(index * 0.06, function()
				local coin = UiKit.create("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromOffset(viewport.X / 2 + math.random(-40, 40), viewport.Y * 0.45 + math.random(-20, 20)),
					Size = UDim2.fromOffset(18, 18),
					BackgroundColor3 = colors.coin,
					BorderSizePixel = 0,
					ZIndex = 20,
				}, gui)
				UiKit.corner(coin, 9)
				UiKit.create("UIStroke", { Color = Color3.fromRGB(170, 110, 20), Thickness = 2 }, coin)
				local flight = UiKit.tween(coin, 0.55, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(12, 12) }, Enum.EasingStyle.Quad)
				flight.Completed:Connect(function()
					coin:Destroy()
					UiKit.pop(coinIcon)
				end)
			end)
		end
	end

	toastFunction = showToast

	local bannerToken = 0
	local function showBanner(title: string, subtitle: string?)
		bannerToken += 1
		local token = bannerToken
		bannerTitle.Text = title
		bannerSub.Text = subtitle or ""
		banner.Visible = true
		UiKit.pop(banner)
		task.delay(2.2, function()
			if bannerToken == token then
				banner.Visible = false
			end
		end)
	end

	local dialogToken = 0
	local function showDialog(npc: string, text: string)
		dialogToken += 1
		local token = dialogToken
		local spec = WorldData.npcs[npc]
		dialogName.Text = if spec then Strings.get(spec.nameKey) else ""
		dialogLabel.Text = text
		dialog.Visible = true
		UiKit.pop(dialog)
		task.delay(6, function()
			if dialogToken == token then
				dialog.Visible = false
			end
		end)
	end

	local knownLevel: number? = nil
	local function onLevelChanged()
		local level = player:GetAttribute("Level")
		if typeof(level) ~= "number" then
			return
		end
		if knownLevel and level > knownLevel then
			local subtitle = if not Progression.waveUnlocked(knownLevel) and Progression.waveUnlocked(level)
				then Strings.get("notice_wave_unlocked")
				else Strings.get("notice_level_up", level)
			showBanner(Strings.get("hud_level", level) .. "!", subtitle)
		end
		knownLevel = level
	end

	for _, name in { "XP", "Coins" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	for _, name in { "QuestState", "QuestId", "QuestCount", "QuestGoal", "QuestNeedLevel", "DataState" } do
		player:GetAttributeChangedSignal(name):Connect(refreshQuest)
	end
	player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
	refreshStats()
	refreshQuest()
	onLevelChanged()

	Remotes:WaitForChild("RewardGranted").OnClientEvent:Connect(function(reason, xp, coins)
		if reason == "quest" then
			showToast(Strings.get("reward_quest", xp, coins), colors.good)
		else
			showToast(Strings.get("reward_purify", xp, coins))
		end
		if typeof(coins) == "number" then
			flyCoins(coins)
		end
	end)

	-- Reassure players after a defeat: nothing is ever lost.
	local firstCharacter = player.Character == nil
	player.CharacterAdded:Connect(function()
		if firstCharacter then
			firstCharacter = false
			return
		end
		task.delay(0.5, function()
			showToast(Strings.get("notice_respawn"), colors.good)
		end)
	end)
	Remotes:WaitForChild("Notice").OnClientEvent:Connect(function(key, ...)
		if typeof(key) == "string" then
			showToast(Strings.get(key, table.unpack(translateArgs(...))), colors.text)
		end
	end)
	Remotes:WaitForChild("NpcSay").OnClientEvent:Connect(function(npc, key, ...)
		if typeof(npc) == "string" and typeof(key) == "string" then
			showDialog(npc, Strings.get(key, table.unpack(translateArgs(...))))
		end
	end)
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, questId)
		if kind == "questComplete" then
			local def = QuestData.quests[questId]
			showBanner(Strings.get("banner_quest_complete"), if def then Strings.get(def.titleKey) else nil)
			Audio.play("questComplete")
		end
	end)

	-- Boss bar polling (the boss model is replaced on every respawn).
	local arena = WorldData.vector(WorldData.areas.arena.center)
	local bossStats = Balance.enemies.Warden
	bossName.Text = Strings.get(bossStats.nameKey)
	task.spawn(function()
		local enemies = workspace:WaitForChild("Enemies")
		while true do
			task.wait(0.25)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local boss: Instance? = nil
			for _, model in enemies:GetChildren() do
				if model:GetAttribute("Boss") and model:GetAttribute("Alive") then
					boss = model
					break
				end
			end
			local near = root ~= nil and (root.Position - arena).Magnitude <= bossStats.leashRadius + 30
			local show = boss ~= nil and near and boss:GetAttribute("Engaged") == true
			if show and not bossPanel.Visible then
				showBanner(Strings.get("banner_boss"), Strings.get("banner_boss_sub"))
			end
			bossPanel.Visible = show
			if show and boss then
				local hp = boss:GetAttribute("Hp") or 0
				local maxHp = boss:GetAttribute("MaxHp") or 1
				UiKit.tween(bossFill, 0.2, { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) })
			end
		end
	end)
end

return Hud
