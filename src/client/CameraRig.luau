-- Angled top-down follow camera (mobile action-RPG style) and the local weapon range ring.
-- Mouse wheel / pinch zooms between fixed limits; the angle never changes while you play, so
-- movement always feels the same (the default controls move relative to the camera). Left alone
-- for a while, the camera slowly circles the hero and comes straight back on any input.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)
local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

-- The camera sits above and behind (+Z) its focus point.
local VIEW_DIRECTION = Vector3.new(0, 0.8, 0.6).Unit
local DEFAULT_DISTANCE = 50
local MIN_DISTANCE = 32
local MAX_DISTANCE = 70
local FOLLOW_SPEED = 10
local FIELD_OF_VIEW = 50
local RING_WIDTH = 0.35
local IDLE_AFTER = 25 -- seconds without moving or any input before the camera starts to circle
local ORBIT_SPEED = math.rad(6) -- per second
local ORBIT_IN = 3 -- seconds to ease into the circling
local ORBIT_OUT = 0.5 -- seconds to swing back once the player is active again

local CameraRig = {}

CameraRig.distance = DEFAULT_DISTANCE
local focus: Vector3? = nil

-- A story shot: while set, the camera glides to `from` looking at `focus` (Cinematic). When it
-- ends, the camera eases back to the follow view instead of jumping.
export type Shot = { from: Vector3, focus: Vector3, fov: number }
local shot: Shot? = nil
local settle = 0 -- 1 right after a shot ends, fading to 0 as the follow view takes over
local leftCFrame: CFrame? = nil
local leftFov = FIELD_OF_VIEW
local punchDegrees = 0 -- a brief zoom-in (level-ups, big moments) that fades on its own
local activeAt = os.clock() -- the last time the player moved, touched a control or was hit
local lastHealth = math.huge
local orbit = 0 -- how far the idle camera has circled (radians)
local orbitBlend = 0 -- 0 = the normal view, 1 = fully circling

function CameraRig.setShot(newShot: Shot?)
	local camera = workspace.CurrentCamera
	if shot and not newShot and camera then
		leftCFrame, leftFov, settle = camera.CFrame, camera.FieldOfView, 1
	end
	shot = newShot
end

-- The story shot in use, if any (a boss intro does not interrupt a story scene).
function CameraRig.currentShot(): Shot?
	return shot
end

function CameraRig.punch(degrees: number)
	if not Settings.get("shake") then
		return
	end
	punchDegrees = math.max(punchDegrees, degrees)
end

-- The follow view of `target`; `turn` (radians) swings it around the target.
function CameraRig.cframeFor(target: Vector3, distance: number, turn: number?): CFrame
	local direction = if turn and turn ~= 0 then CFrame.Angles(0, turn, 0):VectorToWorldSpace(VIEW_DIRECTION) else VIEW_DIRECTION
	return CFrame.lookAt(target + direction * distance, target)
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
		camera.FieldOfView = Settings.get("fov")
	end
	if shot then
		local glide = math.clamp(dt * 3.5, 0, 1)
		camera.CFrame = camera.CFrame:Lerp(CFrame.lookAt(shot.from, shot.focus), glide)
		camera.FieldOfView += (shot.fov - camera.FieldOfView) * glide
		return
	end
	local humanoid, root = character()
	local ok, moving = pcall(function()
		return humanoid ~= nil and humanoid.MoveDirection.Magnitude > 0.05
	end)
	local health = if humanoid then humanoid.Health else math.huge
	-- Standing still in a fight is not idle.
	if (ok and moving) or health < lastHealth then
		activeAt = os.clock()
	end
	lastHealth = health
	if os.clock() - activeAt >= IDLE_AFTER then
		orbitBlend = math.min(1, orbitBlend + dt / ORBIT_IN)
	else
		orbitBlend = math.max(0, orbitBlend - dt / ORBIT_OUT)
	end
	orbit = if orbitBlend > 0 then orbit + ORBIT_SPEED * dt * orbitBlend else 0
	-- Back the shortest way round.
	local turn = ((orbit + math.pi) % (2 * math.pi) - math.pi) * orbitBlend
	if root then
		local goal = root.Position
		focus = if focus and (focus - goal).Magnitude < 60 then focus:Lerp(goal, math.clamp(dt * FOLLOW_SPEED, 0, 1)) else goal
	end
	punchDegrees *= math.exp(-dt * 6)
	local fov = Settings.get("fov") - punchDegrees
	if focus then
		local follow = CameraRig.cframeFor(focus, CameraRig.distance, turn)
		if settle > 0 and leftCFrame then
			settle = math.max(0, settle - dt * 2.5)
			local eased = 1 - settle * settle
			camera.CFrame = leftCFrame:Lerp(follow, eased)
			fov = leftFov + (fov - leftFov) * eased
		else
			camera.CFrame = follow
		end
		camera.Focus = CFrame.new(focus)
	end
	camera.FieldOfView = fov
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
	local shown = alive and Settings.get("rangeRing")
	edge.Visible = shown
	fill.Visible = shown
	if not shown then
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

	UserInputService.InputBegan:Connect(function()
		activeAt = os.clock()
	end)
	UserInputService.InputChanged:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.MouseWheel then
			activeAt = os.clock()
		end
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
