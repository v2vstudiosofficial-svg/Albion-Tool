-- Gölge Bekçisi boss: two readable, telegraphed attacks that alternate with vulnerable rests.
--  * Slam: warning circles appear under players, then burst after a delay (step out to dodge).
--  * Orb ring: a wind-up glow, then a ring of slow orbs with a visible gap to walk through.
-- Phase 2 (below phase2At health) shortens warnings/rests and adds circles and a second ring.
-- HP scales with the number of players in the arena when the fight starts; it resets if everyone leaves.
local WardenBehavior = {}

local PHASE2_COLOR = Color3.fromRGB(95, 45, 130)
local GAP_SIZE = 2

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function arenaTargets(enemy, ctx)
	local list = {}
	for _, target in ctx.targets do
		if flat(target.root.Position - enemy.areaCenter).Magnitude <= enemy.stats.leashRadius then
			table.insert(list, target)
		end
	end
	return list
end

local function nearestOf(enemy, list)
	local best, bestDistance = nil, math.huge
	for _, target in list do
		local distance = flat(target.root.Position - enemy.position).Magnitude
		if distance < bestDistance then
			best, bestDistance = target, distance
		end
	end
	return best, bestDistance
end

local function groundPoint(enemy, position: Vector3): Vector3
	local groundY = enemy.home.Y - enemy.stats.hoverHeight
	return Vector3.new(position.X, groundY, position.Z)
end

local function reset(enemy, ctx)
	local stats = enemy.stats
	enemy.logic.maxHp = stats.maxHp
	enemy.logic.hp = stats.maxHp
	table.clear(enemy.logic.hitters)
	table.clear(enemy.memory)
	enemy.state = "idle"
	enemy.body.Color = Color3.fromRGB(stats.color[1], stats.color[2], stats.color[3])
	enemy.model:SetAttribute("Engaged", false)
	ctx.publishHp(enemy)
	ctx.noticeNear(enemy.areaCenter, stats.leashRadius + 40, "notice_boss_reset")
end

local function engage(enemy, ctx, playerCount: number, now: number)
	local stats = enemy.stats
	local scale = 1 + stats.extraHpPerPlayer * math.max(playerCount - 1, 0)
	local ratio = enemy.logic.hp / enemy.logic.maxHp
	enemy.logic.maxHp = math.floor(stats.maxHp * scale)
	enemy.logic.hp = math.max(1, math.ceil(enemy.logic.maxHp * ratio))
	enemy.memory.engaged = true
	enemy.memory.phase = 1
	enemy.memory.nextAttack = "slam"
	enemy.state = "rest"
	enemy.stateUntil = now + 1.2
	enemy.model:SetAttribute("Engaged", true)
	ctx.publishHp(enemy)
end

local function startSlam(enemy, ctx, list, now: number)
	local stats = enemy.stats
	local phase2 = enemy.memory.phase == 2
	local count = if phase2 then stats.slamCountPhase2 else stats.slamCount
	local warn = if phase2 then stats.slamWarnPhase2 else stats.slamWarn
	local points = {}
	for index, target in list do
		if index > count then
			break
		end
		local jitter = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
		table.insert(points, groundPoint(enemy, target.root.Position + jitter))
	end
	while #points < count do
		local angle = math.random() * math.pi * 2
		local distance = 6 + math.random() * 12
		table.insert(points, groundPoint(enemy, enemy.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance))
	end
	for _, point in points do
		ctx.fx("telegraph", point, stats.slamRadius, warn)
	end
	enemy.memory.slamPoints = points
	enemy.state = "slamWarn"
	enemy.stateUntil = now + warn
end

local function resolveSlam(enemy, ctx)
	local stats = enemy.stats
	for _, point in enemy.memory.slamPoints do
		ctx.fx("slam", point, stats.slamRadius)
		for _, target in ctx.targets do
			if flat(target.root.Position - point).Magnitude <= stats.slamRadius then
				ctx.hurt(target, stats.slamDamage)
			end
		end
	end
	enemy.memory.slamPoints = nil
