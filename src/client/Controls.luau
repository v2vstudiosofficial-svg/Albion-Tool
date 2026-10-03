-- Ability input with cooldown displays. Weapons attack automatically (server-side), so the
-- abilities are the only buttons: Light Wave (Q), Star Fall (R) and Lantern Glow (F), each
-- unlocked at its own level. Touch: ContextActionService buttons appear immediately; once
-- Roblox's jump button exists, big custom buttons placed around it replace them (and follow it
-- if it is rebuilt on resize). Keyboard/mouse gets an ability bar in the bottom-right corner.
-- The server re-validates every cast.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Progression = require(Shared:WaitForChild("Progression"))
local Strings = require(Shared:WaitForChild("Strings"))
local Effects = require(script.Parent.Effects)
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)
local Cinematic = require(script.Parent.Cinematic)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestWave = Remotes:WaitForChild("RequestWave") :: RemoteEvent
local requestAbility = Remotes:WaitForChild("RequestAbility") :: RemoteEvent

local player = Players.LocalPlayer
local colors = UiKit.colors

-- A ready ability that would help right now beats gently: Lantern Glow at or below this share of
-- health, Light Wave with at least this many creatures in its reach (checked a few times a second).
local HEAL_HINT_SHARE = 0.4
local WAVE_HINT_CREATURES = 3
local HINT_CHECK_SECONDS = 0.25

-- Last cast per ability (local prediction; the server keeps its own).
local lastUse: { [string]: number } = {}
-- The ability buttons' containers, hidden while a full scene plays (they would sit under Skip).
local hideDuringScenes: { Instance } = {}

local Controls = {}

local function localCharacter(): (BasePart?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function waveStats()
	return Progression.waveStats(
		Attrs.get("StaffTier", 0),
		Attrs.get("Level", 1),
		Attrs.get("Charm", "") ~= "" and Attrs.get("Charm", "") or nil,
		Attrs.stats().waveRank
	)
end

local function unlockLevel(id: string): number
	return if id == "wave" then Balance.wave.unlockLevel else Balance.abilities[id].unlockLevel
end

local function cooldownOf(id: string): number
	return if id == "wave" then waveStats().cooldown else Balance.abilities[id].cooldown
end

local function ready(id: string): boolean
	if Cinematic.blocking() or Attrs.get("Level", 1) < unlockLevel(id) then
		return false
	end
	return os.clock() - (lastUse[id] or -math.huge) >= cooldownOf(id)
end

-- How many living creatures are within `range` of `from` (counting stops at `enough`).
local function creaturesNear(from: Vector3, range: number, enough: number): number
	local count = 0
	local enemies = workspace:FindFirstChild("Enemies")
	for _, model in if enemies then enemies:GetChildren() else {} do
		local body = model:FindFirstChild("Body") :: BasePart?
		if body and model:GetAttribute("Alive") then
			local offset = body.CFrame.Position - from
			if Vector3.new(offset.X, 0, offset.Z).Magnitude <= range then
				count += 1
				if count >= enough then
					break
				end
			end
		end
	end
	return count
end

-- Whether there is a living creature Star Fall could hit.
local function hasTargetNear(from: Vector3, range: number): boolean
	return creaturesNear(from, range, 1) > 0
end

-- Whether a ready ability would clearly help right now (its button beats).
local function worthUsing(id: string): boolean
	local root, humanoid = localCharacter()
	if not root or not humanoid then
		return false
	end
	if id == "heal" then
		return humanoid.Health <= humanoid.MaxHealth * HEAL_HINT_SHARE
	elseif id == "wave" then
		return creaturesNear(root.Position, waveStats().radius, WAVE_HINT_CREATURES) >= WAVE_HINT_CREATURES
	end
	return false
end

function Controls.wave()
	local root = localCharacter()
	if not ready("wave") or not root then
		return
	end
	lastUse.wave = os.clock()
	Effects.wave(player, root.Position, waveStats().radius, Attrs.get("StaffTier", 0))
	requestWave:FireServer()
end

function Controls.star()
	local root = localCharacter()
	-- No creature in reach: nothing happens and the cooldown is not spent (the server agrees).
	if not ready("star") or not root or not hasTargetNear(root.Position, Balance.abilities.star.range) then
		return
	end
	lastUse.star = os.clock()
	requestAbility:FireServer("star")
end

function Controls.heal()
	local root, humanoid = localCharacter()
	-- At full health the glow would be wasted, so the button waits.
	if not ready("heal") or not root or not humanoid or humanoid.Health >= humanoid.MaxHealth then
		return
	end
	lastUse.heal = os.clock()
	requestAbility:FireServer("heal")
end

-- `key` is the keyboard hint, `pad` the gamepad one (shown while a gamepad is in use).
type Ability = { id: string, action: string, keys: { Enum.KeyCode }, key: string, pad: string, nameKey: string, descKey: string, icon: string, color: Color3, cast: () -> () }

local ABILITIES: { Ability } = {
	{ id = "wave", action = "LvLightWave", keys = { Enum.KeyCode.Q, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2 }, key = "Q", pad = "RT", nameKey = "wave_button", descKey = "ability_wave_desc", icon = "✨", color = colors.xp, cast = Controls.wave },
	{ id = "star", action = "LvStarFall", keys = { Enum.KeyCode.R, Enum.KeyCode.ButtonR1 }, key = "R", pad = "RB", nameKey = "ability_star", descKey = "ability_star_desc", icon = "⭐", color = Color3.fromRGB(255, 205, 90), cast = Controls.star },
	{ id = "heal", action = "LvLanternGlow", keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonL1 }, key = "F", pad = "LB", nameKey = "ability_heal", descKey = "ability_heal_desc", icon = "💚", color = Color3.fromRGB(120, 230, 150), cast = Controls.heal },
}

