-- Automatic weapon attacks and the light wave. Players never pick targets: every living player
-- with a loaded profile attacks the nearest enemy in range with the main weapon and with each
-- floating weapon, each on its own cooldown. Damage, range, line of sight and unlocks are all
-- decided here; the client only asks for the wave, the other abilities and weapon changes.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local WeaponData = require(Shared.WeaponData)
local Balance = require(Shared.Balance)
local Stats = require(Shared.Stats)
local EnemyService = require(script.Parent.EnemyService)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Profile = require(script.Parent.Profile)
local QuestService = require(script.Parent.QuestService)
local Targets = require(script.Parent.Targets)
local WeaponLogic = require(script.Parent.WeaponLogic)

local Remotes = ReplicatedStorage.Remotes
local requestWave = Remotes.RequestWave :: RemoteEvent
local requestAbility = Remotes.RequestAbility :: RemoteEvent
local equipWeapon = Remotes.EquipWeapon :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

-- Allowance for network jitter on the client's wave cooldown.
local COOLDOWN_TOLERANCE = 0.1
-- How soon an idle weapon looks for a target again.
local RETRY_DELAY = 0.12
local EQUIP_COOLDOWN = 0.3

-- Per player: next attack time per weapon slot, plus `due` = the earliest of them.
local nextAttack: { [Player]: { [any]: number } } = {}
local lastWave: { [Player]: number } = {}
local lastEquip: { [Player]: number } = {}
local random = Random.new()
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

-- Where a weapon attacks from: the hand for the main weapon, the hover spot for floating ones.
local function attackOrigin(root: BasePart, slot: number): Vector3
	if slot == 0 then
		return root.Position + Vector3.new(0, 1.5, 0)
	end
	local offset = WeaponData.companionOffsets[slot]
	return root.Position + root.CFrame.Rotation * Vector3.new(offset[1], offset[2], offset[3])
end

-- Returns true when the weapon found a target and attacked.
local function attack(target: Targets.Target, profile: Profile.Profile, stats: Stats.PlayerStats, slot: number, weaponId: string, foes): boolean
	local weapon = WeaponData.weapons[weaponId]
	if stats.rangeMultiplier ~= 1 then
		weapon = table.clone(weapon)
		weapon.range *= stats.rangeMultiplier
	end
	local origin = attackOrigin(target.root, slot)
	local look = target.root.CFrame.LookVector
	local accept = nil
	if weapon.ranged then
		accept = function(foe)
			local enemy = EnemyService.get(foe.id)
			return enemy ~= nil and hasLineOfSight(origin, enemy.body.Position - origin)
		end
	end
	local plan = WeaponLogic.plan(weapon, { x = origin.X, z = origin.Z }, { x = look.X, z = look.Z }, foes, accept)
	local primary = plan and EnemyService.get(plan.primary.id)
	if not plan or not primary then
		return false
	end
	local companion = slot > 0
	local damage = Progression.weaponDamage(weaponId, profile.staffUpgrade, stats.level, companion, profile.slotLevels[slot + 1], profile.weaponStars[weaponId])
		* stats.damageMultiplier
		* (if companion then stats.companionMultiplier else 1)
		* (if target.humanoid.Health <= target.humanoid.MaxHealth * Balance.fury.healthShare then 1 + stats.furyDamage else 1)
	local aim = primary.body.Position
	fx:FireAllClients("attack", target.player, weaponId, slot, origin, aim, profile.staffUpgrade)
	-- Heavy swings shove enemies back; other hits keep them in reach.
	local pushFrom = if weapon.style == "spin" or weapon.style == "slam" then origin else nil
	for _, id in plan.hits do
		local crit = random:NextNumber() < stats.critChance
		local amount = math.max(1, math.floor(damage * (if crit then Balance.critDamage else 1) + 0.5))
		EnemyService.damage(id, target.player, amount, pushFrom, crit)
	end
	return true
end

