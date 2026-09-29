-- Titles shown next to a player's name in the Players panel. Cosmetic only (no power); every title
-- is earned by playing and stays earned for good. `unlock.kind` says what is measured (see
-- server/TitleLogic): level, purifies, elites, rifts, chests, tower, rebirths or quest (a finished
-- story quest in `id`).
return {
	order = {
		"keeper",
		"glow_walker",
		"shadow_friend",
		"elite_hunter",
		"rift_closer",
		"treasure_seeker",
		"tower_climber",
		"kings_bane",
		"promise_keeper",
		"reborn",
		"lantern_master",
	},
	titles = {
		keeper = { nameKey = "title_keeper", unlock = { kind = "level", goal = 1 } },
		glow_walker = { nameKey = "title_glow_walker", unlock = { kind = "level", goal = 25 } },
		shadow_friend = { nameKey = "title_shadow_friend", unlock = { kind = "purifies", goal = 1000 } },
		elite_hunter = { nameKey = "title_elite_hunter", unlock = { kind = "elites", goal = 50 } },
		rift_closer = { nameKey = "title_rift_closer", unlock = { kind = "rifts", goal = 25 } },
		treasure_seeker = { nameKey = "title_treasure_seeker", unlock = { kind = "chests", goal = 50 } },
		tower_climber = { nameKey = "title_tower_climber", unlock = { kind = "tower", goal = 30 } },
		kings_bane = { nameKey = "title_kings_bane", unlock = { kind = "quest", id = "shadow_king", goal = 1 } },
		promise_keeper = { nameKey = "title_promise_keeper", unlock = { kind = "quest", id = "keepers_promise", goal = 1 } },
		reborn = { nameKey = "title_reborn", unlock = { kind = "rebirths", goal = 1 } },
		lantern_master = { nameKey = "title_lantern_master", unlock = { kind = "level", goal = 100 } },
	},
}