end

local function fireRing(enemy, ctx, offset: number)
	local stats = enemy.stats
	local origin = groundPoint(enemy, enemy.position) + Vector3.new(0, 3, 0)
	local gapStart = math.random(0, stats.orbCount - 1)
	for index = 0, stats.orbCount - 1 do
		local inGap = (index - gapStart) % stats.orbCount < GAP_SIZE
		if not inGap then
			local angle = offset + index * (math.pi * 2 / stats.orbCount)
			local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
			ctx.projectiles.fire(
				origin + direction * stats.size * 0.5,
				direction * stats.orbSpeed,
				stats.orbRadius,
				stats.orbDamage,
				stats.orbLifetime,
				"shadow"
			)
		end
	end
end

local function keepDistance(enemy, ctx, target, distance: number, dt: number)
	local stats = enemy.stats
	local targetPosition = target.root.Position
	if distance > stats.keepDistance + 2 then
		ctx.moveToward(enemy, targetPosition, stats.speed, dt, stats.keepDistance)
	elseif distance < stats.keepDistance - 2 then
		local away = enemy.position + flat(enemy.position - targetPosition).Unit * 4
		ctx.moveToward(enemy, away, stats.speed, dt, 0)
	end
	ctx.clampToLeash(enemy)
end

function WardenBehavior.update(enemy, ctx, dt: number, now: number)
	local stats = enemy.stats
	local memory = enemy.memory
	local list = arenaTargets(enemy, ctx)

	if #list == 0 then
		if memory.engaged then
			memory.lostAt = memory.lostAt or now
			if now - memory.lostAt >= stats.resetAfter then
				reset(enemy, ctx)
			end
		end
		ctx.moveToward(enemy, enemy.home, stats.speed, dt, 0.2)
		return
	end
	memory.lostAt = nil

	local target, distance = nearestOf(enemy, list)
	ctx.face(enemy, target.root.Position)

	if not memory.engaged then
		if distance <= stats.aggroRadius then
			engage(enemy, ctx, #list, now)
		end
		return
	end

	if memory.phase == 1 and enemy.logic.hp <= enemy.logic.maxHp * stats.phase2At then
		memory.phase = 2
		enemy.body.Color = PHASE2_COLOR
		ctx.fx("bossPhase", enemy.model)
	end
	local phase2 = memory.phase == 2
	local rest = if phase2 then stats.restTimePhase2 else stats.restTime

	if enemy.state == "rest" then
		keepDistance(enemy, ctx, target, distance, dt)
		if now >= enemy.stateUntil then
			if memory.nextAttack == "slam" then
				startSlam(enemy, ctx, list, now)
			else
				enemy.state = "orbWindup"
				enemy.stateUntil = now + stats.orbWindup
				ctx.fx("windup", enemy.model, stats.orbWindup)
			end
		end
	elseif enemy.state == "slamWarn" then
		if now >= enemy.stateUntil then
			resolveSlam(enemy, ctx)
			memory.nextAttack = "orbs"
			enemy.state = "rest"
			enemy.stateUntil = now + rest
		end
	elseif enemy.state == "orbWindup" then
		if now >= enemy.stateUntil then
			local offset = math.random() * math.pi * 2
			fireRing(enemy, ctx, offset)
			memory.secondRing = if phase2 then { at = now + 0.6, offset = offset + math.pi / stats.orbCount } else nil
			enemy.state = "orbs"
			enemy.stateUntil = now + (if phase2 then 0.8 else 0.2)
		end
	elseif enemy.state == "orbs" then
		local second = memory.secondRing
		if second and now >= second.at then
			fireRing(enemy, ctx, second.offset)
			memory.secondRing = nil
		end
		if now >= enemy.stateUntil and memory.secondRing == nil then
			memory.nextAttack = "slam"
			enemy.state = "rest"
			enemy.stateUntil = now + rest
		end
	else
		enemy.state = "rest"
		enemy.stateUntil = now + rest
	end

	ctx.contact(enemy, now)
end

return WardenBehavior
