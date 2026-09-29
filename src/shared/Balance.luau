-- All tuning values live here. Colors are {r, g, b} so the table stays plain data.
local Balance = {
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

-- East-land creatures and legendary bosses reuse a base creature's behavior and model (`model`)
-- with their own colors and numbers.
local function variant(baseKind: string, overrides: { [string]: any })
	local stats = table.clone(Balance.enemies[baseKind])
	stats.model = baseKind
	for key, value in overrides do
		stats[key] = value
	end
	return stats
end

local enemies = Balance.enemies
enemies.Mudling = variant("Gloomling", {
	nameKey = "enemy_mudling_name",
	maxHp = 70,
	size = 3.8,
	contactDamage = 9,
	reward = { xp = 10, coins = 6 },
	color = { 120, 100, 65 },
	friendColor = { 190, 230, 150 },
})
enemies.Bubbler = variant("Sporeling", {
	nameKey = "enemy_bubbler_name",
	shots = 3,
	spread = 16,
	reward = { xp = 14, coins = 8 },
	color = { 90, 175, 110 },
	friendColor = { 200, 255, 210 },
})
enemies.Snowpuff = variant("Gloomling", {
	nameKey = "enemy_snowpuff_name",
	maxHp = 75,
	speed = 10,
	reward = { xp = 11, coins = 6 },
	color = { 215, 235, 255 },
	friendColor = { 255, 255, 255 },
})
enemies.Frostling = variant("Rockling", {
	nameKey = "enemy_frostling_name",
	reward = { xp = 18, coins = 10 },
	color = { 140, 195, 240 },
	friendColor = { 220, 245, 255 },
})
enemies.Shade = variant("Gloomling", {
	nameKey = "enemy_shade_name",
	blink = { range = 12, cooldown = 4, distance = 9, windup = 0.45 },
	maxHp = 80,
	speed = 11,
	reward = { xp = 12, coins = 7 },
	color = { 75, 45, 115 },
	friendColor = { 230, 200, 255 },
})
enemies.Hexcap = variant("Sporeling", {
	nameKey = "enemy_hexcap_name",
	shots = 5,
	spread = 12,
	reward = { xp = 15, coins = 8 },
	color = { 125, 60, 165 },
	friendColor = { 255, 210, 250 },
})
enemies.Obsidian = variant("Rockling", {
	nameKey = "enemy_obsidian_name",
	dashSpeed = 52,
	windup = 0.75,
	maxHp = 150,
	reward = { xp = 20, coins = 11 },
	color = { 55, 50, 65 },
	friendColor = { 210, 200, 230 },
})

-- Legendary bosses: level-scaled (`scales`), each guarding its own arena. maxHp is the level-1
-- equivalent; the fight lands around a minute for a player of the boss's level.
enemies.BogMother = variant("Warden", {
	nameKey = "enemy_bogmother_name",
	scales = true,
	maxHp = 5000,
	size = 10,
	leashRadius = 32,
	aggroRadius = 30,
	respawnDelay = 60,
	reward = { xp = 4000, coins = 600 },
	color = { 70, 110, 60 },
	accent = { 170, 230, 120 },
	friendColor = { 210, 255, 190 },
})
enemies.FrostTitan = variant("Warden", {
	nameKey = "enemy_frosttitan_name",
	scales = true,
	maxHp = 3000,
	size = 11,
	hoverHeight = 6,
	leashRadius = 32,
	aggroRadius = 30,
	orbCount = 14,
	respawnDelay = 60,
	reward = { xp = 12000, coins = 2500 },
	color = { 150, 200, 250 },
	accent = { 230, 250, 255 },
	friendColor = { 255, 255, 255 },
})
enemies.ShadowKing = variant("Warden", {
	nameKey = "enemy_shadowking_name",
	scales = true,
	maxHp = 900,
	size = 12,
	hoverHeight = 6.5,
	leashRadius = 32,
	aggroRadius = 30,
	orbCount = 16,
	slamCountPhase2 = 6,
	respawnDelay = 60,
	reward = { xp = 40000, coins = 10000 },
	color = { 40, 20, 70 },
	accent = { 255, 120, 220 },
	friendColor = { 255, 230, 180 },
})

-- The Legendary Shadows collection, in the order they are met. The first win against each
-- gives a Mystic chest (or legendCoins when every chest slot is full).
Balance.legends = { "Warden", "BogMother", "FrostTitan", "ShadowKing" }

-- Shadow Rifts: while players are in a creature zone, a rift sometimes opens there and sends
-- `waves` waves of the zone's creatures. Clearing every wave before `timeLimit` gives everyone
-- who helped a `chest` (or coinsPerLevel * zone top level coins when the chest slots are full).
Balance.rifts = {
	checkInterval = 20,
	chance = 0.15,
	cooldown = 120,
	waves = 3,
	baseCount = 3,
	timeLimit = 90,
	waveDelay = 2,
	ringRadius = 9,
	chest = "silver",
	coinsPerLevel = 20,
}

-- The Shadow Tower: an endless climb in a private arena reached from the village. Floor `f`
-- sends creatures of level anchor + levelOffset + f (anchor = level of whoever opened the run, capped
-- at 100); past level 100 they grow by hpGrowth / damageGrowth per floor instead. There is no
-- timer; a run ends when everyone inside has left or been defeated. Clearing a floor pays coins
-- (minutes of own income), Pass XP, and a chest every `chestEvery` floors; a new best floor pays a
-- bonus. A player may join a run when their level is at most `joinRange` below its anchor.
Balance.tower = {
	minLevel = 10,
	joinRange = 20,
	levelOffset = -2,
	hpGrowth = 1.04,
	damageGrowth = 1.03,
	baseCount = 5,
	countEvery = 3,
	maxCount = 12,
	extraPerPlayer = 2,
	eliteEvery = 5,
	-- Every `bossEvery` floors a Legendary Shadow guards the floor (with a few helpers).
	bossEvery = 10,
	-- A tower boss has this share of a Legendary Shadow's health (it comes at a higher level than a
	-- player's own, with helpers, and the run has no timer to rest in).
	bossHpFactor = 0.4,
	startDelay = 3,
	floorDelay = 4,
	ringRadius = 9,
	leaveMargin = 12,
	chestEvery = 5,
	floorMinutes = { base = 0.15, perFloor = 0.01, max = 0.35 },
	-- Creatures a strong party defeats per minute (used to keep floor coins a bonus, see tests/logic).
	killsPerMinute = 30,
	recordMinutes = 2,
}

-- Brave Heart skill: the extra damage applies at or below this share of max health.
Balance.fury = { healthShare = 0.5 }

-- Story blessing: every main quest completed adds `xpPerQuest` XP from creatures for good, so
-- players who follow the story level up faster (and the quests themselves pay levels' worth of XP,
-- see QuestData).
Balance.story = { xpPerQuest = 0.01 }

-- Rebirth: at level 100 a player may start the climb again. Level, XP, weapon power, forge
-- upgrades, skills and the crystal pouch reset (coins become `startCoins`); weapons, stars, slot
-- levels, chests, charms, costumes, pets, quests, the log, the pass and the tower record stay.
-- Every rebirth adds `xpPerRebirth` XP from creatures (up to `maxBonusRebirths` rebirths) and
-- keeps all five chest slots open. Rewards are cosmetic (see CosmeticData sources).
-- Daily gift: coins worth this many minutes of income at the player's level, once per day.
Balance.daily = { coinMinutes = 8 }
Balance.rebirth = { xpPerRebirth = 0.1, maxBonusRebirths = 5, startCoins = 300 }

-- Rough income of a player fighting same-level creatures (used to size coin rewards that should
-- feel the same at every level: Light Pass coins and store coin packs).
Balance.income = { killsPerMinute = 15 }

-- Playing together: every other player within `radius` adds bonusPerAlly to purify XP and
-- crystals, up to maxBonus.
Balance.coop = { radius = 60, bonusPerAlly = 0.1, maxBonus = 0.3 }

-- Elite creatures: a rare, bigger, golden-crowned version of a regular creature. Everyone who
-- helped gets a chestChance roll for one of `chests` (when a chest slot is free).
Balance.elite = {
	chance = 0.06,
	hpMultiplier = 4,
	damageMultiplier = 1.4,
	rewardMultiplier = 3,
	sizeMultiplier = 1.35,
	chestChance = 0.35,
	chests = { "wood", "wood", "silver" },
}
Balance.legendCoins = 300

return Balance
