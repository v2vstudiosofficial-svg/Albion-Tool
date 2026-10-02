-- Enemy registry, AI and server-validated damage. Enemies sleep while no player is near their zone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local Progression = require(Shared.Progression)
local WorldData = require(Shared.WorldData)
local CreatureMotion = require(Shared.CreatureMotion)
local EnemyLogic = require(script.Parent.EnemyLogic)
local EnemyModels = require(script.Parent.EnemyModels)
local Projectiles = require(script.Parent.Projectiles)
local Targets = require(script.Parent.Targets)
local CharacterService = require(script.Parent.CharacterService)
local WardenBehavior = require(script.Parent.WardenBehavior)

local Remotes = ReplicatedStorage.Remotes
local fx = Remotes.Fx :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent

type Target = Targets.Target

export type Enemy = {
	id: number,
	kind: string,
	stats: any,
	level: number,
	-- Level-scaled full health (bosses rescale from this when a fight starts or resets).
	baseMaxHp: number,
	-- Level-scaled values: damage multiplier for its attacks and the purify reward.
	damageMultiplier: number,
	reward: any,
	model: Model,
	body: BasePart,
	spawnIndex: number?,
	elite: boolean,
	tag: string?,
	areaCenter: Vector3,
	areaRadius: number,
	home: Vector3,
	position: Vector3,
	facing: Vector3,
	logic: EnemyLogic.State,
	lastContact: { [Player]: number },
	state: string,
	stateUntil: number,
	memory: { [string]: any },
}

local EnemyService = {}

local enemies: { [number]: Enemy } = {}
local random = Random.new()
local purifiedListeners: { (string, any, { Player }, Vector3, any) -> () } = {}
local folder: Folder
local nextId = 0

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function flatDistance(a: Vector3, b: Vector3): number
	return flat(a - b).Magnitude
end

local function publishHp(enemy: Enemy)
	enemy.model:SetAttribute("Hp", enemy.logic.hp)
	enemy.model:SetAttribute("MaxHp", enemy.logic.maxHp)
end

-- Shared helpers handed to behaviors.
local ctx = {}
ctx.targets = {} :: { Target }

function ctx.nearest(enemy: Enemy, radius: number): Target?
	local best: Target? = nil
	local bestDistance = radius
	for _, target in ctx.targets do
		local position = target.root.Position
		local distance = flatDistance(position, enemy.position)
		if distance < bestDistance and flatDistance(position, enemy.home) <= enemy.stats.leashRadius then
			best, bestDistance = target, distance
		end
	end
	return best
end

function ctx.moveToward(enemy: Enemy, goal: Vector3, speed: number, dt: number, stopDistance: number)
	local offset = flat(goal - enemy.position)
	local distance = offset.Magnitude
	if distance > stopDistance and distance > 0.01 then
		enemy.position += offset.Unit * math.min(speed * dt, distance - stopDistance)
	end
end

function ctx.face(enemy: Enemy, point: Vector3)
	local direction = flat(point - enemy.position)
	if direction.Magnitude > 0.1 then
		enemy.facing = direction.Unit
	end
end

function ctx.clampToLeash(enemy: Enemy)
	local offset = flat(enemy.position - enemy.home)
	if offset.Magnitude > enemy.stats.leashRadius then
		enemy.position = enemy.home + offset.Unit * enemy.stats.leashRadius
	end
end

function ctx.hurt(target: Target, amount: number, from: Vector3)
	CharacterService.damage(target.player, target.humanoid, amount, from)
end

function ctx.contact(enemy: Enemy, now: number, damage: number?)
	local stats = enemy.stats
	for _, target in ctx.targets do
		if (target.root.Position - enemy.position).Magnitude <= stats.contactRange + stats.size * 0.25 then
			local last = enemy.lastContact[target.player]
			if not last or now - last >= stats.contactCooldown then
				enemy.lastContact[target.player] = now
				ctx.hurt(target, (damage or stats.contactDamage) * enemy.damageMultiplier, enemy.position)
			end
		end
	end
end

-- Starts a wind-up pose (CreatureMotion): `pose` for `duration` seconds from now.
function ctx.windup(enemy: Enemy, duration: number, pose: string)
	local memory = enemy.memory
	memory.pose, memory.poseFrom, memory.poseUntil = pose, os.clock(), os.clock() + duration
