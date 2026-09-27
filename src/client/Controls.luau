-- Attack and light-wave input with light aim assist, local prediction and cooldown display.
-- Touch: ContextActionService buttons appear immediately; once Roblox's jump button exists, big
-- custom buttons laid out beside it replace them (and follow it if it is rebuilt on resize).
-- Keyboard/mouse gets an on-screen ability bar. The server re-validates everything.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Progression = require(Shared:WaitForChild("Progression"))
local Strings = require(Shared:WaitForChild("Strings"))
local Effects = require(script.Parent.Effects)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local requestAttack = Remotes:WaitForChild("RequestAttack") :: RemoteEvent
local requestWave = Remotes:WaitForChild("RequestWave") :: RemoteEvent

local ATTACK_ACTION = "LvLightAttack"
local WAVE_ACTION = "LvLightWave"
local FACING_BONUS = 8 -- studs of preference given to enemies in front of the player

local player = Players.LocalPlayer
local colors = UiKit.colors

local lastAttack = -math.huge
local lastWave = -math.huge
local mouseRayParams = RaycastParams.new()
mouseRayParams.FilterType = Enum.RaycastFilterType.Exclude

local Controls = {}

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function localRoot(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function aliveEnemy(instance: Instance?): Model?
	local enemies = workspace:FindFirstChild("Enemies")
	local model = instance and instance:FindFirstAncestorOfClass("Model")
	while model and model.Parent ~= enemies do
		model = model:FindFirstAncestorOfClass("Model")
	end
	if enemies and model and model:GetAttribute("Alive") and model.PrimaryPart then
		return model
	end
	return nil
end

local function reach(model: Model): number
	local stats = Balance.enemies[model:GetAttribute("EnemyType") or ""]
	return Balance.staff.range + (if stats then stats.size * 0.5 else 0)
end

local function inRange(root: BasePart, model: Model): boolean
	return ((model.PrimaryPart :: BasePart).Position - root.Position).Magnitude <= reach(model)
end

local function enemyUnderMouse(root: BasePart): Model?
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	mouseRayParams.FilterDescendantsInstances = { player.Character :: Instance, workspace:FindFirstChild("ClientFx") :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 250, mouseRayParams)
	local model = aliveEnemy(hit and hit.Instance)
	if model and inRange(root, model) then
		return model
	end
	return nil
end

local function assistedTarget(root: BasePart): Model?
	local enemies = workspace:FindFirstChild("Enemies")
	if not enemies then
		return nil
	end
	local best, bestScore = nil, math.huge
	for _, child in enemies:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Alive") and child.PrimaryPart and inRange(root, child) then
			local offset = child.PrimaryPart.Position - root.Position
			local facing = if offset.Magnitude > 0.01 then root.CFrame.LookVector:Dot(offset.Unit) else 1
			local score = offset.Magnitude - facing * FACING_BONUS
			if score < bestScore then
				best, bestScore = child, score
			end
		end
	end
	return best
end

local function waveStats()
	return Progression.waveStats(attr("StaffTier", 0), attr("Level", 1), attr("Charm", "") ~= "" and attr("Charm", "") or nil)
end

function Controls.attack(useMouse: boolean)
	local now = os.clock()
	if now - lastAttack < Balance.staff.cooldown then
		return
	end
	local root = localRoot()
	if not root then
		return
	end
	local target = (useMouse and enemyUnderMouse(root)) or assistedTarget(root)
	if not target then
		return
	end
	lastAttack = now
	local targetPosition = (target.PrimaryPart :: BasePart).Position
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z))
	Effects.bolt(player, root.Position + Vector3.new(0, 1.5, 0), targetPosition, attr("StaffTier", 0))
	requestAttack:FireServer(target:GetAttribute("EnemyId"))
end

function Controls.wave()
	if not Progression.waveUnlocked(attr("Level", 1)) then
		return
	end
	local stats = waveStats()
	local now = os.clock()
	if now - lastWave < stats.cooldown then
		return
	end
	local root = localRoot()
	if not root then
		return
	end
	lastWave = now
	Effects.wave(player, root.Position, stats.radius, attr("StaffTier", 0))
	requestWave:FireServer()
