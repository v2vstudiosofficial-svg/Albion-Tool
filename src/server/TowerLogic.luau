-- Pure Shadow Tower rules: floor levels and scaling, how many and which creatures, rewards.
-- TowerService runs the arena. See Balance.tower.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local WorldData = if Shared then require(Shared.WorldData) else require("../shared/WorldData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local RiftLogic = if script then require(script.Parent.RiftLogic) else require("./RiftLogic")

local TowerLogic = {}

-- Creature level on this floor, and how many levels past the cap it would be (`extra`).
function TowerLogic.floorLevel(anchor: number, floor: number): (number, number)
	local raw = anchor + Balance.tower.levelOffset + floor
	local level = math.clamp(raw, 1, Progression.MAX_LEVEL)
	return level, math.max(0, raw - Progression.MAX_LEVEL)
end

-- Health and damage multipliers for creatures beyond the level cap.
function TowerLogic.scale(extra: number): (number, number)
	return Balance.tower.hpGrowth ^ extra, Balance.tower.damageGrowth ^ extra
end

-- Creatures on a floor for this many players inside (elites are part of the count).
function TowerLogic.count(floor: number, players: number): number
	local tower = Balance.tower
	return math.min(tower.maxCount, tower.baseCount + floor // tower.countEvery) + tower.extraPerPlayer * math.max(0, players - 1)
end

function TowerLogic.eliteCount(floor: number): number
	local tower = Balance.tower
	return if floor % tower.eliteEvery == 0 then math.min(3, 1 + floor // 25) else 0
end

-- Creature kinds for a level: those of the zone whose level range holds it (the closest range
-- when none does).
function TowerLogic.kindsFor(level: number): { string }
	local bestArea, bestGap = nil, math.huge
	for _, areaId in RiftLogic.zones() do
		local range = WorldData.areas[areaId].levels
		local gap = if level < range[1] then range[1] - level elseif level > range[2] then level - range[2] else 0
		if gap < bestGap then
			bestArea, bestGap = areaId, gap
		end
	end
	return RiftLogic.kindsFor(bestArea :: string)
end

-- Chest for clearing this floor (nil on most floors).
function TowerLogic.chestFor(floor: number): string?
	if floor % Balance.tower.chestEvery ~= 0 then
		return nil
	elseif floor >= 30 and floor % 10 == 0 then
		return "mystic"
	elseif floor >= 10 then
		return "gold"
	end
	return "silver"
end

function TowerLogic.floorCoins(level: number, floor: number): number
	local minutes = Balance.tower.floorMinutes
	return Progression.incomeCoins(level, math.min(minutes.max, minutes.base + minutes.perFloor * floor))
end

function TowerLogic.recordCoins(level: number): number
	return Progression.incomeCoins(level, Balance.tower.recordMinutes)
end

-- May this player join a run with this anchor level?
function TowerLogic.canEnter(level: number, anchor: number?): (boolean, string?)
	if level < Balance.tower.minLevel then
		return false, "level"
	end
	if anchor and level < anchor - Balance.tower.joinRange then
		return false, "low"
	end
	return true
end

-- Records a cleared floor; true when it is a new best.
function TowerLogic.record(profile: any, floor: number): boolean
	if floor > profile.towerBest then
		profile.towerBest = floor
		return true
	end
	return false
end

return TowerLogic
