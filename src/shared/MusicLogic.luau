-- Which music plays where (pure; the client's Audio plays it). Boss arenas and the Shadow Tower have
-- their own track; in the east lands the nearest region's plays; in the valley the creature zones
-- south of the village have one, and everywhere else is the village's.
local WorldData = if script then require(script.Parent.WorldData) else require("./WorldData")

local MusicLogic = {}

-- Areas with their own track: inside radius + margin.
local SPECIAL = { arena = "boss", bog = "boss", summit = "boss", throne = "boss", tower = "tower" }
local EAST = { marsh = "marsh", peaks = "peaks", citadel = "citadel", keep = "citadel" }
MusicLogic.margin = 10
-- South of this line (z) the valley's creature zones begin (the glade's edge is at z = -86).
MusicLogic.wildsZ = -75

local function distance(area, x: number, z: number): number
	local dx, dz = x - area.center[1], z - area.center[3]
	return math.sqrt(dx * dx + dz * dz)
end

function MusicLogic.theme(x: number, z: number): string
	for areaId, theme in SPECIAL do
		local area = WorldData.areas[areaId]
		if distance(area, x, z) <= area.radius + MusicLogic.margin then
			return theme
		end
	end
	if x > WorldData.ridge.x then
		local best, bestDistance = "marsh", math.huge
		for areaId, theme in EAST do
			local d = distance(WorldData.areas[areaId], x, z)
			if d < bestDistance then
				best, bestDistance = theme, d
			end
		end
		return best
	end
	return if z < MusicLogic.wildsZ then "wilds" else "village"
end

return MusicLogic
