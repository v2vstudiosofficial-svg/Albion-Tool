-- Light-wave input with a cooldown display. Weapons attack automatically (server-side), so the
-- wave is the only button. Touch: a ContextActionService button appears immediately; once Roblox's
-- jump button exists, a big custom button placed beside it replaces it (and follows it if it is
-- rebuilt on resize). Keyboard/mouse gets an on-screen ability button. The server re-validates.
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

local WAVE_ACTION = "LvLightWave"

local player = Players.LocalPlayer
local colors = UiKit.colors

local lastWave = -math.huge

local Controls = {}

local function localRoot(): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return root
	end
	return nil
end

local function waveStats()
	return Progression.waveStats(
		Attrs.get("StaffTier", 0),
		Attrs.get("Level", 1),
		Attrs.get("Charm", "") ~= "" and Attrs.get("Charm", "") or nil,
		Attrs.stats().waveRank
	)
end

function Controls.wave()
	if Cinematic.blocking() then
		return
	end
	if not Progression.waveUnlocked(Attrs.get("Level", 1)) then
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
	Effects.wave(player, root.Position, stats.radius, Attrs.get("StaffTier", 0))
	requestWave:FireServer()
end

-- Ability visuals ---------------------------------------------------------------------------

type AbilityView = { root: GuiObject, cooldown: Frame, lock: TextLabel }

local function decorate(button: GuiObject, title: string, key: string?, color: Color3): AbilityView
	local face = UiKit.create("Frame", {
		Name = "LvFace",
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
	if not button or button:FindFirstChild("LvFace") then
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

local function buildTouchButton(): AbilityView?
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
	local function makeButton(onPress: () -> ()): TextButton
		local button = UiKit.create("TextButton", { BackgroundTransparency = 1, Text = "", AutoButtonColor = false }, gui)
		button.MouseButton1Down:Connect(onPress)
		return button
	end
	local waveButton = makeButton(Controls.wave)

	local jump: GuiObject = firstJump :: GuiObject
	local function layout()
		local position = jump.AbsolutePosition
		local size = jump.AbsoluteSize
		local big = math.max(size.X * 1.1, 76)
		waveButton.Size = UDim2.fromOffset(big, big)
		waveButton.Position = UDim2.fromOffset(position.X - big - 14, position.Y + size.Y - big)
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

	return decorate(waveButton, Strings.get("wave_button"), nil, colors.xp)
end

local function buildDesktopButton(gui: ScreenGui): AbilityView
	local waveButton = UiKit.create("TextButton", {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -118),
		Size = UDim2.fromOffset(78, 78),
		BackgroundTransparency = 1,
		Text = "",
	}, gui)
	waveButton.Activated:Connect(Controls.wave)
	return decorate(waveButton, Strings.get("wave_button"), "Q", colors.xp)
end

local function onWaveAction(_, state)
	if state == Enum.UserInputState.Begin then
		Controls.wave()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end

local function bindActions(touchButtons: boolean)
	ContextActionService:BindAction(WAVE_ACTION, onWaveAction, touchButtons, Enum.KeyCode.Q, Enum.KeyCode.ButtonL2, Enum.KeyCode.ButtonR2)
end

function Controls.start()
	local gui = UiKit.create("ScreenGui", { Name = "Controls", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	local views: { wave: AbilityView? } = {}
	if UiKit.isTouch() then
		-- Usable right away with a CAS button; upgrade to the big custom button when possible.
		local upgraded = false
		bindActions(true)
		ContextActionService:SetTitle(WAVE_ACTION, Strings.get("wave_button"))
		task.spawn(function()
			-- CAS creates its buttons asynchronously, so style it once it exists.
			for _ = 1, 100 do
				if upgraded then
					return
				end
				local waveView = styleTouchButton(WAVE_ACTION, Strings.get("wave_button"), colors.xp)
				if waveView then
					views.wave = waveView
					return
				end
				task.wait(0.1)
			end
		end)
		task.spawn(function()
			local waveView = buildTouchButton()
			if waveView then
				upgraded = true
				bindActions(false)
				views.wave = waveView
			end
		end)
	else
		bindActions(false)
		views.wave = buildDesktopButton(gui)
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
	local waveWasUnlocked: boolean? = if player:GetAttribute("Level") ~= nil
		then Progression.waveUnlocked(Attrs.get("Level", 1))
		else nil
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local unlocked = Progression.waveUnlocked(Attrs.get("Level", 1))
		if unlocked and waveWasUnlocked == false then
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
		local waveView = views.wave
		if waveView then
			local level = Attrs.get("Level", 1)
			local unlocked = Progression.waveUnlocked(level)
			waveView.lock.Visible = not unlocked
			waveView.lock.Text = Strings.get("wave_locked", Balance.wave.unlockLevel)
			local remaining = if unlocked then math.clamp(1 - (now - lastWave) / waveStats().cooldown, 0, 1) else 0
			waveView.cooldown.Size = UDim2.fromScale(1, remaining)
		end
	end)
end

return Controls
