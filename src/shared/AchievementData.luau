-- Adventure Log: tiered goals with a reward for every tier (claimed by the player). `counter`
-- names what is measured (see server/AchievementLogic). Chest rewards go into a free chest slot,
-- or turn into `chestCoins` coins when the slots are full.
return {
	order = { "friends", "elites", "rifts", "treasure", "crystals", "legends", "arsenal", "rising", "forge" },
	chestCoins = { wood = 60, silver = 150, gold = 400, mystic = 1000 },

	achievements = {
		friends = {
			nameKey = "ach_friends_name",
			descKey = "ach_friends_desc",
			counter = "purifies",
			tiers = {
				{ goal = 50, coins = 100 },
				{ goal = 250, coins = 300, chest = "wood" },
				{ goal = 1000, coins = 1000, chest = "silver" },
				{ goal = 5000, coins = 5000, chest = "gold" },
				{ goal = 20000, coins = 20000, chest = "mystic" },
			},
		},
		elites = {
			nameKey = "ach_elites_name",
			descKey = "ach_elites_desc",
			counter = "elites",
			tiers = {
				{ goal = 1, coins = 100 },
				{ goal = 10, coins = 500, chest = "silver" },
				{ goal = 50, coins = 3000, chest = "gold" },
				{ goal = 200, coins = 15000, chest = "mystic" },
			},
		},
		rifts = {
			nameKey = "ach_rifts_name",
			descKey = "ach_rifts_desc",
			counter = "rifts",
			tiers = {
				{ goal = 1, coins = 150 },
				{ goal = 5, coins = 600, chest = "silver" },
				{ goal = 25, coins = 4000, chest = "gold" },
				{ goal = 100, coins = 20000, chest = "mystic" },
			},
		},
		treasure = {
			nameKey = "ach_treasure_name",
			descKey = "ach_treasure_desc",
			counter = "chests",
			tiers = {
				{ goal = 1, coins = 50 },
				{ goal = 10, coins = 400 },
				{ goal = 50, coins = 3000, chest = "gold" },
				{ goal = 150, coins = 12000, chest = "mystic" },
			},
		},
		crystals = {
			nameKey = "ach_crystals_name",
			descKey = "ach_crystals_desc",
			counter = "crystals",
			tiers = {
				{ goal = 500, coins = 100 },
				{ goal = 5000, coins = 800, chest = "silver" },
				{ goal = 50000, coins = 6000, chest = "gold" },
				{ goal = 500000, coins = 40000, chest = "mystic" },
			},
		},
		legends = {
			nameKey = "ach_legends_name",
			descKey = "ach_legends_desc",
			counter = "legends",
			tiers = {
				{ goal = 1, coins = 200 },
				{ goal = 2, coins = 2000, chest = "gold" },
				{ goal = 3, coins = 10000, chest = "mystic" },
				{ goal = 4, coins = 50000, chest = "mystic" },
			},
		},
		arsenal = {
			nameKey = "ach_arsenal_name",
			descKey = "ach_arsenal_desc",
			counter = "weapons",
			tiers = {
				{ goal = 2, coins = 150 },
				{ goal = 4, coins = 800, chest = "silver" },
				{ goal = 6, coins = 4000, chest = "gold" },
				{ goal = 8, coins = 20000, chest = "mystic" },
			},
		},
		rising = {
			nameKey = "ach_rising_name",
			descKey = "ach_rising_desc",
			counter = "level",
			tiers = {
				{ goal = 10, coins = 300 },
				{ goal = 25, coins = 1500, chest = "silver" },
				{ goal = 50, coins = 8000, chest = "gold" },
				{ goal = 75, coins = 30000, chest = "mystic" },
				{ goal = 100, coins = 100000, chest = "mystic" },
			},
		},
		forge = {
			nameKey = "ach_forge_name",
			descKey = "ach_forge_desc",
			counter = "power",
			tiers = {
				{ goal = 5, coins = 200 },
				{ goal = 15, coins = 2000, chest = "silver" },
				{ goal = 30, coins = 15000, chest = "gold" },
				{ goal = 50, coins = 100000, chest = "mystic" },
			},
		},
	},
}
