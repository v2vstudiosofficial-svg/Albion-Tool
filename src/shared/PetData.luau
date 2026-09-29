-- Friends that follow a player. Cosmetic only (no power); every pet is earned by playing and
-- stays unlocked for good. `unlock.kind` says what is measured (see server/PetLogic):
-- level, purifies, elites, rifts, chests, legend (a Legendary Shadow kind in `id`) or tower.
-- Colors are {r, g, b}; `look` picks the shape in PetModels; `fly` pets hover higher.
return {
	order = { "glowmoth", "sproutling", "pebble", "ember_fox", "frost_pup", "shade_cat" },
	pets = {
		glowmoth = { nameKey = "pet_glowmoth", look = "moth", fly = true, color = { 255, 236, 140 }, unlock = { kind = "level", goal = 10 } },
		sproutling = { nameKey = "pet_sproutling", look = "sprout", color = { 130, 205, 110 }, unlock = { kind = "purifies", goal = 500 } },
		pebble = { nameKey = "pet_pebble", look = "pebble", color = { 170, 165, 180 }, unlock = { kind = "chests", goal = 25 } },
		ember_fox = { nameKey = "pet_ember_fox", look = "fox", color = { 255, 150, 80 }, unlock = { kind = "rifts", goal = 10 } },
		frost_pup = { nameKey = "pet_frost_pup", look = "pup", color = { 170, 220, 255 }, unlock = { kind = "legend", id = "FrostTitan", goal = 1 } },
		shade_cat = { nameKey = "pet_shade_cat", look = "cat", color = { 150, 110, 200 }, unlock = { kind = "tower", goal = 15 } },
	},
	-- Follow spot behind the owner's root part, and how quickly the pet catches up (per second).
	follow = { offset = { -3, -1.4, 3.2 }, flyLift = 2.4, catchUp = 6, snapDistance = 40 },
}