end

function ctx.fx(...)
	fx:FireAllClients(...)
end

function ctx.publishHp(enemy: Enemy)
	publishHp(enemy)
end

function ctx.noticeNear(center: Vector3, radius: number, key: string, ...)
	for _, target in ctx.targets do
		if flatDistance(target.root.Position, center) <= radius then
			notice:FireClient(target.player, key, ...)
		end
	end
end

ctx.projectiles = Projectiles

local function staggered(enemy: Enemy, now: number): boolean
	if enemy.state ~= "recover" then
		return false
	end
	if now < enemy.stateUntil then
		return true
	end
	enemy.state = "idle"
	return false
end

local behaviors = {}

-- Blinking chasers (stats.blink = { range, cooldown, distance, windup }): when the target is
-- far, a short visible wind-up, then a hop toward it.
local function tryBlink(enemy: Enemy, target: Target?, now: number): boolean
	local blink = enemy.stats.blink
	local memory = enemy.memory
	if not blink then
		return false
	end
	if memory.blinkAt then
		if now < memory.blinkAt then
			return true -- winding up: stand still
		end
		memory.blinkAt = nil
		if target then
			local from = enemy.position
			local offset = flat(target.root.Position - from)
			local hop = math.min(blink.distance, math.max(0, offset.Magnitude - enemy.stats.contactRange))
			if offset.Magnitude > 0.1 and hop > 0 then
				enemy.position += offset.Unit * hop
				ctx.clampToLeash(enemy)
				ctx.fx("blink", from, enemy.position)
			end
		end
		memory.nextBlink = now + blink.cooldown
		return true
	end
	if target and now >= (memory.nextBlink or 0) and flatDistance(target.root.Position, enemy.position) > blink.range then
		memory.blinkAt = now + blink.windup
		ctx.windup(enemy, blink.windup, "blink")
		ctx.fx("windup", enemy.model, blink.windup)
		return true
	end
	return false
end

function behaviors.chaser(enemy: Enemy, dt: number, now: number)
	if staggered(enemy, now) then
		return
	end
	local stats = enemy.stats
	local target = ctx.nearest(enemy, stats.aggroRadius)
	if tryBlink(enemy, target, now) then
		return
	end
	local goal = if target then target.root.Position else enemy.home
	enemy.memory.close = target ~= nil and flatDistance(goal, enemy.position) <= stats.contactRange * 2
	ctx.moveToward(enemy, goal, stats.speed, dt, if target then stats.contactRange * 0.6 else 0.2)
	ctx.face(enemy, goal)
	ctx.contact(enemy, now)
end

function behaviors.shooter(enemy: Enemy, dt: number, now: number)
	if staggered(enemy, now) then
		return
	end
	local stats = enemy.stats
	local memory = enemy.memory
	local target = ctx.nearest(enemy, stats.aggroRadius)
	if not target then
		enemy.state = "idle"
		ctx.moveToward(enemy, enemy.home, stats.speed, dt, 0.2)
		ctx.face(enemy, enemy.home)
		return
	end
	local targetPosition = target.root.Position
	ctx.face(enemy, targetPosition)

	if enemy.state == "windup" then
		if now >= enemy.stateUntil then
			local origin = enemy.body.Position
			local direction = (targetPosition - origin)
			if direction.Magnitude > 0.1 then
				-- Several spores fan out evenly (stats.shots, stats.spread degrees apart).
				local shots = stats.shots or 1
				for index = 1, shots do
					local angle = math.rad((index - (shots + 1) / 2) * (stats.spread or 0))
					local aim = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, direction.Unit)).LookVector
					ctx.projectiles.fire(
						origin + aim * stats.size * 0.6,
						aim * stats.projectileSpeed,
						stats.projectileRadius,
						stats.projectileDamage * enemy.damageMultiplier,
						stats.projectileLifetime,
						"spore"
					)
				end
			end
			memory.nextShot = now + stats.fireInterval
			enemy.state = "idle"
		end
		return
	end

	local distance = flatDistance(targetPosition, enemy.position)
	if distance < stats.preferredMin then
		local awayDirection = if distance > 0.05 then flat(enemy.position - targetPosition).Unit else -enemy.facing
		local away = enemy.position + awayDirection * 6
		ctx.moveToward(enemy, away, stats.speed, dt, 0)
		ctx.clampToLeash(enemy)
	elseif distance > stats.preferredMax then
		ctx.moveToward(enemy, targetPosition, stats.speed, dt, stats.preferredMax - 1)
	end

	if now >= (memory.nextShot or 0) and distance <= stats.aggroRadius then
		enemy.state = "windup"
		enemy.stateUntil = now + stats.windup
		ctx.windup(enemy, stats.windup, "shoot")
		ctx.fx("windup", enemy.model, stats.windup)
	end
	ctx.contact(enemy, now)
