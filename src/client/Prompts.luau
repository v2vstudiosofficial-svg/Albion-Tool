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

local Prompts = {}

local shown: { [ProximityPrompt]: BillboardGui } = {}
-- The thing's own name tag is hidden while the prompt (which names it too) is up.
local hiddenTags: { [ProximityPrompt]: BillboardGui } = {}

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
		StudsOffset = Vector3.new(0, 2.6, 0),
		LightInfluence = 0,
		Active = true,
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
	-- Tapping (or clicking) the pill uses the prompt too.
	pill.Activated:Connect(function()
		pcall(function()
			prompt:InputHoldBegin()
			prompt:InputHoldEnd()
		end)
	end)
	UiKit.pop(pill)
	shown[prompt] = gui
	local tag = adornee:FindFirstChild("NameTag")
	if tag and tag:IsA("BillboardGui") and tag.Enabled then
		tag.Enabled = false
		hiddenTags[prompt] = tag
	end
end

function Prompts.hide(prompt: ProximityPrompt)
	local gui = shown[prompt]
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
		end
	end)
	-- (Not every environment has the prompt events; Roblox always does.)
	pcall(function()
		ProximityPromptService.PromptShown:Connect(Prompts.show)
		ProximityPromptService.PromptHidden:Connect(Prompts.hide)
	end)
end

return Prompts
