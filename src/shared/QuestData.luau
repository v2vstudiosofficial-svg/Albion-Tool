-- Main quest chain. Each quest unlocks after the previous one is completed and is started at the Elder.
-- objective.kind: "purify" (enemyType, count) | "collect"/"explore"/"vine" (ids) | "upgrade" (count = staff tier)
return {
	order = {
		"first_purify",
		"lantern_flowers",
		"forest_explore",
		"first_upgrade",
		"ruin_vines",
		"warden",
	},
	quests = {
		first_purify = {
			id = "first_purify",
			titleKey = "quest_first_purify_title",
			offerKey = "elder_offer_first_purify",
			objectiveKey = "quest_first_purify_objective",
			objective = { kind = "purify", enemyType = "Gloomling", count = 3, area = "glade" },
			reward = { xp = 50, coins = 20 },
		},
		lantern_flowers = {
			id = "lantern_flowers",
			titleKey = "quest_lantern_flowers_title",
			offerKey = "elder_offer_lantern_flowers",
			objectiveKey = "quest_lantern_flowers_objective",
			objective = { kind = "collect", ids = { "flower_1", "flower_2", "flower_3", "flower_4", "flower_5" } },
			reward = { xp = 80, coins = 30, charm = "swift", flag = "gardens" },
		},
		forest_explore = {
			id = "forest_explore",
			titleKey = "quest_forest_explore_title",
			offerKey = "elder_offer_forest_explore",
			objectiveKey = "quest_forest_explore_objective",
			objective = { kind = "explore", ids = { "old_oak", "glow_pond", "star_rock" } },
			reward = { xp = 90, coins = 30 },
		},
		first_upgrade = {
			id = "first_upgrade",
			titleKey = "quest_first_upgrade_title",
			offerKey = "elder_offer_first_upgrade",
			objectiveKey = "quest_first_upgrade_objective",
			objective = { kind = "upgrade", count = 1, npc = "Smith" },
			reward = { xp = 100, coins = 0, charm = "guard", flag = "lanterns" },
		},
		ruin_vines = {
			id = "ruin_vines",
			titleKey = "quest_ruin_vines_title",
			offerKey = "elder_offer_ruin_vines",
			objectiveKey = "quest_ruin_vines_objective",
			minLevel = 3,
			objective = { kind = "vine", ids = { "vine_1", "vine_2", "vine_3" } },
			reward = { xp = 150, coins = 50, charm = "glow" },
		},
		warden = {
			id = "warden",
			titleKey = "quest_warden_title",
			offerKey = "elder_offer_warden",
			objectiveKey = "quest_warden_objective",
			minLevel = 5,
			objective = { kind = "purify", enemyType = "Warden", count = 1, area = "arena" },
			reward = { xp = 300, coins = 120, flag = "festival" },
		},
	},
}
