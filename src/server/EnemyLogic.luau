-- Pure enemy health/participation state; the Roblox side lives in EnemyService.
export type State = {
	hp: number,
	maxHp: number,
	alive: boolean,
	hitters: { [any]: number },
}

local EnemyLogic = {}

function EnemyLogic.new(maxHp: number): State
	return { hp = maxHp, maxHp = maxHp, alive = true, hitters = {} }
end

-- Returns true only for the single hit that purifies the enemy.
function EnemyLogic.applyHit(state: State, attacker: any, damage: number, now: number): boolean
	if not state.alive or damage <= 0 then
		return false
	end
	state.hitters[attacker] = now
	state.hp = math.max(state.hp - damage, 0)
	if state.hp == 0 then
		state.alive = false
		return true
	end
	return false
end

function EnemyLogic.participants(state: State, now: number, window: number, isPresent: (any) -> boolean): { any }
	local list = {}
	for attacker, lastHit in state.hitters do
		if now - lastHit <= window and isPresent(attacker) then
			table.insert(list, attacker)
		end
	end
	return list
end

function EnemyLogic.forget(state: State, attacker: any)
	state.hitters[attacker] = nil
end

return EnemyLogic