-- Ability visuals ---------------------------------------------------------------------------

local readyRing: (view: any) -> ()

type AbilityView = { root: GuiObject, cooldown: Frame, timer: TextLabel, lock: TextLabel, wasReady: boolean, color: Color3 }

-- A round ability button: dark rim in the ability's colour, glowing inner disc with an icon,
-- a key badge (desktop), the name underneath (desktop), a dimmed countdown and a lock.
local function decorate(button: GuiObject, ability: Ability, showKey: boolean): AbilityView
	local z = button.ZIndex + 1
	local face = UiKit.create("Frame", {
		Name = "LvFace",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(28, 22, 48),
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
		ZIndex = z,
	}, button)
	UiKit.corner(face, 999)
	UiKit.create("UIStroke", { Color = ability.color, Thickness = 3 }, face)
	local disc = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = z + 1,
	}, face)
	UiKit.corner(disc, 999)
	UiKit.create("UIGradient", {
		Color = ColorSequence.new(ability.color:Lerp(Color3.new(1, 1, 1), 0.45), ability.color:Lerp(Color3.new(0, 0, 0), 0.35)),
		Rotation = 90,
	}, disc)
	UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.62, 0.62),
		Text = ability.icon,
		TextScaled = true,
		ZIndex = z + 2,
	}, face)
	if showKey then
		local badge = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, 4, 0, -4),
			Size = UDim2.fromOffset(24, 24),
			BackgroundColor3 = colors.panel,
			BorderSizePixel = 0,
			ZIndex = z + 5,
		}, face)
		UiKit.corner(badge, 6)
		UiKit.create("UIStroke", { Color = ability.color, Thickness = 1.5 }, badge)
		local keyLabel = UiKit.label({ Name = "KeyHint", Size = UDim2.fromScale(1, 1), TextSize = 15, ZIndex = z + 6 }, badge)
		local function showHint()
			local gamepad = UiKit.usingGamepad()
			keyLabel.Text = if gamepad then ability.pad else ability.key
			badge.Size = UDim2.fromOffset(if gamepad then 30 else 24, 24)
		end
		UiKit.onInputKindChanged(showHint)
		showHint()
		UiKit.label({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 1, 4),
			Size = UDim2.new(1.5, 0, 0, 18),
			Text = Strings.get(ability.nameKey),
			TextSize = 14,
			TextStrokeTransparency = 0.3,
			ZIndex = z,
		}, face)
	end
	local cooldown = UiKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(15, 10, 28),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = z + 3,
	}, face)
	UiKit.corner(cooldown, 999)
	local timer = UiKit.label({ Size = UDim2.fromScale(1, 1), TextScaled = true, ZIndex = z + 4 }, cooldown)
	UiKit.create("UIPadding", { PaddingTop = UDim.new(0.25, 0), PaddingBottom = UDim.new(0.25, 0) }, timer)
	local lock = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(15, 10, 28),
		BackgroundTransparency = 0.25,
		TextScaled = true,
		TextColor3 = colors.muted,
		Visible = false,
		ZIndex = z + 4,
	}, face)
	UiKit.corner(lock, 999)
	UiKit.create("UIPadding", { PaddingTop = UDim.new(0.28, 0), PaddingBottom = UDim.new(0.28, 0) }, lock)
	return { root = face, cooldown = cooldown, timer = timer, lock = lock, wasReady = true, color = ability.color }