end

function behaviors.charger(enemy: Enemy, dt: number, now: number)
	local stats = enemy.stats
	local memory = enemy.memory

	if enemy.state == "windup" then
		if now >= enemy.stateUntil then
			enemy.state = "dash"
			enemy.stateUntil = now + stats.dashDuration
			memory.dashHits = {}
		end
		return
	elseif enemy.state == "dash" then
		enemy.position += enemy.facing * stats.dashSpeed * dt
		local beyond = flatDistance(enemy.position, enemy.home) > stats.leashRadius
		ctx.clampToLeash(enemy)
		for _, target in ctx.targets do
			if not memory.dashHits[target.player] and (target.root.Position - enemy.position).Magnitude <= stats.contactRange + 0.8 then
				memory.dashHits[target.player] = true
				ctx.hurt(target, stats.dashDamage * enemy.damageMultiplier, enemy.position)
			end
		end
		if beyond or now >= enemy.stateUntil then
			enemy.state = "recover"
			enemy.stateUntil = now + stats.recover
		end
		return
	elseif enemy.state == "recover" then
		if now >= enemy.stateUntil then
			enemy.state = "idle"
		end
		return
	end

	local target = ctx.nearest(enemy, stats.aggroRadius)
	if not target then
		ctx.moveToward(enemy, enemy.home, stats.speed, dt, 0.2)
		ctx.face(enemy, enemy.home)
		return
	end
	local targetPosition = target.root.Position
	ctx.face(enemy, targetPosition)
	if flatDistance(targetPosition, enemy.position) > stats.chargeRange then
		ctx.moveToward(enemy, targetPosition, stats.speed, dt, stats.chargeRange - 2)
	else
		enemy.state = "windup"
		enemy.stateUntil = now + stats.windup
		ctx.windup(enemy, stats.windup, "charge")
		ctx.fx("windup", enemy.model, stats.windup)
	end
	ctx.contact(enemy, now)
end

behaviors.boss = function(enemy: Enemy, dt: number, now: number)
	WardenBehavior.update(enemy, ctx, dt, now)
end

-- Replicates a simple "noticed a player" flag so clients can pop a small "!" above the enemy.
local function updateAggro(enemy: Enemy)
	local stats = enemy.stats
	local aggro = false
	if stats.isBoss then
		aggro = enemy.memory.engaged == true
	else
		aggro = ctx.nearest(enemy, stats.aggroRadius) ~= nil
	end
	if enemy.memory.aggro ~= aggro then
		enemy.memory.aggro = aggro
		enemy.model:SetAttribute("Aggro", aggro)
	end
end

-- Each creature kind moves its own way (EnemyModels.motions, CreatureMotion) with its own tempo,
-- and takes a telling pose before and during its attacks.
local function place(enemy: Enemy, now: number)
	local memory = enemy.memory
	local motion = EnemyModels.motions[enemy.kind] or EnemyModels.motions[enemy.stats.model or ""] or "hop"
	local t = now * (0.85 + ((enemy.id * 0.137) % 1) * 0.3) + enemy.id
	local action, progress = nil, 0
	if memory.poseUntil and now < memory.poseUntil then
		action = memory.pose
		progress = (now - memory.poseFrom) / math.max(0.01, memory.poseUntil - memory.poseFrom)
	elseif enemy.state == "dash" then
		action = "dash"
	elseif enemy.state == "recover" then
		action = "dizzy"
	elseif memory.close then
		action = "lunge"
	end
	local pose = CreatureMotion.pose(motion, t, action, progress)
	local position = enemy.position + Vector3.new(math.sin(now * 60) * pose.shake, pose.height, 0)
	enemy.body.CFrame = CFrame.lookAt(position, position + enemy.facing) * CFrame.Angles(pose.pitch, pose.yaw, pose.roll)
