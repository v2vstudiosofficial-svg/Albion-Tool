local Progression = if script then require(script.Parent.Progression) else require("./Progression")

-- Main quest chain. Each quest unlocks after the previous one is completed and is started at its
-- `giver` (an NPC in WorldData.npcs; the Elder unless stated).
-- objective.kind: "purify" (enemyType, count) | "collect"/"explore"/"vine" (ids) | "upgrade" (count = staff tier)
--   | "counter" (a profile counter: counted from the day the quest starts, or `absolute` for a record
--     like the best Shadow Tower floor).
local QuestData = {
	order = {
		"first_purify",
		"lantern_flowers",
		"forest_explore",
		"first_upgrade",
		"ruin_vines",
		"warden",
		-- Chapter 2: the Legendary Shadows of the east lands, with Ranger Wren's errands between them.
		"marsh_scouts",
		"rift_watch",
		"bog_mother",
		"elite_hunt",
		"frost_titan",
		"tower_climb",
		"shadow_king",
		-- Epilogue: Kael, the first Light Keeper, is home again.
		"keepers_promise",
		"begin_again",
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
			reward = { xp = 0, levels = 2, coins = 50, charm = "glow" },
		},
		warden = {
			id = "warden",
			titleKey = "quest_warden_title",
			offerKey = "elder_offer_warden",
			objectiveKey = "quest_warden_objective",
			minLevel = 5,
			objective = { kind = "purify", enemyType = "Warden", count = 1, area = "arena" },
			reward = { xp = 0, levels = 2, coins = 120, flag = "festival" },
		},
		marsh_scouts = {
			id = "marsh_scouts",
			giver = "Wren",
			titleKey = "quest_marsh_scouts_title",
			offerKey = "wren_offer_marsh_scouts",
			objectiveKey = "quest_marsh_scouts_objective",
			minLevel = 8,
			objective = { kind = "purify", enemyType = "Mudling", count = 12, area = "marsh" },
			reward = { xp = 0, levels = 2, coins = 100 },
		},
		rift_watch = {
			id = "rift_watch",
			giver = "Wren",
			titleKey = "quest_rift_watch_title",
			offerKey = "wren_offer_rift_watch",
			objectiveKey = "quest_rift_watch_objective",
			minLevel = 12,
			objective = { kind = "counter", counter = "rifts", count = 1, area = "marsh" },
			reward = { xp = 0, levels = 2, coins = 200 },
		},
		bog_mother = {
			id = "bog_mother",
			titleKey = "quest_bog_mother_title",
			offerKey = "elder_offer_bog_mother",
			objectiveKey = "quest_bog_mother_objective",
			minLevel = 22,
			objective = { kind = "purify", enemyType = "BogMother", count = 1, area = "bog" },
			reward = { xp = 0, levels = 3, coins = 500 },
		},
		elite_hunt = {
			id = "elite_hunt",
			giver = "Wren",
			titleKey = "quest_elite_hunt_title",
			offerKey = "wren_offer_elite_hunt",
			objectiveKey = "quest_elite_hunt_objective",
			minLevel = 26,
			objective = { kind = "counter", counter = "elites", count = 3, area = "peaks" },
			reward = { xp = 0, levels = 2, coins = 300 },
		},
		frost_titan = {
			id = "frost_titan",
			titleKey = "quest_frost_titan_title",
			offerKey = "elder_offer_frost_titan",
			objectiveKey = "quest_frost_titan_objective",
			minLevel = 46,
			objective = { kind = "purify", enemyType = "FrostTitan", count = 1, area = "summit" },
			reward = { xp = 0, levels = 3, coins = 2000 },
		},
		tower_climb = {
			id = "tower_climb",
			giver = "Wren",
			titleKey = "quest_tower_climb_title",
			offerKey = "wren_offer_tower_climb",
			objectiveKey = "quest_tower_climb_objective",
			minLevel = 50,
			objective = { kind = "counter", counter = "towerBest", count = 12, absolute = true },
			reward = { xp = 0, levels = 2, coins = 1200 },
		},
		shadow_king = {
			id = "shadow_king",
			titleKey = "quest_shadow_king_title",
			offerKey = "elder_offer_shadow_king",
			objectiveKey = "quest_shadow_king_objective",
			minLevel = 92,
			objective = { kind = "purify", enemyType = "ShadowKing", count = 1, area = "throne" },
			reward = { xp = 0, levels = 3, coins = 8000 },
		},
		keepers_promise = {
			id = "keepers_promise",
			giver = "Kael",
			titleKey = "quest_keepers_promise_title",
			offerKey = "kael_offer_keepers_promise",
			objectiveKey = "quest_keepers_promise_objective",
			minLevel = 92,
			objective = { kind = "counter", counter = "purifies", count = 200 },
			reward = { xp = 0, levels = 1, coins = 3000, flag = "reunion" },
		},
		begin_again = {
			id = "begin_again",
			giver = "Kael",
			titleKey = "quest_begin_again_title",
			offerKey = "kael_offer_begin_again",
			objectiveKey = "quest_begin_again_objective",
			minLevel = 100,
			objective = { kind = "counter", counter = "rebirths", count = 1, absolute = true },
			reward = { xp = 0, coins = 2500 },
		},
	},
}

-- Level-gated quests pay `levels` levels' worth of XP at the level they open, so following the
-- story always moves a player forward by a few levels (`reward.xp` is filled in here).
for _, quest in QuestData.quests do
	local levels = quest.reward.levels
	if levels then
		local first = quest.minLevel or 1
		local last = math.min(Progression.MAX_LEVEL, first + levels)
		quest.reward.xp = Progression.thresholds[last] - Progression.thresholds[first]
	end
end

return QuestData