local function update()
	local now = os.clock()
	local foes = nil
	for _, target in Targets.get() do
		local player = target.player
		local profile = PlayerProfiles.get(player)
		local timers = nextAttack[player] or {}
		nextAttack[player] = timers
		-- Nothing to do until one of this player's weapons is ready again.
		if profile and now >= (timers.due or 0) then
			local main, companions = Profile.loadout(profile)
			local stats = Stats.of(profile)
			for slot = 0, #companions do
				if now >= (timers[slot] or 0) then
					local weaponId = if slot == 0 then main else companions[slot]
					foes = foes or EnemyService.foes()
					if attack(target, profile, stats, slot, weaponId, foes) then
						timers[slot] = now + Progression.weaponCooldown(weaponId, slot > 0) * stats.cooldownMultiplier
						-- Hits may have purified enemies; look again for the next weapon.
						foes = nil
					else
						timers[slot] = now + RETRY_DELAY
					end
				end
			end
			local due = math.huge
			for slot = 0, #companions do
				due = math.min(due, timers[slot] or 0)
			end
			timers.due = due
		end
	end
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
	local playerStats = Stats.of(profile)
	local stats = Progression.waveStats(profile.staffUpgrade, level, profile.equippedCharm, playerStats.waveRank)
	-- The wave hits like the main weapon (slot level and skills included) times the wave bonus, so
	-- it stays useful at every level.
	local main = Profile.loadout(profile)
	local waveDamage = Progression.weaponDamage(main, profile.staffUpgrade, level, false, profile.slotLevels[1], profile.weaponStars[main])
		* playerStats.damageMultiplier
		* Balance.wave.damageMultiplier
	stats.damage = math.max(stats.damage, math.floor(waveDamage + 0.5))
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

-- Star Fall and Lantern Glow. `id` comes from the client, so it is checked against Balance.
local lastAbility: { [Player]: { [string]: number } } = {}

local function onRequestAbility(player: Player, id: unknown)
	if typeof(id) ~= "string" or Balance.abilities[id :: string] == nil then
		return
	end
	local abilityId = id :: string
	local ability = Balance.abilities[abilityId]
	local now = os.clock()
	local profile = PlayerProfiles.get(player)
	local target = Targets.of(player)
	if not profile or not target then
		return
	end
	local level = Progression.levelForXp(profile.xp)
	if not Progression.abilityUnlocked(abilityId, level) then
		return
	end
	local timers = lastAbility[player] or {}
	lastAbility[player] = timers
	if timers[abilityId] and now - timers[abilityId] < ability.cooldown - COOLDOWN_TOLERANCE then
		return
	end
	local center = target.root.Position
	if abilityId == "star" then
		local best, bestDistance = nil, ability.range
		for _, foe in EnemyService.foes() do
			local distance = math.sqrt((foe.x - center.X) ^ 2 + (foe.z - center.Z) ^ 2)
			if distance <= bestDistance then
				best, bestDistance = foe, distance
			end
		end
		local enemy = best and EnemyService.get(best.id)
		if not best or not enemy then
			return -- nothing to hit: the cooldown is not spent
		end
		local playerStats = Stats.of(profile)
		local main = Profile.loadout(profile)
		local damage = Progression.weaponDamage(main, profile.staffUpgrade, level, false, profile.slotLevels[1], profile.weaponStars[main])
			* playerStats.damageMultiplier
			* ability.damageMultiplier
		timers[abilityId] = now
		fx:FireAllClients("ability", player, "star", enemy.body.Position, 0)
		EnemyService.damage(best.id, player, math.max(1, math.floor(damage + 0.5)), nil, true)
	elseif abilityId == "heal" then
		local humanoid = target.humanoid
		local healed = math.floor(math.min(humanoid.MaxHealth - humanoid.Health, humanoid.MaxHealth * ability.healShare) + 0.5)
		timers[abilityId] = now
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + healed)
		fx:FireAllClients("ability", player, "heal", center, healed)
	end
end

-- slot 0 = main weapon, 1..4 = floating slots; weaponId "" returns a floating slot to auto.
local function onEquipWeapon(player: Player, slot: unknown, weaponId: unknown)
	local now = os.clock()
	if lastEquip[player] and now - lastEquip[player] < EQUIP_COOLDOWN then
		return
	end
	if not isInteger(slot) or typeof(weaponId) ~= "string" or #(weaponId :: string) > 16 then
		return
	end
	lastEquip[player] = now
	local profile = PlayerProfiles.get(player)
	if profile and Profile.equipWeapon(profile, slot :: number, weaponId :: string) then
		PlayerProfiles.sync(player)
	end
end

local CombatService = {}

function CombatService.start()
	requestWave.OnServerEvent:Connect(onRequestWave)
	requestAbility.OnServerEvent:Connect(onRequestAbility)
	equipWeapon.OnServerEvent:Connect(onEquipWeapon)
	RunService.Heartbeat:Connect(update)
	Players.PlayerRemoving:Connect(function(player)
		nextAttack[player] = nil
		lastWave[player] = nil
		lastAbility[player] = nil
		lastEquip[player] = nil
	end)
end

return CombatService
