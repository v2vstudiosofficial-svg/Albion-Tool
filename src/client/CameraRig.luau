-- Angled top-down follow camera (mobile action-RPG style) and the local weapon range ring.
-- Mouse wheel / pinch zooms between fixed limits; the angle never changes, so movement always
-- feels the same (the default controls move relative to the camera).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

-- The camera sits above and behind (+Z) its focus point.
local VIEW_DIRECTION = Vector3.new(0, 0.8, 0.6).Unit
local DEFAULT_DISTANCE = 50
local MIN_DISTANCE = 32
local MAX_DISTANCE = 70
local FOLLOW_SPEED = 10
local FIELD_OF_VIEW = 50
local RING_WIDTH = 0.35

local CameraRig = {}

CameraRig.distance = DEFAULT_DISTANCE
local focus: Vector3? = nil

function CameraRig.cframeFor(target: Vector3, distance: number): CFrame
	return CFrame.lookAt(target + VIEW_DIRECTION * distance, target)
end

function CameraRig.zoom(delta: number)
	CameraRig.distance = math.clamp(CameraRig.distance + delta, MIN_DISTANCE, MAX_DISTANCE)
end

local function character(): (Humanoid?, BasePart?)
	local model = player.Character
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	local root = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, root
end

local function updateCamera(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if camera.CameraType ~= Enum.CameraType.Scriptable then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = FIELD_OF_VIEW
	end
	local _, root = character()
	if root then
		local goal = root.Position
		focus = if focus and (focus - goal).Magnitude < 60 then focus:Lerp(goal, math.clamp(dt * FOLLOW_SPEED, 0, 1)) else goal
	end
	if focus then
		camera.CFrame = CameraRig.cframeFor(focus, CameraRig.distance)
		camera.Focus = CFrame.new(focus)
	end
end

-- A flat ring on the ground showing how far the main weapon reaches.
local function buildRing(parent: Instance): (CylinderHandleAdornment, CylinderHandleAdornment)
	local edge = UiKit.create("CylinderHandleAdornment", {
		Name = "RangeRing",
		Color3 = Color3.new(1, 1, 1),
		Transparency = 0.35,
		Height = 0.12,
		ZIndex = 0,
		AlwaysOnTop = false,
		Visible = false,
	}, parent)
	local fill = UiKit.create("CylinderHandleAdornment", {
		Name = "RangeFill",
		Color3 = Color3.new(1, 1, 1),
		Transparency = 0.9,
		Height = 0.08,
		ZIndex = 0,
		AlwaysOnTop = false,
		Visible = false,
	}, parent)
	return edge, fill
end

local function updateRing(edge: CylinderHandleAdornment, fill: CylinderHandleAdornment)
	local humanoid, root = character()
	local alive = humanoid ~= nil and root ~= nil and humanoid.Health > 0
	edge.Visible = alive
	fill.Visible = alive
	if not alive then
		return
	end
	local weapon = WeaponData.weapons[Attrs.get("Weapon", "staff")] or WeaponData.weapons.staff
	local radius = weapon.range * Attrs.stats().rangeMultiplier
	local drop = (root :: BasePart).Size.Y / 2 + (humanoid :: Humanoid).HipHeight - 0.1
	local flat = CFrame.new(0, -drop, 0) * CFrame.Angles(math.rad(90), 0, 0)
	for _, ring in { edge, fill } do
		ring.Adornee = root
		ring.CFrame = flat
		ring.Radius = radius
	end
	edge.InnerRadius = radius - RING_WIDTH
end

function CameraRig.start()
	-- Adornments render reliably from the workspace; this folder only exists on this client.
	local folder = UiKit.create("Folder", { Name = "ClientRing" }, workspace)
	local edge, fill = buildRing(folder)

	UserInputService.InputChanged:Connect(function(input, processed)
		if not processed and input.UserInputType == Enum.UserInputType.MouseWheel then
			CameraRig.zoom(-input.Position.Z * 4)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale, _, state, processed)
		if not processed and state == Enum.UserInputState.Change and scale > 0 then
			CameraRig.zoom((1 - scale) * 6)
		end
	end)

	RunService:BindToRenderStep("LvCamera", Enum.RenderPriority.Camera.Value, function(dt)
		updateCamera(dt)
		updateRing(edge, fill)
	end)
end

return CameraRig
