-- All tuning values live here. Colors are {r, g, b} so the table stays plain data.
return {
	levels = {
		-- XP needed to go from level L to L + 1 is xpBase + xpScale * L ^ xpPower.
		maxLevel = 100,
		xpBase = 40,
		xpScale = 30,
		xpPower = 1.5,
		baseHealth = 150,
		healthPerLevel = 12,
		damageBonusPerLevel = 0.05,
	},

	player = {
		walkSpeed = 16,
		respawnTime = 3,
	},

	-- Forge upgrades bought from the Smith. Going from level n to n + 1 costs
	-- floor(baseCost * growth ^ n) coins. "power" is saved as profile.staffUpgrade (attribute
	-- StaffTier) for save compatibility; the others live in profile.upgrades.
	upgradeOrder = { "power", "pouch", "health", "regen", "crit" },
	upgrades = {
		-- Weapon damage +perLevel (fraction) per level.
		power = { nameKey = "upgrade_power_name", descKey = "upgrade_power_desc", maxLevel = 50, baseCost = 40, growth = 1.22, perLevel = 0.1 },
		-- Crystal pouch capacity +perLevel per level.
		pouch = { nameKey = "upgrade_pouch_name", descKey = "upgrade_pouch_desc", maxLevel = 20, baseCost = 30, growth = 1.22, perLevel = 20 },
		-- Max health +perLevel (fraction) per level.
		health = { nameKey = "upgrade_health_name", descKey = "upgrade_health_desc", maxLevel = 50, baseCost = 35, growth = 1.2, perLevel = 0.06 },
		-- Health per second outside the village.
		regen = { nameKey = "upgrade_regen_name", descKey = "upgrade_regen_desc", maxLevel = 20, baseCost = 50, growth = 1.22, perLevel = 0.5 },
		-- Critical hit chance +perLevel per level.
		crit = { nameKey = "upgrade_crit_name", descKey = "upgrade_crit_desc", maxLevel = 20, baseCost = 80, growth = 1.25, perLevel = 0.015 },
	},
	-- Weapon glow color by power level band (every 10 levels).
	powerColors = { { 255, 236, 170 }, { 150, 230, 255 }, { 190, 160, 255 }, { 255, 190, 120 }, { 255, 130, 200 }, { 255, 255, 255 } },
	critDamage = 2,

	-- Purified creatures drop Light Crystals into the pouch; the Great Lantern in the village
	-- plaza turns them into coins (one coin each).
	-- Capacity also grows with the player's level (like creature crystals), so a pouch always
	-- holds about the same number of fights.
	pouch = { baseCapacity = 60, perLevel = 0.2, lanternRadius = 14 },

	wave = {
		unlockLevel = 3,
		damageMultiplier = 1.5,
		radius = 14,
		cooldown = 8,
		knockback = 7,
		stagger = 0.5,
	},

	charmOrder = { "swift", "guard", "glow" },
	charms = {
		swift = {
			nameKey = "charm_swift_name",
			descKey = "charm_swift_desc",
			color = { 140, 230, 170 },
			walkSpeedMultiplier = 1.25,
		},
		guard = {
			nameKey = "charm_guard_name",
			descKey = "charm_guard_desc",
			color = { 150, 190, 255 },
			damageTakenMultiplier = 0.65,
		},
		glow = {
			nameKey = "charm_glow_name",
			descKey = "charm_glow_desc",
			color = { 255, 220, 120 },
			waveCooldownMultiplier = 0.65,
			waveRadiusMultiplier = 1.25,
		},
	},

	-- Creatures get tougher and more rewarding with their level (tuned with `lune run tests/balance`).
	-- Health grows by hpGrowth per level up to lateFrom and by hpGrowthLate after it, keeping up
	-- with the player's multiplying power (rarer weapons and floating slots arrive mid-game); XP is set
	-- so a same-level reference creature (reward.xp = referenceXp) is worth 1 / kills of a level,
	-- kills = killsBase + killsPerLevel * (level - 1). Bosses with `scales` follow the same curve.
	enemyScaling = {
		hpGrowth = 1.11,
		hpGrowthLate = 1.06,
		lateFrom = 50,
		damagePerLevel = 0.08,
		referenceXp = 10,
		killsBase = 10,
		killsPerLevel = 2,
		coinsPerLevel = 0.12,
	},

	enemies = {
		Gloomling = {
			nameKey = "enemy_gloomling_name",
			behavior = "chaser",
			maxHp = 60,
			speed = 9,
			size = 3.5,
			hoverHeight = 2,
			aggroRadius = 28,
			leashRadius = 40,
			contactRange = 4,
			contactDamage = 8,
			contactCooldown = 1.5,
			respawnDelay = 10,
			reward = { xp = 10, coins = 5 },
			color = { 115, 75, 175 },
			friendColor = { 255, 236, 170 },
		},
		Sporeling = {
			nameKey = "enemy_sporeling_name",
			behavior = "shooter",
			maxHp = 90,
			speed = 7,
			size = 3.2,
			hoverHeight = 1.8,
			aggroRadius = 32,
			leashRadius = 38,
			preferredMin = 12,
			preferredMax = 20,
			fireInterval = 2.4,
			windup = 0.45,
			projectileSpeed = 30,
			projectileRadius = 1.3,
			projectileDamage = 12,
			projectileLifetime = 2.2,
			contactRange = 3.5,
			contactDamage = 6,
			contactCooldown = 1.5,
			respawnDelay = 12,
			reward = { xp = 16, coins = 8 },
			color = { 205, 95, 150 },
			friendColor = { 255, 200, 230 },
		},
		Rockling = {
			nameKey = "enemy_rockling_name",
			behavior = "charger",
			maxHp = 140,
			speed = 7,
			size = 4,
			hoverHeight = 2.1,
			aggroRadius = 30,
			leashRadius = 42,
			chargeRange = 18,
			windup = 0.9,
			dashSpeed = 42,
			dashDuration = 0.55,
			dashDamage = 18,
			recover = 1.2,
			contactRange = 4.2,
			contactDamage = 8,
			contactCooldown = 1.5,
			respawnDelay = 14,
			reward = { xp = 22, coins = 12 },
			color = { 135, 120, 110 },
			friendColor = { 210, 240, 200 },
		},
		Warden = {
			nameKey = "enemy_warden_name",
			behavior = "boss",
			isBoss = true,
			maxHp = 1800,
			extraHpPerPlayer = 0.6,
			speed = 5,
			size = 9,
			hoverHeight = 5.5,
			aggroRadius = 36,
			leashRadius = 46,
			keepDistance = 11,
			-- Long enough for a defeated solo player to respawn and walk back without losing progress.
			resetAfter = 30,
			restTime = 1.6,
			restTimePhase2 = 1.0,
			phase2At = 0.5,
			slamCount = 3,
			slamCountPhase2 = 5,
			slamRadius = 7,
			slamDamage = 28,
			slamWarn = 1.4,
			slamWarnPhase2 = 1.0,
			orbWindup = 0.6,
			orbCount = 12,
			orbSpeed = 18,
			orbRadius = 1.6,
			orbDamage = 16,
			orbLifetime = 4,
			contactRange = 6.5,
			contactDamage = 15,
			contactCooldown = 1.5,
			respawnDelay = 45,
			participationWindow = 60,
			reward = { xp = 250, coins = 120 },
			color = { 60, 40, 95 },
			friendColor = { 255, 240, 200 },
		},
	},

	-- Players who hit an enemy within this many seconds before it is purified share the reward.
	participationWindow = 30,
	npcTalkDistance = 14,
	hitPush = 1.2,
	-- The village is a safe place: players within this radius of WorldData.plaza heal quickly.
	village = { radius = 50, healPerSecond = 12 },
	shopDistance = 18,
	interactDistance = 12,
	discoverRadius = 12,
	vineHitTolerance = 3,
}