end

-- A ring in the ability's colour swells out of the button and fades when it is ready again.
readyRing = function(view: AbilityView)
	local ring = UiKit.create("Frame", {
		Name = "ReadyRing",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = view.root.ZIndex + 6,
	}, view.root)
	UiKit.corner(ring, 999)
	local stroke = UiKit.create("UIStroke", { Color = view.color, Thickness = 4 }, ring)
	UiKit.tween(ring, 0.45, { Size = UDim2.fromScale(1.6, 1.6) })
	UiKit.tween(stroke, 0.45, { Transparency = 1, Thickness = 1 }).Completed:Connect(function()
		ring:Destroy()
	end)
end

-- Desktop: hovering an ability shows what it does, its recharge and when it unlocks.
local function attachTooltip(button: GuiButton, ability: Ability, bar: GuiObject)
	local tip = UiKit.panel({
		Name = "AbilityTip",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 0, -34),
		Size = UDim2.fromOffset(260, 84),
		Visible = false,
		Corner = 10,
	}, bar)
	local title = UiKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 22), TextSize = 18, TextColor3 = ability.color, TextXAlignment = Enum.TextXAlignment.Left }, tip)
	local desc = UiKit.label({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -24, 0, 34), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top }, tip)
	local footer = UiKit.label({ Position = UDim2.fromOffset(12, 62), Size = UDim2.new(1, -24, 0, 16), TextSize = 13, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left }, tip)
	button.MouseEnter:Connect(function()
		title.Text = Strings.get(ability.nameKey) .. "  [" .. (if UiKit.usingGamepad() then ability.pad else ability.key) .. "]"
		desc.Text = Strings.get(ability.descKey)
		local need = unlockLevel(ability.id)
		footer.Text = if Attrs.get("Level", 1) < need then Strings.get("ability_unlocks", need) else Strings.get("ability_cooldown", math.ceil(cooldownOf(ability.id)))
		tip.Visible = true
	end)
	button.MouseLeave:Connect(function()
		tip.Visible = false
	end)
end

local function styleTouchButton(ability: Ability): AbilityView?
	local button = ContextActionService:GetButton(ability.action)
	if not button or button:FindFirstChild("LvFace") then
		return nil
	end
	button.ImageTransparency = 1
	return decorate(button, ability, false)
end

-- Big touch buttons laid out around Roblox's own jump button so they never overlap it:
-- Light Wave left of the jump button, Star Fall above it, Lantern Glow above the wave.
-- Waits in the background (the CAS fallback is already usable) and returns nil if the jump
-- button never appears. Roblox rebuilds JumpButton when the screen size changes, so the layout
-- re-hooks to whichever JumpButton currently exists.
local JUMP_WAIT = 60
local GAP = 14

