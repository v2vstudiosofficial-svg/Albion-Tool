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
	Smith = { nameKey = "npc_smith_name", position = { -22, 1.6, -36 }, lookAt = { 0, 1.6, -28 } },
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

-- Enemy packs. `level` scales health, damage and rewards (Progression.enemyStats).
WorldData.spawns = {
	{ kind = "Gloomling", area = "glade", level = 1, position = { -10, 0, -104 } },
	{ kind = "Gloomling", area = "glade", level = 1, position = { 11, 0, -112 } },
	{ kind = "Gloomling", area = "glade", level = 1, position = { 0, 0, -124 } },
	{ kind = "Gloomling", area = "glade", level = 2, position = { -6, 0, -116 } },
	{ kind = "Gloomling", area = "glade", level = 2, position = { 6, 0, -100 } },
	{ kind = "Gloomling", area = "glade", level = 2, position = { 14, 0, -124 } },
	{ kind = "Sporeling", area = "grove", level = 3, position = { -52, 0, -152 } },
	{ kind = "Sporeling", area = "grove", level = 3, position = { -38, 0, -166 } },
	{ kind = "Sporeling", area = "grove", level = 4, position = { -54, 0, -176 } },
	{ kind = "Gloomling", area = "grove", level = 3, position = { -44, 0, -158 } },
	{ kind = "Gloomling", area = "grove", level = 3, position = { -36, 0, -154 } },
	{ kind = "Gloomling", area = "grove", level = 4, position = { -48, 0, -170 } },
	{ kind = "Rockling", area = "hollow", level = 5, position = { 38, 0, -176 } },
	{ kind = "Rockling", area = "hollow", level = 6, position = { 54, 0, -194 } },
	{ kind = "Gloomling", area = "hollow", level = 5, position = { 30, 0, -200 } },
	{ kind = "Gloomling", area = "hollow", level = 5, position = { 46, 0, -182 } },
	{ kind = "Gloomling", area = "hollow", level = 6, position = { 40, 0, -196 } },
	{ kind = "Sporeling", area = "hollow", level = 6, position = { 56, 0, -178 } },
	{ kind = "Warden", area = "arena", level = 8, position = { 0, 0, -290 } },
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
