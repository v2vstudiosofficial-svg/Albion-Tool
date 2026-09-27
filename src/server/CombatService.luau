-- Validates client attack requests. The client only names a target; damage, range, line of sight,
-- cooldowns and unlocks are all decided here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local Progression = require(Shared.Progression)
local EnemyService = require(script.Parent.EnemyService)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local QuestService = require(script.Parent.QuestService)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local requestAttack = Remotes.RequestAttack :: RemoteEvent
local requestWave = Remotes.RequestWave :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

-- Allowances for network jitter and target movement between client and server.
local COOLDOWN_TOLERANCE = 0.1
local RANGE_TOLERANCE = 4

local lastAttack: { [Player]: number } = {}
local lastWave: { [Player]: number } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function hasLineOfSight(origin: Vector3, offset: Vector3): boolean
	local exclude: { Instance } = { EnemyService.getFolder() }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	rayParams.FilterDescendantsInstances = exclude
	return workspace:Raycast(origin, offset, rayParams) == nil
end

local function isInteger(value: unknown): boolean
	return typeof(value) == "number" and value == value and value % 1 == 0
end

local function onRequestAttack(player: Player, enemyId: unknown)
	local now = os.clock()
	local last = lastAttack[player]
	if last and now - last < Balance.staff.cooldown - COOLDOWN_TOLERANCE then
		return
	end
	if not isInteger(enemyId) then
		return
	end
	-- Every well-formed request consumes the cooldown, which also rate-limits the raycast below.
	lastAttack[player] = now

	local profile = PlayerProfiles.get(player)
	local target = Targets.of(player)
	local enemy = EnemyService.get(enemyId :: number)
	if not profile or not target or not enemy or not enemy.logic.alive then
		return
	end

	local origin = target.root.Position + Vector3.new(0, 1.5, 0)
	local targetPosition = enemy.body.Position
	local offset = targetPosition - origin
	local reach = Balance.staff.range + RANGE_TOLERANCE + enemy.stats.size * 0.5
	if offset.Magnitude > reach or not hasLineOfSight(origin, offset) then
		return
	end

	local level = Progression.levelForXp(profile.xp)
	fx:FireAllClients("bolt", player, origin, targetPosition, profile.staffUpgrade)
	EnemyService.damage(enemy.id, player, Progression.staffDamage(profile.staffUpgrade, level), origin)
end

local function onRequestWave(player: Player)
	local now = os.clock()
	local profile = PlayerProfiles.get(player)
	local target = Targets.of(player)
	if not profile or not target then
		return
	end
	local level = Progression.levelForXp(profile.xp)
	if not Progression.waveUnlocked(level) then
		return
	end
	local stats = Progression.waveStats(profile.staffUpgrade, level, profile.equippedCharm)
	local last = lastWave[player]
	if last and now - last < stats.cooldown - COOLDOWN_TOLERANCE then
		return
	end
	lastWave[player] = now

	local center = target.root.Position
	fx:FireAllClients("wave", player, center, stats.radius, profile.staffUpgrade)
	EnemyService.damageInRadius(center, stats.radius, player, stats.damage, stats.knockback)
	QuestService.onWave(player, center, stats.radius)
end

local CombatService = {}

function CombatService.start()
	requestAttack.OnServerEvent:Connect(onRequestAttack)
	requestWave.OnServerEvent:Connect(onRequestWave)
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		lastWave[player] = nil
	end)
end

return CombatService