end

export type SpawnOptions = {
	-- Index into WorldData.spawns; purified enemies with one respawn there. Nil = temporary.
	spawnIndex: number?,
	elite: boolean?,
	-- Free-form label for systems that track their own enemies (e.g. "rift").
	tag: string?,
	-- Extra health / damage multipliers (the Shadow Tower past level 100).
	scale: { hp: number, damage: number }?,
}

local function createEnemy(kind: string, level: number, position: Vector3, areaId: string, options: SpawnOptions): Enemy
	local base = Balance.enemies[kind]
	local area = WorldData.areas[areaId]
	local scaled = Progression.enemyStats(base, level)
	local stats = base
	if options.elite then
		scaled = Progression.eliteStats(scaled)
		stats = table.clone(base)
		stats.size *= Balance.elite.sizeMultiplier
		stats.elite = true
	end
	if options.scale then
		scaled = table.clone(scaled)
		scaled.maxHp = math.max(1, math.floor(scaled.maxHp * options.scale.hp + 0.5))
		scaled.damageMultiplier *= options.scale.damage
	end
	nextId += 1
	local home = position + Vector3.new(0, stats.hoverHeight, 0)
	local model, body = EnemyModels.build(kind, stats, CFrame.new(home), nextId)
	model:SetAttribute("EnemyId", nextId)
	model:SetAttribute("EnemyType", kind)
	model:SetAttribute("Level", level)
	model:SetAttribute("Boss", stats.isBoss == true)
	model:SetAttribute("Elite", options.elite == true)
	model:SetAttribute("Alive", true)

	local enemy: Enemy = {
		id = nextId,
		kind = kind,
		stats = stats,
		level = level,
		elite = options.elite == true,
		tag = options.tag,
		baseMaxHp = scaled.maxHp,
		damageMultiplier = scaled.damageMultiplier,
		reward = scaled.reward,
		model = model,
		body = body,
		spawnIndex = options.spawnIndex,
		areaCenter = WorldData.vector(area.center),
		areaRadius = area.radius,
		home = home,
		position = home,
		facing = Vector3.new(0, 0, 1),
		logic = EnemyLogic.new(scaled.maxHp),
		lastContact = {},
		state = "idle",
		stateUntil = 0,
		memory = {},
	}
	publishHp(enemy)
	model.Parent = folder
	enemies[nextId] = enemy
	return enemy
end

local function spawnAt(spawnIndex: number)
	local spawn = WorldData.spawns[spawnIndex]
	local stats = Balance.enemies[spawn.kind]
	local level = spawn.level or (if spawn.levels then random:NextInteger(spawn.levels[1], spawn.levels[2]) else 1)
	local elite = not stats.isBoss and random:NextNumber() < Balance.elite.chance
	createEnemy(spawn.kind, level, WorldData.vector(spawn.position), spawn.area, { spawnIndex = spawnIndex, elite = elite })
end

-- A one-off enemy that never respawns (wave events). Returns its id.
function EnemyService.spawnTemporary(kind: string, level: number, position: Vector3, areaId: string, tag: string?, elite: boolean?, scale: { hp: number, damage: number }?): number
	return createEnemy(kind, level, position, areaId, { tag = tag, elite = elite, scale = scale }).id
end

local function purify(enemy: Enemy)
	enemies[enemy.id] = nil
	local window = enemy.stats.participationWindow or Balance.participationWindow
	local participants = EnemyLogic.participants(enemy.logic, os.clock(), window, function(player)
		return player.Parent == Players
	end)
	local position = enemy.body.Position
	enemy.model:SetAttribute("Alive", false)
	fx:FireAllClients("purify", position, enemy.kind, enemy.facing)
	enemy.model:Destroy()
	if enemy.spawnIndex then
		task.delay(enemy.stats.respawnDelay, spawnAt, enemy.spawnIndex)
	end
	for _, listener in purifiedListeners do
		task.spawn(listener, enemy.kind, enemy.reward, participants, position, enemy)
	end
end

