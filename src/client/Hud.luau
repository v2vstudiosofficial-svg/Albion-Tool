local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local QuestData = require(Shared:WaitForChild("QuestData"))
local Balance = require(Shared:WaitForChild("Balance"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Progression = require(Shared:WaitForChild("Progression"))
local Goals = require(Shared:WaitForChild("Goals"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)
local Attrs = require(script.Parent.Attrs)
local Format = require(Shared:WaitForChild("Format"))
local CombatFeel = require(Shared:WaitForChild("CombatFeel"))
local MapLogic = require(Shared:WaitForChild("MapLogic"))
local CameraRig = require(script.Parent.CameraRig)
local Settings = require(script.Parent.Settings)

local PURIFY_TOAST_WINDOW = 1.2
-- Below this share of health the screen edges pulse red.
local LOW_HEALTH = 0.3
-- A hit must take at least this share of health to flash the screen edges.
local HIT_FLASH_FROM = 0.06
local HP_HIGH = Color3.fromRGB(110, 220, 120)
local HP_LOW = Color3.fromRGB(255, 90, 90)
local MAX_TOASTS = 4
-- The first time each boss joins a fight this session, the camera glides over to it for a moment.
local BOSS_INTRO_SECONDS = 1.4
local RAY_COUNT = 8 -- bars through the center, so twice as many rays
-- The streak counter appears from this many purifications in a row.
local STREAK_SHOWN_FROM = 3
-- Every hit shows a red chevron this far from the middle of the screen (where the hero is), pointing
-- to where it came from; it holds, then fades.
local HURT_ARROW_RADIUS = 120
local HURT_ARROW_HOLD = 0.35
local HURT_ARROW_FADE = 0.6
local MAX_HURT_ARROWS = 4
-- A new best Shadow Tower floor: the tower card glows this gold for a few seconds.
local RECORD_GOLD = Color3.fromRGB(255, 236, 140)
local RECORD_SECONDS = 3.5
local STREAK_COLORS = { { 50, Color3.fromRGB(255, 120, 200) }, { 25, Color3.fromRGB(255, 140, 70) }, { 10, Color3.fromRGB(255, 200, 80) } }

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local colors = UiKit.colors

local Hud = {}

local toastFunction: ((string, Color3?) -> ())? = nil
local bannerFunction: ((string, string?, string?) -> ())? = nil

-- Lets other client modules show a short toast once the HUD exists.
function Hud.toast(text: string, color: Color3?)
	if toastFunction then
		toastFunction(text, color)
	end
end

-- Lets other client modules show the middle banner (style "celebrate", "danger", "place" or nil).
function Hud.banner(title: string, subtitle: string?, style: string?)
	if bannerFunction then
		bannerFunction(title, subtitle, style)
	end
end

-- Notice arguments that are string keys (e.g. a charm name key) are translated before formatting.
local bossFighting = false
-- Bosses that reached their second phase (weak keys: boss models are replaced on respawn).
local enragedBosses: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local ENRAGED_COLOR = Color3.fromRGB(255, 80, 110)

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
	local topLeft = UiKit.region(gui, Vector2.new(0, 0), UDim2.fromOffset(12, 12), Vector2.new(240, 164))
	local topCenter = UiKit.region(gui, Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 12), Vector2.new(440, 300))
	local middle = UiKit.region(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.36), Vector2.new(460, 110))
	local bottom = UiKit.region(gui, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, if isTouch then -130 else -24), Vector2.new(460, 86))

	-- Roblox's own small health bar is replaced by the one on the player card.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)

	local card = UiKit.panel({ Size = UDim2.fromOffset(232, 112) }, topLeft)
	local badge = UiKit.create("Frame", {
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(60, 60),
		BackgroundColor3 = colors.accent,
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(badge, 30)
	local levelLabel = UiKit.label({ Size = UDim2.fromScale(1, 1), TextColor3 = colors.panel, TextSize = 22 }, badge)
	-- Shown under the level badge once the player has been reborn.
	local rebirthLabel = UiKit.label({
		Position = UDim2.fromOffset(4, 76),
		Size = UDim2.fromOffset(72, 22),
		TextSize = 13,
		TextColor3 = colors.accent,
		Visible = false,
	}, card)
	local function refreshRebirth()
		local count = player:GetAttribute("Rebirths") or 0
		rebirthLabel.Visible = count > 0
		rebirthLabel.Text = Strings.get("rebirth_hud", count)
	end
	player:GetAttributeChangedSignal("Rebirths"):Connect(refreshRebirth)
	refreshRebirth()
	-- Health: the main bar, green to red, with the numbers inside it.
	local hpBack = UiKit.create("Frame", {
		Name = "HealthBar",
		Position = UDim2.fromOffset(80, 10),
		Size = UDim2.fromOffset(140, 20),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(hpBack, 8)
	-- A pale trail shows the last hit before it drains away.
	local hpTrail = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 235, 200), BorderSizePixel = 0 }, hpBack)
	UiKit.corner(hpTrail, 8)
	local hpFill = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = HP_HIGH, BorderSizePixel = 0 }, hpBack)
	UiKit.corner(hpFill, 8)
	local hpLabel = UiKit.label({ Size = UDim2.fromScale(1, 1), TextSize = 14, TextStrokeTransparency = 0.4, ZIndex = 2 }, hpBack)
	local xpBack = UiKit.create("Frame", {
		Position = UDim2.fromOffset(80, 35),
		Size = UDim2.fromOffset(140, 8),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(xpBack, 4)
	local xpFill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.xp, BorderSizePixel = 0 }, xpBack)
	UiKit.corner(xpFill, 4)
	local xpLabel = UiKit.label({
		Position = UDim2.fromOffset(80, 44),
		Size = UDim2.fromOffset(140, 16),
		TextSize = 13,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)
	local coinIcon = UiKit.create("Frame", {
		Position = UDim2.fromOffset(80, 64),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = colors.coin,
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(coinIcon, 9)
	UiKit.create("UIStroke", { Color = Color3.fromRGB(170, 110, 20), Thickness = 2 }, coinIcon)
	local coinsLabel = UiKit.label({
		Position = UDim2.fromOffset(104, 60),
		Size = UDim2.fromOffset(110, 26),
		TextColor3 = colors.coin,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	-- Light Crystal pouch: carried / capacity; turns into coins at the Great Lantern.
	local crystalIcon = UiKit.create("Frame", {
		Position = UDim2.fromOffset(82, 91),
		Size = UDim2.fromOffset(15, 15),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(150, 210, 255),
		BorderSizePixel = 0,
	}, card)
	UiKit.corner(crystalIcon, 3)
	local crystalsLabel = UiKit.label({
		Position = UDim2.fromOffset(104, 86),
		Size = UDim2.fromOffset(110, 24),
		TextColor3 = Color3.fromRGB(150, 210, 255),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, card)

	-- Team bonus: shown while other players are close by (the server applies the same rule).
	local teamLabel = UiKit.label({
		Position = UDim2.fromOffset(4, 118),
		Size = UDim2.fromOffset(120, 20),
		TextSize = 16,
		TextColor3 = colors.good,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		Visible = false,
	}, topLeft)
	-- What the next level milestone opens, so there is always something just ahead.
	local nextUnlockLabel = UiKit.label({
		Name = "NextUnlock",
		Position = UDim2.fromOffset(4, 140),
		Size = UDim2.fromOffset(236, 20),
		TextSize = 14,
		TextColor3 = colors.accent,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		Visible = false,
	}, topLeft)
	local function refreshNextUnlock()
		local level = player:GetAttribute("Level")
		local nextUnlock = if typeof(level) == "number" and player:GetAttribute("DataState") == "ready" then Progression.nextUnlock(level) else nil
		nextUnlockLabel.Visible = nextUnlock ~= nil
		if nextUnlock then
			local name = if nextUnlock.arg then Strings.get(nextUnlock.key, nextUnlock.arg) else Strings.get(nextUnlock.key)
			nextUnlockLabel.Text = Strings.get("hud_next_unlock", nextUnlock.level, name)
		end
	end
	player:GetAttributeChangedSignal("Level"):Connect(refreshNextUnlock)
	player:GetAttributeChangedSignal("DataState"):Connect(refreshNextUnlock)
	refreshNextUnlock()
	-- Double XP time left (store boost), next to the team bonus.
	local boostLabel = UiKit.label({
		Position = UDim2.fromOffset(126, 118),
		Size = UDim2.fromOffset(106, 20),
		TextSize = 16,
		TextColor3 = colors.xp,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.4,
		Visible = false,
	}, topLeft)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local left = math.floor((player:GetAttribute("BoostUntil") or 0) - workspace:GetServerTimeNow())
			boostLabel.Visible = left > 0
			if left > 0 then
				boostLabel.Text = Strings.get("hud_boost", left // 60, left % 60)
			end
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local allies = 0
			if root then
				for _, other in Players:GetPlayers() do
					local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
					if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Balance.coop.radius then
						allies += 1
					end
				end
			end
			local bonus = Progression.coopMultiplier(allies) - 1
			teamLabel.Visible = bonus > 0
			teamLabel.Text = Strings.get("hud_team_bonus", math.floor(bonus * 100 + 0.5))
		end
	end)

	-- Quest panel ---------------------------------------------------------------------------
	local quest = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(340, 72),
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
	-- A finished quest: a green tick pops on the panel's right edge and the outline flashes green.
	local questTick = UiKit.label({
		Name = "QuestTick",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = colors.good,
		BackgroundTransparency = 0,
		Text = "✓",
		TextSize = 28,
		TextColor3 = colors.panel,
		Visible = false,
		ZIndex = 3,
	}, quest)
	UiKit.corner(questTick, 20)
	local questStroke = quest:FindFirstChildOfClass("UIStroke")
	local tickToken = 0
	local function celebrateQuest()
		tickToken += 1
		local token = tickToken
		questTick.Visible = true
		UiKit.pop(questTick)
		if questStroke then
			questStroke.Color = colors.good
			questStroke.Transparency = 0
		end
		task.delay(2, function()
			if tickToken == token then
				questTick.Visible = false
				if questStroke then
					questStroke.Color = colors.accent
					questStroke.Transparency = 0.35
				end
			end
		end)
	end
	-- Counting quests ("purify 5 Gloomlings") fill a thin bar under the objective.
	local questBar = UiKit.create("Frame", {
		Name = "QuestBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -7),
		Size = UDim2.new(1, -48, 0, 5),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
		Visible = false,
	}, quest)
	UiKit.corner(questBar, 3)
	local questFill = UiKit.create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.accent, BorderSizePixel = 0 }, questBar)
	UiKit.corner(questFill, 3)

	-- Boss bar ------------------------------------------------------------------------------
	local bossPanel = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.fromOffset(420, 46),
		Visible = false,
	}, topCenter)
	local bossName = UiKit.label({ Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -24, 0, 20), TextSize = 17, TextColor3 = colors.boss }, bossPanel)
	local bossPercent = UiKit.label({
		Name = "BossPercent",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 2),
		Size = UDim2.fromOffset(60, 20),
		TextSize = 15,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, bossPanel)
	local bossBack = UiKit.create("Frame", {
		Position = UDim2.fromOffset(12, 24),
		Size = UDim2.new(1, -24, 0, 14),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, bossPanel)
	UiKit.corner(bossBack, 7)
	local bossTrail = UiKit.create("Frame", { Name = "Trail", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 235, 255), BorderSizePixel = 0 }, bossBack)
	UiKit.corner(bossTrail, 7)
	local bossFill = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = colors.boss, BorderSizePixel = 0 }, bossBack)
	UiKit.corner(bossFill, 7)

	-- Toasts, banner, dialog ----------------------------------------------------------------
	local toasts = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 134),
		Size = UDim2.fromOffset(440, 170),
		BackgroundTransparency = 1,
	}, topCenter)
	UiKit.create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, toasts)

	local banner = UiKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, middle)
	-- Behind the words: a dark ribbon that fades out at both ends, and for happy moments a slowly
	-- turning fan of light rays; danger banners tint the ribbon purple instead.
	local rays = UiKit.create("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 46),
		Size = UDim2.fromOffset(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, banner)
	for index = 1, RAY_COUNT do
		-- GUI objects turn around their own middle, so each bar is centered and fades toward both tips.
		local ray = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if index % 2 == 0 then 16 else 28, 420),
			Rotation = (index - 1) * 180 / RAY_COUNT,
			BackgroundColor3 = colors.accent,
			BorderSizePixel = 0,
		}, rays)
		UiKit.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.5),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, ray)
	end
	local ribbon = UiKit.create("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		Size = UDim2.new(1, 120, 0, 96),
		BackgroundColor3 = Color3.fromRGB(25, 20, 45),
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
	}, banner)
	UiKit.create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0),
			NumberSequenceKeypoint.new(0.8, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, ribbon)
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
	local shownLevel: number? = nil
	local shownCoins: number? = nil
	local function refreshStats()
		local xp = player:GetAttribute("XP") or 0
		local level, into, span = Progression.levelProgress(xp)
		levelLabel.Text = Strings.get("hud_level", level)
		-- The badge pops on a level-up and the coin count on a gain (not when the game first loads).
		if shownLevel and level > shownLevel then
			UiKit.pop(badge)
		end
		shownLevel = level
		local coinCount = player:GetAttribute("Coins") or 0
		if shownCoins and coinCount > shownCoins then
			UiKit.pop(coinsLabel)
		end
		shownCoins = coinCount
		if span then
			xpLabel.Text = Strings.get("hud_xp", Format.short(into), Format.short(span))
			UiKit.tween(xpFill, 0.3, { Size = UDim2.fromScale(math.clamp(into / span, 0, 1), 1) })
		else
			xpLabel.Text = Strings.get("hud_xp_max")
			xpFill.Size = UDim2.fromScale(1, 1)
		end
		coinsLabel.Text = Strings.get("hud_coins", Format.short(player:GetAttribute("Coins") or 0))
		local capacity = Attrs.stats().pouchCapacity
		local crystals = player:GetAttribute("Crystals") or 0
		crystalsLabel.Text = Strings.get("hud_crystals", Format.short(crystals), Format.short(capacity))
		crystalsLabel.TextColor3 = if crystals >= capacity then colors.bad else Color3.fromRGB(150, 210, 255)
	end

	-- Shadow Tower: inside, this card takes the quest panel's place - the floor, the best floor, how
	-- far the next boss is and how many shadows still stand. A new best floor lights it up gold.
	local towerCard = UiKit.panel({
		Name = "TowerCard",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(340, 72),
		Visible = false,
	}, topCenter)
	local towerStroke = towerCard:FindFirstChildOfClass("UIStroke")
	UiKit.label({ Position = UDim2.fromOffset(6, 0), Size = UDim2.new(0, 46, 1, 0), Text = Strings.get("icon_tower"), TextSize = 32 }, towerCard)
	local towerFloorLabel = UiKit.label({ Position = UDim2.fromOffset(56, 8), Size = UDim2.new(1, -136, 0, 30), TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left }, towerCard)
	local towerSub = UiKit.label({ Position = UDim2.fromOffset(56, 42), Size = UDim2.new(1, -136, 0, 20), TextSize = 14, TextXAlignment = Enum.TextXAlignment.Left }, towerCard)
	local leftBox = UiKit.create("Frame", { Name = "Left", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(70, 56), BackgroundColor3 = colors.panelLight, BorderSizePixel = 0 }, towerCard)
	UiKit.corner(leftBox, 12)
	local leftCount = UiKit.label({ Name = "Count", Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 30), TextSize = 26 }, leftBox)
	local leftCaption = UiKit.label({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 16), TextSize = 12, TextColor3 = colors.muted }, leftBox)
	local shownLeft: number? = nil
	local knownBest = player:GetAttribute("TowerBest") or 0
	local recordToken = 0
	local recordShowing = false
	local function refreshTower()
		local floor = player:GetAttribute("TowerFloor") or 0
		towerCard.Visible = floor > 0 and not bossFighting
		if floor <= 0 then
			shownLeft = nil
			return
		end
		towerFloorLabel.Text = Strings.get("tower_floor", floor)
		local untilBoss = (-floor) % Balance.tower.bossEvery
		if recordShowing then
			towerSub.Text = Strings.get("tower_card_record")
			towerSub.TextColor3 = RECORD_GOLD
		else
			local bossText = if untilBoss == 0 then Strings.get("tower_card_boss_now") elseif untilBoss == 1 then Strings.get("tower_card_boss_next") else Strings.get("tower_card_boss_in", untilBoss)
			towerSub.Text = Strings.get("tower_card_best", player:GetAttribute("TowerBest") or 0) .. "   ·   " .. bossText
			towerSub.TextColor3 = if untilBoss <= 1 then colors.bad else colors.muted
		end
		-- Nothing to count before the first floor's shadows arrive.
		local left = player:GetAttribute("TowerLeft")
		leftBox.Visible = typeof(left) == "number"
		if typeof(left) ~= "number" then
			shownLeft = nil
			return
		end
		leftCount.Text = if left > 0 then tostring(left) else "✓"
		leftCount.TextColor3 = if left > 0 then colors.text else colors.good
		leftCaption.Text = if left > 0 then Strings.get("tower_card_left") else Strings.get("tower_card_clear")
		if shownLeft and left ~= shownLeft then
			UiKit.pop(leftBox)
		end
		shownLeft = left
	end
	player:GetAttributeChangedSignal("TowerLeft"):Connect(refreshTower)
	player:GetAttributeChangedSignal("TowerBest"):Connect(function()
		local best = player:GetAttribute("TowerBest") or 0
		if best > knownBest and (player:GetAttribute("TowerFloor") or 0) > 0 then
			recordToken += 1
			local token = recordToken
			recordShowing = true
			UiKit.pop(towerCard)
			if towerStroke then
				towerStroke.Color, towerStroke.Thickness, towerStroke.Transparency = RECORD_GOLD, 5, 0
				UiKit.tween(towerStroke, RECORD_SECONDS, { Color = colors.accent, Thickness = 2, Transparency = 0.35 })
			end
			task.delay(RECORD_SECONDS, function()
				if recordToken == token then
					recordShowing = false
					refreshTower()
				end
			end)
		end
		knownBest = best
		refreshTower()
	end)

	local lastQuestText = ""
	local function refreshQuest()
		local ready = player:GetAttribute("DataState") == "ready"
		-- During a boss fight the boss bar takes the top spot (the camera looks north, so anything
		-- tall up there would cover the boss itself); inside the Shadow Tower its card does.
		quest.Visible = ready and not bossFighting and (player:GetAttribute("TowerFloor") or 0) <= 0
		refreshTower()
		card.Visible = ready
		local state = player:GetAttribute("QuestState")
		local def = QuestData.quests[player:GetAttribute("QuestId") or ""]
		local title, text = "", ""
		if state == "active" and def then
			title = Strings.get(def.titleKey)
			text = Strings.get(def.objectiveKey, player:GetAttribute("QuestCount") or 0, player:GetAttribute("QuestGoal") or 0)
		elseif state == "available" and def then
			title = Strings.get(def.titleKey)
			text = Strings.get("quest_talk_to", Strings.get(WorldData.npcs[def.giver or "Elder"].nameKey))
		elseif state == "level" then
			title = if def then Strings.get(def.titleKey) else ""
			text = Strings.get("quest_need_level", player:GetAttribute("QuestNeedLevel") or 0)
		elseif state == "done" then
			local goal = Goals.next(player:GetAttribute("XP") or 0, player:GetAttribute("Coins") or 0, player:GetAttribute("StaffTier") or 0)
			title = Strings.get("goal_title")
			if goal.kind == "staff" and goal.affordable then
				text = Strings.get("goal_staff_ready", goal.target)
			elseif goal.kind == "staff" then
				text = Strings.get("goal_staff_coins", goal.target, goal.missing)
			elseif goal.kind == "level" then
				text = Strings.get("goal_level", goal.target, goal.current)
			else
				text = Strings.get("goal_all")
			end
		end
		questTitle.Text = title
		questLabel.Text = text
		local goal = player:GetAttribute("QuestGoal") or 0
		local counting = state == "active" and typeof(goal) == "number" and goal > 1
		questBar.Visible = counting
		if counting then
			local done = math.clamp((player:GetAttribute("QuestCount") or 0) / goal, 0, 1)
			UiKit.tween(questFill, 0.25, { Size = UDim2.fromScale(done, 1) })
			questFill.BackgroundColor3 = if done >= 1 then colors.good else colors.accent
		end
		-- Post-story goal numbers tick with every kill; only quest changes deserve the pop.
		if text ~= lastQuestText and lastQuestText ~= "" and state ~= "done" then
			UiKit.pop(quest)
		end
		lastQuestText = text
	end

	-- Toasts are small pills under the quest panel: the newest at the bottom, at most MAX_TOASTS at
	-- once, and the same text again bumps a counter instead of stacking a copy.
	local toastOrder = 0
	local liveToasts: { { text: string, pill: Frame, label: TextLabel, count: number, token: number } } = {}
	local function dropToast(entry)
		local index = table.find(liveToasts, entry)
		if index then
			table.remove(liveToasts, index)
		end
		entry.pill.Name = "ToastLeaving"
		UiKit.tween(entry.pill, 0.3, { BackgroundTransparency = 1 })
		UiKit.tween(entry.label, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Connect(function()
			entry.pill:Destroy()
		end)
	end
	local function scheduleDrop(entry)
		entry.token += 1
		local token = entry.token
		task.delay(2.6, function()
			if entry.token == token and table.find(liveToasts, entry) then
				-- A banner hides the toasts; keep this one until it has been seen.
				if banner.Visible then
					scheduleDrop(entry)
				else
					dropToast(entry)
				end
			end
		end)
	end
	local function showToast(text: string, color: Color3?)
		for _, entry in liveToasts do
			if entry.text == text then
				entry.count += 1
				entry.label.Text = text .. "  x" .. entry.count
				UiKit.pop(entry.pill)
				scheduleDrop(entry)
				return
			end
		end
		toastOrder += 1
		local pill = UiKit.create("Frame", {
			Name = "Toast",
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			BackgroundColor3 = colors.panel,
			BackgroundTransparency = 0.2,
			BorderSizePixel = 0,
			LayoutOrder = toastOrder,
		}, toasts)
		UiKit.corner(pill, 17)
		UiKit.create("UIPadding", { PaddingLeft = UDim.new(0, 26), PaddingRight = UDim.new(0, 14) }, pill)
		-- A colored dot on the left says what kind of news it is.
		local dot = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, -16, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			BackgroundColor3 = color or colors.accent,
			BorderSizePixel = 0,
		}, pill)
		UiKit.corner(dot, 5)
		local label = UiKit.label({
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.fromOffset(0, 34),
			Text = text,
			TextSize = 20,
			TextColor3 = color or colors.accent,
			TextStrokeTransparency = 0.6,
		}, pill)
		local entry = { text = text, pill = pill, label = label, count = 1, token = 0 }
		table.insert(liveToasts, entry)
		while #liveToasts > MAX_TOASTS do
			dropToast(liveToasts[1])
		end
		UiKit.pop(pill)
		scheduleDrop(entry)
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
	-- style: "celebrate" (gold rays), "danger" (purple ribbon) or nil (plain ribbon).
	local function showBanner(title: string, subtitle: string?, style: string?)
		bannerToken += 1
		local token = bannerToken
		bannerTitle.Text = title
		bannerSub.Text = subtitle or ""
		rays.Visible = style == "celebrate"
		ribbon.BackgroundColor3 = if style == "danger" then Color3.fromRGB(60, 20, 70) else Color3.fromRGB(25, 20, 45)
		bannerTitle.TextColor3 = if style == "danger" then Color3.fromRGB(230, 170, 255) elseif style == "place" then Color3.fromRGB(255, 240, 210) else colors.accent
		banner.Visible = true
		-- Toasts sit right under the quest panel, where the banner's ribbon would cross them.
		toasts.Visible = false
		UiKit.pop(banner)
		task.delay(2.2, function()
			if bannerToken == token then
				banner.Visible = false
				toasts.Visible = true
				-- Whatever arrived under the banner gets its full time on screen now.
				for _, entry in liveToasts do
					scheduleDrop(entry)
				end
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

	bannerFunction = showBanner

	local knownLevel: number? = nil
	local function onLevelChanged()
		local level = player:GetAttribute("Level")
		if typeof(level) ~= "number" then
			return
		end
		if knownLevel and level > knownLevel then
			local subtitle = Strings.get("notice_level_up", level)
			if not Progression.waveUnlocked(knownLevel) and Progression.waveUnlocked(level) then
				subtitle = Strings.get("notice_wave_unlocked")
			end
			for id, key in { star = "notice_star_unlocked", heal = "notice_heal_unlocked" } do
				if not Progression.abilityUnlocked(id, knownLevel) and Progression.abilityUnlocked(id, level) then
					subtitle = Strings.get(key)
				end
			end
			showBanner(Strings.get("hud_level", level) .. "!", subtitle, "celebrate")
		end
		knownLevel = level
	end

	for _, name in { "XP", "Coins", "Crystals", "Upgrades" } do
		player:GetAttributeChangedSignal(name):Connect(refreshStats)
	end
	for _, name in { "QuestState", "QuestId", "QuestCount", "QuestGoal", "QuestNeedLevel", "DataState", "TowerFloor" } do
		player:GetAttributeChangedSignal(name):Connect(refreshQuest)
	end
	-- Progress numbers only matter for the post-story goal line.
	for _, name in { "XP", "Coins", "StaffTier" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if player:GetAttribute("QuestState") == "done" then
				refreshQuest()
			end
		end)
	end
	player:GetAttributeChangedSignal("Level"):Connect(onLevelChanged)
	refreshStats()
	refreshQuest()
	onLevelChanged()

	-- Purify streak: chained purifications count up under the player, warmer with every milestone;
	-- the counter leaves once the chain breaks (cosmetic, nothing is rewarded for it).
	local streakRegion = UiKit.region(gui, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -120), Vector2.new(220, 70))
	local streakCount = UiKit.label({
		Name = "StreakCount",
		Size = UDim2.new(1, 0, 0, 46),
		TextSize = 44,
		TextColor3 = colors.accent,
		TextStrokeTransparency = 0.1,
		TextStrokeColor3 = Color3.fromRGB(90, 50, 20),
		Visible = false,
	}, streakRegion)
	local streakLabel = UiKit.label({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		Text = Strings.get("hud_streak_label"),
		TextStrokeTransparency = 0.3,
		Visible = false,
	}, streakRegion)
	local streak = CombatFeel.newStreak()
	local function addToStreak(amount: number)
		local count, milestone = CombatFeel.add(streak, os.clock(), amount)
		if count < STREAK_SHOWN_FROM then
			return
		end
		streakCount.Text = Strings.get("hud_streak", count)
		local color = colors.accent
		for _, step in STREAK_COLORS do
			if count >= step[1] then
				color = step[2]
				break
			end
		end
		streakCount.TextColor3 = color
		streakCount.Visible, streakLabel.Visible = true, true
		UiKit.pop(streakCount)
		if milestone then
			showToast(Strings.get("notice_streak", milestone), color)
		end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			if streakCount.Visible and not CombatFeel.alive(streak, os.clock()) then
				streakCount.Visible, streakLabel.Visible = false, false
			end
		end
	end)

	-- Auto-battle purifies whole packs at once, so purify rewards are summed into one toast.
	local pendingXp, pendingCount, flushScheduled = 0, 0, false
	local function flushPurifies()
		flushScheduled = false
		if pendingCount == 1 then
			showToast(Strings.get("reward_purify", Format.short(pendingXp)))
		elseif pendingCount > 1 then
			showToast(Strings.get("reward_purify_many", pendingCount, Format.short(pendingXp)))
		end
		pendingXp, pendingCount = 0, 0
	end
	Remotes:WaitForChild("RewardGranted").OnClientEvent:Connect(function(reason, xp, coins)
		if reason == "quest" then
			showToast(Strings.get("reward_quest", xp, coins), colors.good)
		else
			pendingXp += if typeof(xp) == "number" then xp else 0
			pendingCount += 1
			if reason == "purify" then
				addToStreak(1)
			end
			if not flushScheduled then
				flushScheduled = true
				task.delay(PURIFY_TOAST_WINDOW, flushPurifies)
			end
		end
		if typeof(coins) == "number" then
			flyCoins(coins)
		end
	end)

	-- Defeat: the screen dims, says what happened, counts down to waking up in the village and
	-- gives one useful tip. It leaves as soon as the new character arrives.
	local DEFEAT_TIPS = { "defeat_tip_heal", "defeat_tip_level", "defeat_tip_weapons" }
	local defeatGui = UiKit.create("ScreenGui", { Name = "Defeat", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Enabled = false }, gui.Parent)
	local defeatShade = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 8, 30), BackgroundTransparency = 1, BorderSizePixel = 0 }, defeatGui)
	local defeatRegion = UiKit.region(defeatGui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.45), Vector2.new(520, 150))
	UiKit.label({ Size = UDim2.new(1, 0, 0, 56), Text = Strings.get("defeat_title"), TextSize = 46, TextColor3 = Color3.fromRGB(230, 170, 255), TextStrokeTransparency = 0.2 }, defeatRegion)
	local defeatCountdown = UiKit.label({ Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 30), TextSize = 24, TextStrokeTransparency = 0.3 }, defeatRegion)
	local defeatTip = UiKit.label({ Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 44), TextSize = 18, TextWrapped = true, TextColor3 = colors.accent, TextStrokeTransparency = 0.4 }, defeatRegion)
	local defeatedCharacter: Model? = nil
	local defeatedAt = 0
	local tipIndex = 0
	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health <= 0 and defeatedCharacter ~= character then
			defeatedCharacter, defeatedAt = character, os.clock()
			tipIndex = tipIndex % #DEFEAT_TIPS + 1
			defeatTip.Text = Strings.get(DEFEAT_TIPS[tipIndex])
			defeatShade.BackgroundTransparency = 1
			UiKit.tween(defeatShade, 0.6, { BackgroundTransparency = 0.45 })
			defeatGui.Enabled = true
			UiKit.pop(defeatRegion)
		elseif defeatGui.Enabled and (character ~= defeatedCharacter or (humanoid and humanoid.Health > 0)) then
			defeatGui.Enabled = false
		end
		if defeatGui.Enabled then
			local left = math.max(1, math.ceil(Balance.player.respawnTime - (os.clock() - defeatedAt)))
			defeatCountdown.Text = Strings.get("defeat_countdown", left)
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
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, first, second, ...)
		local purified = if kind == "purify" and typeof(second) == "string" then Balance.enemies[second] else nil
		if purified and purified.isBoss and typeof(first) == "Vector3" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and (root.Position - first).Magnitude <= purified.leashRadius + 30 then
				showBanner(Strings.get("banner_boss_down", Strings.get(purified.nameKey)), Strings.get("banner_boss_down_sub"), "celebrate")
			end
		elseif kind == "towerFloor" and typeof(first) == "number" and typeof(second) == "number" then
			local bossKey = select(1, ...)
			local subtitle = if typeof(bossKey) == "string" then Strings.get("tower_floor_boss", Strings.get(bossKey)) else Strings.get("tower_floor_sub", second)
			showBanner(Strings.get("tower_floor", first), subtitle, if typeof(bossKey) == "string" then "danger" else nil)
		elseif kind == "riftWave" then
			-- first = zone id, second = rift center; wave numbers follow.
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and typeof(second) == "Vector3" and (root.Position - second).Magnitude <= 90 then
				showBanner(Strings.get("banner_rift"), Strings.get("banner_rift_wave", select(1, ...), select(2, ...)), "danger")
			end
		elseif kind == "bossPhase" and typeof(first) == "Instance" then
			-- The boss enters its second phase: warn, and turn its bar an angry red.
			local stats = Balance.enemies[first:GetAttribute("EnemyType") or ""]
			local body = first:FindFirstChild("Body") :: BasePart?
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if stats and body and root and (root.Position - body.Position).Magnitude <= stats.leashRadius + 30 then
				showBanner(Strings.get("banner_boss_enraged", Strings.get(stats.nameKey)), Strings.get("banner_boss_enraged_sub"), "danger")
				enragedBosses[first] = true
			end
		elseif kind == "questComplete" then
			local def = QuestData.quests[first]
			showBanner(Strings.get("banner_quest_complete"), if def then Strings.get(def.titleKey) else nil, "celebrate")
			celebrateQuest()
			Audio.play("questComplete")
		end
	end)

	-- Health ------------------------------------------------------------------------------------
	-- The card's bar follows the character every frame (cheap: it only redraws on a change). A hit
	-- flashes the screen edges red and leaves a pale trail on the bar; below LOW_HEALTH the edges
	-- keep pulsing until the player heals.
	local edgesGui = UiKit.create("ScreenGui", { Name = "HealthEdges", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = -1 }, gui.Parent)
	local edges: { Frame } = {}
	for _, side in { { 0.5, 0, 1, 0.2, 90 }, { 0.5, 1, 1, 0.2, -90 }, { 0, 0.5, 0.13, 1, 0 }, { 1, 0.5, 0.13, 1, 180 } } do
		local edge = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(side[1], side[2]),
			Position = UDim2.fromScale(side[1], side[2]),
			Size = UDim2.fromScale(side[3], side[4]),
			BackgroundColor3 = Color3.fromRGB(200, 20, 30),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
		}, edgesGui)
		UiKit.create("UIGradient", { Rotation = side[5], Transparency = NumberSequence.new(0, 1) }, edge)
		table.insert(edges, edge)
	end
	local liveArrows = 0
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, from)
		local camera = workspace.CurrentCamera
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if kind ~= "hurt" or typeof(from) ~= "Vector3" or not camera or not root or liveArrows >= MAX_HURT_ARROWS then
			return
		end
		local offset = from - root.Position
		if Vector3.new(offset.X, 0, offset.Z).Magnitude < 1 then
			return -- right on top of the hero: no direction to show
		end
		local look = camera.CFrame.LookVector
		local angle = (MapLogic.heading(offset.X, offset.Z) - MapLogic.heading(look.X, look.Z)) % 360
		local radius = HURT_ARROW_RADIUS * UiKit.screenScale()
		local arrow = UiKit.label({
			Name = "HurtArrow",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, math.sin(math.rad(angle)) * radius, 0.5, -math.cos(math.rad(angle)) * radius),
			Size = UDim2.fromOffset(48, 32),
			Rotation = angle,
			Text = "▲",
			TextSize = 34,
			TextColor3 = Color3.fromRGB(255, 70, 70),
			TextStrokeTransparency = 0.3,
		}, edgesGui)
		liveArrows += 1
		task.delay(HURT_ARROW_HOLD, function()
			UiKit.tween(arrow, HURT_ARROW_FADE, { TextTransparency = 1, TextStrokeTransparency = 1 }).Completed:Connect(function()
				liveArrows -= 1
				arrow:Destroy()
			end)
		end)
	end)
	local shownHp, shownMax = -1, -1
	local flash = 0
	local trailToken = 0
	local clock = 0
	RunService.Heartbeat:Connect(function(dt)
		clock += dt
		if rays.Visible and banner.Visible then
			rays.Rotation = (rays.Rotation + dt * 25) % 360
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local hp, maxHp = math.max(0, humanoid.Health), math.max(1, humanoid.MaxHealth)
		local ratio = math.clamp(hp / maxHp, 0, 1)
		if hp ~= shownHp or maxHp ~= shownMax then
			local lost = if shownHp >= 0 and maxHp == shownMax then (shownHp - hp) / maxHp else 0
			local hurt = lost > 0.02
			hpLabel.Text = Strings.get("hud_hp", Format.short(math.ceil(hp)), Format.short(math.ceil(maxHp)))
			hpFill.BackgroundColor3 = HP_LOW:Lerp(HP_HIGH, math.clamp((ratio - 0.15) / 0.6, 0, 1))
			UiKit.tween(hpFill, 0.12, { Size = UDim2.fromScale(ratio, 1) })
			trailToken += 1
			if hurt then
				-- Only real hits flash the edges, and in proportion: chip damage in a long fight must
				-- not keep the whole screen red.
				if lost >= HIT_FLASH_FROM then
					flash = math.max(flash, math.min(0.55, lost * 4))
				end
				local token = trailToken
				task.delay(0.35, function()
					if trailToken == token then
						UiKit.tween(hpTrail, 0.4, { Size = UDim2.fromScale(ratio, 1) })
					end
				end)
			else
				hpTrail.Size = UDim2.fromScale(ratio, 1)
			end
			shownHp, shownMax = hp, maxHp
		end
		flash = math.max(0, flash - dt * 1.6)
		local low = ratio < LOW_HEALTH and hp > 0
		local strength
		if Settings.get("flashes") then
			strength = math.max(flash, if low then 0.4 + 0.15 * math.sin(clock * 5) else 0)
		else
			-- No flashing at all: low health is a calm, steady edge.
			strength = if low then 0.3 else 0
		end
		for _, edge in edges do
			edge.BackgroundTransparency = 1 - strength
		end
	end)

	-- Boss bar polling: the nearest engaged boss (boss models are replaced on every respawn).
	local shownBoss: Instance? = nil
	local introduced: { [string]: boolean } = {}
	task.spawn(function()
		local enemies = workspace:WaitForChild("Enemies")
		while true do
			task.wait(0.25)
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local boss: Model? = nil
			local bossStats = nil
			for _, model in enemies:GetChildren() do
				local stats = Balance.enemies[model:GetAttribute("EnemyType") or ""]
				local body = model:FindFirstChild("Body") :: BasePart?
				if root and body and stats and model:GetAttribute("Boss") and model:GetAttribute("Alive") and model:GetAttribute("Engaged") then
					if (root.Position - body.Position).Magnitude <= stats.leashRadius + 30 then
						boss, bossStats = model :: Model, stats
						break
					end
				end
			end
			local show = boss ~= nil
			if boss and bossStats then
				bossName.Text = Strings.get("enemy_label", boss:GetAttribute("Level") or 1, Strings.get(bossStats.nameKey))
				if not bossPanel.Visible or shownBoss ~= boss then
					showBanner(Strings.get("banner_boss", Strings.get(bossStats.nameKey)), Strings.get("banner_boss_sub"), "danger")
					local kind = boss:GetAttribute("EnemyType")
					local body = boss:FindFirstChild("Body") :: BasePart?
					if kind and body and not introduced[kind] and Settings.get("cinematics") and not CameraRig.currentShot() then
						introduced[kind] = true
						local focus = body.Position + Vector3.new(0, bossStats.size * 0.3, 0)
						local intro = { from = focus + Vector3.new(0, bossStats.size * 0.8 + 6, bossStats.size * 1.6 + 14), focus = focus, fov = 45 }
						CameraRig.setShot(intro)
						task.delay(BOSS_INTRO_SECONDS, function()
							if CameraRig.currentShot() == intro then
								CameraRig.setShot(nil)
							end
						end)
					end
				end
			end
			shownBoss = boss
			bossPanel.Visible = show
			if bossFighting ~= show then
				bossFighting = show
				refreshQuest()
			end
			if show and boss then
				local hp = boss:GetAttribute("Hp") or 0
				local maxHp = boss:GetAttribute("MaxHp") or 1
				local ratio = math.clamp(hp / maxHp, 0, 1)
				UiKit.tween(bossFill, 0.2, { Size = UDim2.fromScale(ratio, 1) })
				bossFill.BackgroundColor3 = if enragedBosses[boss] then ENRAGED_COLOR else colors.boss
				bossPercent.Text = Strings.get("hud_percent", math.ceil(ratio * 100))
				-- The trail waits a moment at the old value before draining, so big hits read.
				if ratio >= bossTrail.Size.X.Scale then
					bossTrail.Size = UDim2.fromScale(ratio, 1)
				else
					task.delay(0.35, function()
						UiKit.tween(bossTrail, 0.4, { Size = UDim2.fromScale(ratio, 1) })
					end)
				end
			end
		end
	end)
end

return Hud
