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
	-- The first Light Keeper, back by the Great Lantern once the Shadow King is purified (only shown
	-- to players who have finished that quest).
	Kael = { nameKey = "npc_kael_name", position = { -7, 1.6, 6 }, lookAt = { 0, 1.6, 12 } },
	-- Just inside the east lands, beside the first opening in the rock ridge.
	Wren = { nameKey = "npc_wren_name", position = { 100, 1.6, 30 }, lookAt = { 90, 1.6, 14 } },
}

-- The Bounty Board in the village (BountyData); read it with the prompt.
WorldData.board = { nameKey = "board_name", position = { -12, 2.4, 30 }, lookAt = { 0, 2.4, 40 } }

-- Enemy zones; enemies in a zone sleep while no player is within radius + WorldData.wakeMargin.
-- `levels` = creature levels there (the waypoint picks a zone that fits the player's level).
-- The east lands (x > 82) are reached through openings in the rock ridge.
WorldData.wakeMargin = 70
WorldData.areas = {
	glade = { center = { 0, 0, -112 }, radius = 26, levels = { 1, 2 } },
	grove = { center = { -46, 0, -162 }, radius = 24, levels = { 3, 4 } },
	hollow = { center = { 44, 0, -186 }, radius = 24, levels = { 5, 6 } },
	gate = { center = { 0, 0, -224 }, radius = 12 },
	arena = { center = { 0, 0, -285 }, radius = 34 },
	marsh = { center = { 165, 0, 10 }, radius = 48, levels = { 8, 25 } },
	bog = { center = { 222, 0, 48 }, radius = 20 },
	peaks = { center = { 160, 0, -130 }, radius = 48, levels = { 26, 50 } },
	summit = { center = { 225, 0, -172 }, radius = 20 },
	citadel = { center = { 150, 0, -245 }, radius = 40, levels = { 51, 75 } },
	keep = { center = { 210, 0, -292 }, radius = 30, levels = { 76, 100 } },
	throne = { center = { 118, 0, -305 }, radius = 20 },
	-- The Shadow Tower's arena, far outside the playable valley (players are teleported in).
	tower = { center = { -320, 0, 0 }, radius = 36 },
}

-- The village gate to the Shadow Tower and the pad inside the arena that leads back.
WorldData.towerGate = { nameKey = "tower_gate_name", position = { 24, 0, -34 }, lookAt = { 0, 0, 12 } }
WorldData.towerExit = { offset = { 0, 0, -28 } }

-- Rock ridge between the valley and the east lands; players pass through these openings (z ranges).
WorldData.ridge = { x = 83, openings = { { 2, 26 }, { -132, -106 }, { -304, -280 } } }

-- Enemy packs. `level` scales health, damage and rewards (Progression.enemyStats); `levels`
-- ({min, max}) rolls a new level on every respawn.
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

-- East-land packs: `count` creatures in a small circle around `at`.
local function pack(kind: string, area: string, levels: { number }, at: { number }, count: number)
	for index = 1, count do
		local angle = index / count * math.pi * 2
		table.insert(WorldData.spawns, {
			kind = kind,
			area = area,
			levels = levels,
			position = { at[1] + math.cos(angle) * 7, 0, at[3] + math.sin(angle) * 7 },
		})
	end
end
pack("Mudling", "marsh", { 8, 12 }, { 128, 0, 40 }, 4)
pack("Bubbler", "marsh", { 12, 18 }, { 172, 0, 2 }, 3)
pack("Mudling", "marsh", { 18, 25 }, { 196, 0, -28 }, 4)
pack("Snowpuff", "peaks", { 26, 33 }, { 128, 0, -100 }, 4)
pack("Frostling", "peaks", { 33, 42 }, { 180, 0, -118 }, 3)
pack("Snowpuff", "peaks", { 42, 50 }, { 156, 0, -162 }, 4)
pack("Shade", "citadel", { 51, 62 }, { 136, 0, -228 }, 4)
pack("Hexcap", "citadel", { 62, 75 }, { 178, 0, -250 }, 3)
pack("Obsidian", "keep", { 76, 88 }, { 200, 0, -282 }, 4)
pack("Shade", "keep", { 88, 100 }, { 222, 0, -308 }, 4)
table.insert(WorldData.spawns, { kind = "BogMother", area = "bog", level = 25, position = { 222, 0, 50 } })
table.insert(WorldData.spawns, { kind = "FrostTitan", area = "summit", level = 50, position = { 225, 0, -175 } })
table.insert(WorldData.spawns, { kind = "ShadowKing", area = "throne", level = 100, position = { 118, 0, -308 } })

-- Chest spots (see ChestData). Each player sees and takes their own chest; it comes back after
-- the chest type's respawn time. Rarer chests sit deeper in the valley.
WorldData.chests = {
	chest_glade_1 = { type = "wood", position = { -22, 0, -120 } },
	chest_glade_2 = { type = "wood", position = { 20, 0, -96 } },
	chest_grove_1 = { type = "silver", position = { -62, 0, -166 } },
	chest_grove_2 = { type = "wood", position = { -30, 0, -180 } },
	chest_hollow_1 = { type = "gold", position = { 62, 0, -190 } },
	chest_hollow_2 = { type = "silver", position = { 34, 0, -208 } },
	chest_ruins = { type = "mystic", position = { 24, 0, -302 } },
	chest_marsh = { type = "gold", position = { 150, 0, 52 } },
	chest_peaks = { type = "gold", position = { 128, 0, -150 } },
	chest_citadel = { type = "mystic", position = { 178, 0, -222 } },
	chest_keep = { type = "mystic", position = { 238, 0, -270 } },
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
WorldData.bounds = { minX = -80, maxX = 250, minZ = -330, maxZ = 70 }

function WorldData.vector(p: { number }): Vector3
	return Vector3.new(p[1], p[2], p[3])
end

function WorldData.flatDistance(a: { number }, b: { number }): number
	local dx, dz = a[1] - b[1], a[3] - b[3]
	return math.sqrt(dx * dx + dz * dz)
end

return WorldData
