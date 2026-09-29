-- Creature Codex: how many of each creature kind a player has purified, with a small coin reward
-- at each milestone (paid automatically, once, when the count reaches it). `minutes` is minutes of
-- the player's current income (Progression.incomeCoins). Every kind in Balance.enemies is listed.
return {
	order = {
		"Gloomling", "Sporeling", "Rockling", "Mudling", "Bubbler", "Snowpuff", "Frostling",
		"Shade", "Hexcap", "Obsidian", "Warden", "BogMother", "FrostTitan", "ShadowKing",
	},
	tiers = {
		regular = {
			{ goal = 10, minutes = 1 },
			{ goal = 50, minutes = 3 },
			{ goal = 250, minutes = 8 },
			{ goal = 1000, minutes = 20 },
		},
		-- Bosses and Legendary Shadows.
		boss = {
			{ goal = 1, minutes = 2 },
			{ goal = 5, minutes = 5 },
			{ goal = 25, minutes = 12 },
		},
	},
	-- Counts stop here (a save can never grow without bound).
	maxCount = 10000000,
}
