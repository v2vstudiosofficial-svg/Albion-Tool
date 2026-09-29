-- Timed chests. Players pick chests up from spots in the world (WorldData.chests) into their
-- chest slots, unlock one at a time, then open it for coins, maybe a weapon and slot levels.
-- Times are seconds; coins are {min, max}; rarity weights are relative.
return {
	order = { "wood", "silver", "gold", "mystic" },

	-- Chest slot n opens at slotUnlockLevels[n] (1 slot at the start, 5 at most).
	slotUnlockLevels = { 1, 3, 6, 10, 15 },

	chests = {
		wood = {
			nameKey = "chest_wood_name",
			unlockSeconds = 120,
			respawnSeconds = 180,
			coins = { 20, 40 },
			weaponChance = 0.25,
			rarityWeights = { common = 80, rare = 20 },
			slotLevels = 1,
			color = { 180, 130, 80 },
		},
		silver = {
			nameKey = "chest_silver_name",
			unlockSeconds = 300,
			respawnSeconds = 360,
			coins = { 50, 90 },
			weaponChance = 0.45,
			rarityWeights = { common = 50, rare = 40, epic = 10 },
			slotLevels = 2,
			color = { 190, 205, 225 },
		},
		gold = {
			nameKey = "chest_gold_name",
			unlockSeconds = 600,
			respawnSeconds = 720,
			coins = { 120, 200 },
			weaponChance = 0.7,
			rarityWeights = { common = 20, rare = 45, epic = 30, legendary = 5 },
			slotLevels = 3,
			color = { 255, 205, 80 },
		},
		mystic = {
			nameKey = "chest_mystic_name",
			unlockSeconds = 1200,
			respawnSeconds = 1500,
			coins = { 250, 400 },
			weaponChance = 1,
			rarityWeights = { rare = 30, epic = 45, legendary = 25 },
			slotLevels = 5,
			color = { 190, 120, 255 },
		},
	},

	-- A weapon the player already owns turns into coins instead.
	duplicateCoins = { common = 30, rare = 60, epic = 120, legendary = 250 },
}
