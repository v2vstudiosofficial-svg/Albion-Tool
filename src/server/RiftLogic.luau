-- Pure Shadow Rift rules (wave sizes, which creatures, rewards). RiftService runs the events.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local WorldData = if Shared then require(Shared.WorldData) else require("../shared/WorldData")

local RiftLogic = {}

-- Zones where rifts can open: creature zones with a level range.
function RiftLogic.zones(): { string }
	local list = {}
	for areaId, area in WorldData.areas do
		if area.levels then
			table.insert(list, areaId)
		end
	end
	table.sort(list)
	return list
end

-- The regular creature kinds living in a zone (rifts send the same kinds).
function RiftLogic.kindsFor(areaId: string): { string }
	local seen, list = {}, {}
	for _, spawn in WorldData.spawns do
		if spawn.area == areaId and not Balance.enemies[spawn.kind].isBoss and not seen[spawn.kind] then
			seen[spawn.kind] = true
			table.insert(list, spawn.kind)
		end
	end
	table.sort(list)
	return list
end

-- Creatures in wave `wave` (1-based) for this many players nearby.
function RiftLogic.waveSize(wave: number, players: number): number
	return Balance.rifts.baseCount + wave + math.max(0, players - 1)
end

-- Coins given instead of the chest when the chest slots are full.
function RiftLogic.fallbackCoins(areaId: string): number
	return Balance.rifts.coinsPerLevel * WorldData.areas[areaId].levels[2]
end

return RiftLogic
