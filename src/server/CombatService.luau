local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local EnemyService = require(script.Parent.EnemyService)

local requestAttack = ReplicatedStorage.Remotes.RequestAttack :: RemoteEvent

-- Allowances for network jitter and target movement between client and server.
local COOLDOWN_TOLERANCE = 0.1
local RANGE_TOLERANCE = 4
local BOLT_COLOR = Color3.fromRGB(255, 235, 150)

local lastAttack: { [Player]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local effects: Folder

local function showBolt(from: Vector3, to: Vector3)
	local length = (to - from).Magnitude
	if length < 0.05 then
		return
	end
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.CanTouch = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = BOLT_COLOR
	bolt.Size = Vector3.new(0.35, 0.35, length)
	bolt.CFrame = CFrame.lookAt((from + to) / 2, to)
	bolt.Parent = effects
	Debris:AddItem(bolt, 0.15)
end

local function hasLineOfSight(origin: Vector3, offset: Vector3): boolean
	local exclude: { Instance } = { EnemyService.getFolder(), effects }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(origin, offset, rayParams) == nil
end

local function onRequestAttack(player: Player, enemyId: unknown)
	local now = os.clock()
	local last = lastAttack[player]
	if last and now - last < Balance.staff.cooldown - COOLDOWN_TOLERANCE then
		return
	end
	if typeof(enemyId) ~= "number" or enemyId ~= enemyId or enemyId % 1 ~= 0 then
		return
	end
	-- Every well-formed request consumes the cooldown, which also rate-limits the raycast below.
	lastAttack[player] = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	local enemy = EnemyService.get(enemyId)
	if not enemy or not enemy.logic.alive then
		return
	end

	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local targetPosition = enemy.body.Position
	local offset = targetPosition - origin
	if offset.Magnitude > Balance.staff.range + RANGE_TOLERANCE then
		return
	end
	if not hasLineOfSight(origin, offset) then
		return
	end

	showBolt(origin, targetPosition)
	EnemyService.damage(enemyId, player, Balance.staff.damage)
end

local CombatService = {}

function CombatService.start()
	effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = workspace

	requestAttack.OnServerEvent:Connect(onRequestAttack)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
	end)
end

return CombatService
