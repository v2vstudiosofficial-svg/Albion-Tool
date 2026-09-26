-- Small UI toolkit so every panel and button shares the same rounded, warm look.
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UiKit = {}

UiKit.font = Enum.Font.FredokaOne
UiKit.colors = {
	panel = Color3.fromRGB(45, 40, 70),
	panelLight = Color3.fromRGB(70, 62, 105),
	text = Color3.fromRGB(255, 248, 230),
	muted = Color3.fromRGB(190, 180, 210),
	accent = Color3.fromRGB(255, 215, 110),
	good = Color3.fromRGB(120, 220, 140),
	bad = Color3.fromRGB(255, 120, 120),
	xp = Color3.fromRGB(140, 200, 255),
	coin = Color3.fromRGB(255, 200, 70),
	boss = Color3.fromRGB(185, 120, 255),
}

function UiKit.rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

function UiKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function UiKit.create(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props or {} do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UiKit.corner(parent: Instance, radius: number?)
	UiKit.create("UICorner", { CornerRadius = UDim.new(0, radius or 14) }, parent)
end

function UiKit.panel(props: { [string]: any }, parent: Instance): Frame
	props.BackgroundColor3 = props.BackgroundColor3 or UiKit.colors.panel
	props.BackgroundTransparency = props.BackgroundTransparency or 0.12
	props.BorderSizePixel = 0
	local radius = props.Corner
	props.Corner = nil
	local frame = UiKit.create("Frame", props, parent)
	UiKit.corner(frame, radius)
	UiKit.create("UIStroke", { Color = UiKit.colors.accent, Thickness = 2, Transparency = 0.35 }, frame)
	return frame
end

function UiKit.label(props: { [string]: any }, parent: Instance): TextLabel
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = UiKit.font
	props.TextColor3 = props.TextColor3 or UiKit.colors.text
	props.TextSize = props.TextSize or 22
	return UiKit.create("TextLabel", props, parent)
end

function UiKit.tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?): Tween
	local tween = TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		goal
	)
	tween:Play()
	return tween
end

-- Big rounded button with a small press animation.
function UiKit.button(props: { [string]: any }, parent: Instance, onClick: () -> ()): TextButton
	props.BackgroundColor3 = props.BackgroundColor3 or UiKit.colors.accent
	props.TextColor3 = props.TextColor3 or UiKit.colors.panel
	props.Font = UiKit.font
	props.TextSize = props.TextSize or 22
	props.AutoButtonColor = false
	props.BorderSizePixel = 0
	local radius = props.Corner or 12
	props.Corner = nil
	local button = UiKit.create("TextButton", props, parent)
	UiKit.corner(button, radius)
	local scale = UiKit.create("UIScale", nil, button)
	button.MouseButton1Down:Connect(function()
		UiKit.tween(scale, 0.08, { Scale = 0.92 })
	end)
	button.MouseButton1Up:Connect(function()
		UiKit.tween(scale, 0.12, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		UiKit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.Activated:Connect(onClick)
	return button
end

-- Uniform scale so layouts designed for ~1000x560 fit small landscape phones without overlap.
function UiKit.screenScale(): number
	local viewport = workspace.CurrentCamera.ViewportSize
	return math.clamp(math.min(viewport.X / 1000, viewport.Y / 560), 0.6, 1)
end

-- A transparent, auto-scaling container anchored to a screen region; place panels inside it.
function UiKit.region(parent: Instance, anchor: Vector2, position: UDim2, size: Vector2): Frame
	local frame = UiKit.create("Frame", {
		AnchorPoint = anchor,
		Position = position,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundTransparency = 1,
	}, parent)
	local scale = UiKit.create("UIScale", nil, frame)
	local function update()
		scale.Scale = UiKit.screenScale()
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	return frame
end

function UiKit.pop(instance: GuiObject)
	local scale = instance:FindFirstChildOfClass("UIScale") or UiKit.create("UIScale", nil, instance)
	scale.Scale = 0.6
	UiKit.tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
end

return UiKit