local function buildTouchButtons(): { [string]: AbilityView }?
	local playerGui = player:WaitForChild("PlayerGui")
	local touchGui = playerGui:WaitForChild("TouchGui", JUMP_WAIT)
	local frame = touchGui and touchGui:WaitForChild("TouchControlFrame", JUMP_WAIT)
	local firstJump = frame and frame:WaitForChild("JumpButton", JUMP_WAIT)
	if not touchGui or not frame or not firstJump then
		return nil
	end
	-- Same inset setting as TouchGui keeps both absolute coordinate spaces identical.
	local gui = UiKit.create("ScreenGui", {
		Name = "TouchAbilities",
		ResetOnSpawn = false,
		IgnoreGuiInset = (touchGui :: ScreenGui).IgnoreGuiInset,
	}, playerGui)
	table.insert(hideDuringScenes, gui)
	local buttons: { [string]: TextButton } = {}
	for _, ability in ABILITIES do
		local button = UiKit.create("TextButton", { Name = ability.id, BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, gui)
		button.MouseButton1Down:Connect(ability.cast)
		buttons[ability.id] = button
	end

	local jump: GuiObject = firstJump :: GuiObject
	local function layout()
		local position = jump.AbsolutePosition
		local size = jump.AbsoluteSize
		local big = math.max(size.X * 1.1, 76)
		local small = big * 0.85
		local waveX, waveY = position.X - big - GAP, position.Y + size.Y - big
		buttons.wave.Size = UDim2.fromOffset(big, big)
		buttons.wave.Position = UDim2.fromOffset(waveX, waveY)
		buttons.star.Size = UDim2.fromOffset(small, small)
		buttons.star.Position = UDim2.fromOffset(position.X + size.X - small, position.Y - small - GAP)
		buttons.heal.Size = UDim2.fromOffset(small, small)
		buttons.heal.Position = UDim2.fromOffset(waveX + (big - small) / 2, waveY - small - GAP)
	end
	local connections: { RBXScriptConnection } = {}
	local function hook(newJump: GuiObject)
		for _, connection in connections do
			connection:Disconnect()
		end
		jump = newJump
		connections = {
			jump:GetPropertyChangedSignal("AbsolutePosition"):Connect(layout),
			jump:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout),
		}
		layout()
	end
	frame.ChildAdded:Connect(function(child)
		if child.Name == "JumpButton" and child:IsA("GuiObject") then
			hook(child)
		end
	end)
	hook(jump)

	local views = {}
	for _, ability in ABILITIES do
		views[ability.id] = decorate(buttons[ability.id], ability, false)
	end
	return views
end

-- Keyboard/mouse: a row of ability buttons in the bottom-right corner, clear of the character.
local DESKTOP_SIZE = 76
local DESKTOP_GAP = 18

local function buildDesktopButtons(gui: ScreenGui): { [string]: AbilityView }
	local width = #ABILITIES * DESKTOP_SIZE + (#ABILITIES - 1) * DESKTOP_GAP
	local bar = UiKit.region(gui, Vector2.new(1, 1), UDim2.new(1, -20, 1, -34), Vector2.new(width, DESKTOP_SIZE))
	bar.Name = "AbilityBar"
	table.insert(hideDuringScenes, bar)
	local views = {}
	for index, ability in ABILITIES do
		local button = UiKit.create("TextButton", {
			Name = ability.id,
			Position = UDim2.fromOffset((index - 1) * (DESKTOP_SIZE + DESKTOP_GAP), 0),
			Size = UDim2.fromOffset(DESKTOP_SIZE, DESKTOP_SIZE),
			BackgroundTransparency = 1,
			Text = "",
		}, bar)
		button.Activated:Connect(ability.cast)
		views[ability.id] = decorate(button, ability, true)
		attachTooltip(button, ability, bar)
	end
	return views
end

local function bindActions(touchButtons: boolean)
	for _, ability in ABILITIES do
		ContextActionService:BindAction(ability.action, function(_, state)
			if state == Enum.UserInputState.Begin then
				ability.cast()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, touchButtons, table.unpack(ability.keys))
	end
end