-- Removes an enemy without rewards (a failed wave event fading away).
function EnemyService.despawn(id: number)
	local enemy = enemies[id]
	if not enemy then
		return
	end
	enemies[id] = nil
	enemy.model:SetAttribute("Alive", false)
	fx:FireAllClients("despawn", enemy.body.Position)
	enemy.model:Destroy()
end

function EnemyService.get(id: number): Enemy?
	return enemies[id]
end

-- Living enemies as flat points for weapon targeting (see WeaponLogic).
function EnemyService.foes(): { { id: number, x: number, z: number, size: number } }
	local list = {}
	for id, enemy in enemies do
		if enemy.logic.alive then
			table.insert(list, { id = id, x = enemy.position.X, z = enemy.position.Z, size = enemy.stats.size })
		end
	end
	return list
end

function EnemyService.getFolder(): Folder
	return folder
end

-- listener(enemyType, reward, participants, position, enemy)
function EnemyService.connectPurified(listener: (string, any, { Player }, Vector3, any) -> ())
	table.insert(purifiedListeners, listener)
end

-- Moves the enemy away from a point and places it immediately, so effects use the new spot.
local function pushAway(enemy: Enemy, from: Vector3, distance: number)
	local away = flat(enemy.position - from)
	if away.Magnitude > 0.01 then
		enemy.position += away.Unit * distance
		ctx.clampToLeash(enemy)
		place(enemy, os.clock())
	end
end

-- Server-validated damage entry point; returns true when the hit was applied.
-- pushFrom (optional) nudges regular enemies away from the attacker for a punchier hit;
-- crit only changes how the hit number looks on clients.
function EnemyService.damage(id: number, player: Player, amount: number, pushFrom: Vector3?, crit: boolean?): boolean
	local enemy = enemies[id]
	if not enemy or not enemy.logic.alive then
		return false
	end
	if pushFrom and not enemy.stats.isBoss then
		pushAway(enemy, pushFrom, Balance.hitPush)
	end
	local purified = EnemyLogic.applyHit(enemy.logic, player, amount, os.clock())
	publishHp(enemy)
	fx:FireAllClients("hit", enemy.model, enemy.body.Position, amount, crit == true)
	if purified then
		purify(enemy)
	end
	return true
end

-- Area damage (light wave). Returns the number of enemies hit.
function EnemyService.damageInRadius(center: Vector3, radius: number, player: Player, amount: number, knockback: number): number
	local hits = 0
	for id, enemy in enemies do
		if enemy.logic.alive and flatDistance(enemy.position, center) <= radius + enemy.stats.size * 0.5 then
			hits += 1
			if not enemy.stats.isBoss and knockback > 0 then
				pushAway(enemy, center, knockback)
				enemy.state = "recover"
				enemy.stateUntil = os.clock() + Balance.wave.stagger
			end
			EnemyService.damage(id, player, amount)
		end
	end
	return hits
end

-- A sleeping enemy drops any in-progress attack and its "noticed" flag, so it wakes up calm.
local function settle(enemy: Enemy)
	if enemy.state ~= "idle" then
		enemy.state = "idle"
	end
	if enemy.memory.aggro then
		enemy.memory.aggro = false
		enemy.model:SetAttribute("Aggro", false)
	end
end

local function isAwake(enemy: Enemy): boolean
	local range = enemy.areaRadius + WorldData.wakeMargin
	for _, target in ctx.targets do
		if flatDistance(target.root.Position, enemy.areaCenter) <= range then
			return true
		end
	end
	return false
end

function EnemyService.start()
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace

	for index in WorldData.spawns do
		spawnAt(index)
	end

	Projectiles.setHitHandler(CharacterService.damage)

	Players.PlayerRemoving:Connect(function(player)
		for _, enemy in enemies do
			EnemyLogic.forget(enemy.logic, player)
			enemy.lastContact[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		ctx.targets = Targets.get()
		for _, enemy in enemies do
			-- The boss always updates so its reset timer runs even when nobody is nearby.
			if enemy.stats.isBoss or isAwake(enemy) then
				behaviors[enemy.stats.behavior](enemy, dt, now)
				updateAggro(enemy)
				place(enemy, now)
			else
				settle(enemy)
			end
		end
	end)
end

return EnemyService
