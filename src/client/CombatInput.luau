-- Picks a target locally (with light aim assist) and asks the server to attack it.
-- The server re-validates everything; this only improves feel.
local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Strings = require(Shared:WaitForChild("Strings"))
local requestAttack = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RequestAttack") :: RemoteEvent

local ACTION = "LightAttack"
local FACING_BONUS = 8 -- studs of preference given to enemies in front of the player

local player = Players.LocalPlayer
local lastAttack = 0
local mouseRayParams = RaycastParams.new()
mouseRayParams.FilterType = Enum.RaycastFilterType.Exclude

local function aliveEnemy(instance: Instance?): Model?
	local enemies = workspace:FindFirstChild("Enemies")
	local model = instance and instance:FindFirstAncestorOfClass("Model")
	if enemies and model and model.Parent == enemies and model:GetAttribute("Alive") and model.PrimaryPart then
		return model
	end
	return nil
end

local function inRange(root: BasePart, model: Model): boolean
	return ((model.PrimaryPart :: BasePart).Position - root.Position).Magnitude <= Balance.staff.range
end

local function enemyUnderMouse(root: BasePart): Model?
	local camera = workspace.CurrentCamera
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	mouseRayParams.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, mouseRayParams)
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
		local model = aliveEnemy(child)
		if model and inRange(root, model) then
			local offset = (model.PrimaryPart :: BasePart).Position - root.Position
			local facing = if offset.Magnitude > 0.01 then root.CFrame.LookVector:Dot(offset.Unit) else 1
			local score = offset.Magnitude - facing * FACING_BONUS
			if score < bestScore then
				best, bestScore = model, score
			end
		end
	end
	return best
end

local function attack(useMouse: boolean)
	local now = os.clock()
	if now - lastAttack < Balance.staff.cooldown then
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local target = (useMouse and enemyUnderMouse(root)) or assistedTarget(root)
	if not target then
		return
	end
	lastAttack = now
	local targetPosition = (target.PrimaryPart :: BasePart).Position
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z))
	requestAttack:FireServer(target:GetAttribute("EnemyId"))
end

local CombatInput = {}

function CombatInput.start()
	ContextActionService:BindAction(ACTION, function(_, state, input)
		if state ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		local isMouse = input.UserInputType == Enum.UserInputType.MouseButton1
		attack(isMouse)
		return if isMouse then Enum.ContextActionResult.Pass else Enum.ContextActionResult.Sink
	end, true, Enum.UserInputType.MouseButton1, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
	ContextActionService:SetTitle(ACTION, Strings.get("attack_button"))
end

return CombatInput