end

-- Ability visuals ---------------------------------------------------------------------------

type AbilityView = { root: GuiObject, cooldown: Frame, lock: TextLabel }

local function decorate(button: GuiObject, title: string, key: string?, color: Color3): AbilityView
	local face = UiKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = button.ZIndex + 1,
	}, button)
	UiKit.corner(face, 999)
	UiKit.create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3, Transparency = 0.2 }, face)
	UiKit.label({
		Size = UDim2.fromScale(1, if key then 0.62 else 1),
		Text = title,
		TextScaled = true,
		TextColor3 = colors.panel,
		ZIndex = face.ZIndex + 1,
	}, face)
	if key then
		UiKit.label({
			Position = UDim2.fromScale(0, 0.58),
			Size = UDim2.fromScale(1, 0.34),
			Text = key,
			TextScaled = true,
			TextColor3 = colors.panel,
			ZIndex = face.ZIndex + 1,
		}, face)
	end
	local cooldown = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.fromRGB(20, 15, 35),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		ZIndex = face.ZIndex + 2,
	}, face)
	UiKit.corner(cooldown, 999)
	local lock = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(20, 15, 35),
		BackgroundTransparency = 0.3,
		TextScaled = true,
		Visible = false,
		ZIndex = face.ZIndex + 3,
	}, face)
	UiKit.corner(lock, 999)
	return { root = face, cooldown = cooldown, lock = lock }
end

local function styleTouchButton(action: string, title: string, color: Color3): AbilityView?
	local button = ContextActionService:GetButton(action)
	if not button then
		return nil
	end
	button.ImageTransparency = 1
	return decorate(button, title, nil, color)
end

-- Big touch buttons laid out around Roblox's own jump button so they never overlap it.
-- Waits in the background (the CAS fallback is already usable) and returns nil if the jump
-- button never appears. Roblox rebuilds JumpButton when the screen size changes, so the layout
-- re-hooks to whichever JumpButton currently exists.
local JUMP_WAIT = 60

local function buildTouchButtons(): (AbilityView?, AbilityView?)
	local playerGui = player:WaitForChild("PlayerGui")
	local touchGui = playerGui:WaitForChild("TouchGui", JUMP_WAIT)
	local frame = touchGui and touchGui:WaitForChild("TouchControlFrame", JUMP_WAIT)
	local firstJump = frame and frame:WaitForChild("JumpButton", JUMP_WAIT)
	if not touchGui or not frame or not firstJump then
		return nil, nil
	end
	-- Same inset setting as TouchGui keeps both absolute coordinate spaces identical.
	local gui = UiKit.create("ScreenGui", {
		Name = "TouchAbilities",
		ResetOnSpawn = false,
		IgnoreGuiInset = (touchGui :: ScreenGui).IgnoreGuiInset,
	}, playerGui)
	local function makeButton(onPress: () -> ()): TextButton
		local button = UiKit.create("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, gui)
		button.MouseButton1Down:Connect(onPress)
		return button
	end
	local attackButton = makeButton(function()
		Controls.attack(false)
	end)
	local waveButton = makeButton(Controls.wave)

	local jump: GuiObject = firstJump :: GuiObject
	local function layout()
		local position = jump.AbsolutePosition
		local size = jump.AbsoluteSize
		local big = math.max(size.X * 1.1, 76)
		local small = big * 0.85
		attackButton.Size = UDim2.fromOffset(big, big)
		attackButton.Position = UDim2.fromOffset(position.X - big - 14, position.Y + size.Y - big)
		waveButton.Size = UDim2.fromOffset(small, small)
		waveButton.Position = UDim2.fromOffset(position.X + (size.X - small) / 2, position.Y - small - 14)
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

	return decorate(attackButton, Strings.get("attack_button"), nil, colors.accent),
		decorate(waveButton, Strings.get("wave_button"), nil, colors.xp)
end

local function buildDesktopBar(gui: ScreenGui): (AbilityView, AbilityView)
	local bar = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(180, 80),
		BackgroundTransparency = 1,
	}, gui)
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 16),
	}, bar)
	local attackButton = UiKit.create("TextButton", { Size = UDim2.fromOffset(78, 78), BackgroundTransparency = 1, Text = "" }, bar)
	attackButton.Activated:Connect(function()
		Controls.attack(false)
	end)
	local waveButton = UiKit.create("TextButton", { Size = UDim2.fromOffset(78, 78), BackgroundTransparency = 1, Text = "" }, bar)
	waveButton.Activated:Connect(Controls.wave)
	return decorate(attackButton, Strings.get("attack_button"), "F", colors.accent),
		decorate(waveButton, Strings.get("wave_button"), "Q", colors.xp)