function Controls.start()
	local gui = UiKit.create("ScreenGui", { Name = "Controls", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	local views: { [string]: AbilityView } = {}
	if UiKit.isTouch() then
		-- Usable right away with CAS buttons; upgrade to the big custom buttons when possible.
		local upgraded = false
		bindActions(true)
		for _, ability in ABILITIES do
			ContextActionService:SetTitle(ability.action, Strings.get(ability.nameKey))
		end
		task.spawn(function()
			-- CAS creates its buttons asynchronously, so style them once they exist.
			for _ = 1, 100 do
				if upgraded then
					return
				end
				local missing = false
				for _, ability in ABILITIES do
					if not views[ability.id] then
						local view = styleTouchButton(ability)
						if view then
							views[ability.id] = view
						else
							missing = true
						end
					end
				end
				if not missing then
					return
				end
				task.wait(0.1)
			end
		end)
		task.spawn(function()
			local touchViews = buildTouchButtons()
			if touchViews then
				upgraded = true
				bindActions(false)
				views = touchViews
			end
		end)
	else
		bindActions(false)
		views = buildDesktopButtons(gui)
	end

	-- First-minute hint, hidden after the first purification.
	local hint = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -206),
		Size = UDim2.fromOffset(420, 32),
		TextSize = 22,
		TextStrokeTransparency = 0.2,
		Visible = false,
	}, gui)
	local hintDone = false
	local function refreshHint()
		local onFirstQuest = Attrs.get("QuestId", "") == "first_purify" and Attrs.get("QuestState", "") == "active"
		hint.Visible = onFirstQuest and not hintDone
		hint.Text = Strings.get("hint_auto")
	end
	for _, name in { "QuestId", "QuestState" } do
		player:GetAttributeChangedSignal(name):Connect(refreshHint)
	end
	Remotes:WaitForChild("RewardGranted").OnClientEvent:Connect(function(reason)
		if reason == "purify" and not hintDone then
			hintDone = true
			refreshHint()
		end
	end)
	-- nil until the profile has loaded, so a returning player's first sync is not an "unlock".
	local knownLevel: number? = if player:GetAttribute("Level") ~= nil then Attrs.get("Level", 1) else nil
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = Attrs.get("Level", 1)
		for _, ability in ABILITIES do
			local need = unlockLevel(ability.id)
			if knownLevel and knownLevel < need and level >= need then
				local view = views[ability.id]
				if view then
					UiKit.pop(view.root)
				end
				if ability.id == "wave" and not UiKit.isTouch() then
					hint.Text = Strings.get("hint_wave_pc")
					hint.Visible = true
					task.delay(8, refreshHint)
				end
			end
		end
		knownLevel = level
	end)
	refreshHint()

	local nextHintCheck = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local checkHints = now >= nextHintCheck
		if checkHints then
			nextHintCheck = now + HINT_CHECK_SECONDS
		end
		local level = Attrs.get("Level", 1)
		local inScene = Cinematic.blocking()
		for _, container in hideDuringScenes do
			if container:IsA("ScreenGui") then
				container.Enabled = not inScene
			else
				(container :: GuiObject).Visible = not inScene
			end
		end
		for _, ability in ABILITIES do
			local view = views[ability.id]
			if view then
				local need = unlockLevel(ability.id)
				local unlocked = level >= need
				view.lock.Visible = not unlocked
				view.lock.Text = Strings.get("wave_locked", need)
				local remaining = if unlocked then math.max(0, cooldownOf(ability.id) - (now - (lastUse[ability.id] or -math.huge))) else 0
				view.cooldown.Visible = remaining > 0
				view.timer.Text = tostring(math.ceil(remaining))
				-- A little pop when an ability comes back.
				local isReady = unlocked and remaining == 0
				if isReady and not view.wasReady then
					UiKit.pop(view.root)
					readyRing(view)
				end
				view.wasReady = isReady
				if checkHints then
					UiKit.setPulse(view.root, isReady and not inScene and worthUsing(ability.id))
				end
			end
		end
	end)
end

return Controls
