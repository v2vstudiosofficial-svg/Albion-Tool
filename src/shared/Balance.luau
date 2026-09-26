return {
	staff = {
		damage = 25,
		cooldown = 0.6,
		range = 22,
	},
	enemies = {
		Gloomling = {
			nameKey = "enemy_gloomling_name",
			maxHp = 50,
			speed = 8,
			hoverHeight = 2,
			aggroRadius = 28,
			leashRadius = 40,
			contactRange = 4,
			contactDamage = 10,
			contactCooldown = 1.5,
			respawnDelay = 10,
			reward = { xp = 10, coins = 5 },
		},
	},
	-- Players who hit an enemy within this many seconds before it is purified share the reward.
	participationWindow = 30,
	npcTalkDistance = 14,
}