end

local function onAttackAction(_, state, input)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
	Controls.attack(isMouse)
	return if isMouse then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
end

local function onWaveAction(_, state)
	if state == Enum.UserInputState.Begin then
		Controls.wave()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bindActions(touchButtons: boolean)
	ContextActionService:BindAction(ATTACK_ACTION, onAttackAction, touchButtons, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:BindAction(WAVE_ACTION, onWaveAction, touchButtons, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2)
end

function Controls.start()
	local gui = UiKit.create("ScreenGui", { Name = "Controls", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	local views: { attack: AbilityView?, wave: AbilityView? } = {}
	if UiKit.isTouch() then
		-- Usable right away with CAS buttons; upgrade to the big custom buttons when possible.
		bindActions(true)
		views.attack = styleTouchButton(ATTACK_ACTION, Strings.get("attack_button"), colors.accent)
		views.wave = styleTouchButton(WAVE_ACTION, Strings.get("wave_button"), colors.xp)
		task.spawn(function()
			local attackView, waveView = buildTouchButtons()
			if attackView and waveView then
				bindActions(false)
				views.attack, views.wave = attackView, waveView
			end
		end)
	else
		bindActions(false)
		views.attack, views.wave = buildDesktopBar(gui)
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
	local attackHintDone = false
	local function refreshHint()
		local onFirstQuest = attr("QuestId", "") == "first_purify" and attr("QuestState", "") == "active"
		hint.Visible = onFirstQuest and not attackHintDone
		hint.Text = Strings.get(if UiKit.isTouch() then "hint_attack_touch" else "hint_attack_pc")
	end
	for _, name in { "QuestId", "QuestState" } do
		player:GetAttributeChangedSignal(name):Connect(refreshHint)
	end
	Remotes:WaitForChild("RewardGranted").OnClientEvent:Connect(function(reason)
		if reason == "purify" and not attackHintDone then
			attackHintDone = true
			refreshHint()
		end
	end)
	local waveWasUnlocked = Progression.waveUnlocked(attr("Level", 1))
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local unlocked = Progression.waveUnlocked(attr("Level", 1))
		if unlocked and not waveWasUnlocked then
			if views.wave then
				UiKit.pop(views.wave.root)
			end
			if not UiKit.isTouch() then
				hint.Text = Strings.get("hint_wave_pc")
				hint.Visible = true
				task.delay(8, refreshHint)
			end
		end
		waveWasUnlocked = unlocked
	end)
	refreshHint()

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local attackView = views.attack
		if attackView then
			local remaining = math.clamp(1 - (now - lastAttack) / Balance.staff.cooldown, 0, 1)
			attackView.cooldown.Size = UDim2.fromScale(1, remaining)
		end
		local waveView = views.wave
		if waveView then
			local level = attr("Level", 1)
			local unlocked = Progression.waveUnlocked(level)
			waveView.lock.Visible = not unlocked
			waveView.lock.Text = Strings.get("wave_locked", Balance.wave.unlockLevel)
			local remaining = if unlocked then math.clamp(1 - (now - lastWave) / waveStats().cooldown, 0, 1) else 0
			waveView.cooldown.Size = UDim2.fromScale(1, remaining)
		end
	end)
end

return Controls
