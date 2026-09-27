-- Gameplay-relevant world points shared by server validation and client visuals.
-- Positions are {x, y, z}; convert with WorldData.vector(p) on the Roblox side.
local WorldData = {}

WorldData.spawn = { 0, 0.5, 40 }
-- Village plaza center: lantern, decorations and the safe healing area are placed around it.
WorldData.plaza = { 0, 0, 12 }
-- House bases (doors face the village's middle line). Restoration decor hangs off these.
WorldData.houses = { { -35, 0, 0 }, { 35, 0, 0 }, { -35, 0, 32 }, { 35, 0, 32 } }

WorldData.npcs = {
	Elder = { nameKey = "npc_elder_name", position = { 8, 1.6, 28 }, lookAt = { 0, 1.6, 40 } },
	Demir = { nameKey = "npc_demir_name", position = { -22, 1.6, -36 }, lookAt = { 0, 1.6, -28 } },
}

-- Enemy zones; enemies in a zone sleep while no player is within radius + WorldData.wakeMargin.
WorldData.wakeMargin = 70
WorldData.areas = {
	glade = { center = { 0, 0, -112 }, radius = 26 },
	grove = { center = { -46, 0, -162 }, radius = 24 },
	hollow = { center = { 44, 0, -186 }, radius = 24 },
	gate = { center = { 0, 0, -224 }, radius = 12 },
	arena = { center = { 0, 0, -285 }, radius = 34 },
}

WorldData.spawns = {
	{ kind = "Gloomling", area = "glade", position = { -10, 0, -104 } },
	{ kind = "Gloomling", area = "glade", position = { 11, 0, -112 } },
	{ kind = "Gloomling", area = "glade", position = { 0, 0, -124 } },
	{ kind = "Sporeling", area = "grove", position = { -52, 0, -152 } },
	{ kind = "Sporeling", area = "grove", position = { -38, 0, -166 } },
	{ kind = "Sporeling", area = "grove", position = { -54, 0, -176 } },
	{ kind = "Rockling", area = "hollow", position = { 38, 0, -176 } },
	{ kind = "Rockling", area = "hollow", position = { 54, 0, -194 } },
	{ kind = "Gloomling", area = "hollow", position = { 30, 0, -200 } },
	{ kind = "Warden", area = "arena", position = { 0, 0, -290 } },
}

WorldData.flowers = {
	flower_1 = { -18, 0, -84 },
	flower_2 = { 24, 0, -92 },
	flower_3 = { -30, 0, -132 },
	flower_4 = { 32, 0, -138 },
	flower_5 = { -9, 0, -152 },
}

WorldData.landmarks = {
	old_oak = { nameKey = "landmark_old_oak", position = { -56, 0, -108 } },
	glow_pond = { nameKey = "landmark_glow_pond", position = { 52, 0, -122 } },
	star_rock = { nameKey = "landmark_star_rock", position = { -24, 0, -204 } },
}

-- Ruins wall runs along z = gate.z with a single opening of width 2 * halfWidth.
WorldData.gate = { z = -229, halfWidth = 8 }
WorldData.vines = {
	vine_1 = { -5, 0, -229 },
	vine_2 = { 0, 0, -229 },
	vine_3 = { 5, 0, -229 },
}

-- Playable bounds (x, z) used for invisible walls.
WorldData.bounds = { minX = -80, maxX = 80, minZ = -330, maxZ = 70 }

function WorldData.vector(p: { number }): Vector3
	return Vector3.new(p[1], p[2], p[3])
end

function WorldData.flatDistance(a: { number }, b: { number }): number
	local dx, dz = a[1] - b[1], a[3] - b[3]
	return math.sqrt(dx * dx + dz * dz)
end

return WorldData
