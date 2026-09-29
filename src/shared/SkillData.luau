-- Skill cards offered on every level-up (pick one of three). Ranks stack up to maxRank and are
-- kept forever. `perRank` is a fraction unless noted. When every skill is maxed the card turns
-- into a coin gift.
return {
	order = { "swift", "sharp", "reach", "lucky", "tough", "magnet", "feet", "wave", "wisdom", "echo", "healing", "fury", "treasure" },
	offerCount = 3,
	fallbackCoins = 50,

	skills = {
		-- Weapon cooldowns shorter by perRank each rank.
		swift = { nameKey = "skill_swift_name", descKey = "skill_swift_desc", maxRank = 5, perRank = 0.05, color = { 150, 220, 255 } },
		-- Weapon damage.
		sharp = { nameKey = "skill_sharp_name", descKey = "skill_sharp_desc", maxRank = 5, perRank = 0.06, color = { 255, 170, 120 } },
		-- Weapon range.
		reach = { nameKey = "skill_reach_name", descKey = "skill_reach_desc", maxRank = 4, perRank = 0.08, color = { 200, 230, 140 } },
		-- Critical chance (added).
		lucky = { nameKey = "skill_lucky_name", descKey = "skill_lucky_desc", maxRank = 5, perRank = 0.03, color = { 255, 230, 110 } },
		-- Max health.
		tough = { nameKey = "skill_tough_name", descKey = "skill_tough_desc", maxRank = 5, perRank = 0.08, color = { 255, 130, 150 } },
		-- More crystals from creatures.
		magnet = { nameKey = "skill_magnet_name", descKey = "skill_magnet_desc", maxRank = 4, perRank = 0.15, color = { 170, 140, 255 } },
		-- Walk speed.
		feet = { nameKey = "skill_feet_name", descKey = "skill_feet_desc", maxRank = 4, perRank = 0.05, color = { 140, 230, 170 } },
		-- Light Wave: cooldown shorter and radius bigger by perRank.
		wave = { nameKey = "skill_wave_name", descKey = "skill_wave_desc", maxRank = 4, perRank = 0.08, color = { 140, 200, 255 } },
		-- More XP from creatures.
		wisdom = { nameKey = "skill_wisdom_name", descKey = "skill_wisdom_desc", maxRank = 4, perRank = 0.08, color = { 230, 200, 255 } },
		-- Floating weapons hit harder.
		-- Heals this share of max health every time you purify a creature.
		healing = { nameKey = "skill_healing_name", descKey = "skill_healing_desc", maxRank = 5, perRank = 0.02, color = { 150, 255, 170 } },
		-- More damage while at half health or less.
		fury = { nameKey = "skill_fury_name", descKey = "skill_fury_desc", maxRank = 4, perRank = 0.1, color = { 255, 110, 90 } },
		-- More coins from chests.
		treasure = { nameKey = "skill_treasure_name", descKey = "skill_treasure_desc", maxRank = 4, perRank = 0.15, color = { 255, 215, 100 } },
		echo = { nameKey = "skill_echo_name", descKey = "skill_echo_desc", maxRank = 5, perRank = 0.1, color = { 120, 240, 220 } },
	},
}
