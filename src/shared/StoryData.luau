-- The story, told in short scenes. A scene plays when a quest is offered (scene id = quest id),
-- when it is completed (id .. "_end"), and once at the very start ("prologue"). Text lives in
-- Strings (story_<scene>_<line>); only the order, speaker and camera are here.
--   mode  "full": the camera moves to the speaker and controls pause (safe places only).
--         "soft": a caption at the bottom; the game keeps running.
--   focus who the camera looks at at first: an NPC name, "player" or "lantern".
-- Every scene may be skipped with the Skip button; nothing in a scene is needed for progress.
local StoryData = {}

StoryData.speakers = {
	Elder = { nameKey = "npc_elder_name", color = { 150, 175, 255 } },
	Smith = { nameKey = "npc_smith_name", color = { 255, 170, 100 } },
	Wren = { nameKey = "npc_wren_name", color = { 140, 220, 150 } },
	Narrator = { nameKey = nil, color = { 235, 225, 200 } },
	Kael = { nameKey = "npc_kael_name", color = { 255, 215, 120 } },
	Hero = { nameKey = "story_hero_name", color = { 255, 225, 120 } },
}

StoryData.scenes = {
	prologue = {
		mode = "full",
		focus = "lantern",
		lines = {
			{ speaker = "Narrator", key = "story_prologue_1" },
			{ speaker = "Narrator", key = "story_prologue_2" },
			{ speaker = "Elder", key = "story_prologue_3" },
			{ speaker = "Elder", key = "story_prologue_4" },
			{ speaker = "Elder", key = "story_prologue_5" },
		},
	},
	first_purify = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_first_purify_1" },
			{ speaker = "Elder", key = "story_first_purify_2" },
			{ speaker = "Hero", key = "story_first_purify_3" },
		},
	},
	first_purify_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Elder", key = "story_first_purify_end_1" },
		},
	},
	lantern_flowers = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_lantern_flowers_1" },
			{ speaker = "Elder", key = "story_lantern_flowers_2" },
		},
	},
	lantern_flowers_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Elder", key = "story_lantern_flowers_end_1" },
		},
	},
	forest_explore = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_forest_explore_1" },
			{ speaker = "Elder", key = "story_forest_explore_2" },
		},
	},
	forest_explore_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Elder", key = "story_forest_explore_end_1" },
		},
	},
	first_upgrade = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_first_upgrade_1" },
			{ speaker = "Smith", key = "story_first_upgrade_2" },
			{ speaker = "Smith", key = "story_first_upgrade_3" },
		},
	},
	first_upgrade_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Smith", key = "story_first_upgrade_end_1" },
		},
	},
	ruin_vines = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_ruin_vines_1" },
			{ speaker = "Elder", key = "story_ruin_vines_2" },
		},
	},
	ruin_vines_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Elder", key = "story_ruin_vines_end_1" },
		},
	},
	warden = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_warden_1" },
			{ speaker = "Elder", key = "story_warden_2" },
			{ speaker = "Hero", key = "story_warden_3" },
		},
	},
	warden_end = {
		mode = "full",
		focus = "player",
		lines = {
			{ speaker = "Narrator", key = "story_warden_end_1" },
			{ speaker = "Elder", key = "story_warden_end_2" },
			{ speaker = "Elder", key = "story_warden_end_3" },
		},
	},
	marsh_scouts = {
		mode = "full",
		focus = "Wren",
		lines = {
			{ speaker = "Wren", key = "story_marsh_scouts_1" },
			{ speaker = "Wren", key = "story_marsh_scouts_2" },
			{ speaker = "Hero", key = "story_marsh_scouts_3" },
			{ speaker = "Wren", key = "story_marsh_scouts_4" },
		},
	},
	marsh_scouts_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Wren", key = "story_marsh_scouts_end_1" },
		},
	},
	rift_watch = {
		mode = "full",
		focus = "Wren",
		lines = {
			{ speaker = "Wren", key = "story_rift_watch_1" },
			{ speaker = "Wren", key = "story_rift_watch_2" },
		},
	},
	rift_watch_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Wren", key = "story_rift_watch_end_1" },
		},
	},
	bog_mother = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_bog_mother_1" },
			{ speaker = "Elder", key = "story_bog_mother_2" },
		},
	},
	bog_mother_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Narrator", key = "story_bog_mother_end_1" },
		},
	},
	elite_hunt = {
		mode = "full",
		focus = "Wren",
		lines = {
			{ speaker = "Wren", key = "story_elite_hunt_1" },
			{ speaker = "Wren", key = "story_elite_hunt_2" },
		},
	},
	elite_hunt_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Wren", key = "story_elite_hunt_end_1" },
		},
	},
	frost_titan = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_frost_titan_1" },
			{ speaker = "Elder", key = "story_frost_titan_2" },
		},
	},
	frost_titan_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Narrator", key = "story_frost_titan_end_1" },
		},
	},
	tower_climb = {
		mode = "full",
		focus = "Wren",
		lines = {
			{ speaker = "Wren", key = "story_tower_climb_1" },
			{ speaker = "Wren", key = "story_tower_climb_2" },
		},
	},
	tower_climb_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Wren", key = "story_tower_climb_end_1" },
		},
	},
	shadow_king = {
		mode = "full",
		focus = "Elder",
		lines = {
			{ speaker = "Elder", key = "story_shadow_king_1" },
			{ speaker = "Smith", key = "story_shadow_king_2" },
			{ speaker = "Elder", key = "story_shadow_king_3" },
			{ speaker = "Hero", key = "story_shadow_king_4" },
		},
	},
	shadow_king_end = {
		mode = "full",
		focus = "lantern",
		lines = {
			{ speaker = "Narrator", key = "story_shadow_king_end_1" },
			{ speaker = "Narrator", key = "story_shadow_king_end_2" },
			{ speaker = "Elder", key = "story_shadow_king_end_3" },
			{ speaker = "Elder", key = "story_shadow_king_end_4" },
		},
	},
	keepers_promise = {
		mode = "full",
		focus = "Kael",
		lines = {
			{ speaker = "Kael", key = "story_keepers_promise_1" },
			{ speaker = "Kael", key = "story_keepers_promise_2" },
			{ speaker = "Kael", key = "story_keepers_promise_3" },
			{ speaker = "Hero", key = "story_keepers_promise_4" },
		},
	},
	keepers_promise_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Kael", key = "story_keepers_promise_end_1" },
		},
	},
	begin_again = {
		mode = "full",
		focus = "Kael",
		lines = {
			{ speaker = "Kael", key = "story_begin_again_1" },
			{ speaker = "Kael", key = "story_begin_again_2" },
			{ speaker = "Kael", key = "story_begin_again_3" },
		},
	},
	begin_again_end = {
		mode = "soft",
		focus = "player",
		lines = {
			{ speaker = "Kael", key = "story_begin_again_end_1" },
		},
	},
}

return StoryData
