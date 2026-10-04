-- Interaction prompts in the game's own look: a rounded pill over the thing you can use, with the
-- key to press (a hand on touch screens), what happens ("Talk") and to whom ("Elder Nora"). Roblox
-- still decides when a prompt shows; this only draws it (Style = Custom, set on this screen only).
-- On touch screens the pill itself is the button.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local RunService = game:GetService("RunService")

local Cinematic = require(script.Parent.Cinematic)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local colors = UiKit.colors

local TOUCH_ICON = "👆"
-- The pill floats over the thing, or under it while the hero stands beyond it (farther from the
-- camera, so higher on screen): over it the pill covered the hero. SIDE_MARGIN studs of slack keep
-- it from flipping back and forth.
local PILL_ABOVE = 2.6
local PILL_BELOW = -3
local SIDE_MARGIN = 1

local Prompts = {}

local shown: { [ProximityPrompt]: BillboardGui } = {}
-- The thing's own name tag is hidden while the prompt (which names it too) is up.
local hiddenTags: { [ProximityPrompt]: BillboardGui } = {}
local holds: { [ProximityPrompt]: (boolean) -> () } = {}

local function pointOf(adornee: Instance?): Vector3?
	if not adornee then
		return nil
	elseif adornee:IsA("BasePart") then
		return adornee.Position
	elseif adornee:IsA("Attachment") then
		return adornee.WorldPosition
	elseif adornee:IsA("Model") then
		return adornee:GetPivot().Position
	end
	return nil
end

local function placePill(gui: BillboardGui)
	local camera = workspace.CurrentCamera
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local at = pointOf(gui.Adornee)
	if not camera or not root or not at then
		return
	end
	local eye = camera.CFrame.Position
	local flat = Vector3.new(1, 0, 1)
	local beyond = ((root.Position - eye) * flat).Magnitude - ((at - eye) * flat).Magnitude
	local below = gui.StudsOffset.Y < 0
	if below and beyond < -SIDE_MARGIN then
		below = false
	elseif not below and beyond > SIDE_MARGIN then
		below = true
	end
	gui.StudsOffset = Vector3.new(0, if below then PILL_BELOW else PILL_ABOVE, 0)
end

local function keyName(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return TOUCH_ICON
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return (prompt.GamepadKeyCode.Name:gsub("^Button", ""))
	end
	return prompt.KeyboardKeyCode.Name
end

function Prompts.show(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	Prompts.hide(prompt)
	local adornee = prompt.Parent
	if not adornee or not adornee:IsA("BasePart") and not adornee:IsA("Attachment") and not adornee:IsA("Model") then
		return
	end
	local gui = UiKit.create("BillboardGui", {
		Name = "LvPrompt",
		Adornee = adornee,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(220, 56),
		StudsOffset = Vector3.new(0, PILL_ABOVE, 0),
		LightInfluence = 0,
		Active = true,
		ResetOnSpawn = false,
	}, player:WaitForChild("PlayerGui"))
	local pill = UiKit.create("TextButton", {
		Name = "Pill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = colors.panel,
		BackgroundTransparency = 0.12,
		Text = "",
		AutoButtonColor = false,
	}, gui)
	UiKit.corner(pill, 24)
	UiKit.create("UIStroke", { Color = colors.accent, Thickness = 2, Transparency = 0.25 }, pill)
	local key = UiKit.label({
		Name = "Key",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 6, 0.5, 0),
		Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = colors.accent,
		BackgroundTransparency = 0,
		Text = keyName(prompt, inputType),
		TextSize = 20,
		TextColor3 = colors.panel,
	}, pill)
	UiKit.corner(key, 19)
	UiKit.label({
		Name = "Action",
		Position = UDim2.fromOffset(52, 4),
		Size = UDim2.new(1, -60, 0, 22),
		Text = prompt.ActionText,
		TextSize = 19,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, pill)
	UiKit.label({
		Name = "Object",
		Position = UDim2.fromOffset(52, 25),
		Size = UDim2.new(1, -60, 0, 18),
		Text = prompt.ObjectText,
		TextSize = 14,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, pill)
	-- Hold prompts fill a bar along the pill's bottom while the key (or a finger) is held.
	local holdBar = UiKit.create("Frame", {
		Name = "Hold",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 20, 1, -3),
		Size = UDim2.new(0, 0, 0, 4),
		BackgroundColor3 = colors.accent,
		BorderSizePixel = 0,
		Visible = prompt.HoldDuration > 0,
	}, pill)
	UiKit.corner(holdBar, 2)
	local holdWidth = 220 - 40
	holds[prompt] = function(holding: boolean)
		if holding then
			holdBar.Size = UDim2.new(0, 0, 0, 4)
			UiKit.tween(holdBar, prompt.HoldDuration, { Size = UDim2.new(0, holdWidth, 0, 4) }, Enum.EasingStyle.Linear)
		else
			holdBar.Size = UDim2.new(0, 0, 0, 4)
		end
	end
	-- Tapping (or clicking) the pill uses the prompt too, holding it as long as it needs.
	pill.Activated:Connect(function()
		pcall(function()
			prompt:InputHoldBegin()
		end)
		task.delay(prompt.HoldDuration + 0.05, function()
			pcall(function()
				prompt:InputHoldEnd()
			end)
		end)
	end)
	UiKit.pop(pill)
	placePill(gui)
	shown[prompt] = gui
	local tag = adornee:FindFirstChild("NameTag")
	if tag and tag:IsA("BillboardGui") and tag.Enabled then
		tag.Enabled = false
		hiddenTags[prompt] = tag
	end
end

function Prompts.anyShown(): boolean
	return next(shown) ~= nil
end

function Prompts.hide(prompt: ProximityPrompt)
	local gui = shown[prompt]
	holds[prompt] = nil
	if gui then
		shown[prompt] = nil
		gui:Destroy()
	end
	local tag = hiddenTags[prompt]
	if tag then
		hiddenTags[prompt] = nil
		tag.Enabled = true
	end
end

function Prompts.start()
	local function adopt(prompt: Instance)
		if prompt:IsA("ProximityPrompt") then
			prompt.Style = Enum.ProximityPromptStyle.Custom
		end
	end
	for _, descendant in workspace:GetDescendants() do
		adopt(descendant)
	end
	workspace.DescendantAdded:Connect(adopt)
	-- Story scenes film the person you talk to: no prompt pill over their face.
	RunService.Heartbeat:Connect(function()
		local inScene = Cinematic.blocking()
		for _, gui in shown do
			gui.Enabled = not inScene
			placePill(gui)
		end
	end)
	-- (Not every environment has the prompt events; Roblox always does.)
	pcall(function()
		ProximityPromptService.PromptShown:Connect(Prompts.show)
		ProximityPromptService.PromptHidden:Connect(Prompts.hide)
		ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
			local hold = holds[prompt]
			if hold then
				hold(true)
			end
		end)
		ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
			local hold = holds[prompt]
			if hold then
				hold(false)
			end
		end)
	end)
end

return Prompts
