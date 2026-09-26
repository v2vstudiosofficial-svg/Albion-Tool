-- Enemy registry, AI and server-validated damage. Enemies sleep while no player is near their zone.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
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
	model: Model,
	body: BasePart,
	spawnIndex: number,
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
local purifiedListeners: { (string, any, { Player }) -> () } = {}
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

function ctx.hurt(target: Target, amount: number)
	CharacterService.damage(target.player, target.humanoid, amount)
end

function ctx.contact(enemy: Enemy, now: number, damage: number?)
	local stats = enemy.stats
	for _, target in ctx.targets do
		if (target.root.Position - enemy.position).Magnitude <= stats.contactRange + stats.size * 0.25 then
			local last = enemy.lastContact[target.player]
			if not last or now - last >= stats.contactCooldown then
				enemy.lastContact[target.player] = now
				ctx.hurt(target, damage or stats.contactDamage)
			end
		end
	end
end

function ctx.fx(...)
	fx:FireAllClients(...)
end

function ctx.publishHp(enemy: Enemy)
	publishHp(enemy)
end

function ctx.noticeNear(center: Vector3, radius: number, key: string)
	for _, target in ctx.targets do
		if flatDistance(target.root.Position, center) <= radius then
			notice:FireClient(target.player, key)
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

function behaviors.chaser(enemy: Enemy, dt: number, now: number)
	if staggered(enemy, now) then
		return
	end
	local stats = enemy.stats
	local target = ctx.nearest(enemy, stats.aggroRadius)
	local goal = if target then target.root.Position else enemy.home
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
				ctx.projectiles.fire(
					origin + direction.Unit * stats.size * 0.6,
					direction.Unit * stats.projectileSpeed,
					stats.projectileRadius,
					stats.projectileDamage,
					stats.projectileLifetime,
					"spore"
				)
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
				ctx.hurt(target, stats.dashDamage)
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
		ctx.fx("windup", enemy.model, stats.windup)
	end
	ctx.contact(enemy, now)
end

behaviors.boss = function(enemy: Enemy, dt: number, now: number)
	WardenBehavior.update(enemy, ctx, dt, now)
end

local function place(enemy: Enemy, now: number)
	local behavior = enemy.stats.behavior
	local wave = math.sin(now * 3 + enemy.id)
	local height = if behavior == "shooter"
		then math.abs(math.sin(now * 4.5 + enemy.id)) * 1.1
		elseif behavior == "charger" then wave * 0.2
		elseif enemy.stats.isBoss then wave * 0.7
		else wave * 0.4
	local bob = Vector3.new(0, height, 0)
	if enemy.state == "windup" then
		bob += Vector3.new(math.sin(now * 60) * 0.12, 0, 0)
	end
	local position = enemy.position + bob
	enemy.body.CFrame = CFrame.lookAt(position, position + enemy.facing)
end

local function spawnAt(spawnIndex: number)
	local spawn = WorldData.spawns[spawnIndex]
	local stats = Balance.enemies[spawn.kind]
	local area = WorldData.areas[spawn.area]
	nextId += 1
	local home = WorldData.vector(spawn.position) + Vector3.new(0, stats.hoverHeight, 0)
	local model, body = EnemyModels.build(spawn.kind, stats, CFrame.new(home))
	model:SetAttribute("EnemyId", nextId)
	model:SetAttribute("EnemyType", spawn.kind)
	model:SetAttribute("Boss", stats.isBoss == true)
	model:SetAttribute("Alive", true)

	local enemy: Enemy = {
		id = nextId,
		kind = spawn.kind,
		stats = stats,
		model = model,
		body = body,
		spawnIndex = spawnIndex,
		areaCenter = WorldData.vector(area.center),
		areaRadius = area.radius,
		home = home,
		position = home,
		facing = Vector3.new(0, 0, 1),
		logic = EnemyLogic.new(stats.maxHp),
		lastContact = {},
		state = "idle",
		stateUntil = 0,
		memory = {},
	}
	publishHp(enemy)
	model.Parent = folder
	enemies[nextId] = enemy
end

local function purify(enemy: Enemy)
	enemies[enemy.id] = nil
	local window = enemy.stats.participationWindow or Balance.participationWindow
	local participants = EnemyLogic.participants(enemy.logic, os.clock(), window, function(player)
		return player.Parent == Players
	end)
	enemy.model:SetAttribute("Alive", false)
	fx:FireAllClients("purify", enemy.body.Position, enemy.kind, enemy.facing)
	enemy.model:Destroy()
	task.delay(enemy.stats.respawnDelay, spawnAt, enemy.spawnIndex)
	for _, listener in purifiedListeners do
		task.spawn(listener, enemy.kind, enemy.stats.reward, participants)
	end
end

function EnemyService.get(id: number): Enemy?
	return enemies[id]
end

function EnemyService.getFolder(): Folder
	return folder
end

function EnemyService.connectPurified(listener: (string, any, { Player }) -> ())
	table.insert(purifiedListeners, listener)
end

-- Server-validated damage entry point; returns true when the hit was applied.
function EnemyService.damage(id: number, player: Player, amount: number): boolean
	local enemy = enemies[id]
	if not enemy or not enemy.logic.alive then
		return false
	end
	local purified = EnemyLogic.applyHit(enemy.logic, player, amount, os.clock())
	publishHp(enemy)
	fx:FireAllClients("hit", enemy.model, enemy.body.Position, amount)
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
				local away = flat(enemy.position - center)
				if away.Magnitude > 0.01 then
					enemy.position += away.Unit * knockback
					ctx.clampToLeash(enemy)
				end
				enemy.state = "recover"
				enemy.stateUntil = os.clock() + 0.5
			end
			EnemyService.damage(id, player, amount)
		end
	end
	return hits
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

	Projectiles.setHitHandler(function(player, humanoid, amount)
		CharacterService.damage(player, humanoid, amount)
	end)

	Players.PlayerRemoving:Connect(function(player)
		for _, enemy in enemies do
			EnemyLogic.forget(enemy.logic, player)
			enemy.lastContact[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		ctx.targets = Targets.get(now)
		for _, enemy in enemies do
			if isAwake(enemy) then
				behaviors[enemy.stats.behavior](enemy, dt, now)
				place(enemy, now)
			end
		end
	end)
end

return EnemyService
