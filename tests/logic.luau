-- Run: lune run tests/logic
local fs = require("@lune/fs")

local Profile = require("../src/server/Profile")
local QuestLogic = require("../src/server/QuestLogic")
local EnemyLogic = require("../src/server/EnemyLogic")
local QuestData = require("../src/shared/QuestData")
local Balance = require("../src/shared/Balance")
local Strings = require("../src/shared/Strings")
local WorldData = require("../src/shared/WorldData")
local Progression = require("../src/shared/Progression")
local Sounds = require("../src/shared/Sounds")
local Goals = require("../src/shared/Goals")
local WeaponData = require("../src/shared/WeaponData")
local WeaponLogic = require("../src/server/WeaponLogic")
local ChestData = require("../src/shared/ChestData")
local ChestLogic = require("../src/server/ChestLogic")
local SkillData = require("../src/shared/SkillData")
local SkillLogic = require("../src/server/SkillLogic")
local Stats = require("../src/shared/Stats")

local passed, failed = 0, 0

local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function eq(actual, expected, message: string?)
	if actual ~= expected then
		error(`{message or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local function contains(list, value): boolean
	return table.find(list, value) ~= nil
end

-- Completes a quest the way the server does: record events, then pay rewards once.
local function payCompleted(profile, completed: { string })
	for _, questId in completed do
		local reward = QuestData.quests[questId].reward
		if reward.charm then
			Profile.grantCharm(profile, reward.charm)
		end
		if reward.flag then
			Profile.setFlag(profile, reward.flag)
		end
		Profile.applyReward(profile, reward)
	end
end

local function level(profile): number
	return Progression.levelForXp(profile.xp)
end

-- Profile ---------------------------------------------------------------------------------------

test("new profile has every schema field", function()
	local p = Profile.new()
	eq(p.schemaVersion, 1)
	eq(p.xp, 0)
	eq(p.coins, 0)
	eq(p.staffUpgrade, 0)
	eq(type(p.ownedCharms), "table")
	eq(p.equippedCharm, nil)
	eq(type(p.questProgress), "table")
	eq(type(p.restorationFlags), "table")
end)

test("applyReward adds and rejects invalid amounts", function()
	local p = Profile.new()
	Profile.applyReward(p, { xp = 10, coins = 5 })
	Profile.applyReward(p, { coins = 1 })
	eq(p.xp, 10)
	eq(p.coins, 6)
	eq(pcall(Profile.applyReward, p, { coins = -1 }), false, "negative")
	eq(pcall(Profile.applyReward, p, { xp = 1.5 }), false, "fraction")
	eq(pcall(Profile.applyReward, p, { xp = 0 / 0 }), false, "nan")
	eq(pcall(Profile.applyReward, p, { xp = math.huge }), false, "inf")
	eq(p.xp, 10, "unchanged xp")
	eq(p.coins, 6, "unchanged coins")
end)

test("sanitize repairs corrupted data without dropping valid progress", function()
	local data = {
		schemaVersion = 1,
		xp = -5,
		coins = "lots",
		staffUpgrade = 99,
		ownedCharms = { swift = true, hacked = true, guard = "yes" },
		equippedCharm = "guard",
		questProgress = {
			first_purify = { state = "completed", count = 1 },
			broken = { state = "weird", count = 1 },
			future_quest = { state = "active", count = 2, found = "bad" },
		},
		restorationFlags = { gardens = true, bogus = 1 },
	}
	Profile.sanitize(data)
	eq(data.xp, 0, "xp")
	eq(data.coins, 0, "coins")
	eq(data.staffUpgrade, Progression.maxStaffUpgrade(), "staff clamp")
	eq(data.ownedCharms.swift, true, "valid charm kept")
	eq(data.ownedCharms.hacked, nil, "unknown charm removed")
	eq(data.ownedCharms.guard, nil, "non-true charm removed")
	eq(data.equippedCharm, nil, "unowned equipped charm cleared")
	eq(data.questProgress.first_purify.state, "completed", "valid quest kept")
	eq(data.questProgress.broken, nil, "invalid quest removed")
	eq(data.questProgress.future_quest.count, 2, "unknown quest kept")
	eq(data.questProgress.future_quest.found, nil, "bad found cleared")
	eq(data.restorationFlags.gardens, true)
	eq(data.restorationFlags.bogus, nil)
end)

test("sanitize fills missing tables on an empty record", function()
	local data = Profile.sanitize({})
	eq(data.xp, 0)
	eq(type(data.ownedCharms), "table")
	eq(type(data.questProgress), "table")
	eq(type(data.restorationFlags), "table")
end)

test("forge upgrades spend coins once per level, prices rise, and stop at max", function()
	for _, stat in Balance.upgradeOrder do
		local upgrade = Balance.upgrades[stat]
		assert(Strings.has(upgrade.nameKey) and Strings.has(upgrade.descKey), "upgrade strings " .. stat)
		local p = Profile.new()
		local ok, reason, missing = Profile.buyUpgrade(p, stat)
		eq(ok, false)
		eq(reason, "coins")
		eq(missing, Progression.upgradeCost(stat, 0))
		p.coins = 10 ^ 12
		local spent, previousCost = 0, 0
		for level = 1, upgrade.maxLevel do
			local cost = Progression.upgradeCost(stat, level - 1) :: number
			assert(cost >= previousCost, stat .. " prices never drop")
			previousCost = cost
			eq(Profile.buyUpgrade(p, stat), true, stat .. " level " .. level)
			spent += cost
		end
		eq(Profile.upgradeLevel(p, stat), upgrade.maxLevel)
		eq(select(2, Profile.buyUpgrade(p, stat)), "max")
		eq(p.coins, 10 ^ 12 - spent, stat .. " charged exactly")
	end
	eq(select(2, Profile.buyUpgrade(Profile.new(), "nope")), "unknown")
end)

test("charms: grant once, auto-equip first, equip only owned", function()
	local p = Profile.new()
	eq(Profile.grantCharm(p, "swift"), true)
	eq(Profile.grantCharm(p, "swift"), false, "duplicate")
	eq(Profile.grantCharm(p, "nope"), false, "unknown")
	eq(p.equippedCharm, "swift", "auto equip")
	eq(Profile.grantCharm(p, "guard"), true)
	eq(p.equippedCharm, "swift", "keeps current")
	eq(Profile.equipCharm(p, "glow"), false, "not owned")
	eq(Profile.equipCharm(p, "guard"), true)
	eq(p.equippedCharm, "guard")
	eq(Profile.equipCharm(p, nil), true)
	eq(p.equippedCharm, nil)
end)

-- Progression -----------------------------------------------------------------------------------

test("levels follow the thresholds and cap at max", function()
	local thresholds = Progression.thresholds
	eq(Progression.levelForXp(0), 1)
	eq(Progression.levelForXp(thresholds[2] - 1), 1)
	eq(Progression.levelForXp(thresholds[2]), 2)
	eq(Progression.levelForXp(10 ^ 9), Progression.MAX_LEVEL)
	eq(Progression.MAX_LEVEL, 100)
	eq(#thresholds, 100)
	for level = 1, 100 do
		eq(Progression.levelForXp(thresholds[level]), level, "exact threshold " .. level)
		if level > 1 then
			eq(Progression.levelForXp(thresholds[level] - 1), level - 1, "just below " .. level)
		end
	end
	local lvl, into, span = Progression.levelProgress(thresholds[3] + 50)
	eq(lvl, 3)
	eq(into, 50)
	eq(span, thresholds[4] - thresholds[3])
	local _, _, maxSpan = Progression.levelProgress(10 ^ 9)
	eq(maxSpan, nil, "no span at max level")
	local previous = -1
	for _, needed in thresholds do
		assert(needed > previous, "thresholds must increase")
		previous = needed
	end
end)

test("derived stats: health, damage, wave, charms", function()
	eq(Progression.maxHealth(1), Balance.levels.baseHealth)
	eq(Progression.maxHealth(10), Balance.levels.baseHealth + 9 * Balance.levels.healthPerLevel)
	eq(Progression.staffDamage(0, 1), 25)
	assert(Progression.staffDamage(3, 10) > Progression.staffDamage(0, 1), "damage grows")
	eq(Progression.waveUnlocked(2), false)
	eq(Progression.waveUnlocked(3), true)
	local plain = Progression.waveStats(0, 3, nil)
	local glow = Progression.waveStats(0, 3, "glow")
	assert(glow.cooldown < plain.cooldown and glow.radius > plain.radius, "glow charm improves wave")
	eq(Progression.damageTaken(20, nil), 20)
	assert(Progression.damageTaken(20, "guard") < 20, "guard reduces damage")
	eq(Progression.damageTaken(1, "guard"), 1, "never below 1")
	assert(Progression.walkSpeed("swift") > Progression.walkSpeed(nil), "swift is faster")
end)

test("post-story goals: affordable upgrade, then level cap, then remaining tiers, then done", function()
	local maxXp = Progression.thresholds[Progression.MAX_LEVEL]
	local g = Goals.next(0, Progression.upgradeCost("power", 0), 0)
	eq(g.kind, "staff", "affordable upgrade first")
	eq(g.affordable, true)
	local levelGoal = Goals.next(0, 0, 0)
	eq(levelGoal.kind, "level", "otherwise level up")
	eq(levelGoal.target, ChestData.slotUnlockLevels[2], "toward the next chest slot")
	eq(Goals.next(Progression.thresholds[24], 0, 0).target, 25, "floating slot is a milestone")
	local lastTier = Progression.maxStaffUpgrade()
	local staffOnly = Goals.next(maxXp, 0, lastTier - 1)
	eq(staffOnly.kind, "staff", "at max level, remaining tiers")
	eq(staffOnly.affordable, false)
	eq(staffOnly.missing, Progression.upgradeCost("power", lastTier - 1), "missing coins")
	eq(Goals.next(maxXp, 0, lastTier).kind, "done")
	eq(Goals.next(maxXp, 10 ^ 6, lastTier).kind, "done", "max tier with lots of coins")
	local capped = Goals.next(maxXp, Progression.upgradeCost("power", 0), 0)
	eq(capped.kind, "staff", "affordable power level at the level cap")
	eq(capped.affordable, true)
	eq(capped.target, 1, "the next power level")
end)

-- Quests ----------------------------------------------------------------------------------------

test("purify before accepting the quest does not count", function()
	local p = Profile.new()
	eq(#QuestLogic.record(p, QuestData, { kind = "purify", target = "Gloomling" }), 0)
	eq(p.questProgress.first_purify, nil)
end)

test("quests unlock in order and cannot be skipped", function()
	local p = Profile.new()
	local ok, reason = QuestLogic.start(p, QuestData, "forest_explore", 10)
	eq(ok, false)
	eq(reason, "locked")
	eq(QuestLogic.start(p, QuestData, "first_purify", 1), true)
	local again, againReason = QuestLogic.start(p, QuestData, "first_purify", 1)
	eq(again, false)
	eq(againReason, "started")
	eq(select(2, QuestLogic.start(p, QuestData, "nope", 1)), "unknown")
end)

test("quest completes exactly once", function()
	local p = Profile.new()
	QuestLogic.start(p, QuestData, "first_purify", 1)
	eq(#QuestLogic.record(p, QuestData, { kind = "purify", target = "Sporeling" }), 0, "wrong enemy")
	local goal = QuestData.quests.first_purify.objective.count
	for _ = 1, goal - 1 do
		eq(#QuestLogic.record(p, QuestData, { kind = "purify", target = "Gloomling" }), 0, "not yet")
	end
	eq(p.questProgress.first_purify.count, goal - 1)
	local completed = QuestLogic.record(p, QuestData, { kind = "purify", target = "Gloomling" })
	eq(#completed, 1)
	eq(completed[1], "first_purify")
	eq(#QuestLogic.record(p, QuestData, { kind = "purify", target = "Gloomling" }), 0, "second purify")
	eq(QuestLogic.isCompleted(p, "first_purify"), true)
	eq(QuestLogic.tracked(p, QuestData), nil)
	eq(QuestLogic.nextAvailable(p, QuestData), "lantern_flowers")
end)

test("collect counts each id once and ignores unknown ids", function()
	local p = Profile.new()
	p.questProgress.first_purify = { state = "completed", count = 1 }
	QuestLogic.start(p, QuestData, "lantern_flowers", 1)
	QuestLogic.record(p, QuestData, { kind = "collect", id = "flower_1" })
	QuestLogic.record(p, QuestData, { kind = "collect", id = "flower_1" })
	QuestLogic.record(p, QuestData, { kind = "collect", id = "flower_999" })
	QuestLogic.record(p, QuestData, { kind = "collect", id = 5 })
	eq(p.questProgress.lantern_flowers.count, 1)
	eq(QuestLogic.isFound(p, "lantern_flowers", "flower_1"), true)
	eq(QuestLogic.isFound(p, "lantern_flowers", "flower_2"), false)
end)

test("level gate blocks the ruins quest until level 3", function()
	local p = Profile.new()
	for _, questId in { "first_purify", "lantern_flowers", "forest_explore", "first_upgrade" } do
		p.questProgress[questId] = { state = "completed", count = 1 }
	end
	local ok, reason = QuestLogic.start(p, QuestData, "ruin_vines", 2)
	eq(ok, false)
	eq(reason, "level")
	eq(QuestLogic.start(p, QuestData, "ruin_vines", 3), true)
end)

test("upgrade quest counts an upgrade bought before the quest started", function()
	local p = Profile.new()
	for _, questId in { "first_purify", "lantern_flowers", "forest_explore" } do
		p.questProgress[questId] = { state = "completed", count = 1 }
	end
	p.staffUpgrade = 1
	QuestLogic.start(p, QuestData, "first_upgrade", 3)
	local completed = QuestLogic.record(p, QuestData, { kind = "upgrade", value = p.staffUpgrade })
	eq(completed[1], "first_upgrade")
end)

test("full chain is completable with a short grind at most, paying each reward once", function()
	local p = Profile.new()
	local function start(questId: string)
		local ok, reason = QuestLogic.start(p, QuestData, questId, level(p))
		assert(ok, `could not start {questId}: {tostring(reason)}`)
	end
	local function event(e)
		payCompleted(p, QuestLogic.record(p, QuestData, e))
	end
	local fights = {}
	local function purify(kind: string, enemyLevel: number)
		local reward = Progression.enemyStats(Balance.enemies[kind], enemyLevel).reward
		table.insert(fights, reward)
		Profile.applyReward(p, reward)
		event({ kind = "purify", target = kind })
	end

	start("first_purify")
	for _ = 1, QuestData.quests.first_purify.objective.count do
		purify("Gloomling", 1)
	end
	start("lantern_flowers")
	for _, id in QuestData.quests.lantern_flowers.objective.ids do
		event({ kind = "collect", id = id })
		event({ kind = "collect", id = id })
	end
	start("forest_explore")
	for _, id in QuestData.quests.forest_explore.objective.ids do
		event({ kind = "explore", id = id })
	end
	start("first_upgrade")
	assert(Profile.buyUpgrade(p, "power"), "enough coins for the first upgrade without grinding")
	event({ kind = "upgrade", value = p.staffUpgrade })
	start("ruin_vines")
	for _, id in QuestData.quests.ruin_vines.objective.ids do
		event({ kind = "vine", id = id })
	end
	-- The boss quest is level-gated; a player may need a few extra fights in the hollow.
	local extraFights = 0
	while not QuestLogic.canStart(p, QuestData, "warden", level(p)) do
		purify("Gloomling", 5)
		extraFights += 1
	end
	assert(extraFights <= 12, "grind before the boss stays short: " .. extraFights .. " Gloomlings")
	start("warden")
	purify("Warden", 8)
	purify("Warden", 8)

	local chapterOne = { "first_purify", "lantern_flowers", "forest_explore", "first_upgrade", "ruin_vines", "warden" }
	for _, questId in chapterOne do
		eq(QuestLogic.isCompleted(p, questId), true, questId)
	end
	eq(QuestLogic.nextAvailable(p, QuestData), "marsh_scouts", "chapter 2 comes next")
	local canStart, reason = QuestLogic.canStart(p, QuestData, "marsh_scouts", level(p))
	eq(canStart, false, "the east lands wait for a stronger player")
	eq(reason, "level")
	eq(p.ownedCharms.swift and p.ownedCharms.guard and p.ownedCharms.glow, true, "all charms")
	eq(p.restorationFlags.gardens and p.restorationFlags.lanterns and p.restorationFlags.festival, true, "all flags")

	local expectedXp, expectedCoins = 0, -(Progression.upgradeCost("power", 0) :: number)
	for _, questId in chapterOne do
		local reward = QuestData.quests[questId].reward
		expectedXp += reward.xp or 0
		expectedCoins += reward.coins or 0
	end
	for _, reward in fights do
		expectedXp += reward.xp
		expectedCoins += reward.coins
	end
	eq(p.xp, expectedXp, "xp")
	eq(p.coins, expectedCoins, "coins")
	assert(level(p) >= 5, "reaches a satisfying level by the end of the chain")
	assert(level(p) < Progression.MAX_LEVEL, "the level cap stays a post-game goal")
	local powerTen = 0
	for level = 1, 9 do
		powerTen += Progression.upgradeCost("power", level) :: number
	end
	assert(p.coins < powerTen, "weapon power 10 stays a post-game goal")
end)

-- Enemies ---------------------------------------------------------------------------------------

test("enemy purifies exactly once across many hits", function()
	local state = EnemyLogic.new(50)
	local purifications = 0
	for i = 1, 10 do
		if EnemyLogic.applyHit(state, if i % 2 == 0 then "a" else "b", 25, i) then
			purifications += 1
		end
	end
	eq(purifications, 1)
	eq(state.alive, false)
	eq(state.hp, 0)
	eq(EnemyLogic.applyHit(state, "a", 0, 11), false, "zero damage")
end)

test("participants: recent and present hitters only", function()
	local state = EnemyLogic.new(100)
	EnemyLogic.applyHit(state, "old", 10, 0)
	EnemyLogic.applyHit(state, "a", 10, 40)
	EnemyLogic.applyHit(state, "left", 10, 45)
	EnemyLogic.applyHit(state, "b", 10, 50)
	local list = EnemyLogic.participants(state, 50, 30, function(who)
		return who ~= "left"
	end)
	eq(#list, 2)
	eq(contains(list, "a"), true, "a")
	eq(contains(list, "b"), true, "b")
end)

test("co-op: each participant gets one enemy reward and one quest reward", function()
	local stats = Balance.enemies.Gloomling
	local profiles = { a = Profile.new(), b = Profile.new() }
	for _, p in profiles do
		QuestLogic.start(p, QuestData, "first_purify", 1)
		p.questProgress.first_purify.count = QuestData.quests.first_purify.objective.count - 1
	end
	local state = EnemyLogic.new(stats.maxHp)
	for i = 1, 10 do
		local who = if i % 2 == 0 then "a" else "b"
		if EnemyLogic.applyHit(state, who, WeaponData.weapons.staff.damage, i) then
			for _, name in EnemyLogic.participants(state, i, Balance.participationWindow, function()
				return true
			end) do
				Profile.applyReward(profiles[name], stats.reward)
				payCompleted(profiles[name], QuestLogic.record(profiles[name], QuestData, { kind = "purify", target = "Gloomling" }))
			end
		end
	end
	local quest = QuestData.quests.first_purify.reward
	for _, p in profiles do
		eq(p.xp, stats.reward.xp + quest.xp, "xp")
		eq(p.coins, stats.reward.coins + quest.coins, "coins")
	end
end)

-- Data consistency ------------------------------------------------------------------------------

test("quest data references existing enemies, world points, charms and strings", function()
	for index, questId in QuestData.order do
		local quest = QuestData.quests[questId]
		assert(quest, "missing quest " .. questId)
		eq(quest.id, questId, "quest id")
		for _, key in { quest.titleKey, quest.offerKey, quest.objectiveKey } do
			assert(Strings.has(key), "missing string " .. key)
		end
		local objective = quest.objective
		if objective.kind == "purify" then
			assert(Balance.enemies[objective.enemyType], "missing enemy " .. objective.enemyType)
			assert(WorldData.areas[objective.area], "missing area " .. objective.area)
		elseif objective.kind == "collect" then
			for _, id in objective.ids do
				assert(WorldData.flowers[id], "missing flower " .. id)
			end
		elseif objective.kind == "explore" then
			for _, id in objective.ids do
				assert(WorldData.landmarks[id], "missing landmark " .. id)
			end
		elseif objective.kind == "vine" then
			for _, id in objective.ids do
				assert(WorldData.vines[id], "missing vine " .. id)
			end
		elseif objective.kind == "upgrade" then
			assert(WorldData.npcs[objective.npc], "missing npc")
		elseif objective.kind == "counter" then
			assert(objective.counter == "towerBest" or table.find(require("../src/server/AchievementLogic").COUNTERS, objective.counter), "unknown counter " .. objective.counter)
			assert(objective.count >= 1 and (not objective.area or WorldData.areas[objective.area]), "counter goal and area")
		else
			error("unknown objective kind " .. tostring(objective.kind))
		end
		if quest.reward.charm then
			assert(Balance.charms[quest.reward.charm], "missing charm " .. quest.reward.charm)
		end
		if quest.reward.flag then
			assert(Strings.has("notice_restore_" .. quest.reward.flag), "missing restore notice for " .. quest.reward.flag)
		end
		assert(index == 1 or not quest.minLevel or quest.minLevel <= Progression.MAX_LEVEL, "reachable level gate")
		assert(WorldData.npcs[quest.giver or "Elder"], "quest giver " .. questId)
		-- Level gates never go down along the chain, so no quest waits behind an easier one.
		local previous = QuestData.quests[QuestData.order[index - 1] or questId]
		assert((quest.minLevel or 0) >= (previous.minLevel or 0), "level gate order at " .. questId)
	end
	for kind, stats in Balance.enemies do
		assert(Strings.has(stats.nameKey), "missing name string for " .. kind)
	end
	for _, spawn in WorldData.spawns do
		assert(Balance.enemies[spawn.kind], "spawn of unknown enemy " .. spawn.kind)
		assert(WorldData.areas[spawn.area], "spawn in unknown area " .. spawn.area)
	end
	for _, charmId in Balance.charmOrder do
		local charm = Balance.charms[charmId]
		assert(Strings.has(charm.nameKey) and Strings.has(charm.descKey), "charm strings " .. charmId)
	end
	for _, landmark in WorldData.landmarks do
		assert(Strings.has(landmark.nameKey), "landmark string " .. landmark.nameKey)
	end
	for _, npc in WorldData.npcs do
		assert(Strings.has(npc.nameKey), "npc string " .. npc.nameKey)
	end
end)

test("every charm is rewarded by exactly one quest", function()
	local sources = {}
	for _, questId in QuestData.order do
		local charm = QuestData.quests[questId].reward.charm
		if charm then
			sources[charm] = (sources[charm] or 0) + 1
		end
	end
	for _, charmId in Balance.charmOrder do
		eq(sources[charmId], 1, charmId)
	end
end)

test("sound entries are silent or use an explicit asset scheme", function()
	for key, entry in Sounds do
		local ok = entry.id == "" or string.match(entry.id, "^rbxasset://") or string.match(entry.id, "^rbxassetid://%d+$")
		assert(ok, "bad sound id for " .. key)
	end
end)

test("every literal string key used in source exists", function()
	local missing = {}
	local function scan(dir: string)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				if name ~= "Packages" then
					scan(path)
				end
			elseif string.sub(name, -5) == ".luau" then
				local source = fs.readFile(path)
				for key in string.gmatch(source, "Strings%.get%(%s*\"([%w_]+)\"") do
					if not Strings.has(key) then
						table.insert(missing, path .. ": " .. key)
					end
				end
				for key in string.gmatch(source, "FireClient%([^,]+,%s*\"([%w_]+)\"") do
					local isFx = string.find(source, "fx:FireClient%([^,]+,%s*\"" .. key .. "\"") ~= nil
					local isPrefix = string.sub(key, -1) == "_" -- dynamic key built with "..", checked by the quest data test
					if not isFx and not isPrefix and not Strings.has(key) and not WorldData.npcs[key] then
						table.insert(missing, path .. ": " .. key)
					end
				end
				for npc, key in string.gmatch(source, "npcSay:FireClient%([^,]+,%s*\"([%w_]+)\",%s*\"([%w_]+)\"") do
					if not WorldData.npcs[npc] or not Strings.has(key) then
						table.insert(missing, path .. ": " .. npc .. "/" .. key)
					end
				end
			end
		end
	end
	scan("src")
	eq(#missing, 0, "missing keys: " .. table.concat(missing, ", "))
end)

-- Weapons ---------------------------------------------------------------------------------------

local function foe(id: number, x: number, z: number, size: number?)
	return { id = id, x = x, z = z, size = size or 2 }
end

local function sorted(list: { number }): string
	local copy = table.clone(list)
	table.sort(copy)
	return table.concat(copy, ",")
end

test("weapon data: eight weapons sorted by rarity, strings, known styles", function()
	eq(#WeaponData.order, 8, "eight weapons")
	local previous = 1
	local styles = {}
	for _, weaponId in WeaponData.order do
		local weapon = WeaponData.weapons[weaponId]
		assert(weapon, "missing weapon " .. weaponId)
		assert(Strings.has(weapon.nameKey) and Strings.has(weapon.descKey), "weapon strings " .. weaponId)
		local rank = table.find(WeaponData.rarityOrder, weapon.rarity)
		assert(rank, "known rarity " .. weaponId)
		assert(rank >= previous, "order goes from common to legendary: " .. weaponId)
		previous = rank
		assert(weapon.damage > 0 and weapon.cooldown > 0 and weapon.range > 0, "stats " .. weaponId)
		styles[weapon.style] = true
		-- Each weapon plans an attack without erroring.
		assert(WeaponLogic.plan(weapon, { x = 0, z = 0 }, { x = 0, z = -1 }, { foe(1, 0, -3) }), "plan " .. weaponId)
	end
	eq(WeaponData.starter, "staff", "starter weapon")
	for _, rarity in WeaponData.rarityOrder do
		assert(Strings.has(WeaponData.rarities[rarity].nameKey), "rarity string " .. rarity)
	end
	local count = 0
	for _ in styles do
		count += 1
	end
	eq(count, 8, "every weapon attacks differently")
	eq(#WeaponData.companionOffsets, WeaponData.maxCompanions, "a hover spot per floating slot")
end)

test("weapon logic: nearest target, range, line-of-sight veto", function()
	local staff = WeaponData.weapons.staff
	local foes = { foe(1, 0, -20), foe(2, 0, -10), foe(3, 0, -40) }
	local plan = WeaponLogic.plan(staff, { x = 0, z = 0 }, { x = 0, z = -1 }, foes)
	eq(plan and plan.primary.id, 2, "nearest first")
	eq(plan and sorted(plan.hits), "2", "single target")
	local blocked = WeaponLogic.plan(staff, { x = 0, z = 0 }, { x = 0, z = -1 }, foes, function(f)
		return f.id ~= 2
	end)
	eq(blocked and blocked.primary.id, 1, "skips a hidden target")
	eq(WeaponLogic.plan(staff, { x = 0, z = 0 }, { x = 0, z = -1 }, { foe(1, 0, -40) }), nil, "out of range")
	-- Edge of a big enemy counts: center 25 away, radius 2 reaches inside range 24.
	assert(WeaponLogic.plan(staff, { x = 0, z = 0 }, { x = 0, z = -1 }, { foe(1, 0, -25, 4) }), "big enemy edge")
end)

test("weapon logic: area styles hit the right groups", function()
	local w = WeaponData.weapons
	local origin, facing = { x = 0, z = 0 }, { x = 0, z = -1 }
	-- Sword arc: front ones only.
	local arc = WeaponLogic.plan(w.sword, origin, facing, { foe(1, 0, -5), foe(2, 3, -5), foe(3, 0, 6), foe(4, 0, -30) })
	eq(arc and sorted(arc.hits), "1,2", "sword hits the front, not behind or far")
	-- Axe spin: everything close, any side.
	local spin = WeaponLogic.plan(w.axe, origin, facing, { foe(1, 0, -5), foe(2, 0, 6), foe(3, -6, 0), foe(4, 0, -30) })
	eq(spin and sorted(spin.hits), "1,2,3", "axe hits all around")
	-- Spear thrust / crossbow pierce: a line, capped.
	local line = { foe(1, 0, -3), foe(2, 0.5, -7), foe(3, 0, -11), foe(4, 6, -6) }
	local thrust = WeaponLogic.plan(w.spear, origin, facing, line)
	eq(thrust and sorted(thrust.hits), "1,2,3", "spear goes through the line only")
	local many = {}
	for i = 1, 8 do
		table.insert(many, foe(i, 0, -3 * i))
	end
	local pierce = WeaponLogic.plan(w.crossbow, origin, facing, many)
	eq(pierce and #pierce.hits, w.crossbow.maxHits, "crossbow pierce cap")
	eq(pierce and pierce.hits[1], 1, "nearest first along the line")
	-- Hammer slam: a circle around the target.
	local slam = WeaponLogic.plan(w.hammer, origin, facing, { foe(1, 0, -10), foe(2, 4, -12), foe(3, 0, -30) })
	eq(slam and sorted(slam.hits), "1,2", "hammer hits the group at the target")
	-- Daggers: middle always hits the target, sides hit whatever is in their lane.
	local fan = WeaponLogic.plan(w.daggers, origin, facing, { foe(1, 0, -10) })
	eq(fan and #fan.hits, 1, "lone target: one dagger lands")
	local sideX = math.sin(math.rad(w.daggers.spread)) * 10
	local spread = WeaponLogic.plan(w.daggers, origin, facing, { foe(1, 0, -10), foe(2, sideX, -10), foe(3, -sideX, -10) })
	eq(spread and sorted(spread.hits), "1,2,3", "three daggers, three targets")
end)

test("progression: damage scaling, slot levels, chest slots, floating slots every 25 levels", function()
	eq(Progression.weaponDamage("staff", 0, 1), WeaponData.weapons.staff.damage, "base damage")
	eq(Progression.weaponDamage("staff", 0, 1, false, 0), WeaponData.weapons.staff.damage, "slot level 0")
	assert(Progression.weaponDamage("staff", 0, 1, false, 5) > Progression.weaponDamage("staff", 0, 1), "slot levels help")
	eq(Progression.slotMultiplier(WeaponData.maxSlotLevel + 50), Progression.slotMultiplier(WeaponData.maxSlotLevel), "slot level cap")
	eq(Progression.chestSlots(1), 1, "one chest slot at the start")
	eq(Progression.chestSlots(100), 5, "five at most")
	assert(Progression.weaponDamage("staff", 1, 1) > Progression.weaponDamage("staff", 0, 1), "power tier helps")
	assert(Progression.weaponDamage("staff", 0, 50) > Progression.weaponDamage("staff", 0, 1), "levels help")
	assert(Progression.weaponDamage("sword", 0, 20, true) < Progression.weaponDamage("sword", 0, 20), "floating hits softer")
	assert(Progression.weaponCooldown("sword", true) > Progression.weaponCooldown("sword"), "floating attacks slower")
	eq(Progression.companionSlots(24), 0)
	eq(Progression.companionSlots(25), 1)
	eq(Progression.companionSlots(74), 2)
	eq(Progression.companionSlots(100), 4)
	eq(Progression.nextMilestone(1), ChestData.slotUnlockLevels[2])
	eq(Progression.nextMilestone(61), 75)
	eq(Progression.nextMilestone(99), 100)
	eq(Progression.nextMilestone(100), 100)
end)

test("enemy levels scale health, damage and rewards; bosses keep their tuning", function()
	local gloom = Balance.enemies.Gloomling
	local one = Progression.enemyStats(gloom, 1)
	eq(one.maxHp, gloom.maxHp)
	eq(one.damageMultiplier, 1)
	local oneSpan = Progression.thresholds[2] - Progression.thresholds[1]
	eq(one.reward.xp, math.floor(oneSpan / Progression.killsPerLevel(1) + 0.5), "a level-1 level takes killsPerLevel(1) purifies")
	local five = Progression.enemyStats(gloom, 5)
	assert(five.maxHp > one.maxHp and five.damageMultiplier > 1, "tougher")
	assert(five.reward.xp > one.reward.xp and five.reward.coins > one.reward.coins, "more rewarding")
	local boss = Progression.enemyStats(Balance.enemies.Warden, 8)
	eq(boss.maxHp, Balance.enemies.Warden.maxHp, "boss hp")
	eq(boss.reward.xp, Balance.enemies.Warden.reward.xp, "boss reward")
	for _, spawn in WorldData.spawns do
		local fixed = type(spawn.level) == "number" and spawn.level >= 1
		local ranged = type(spawn.levels) == "table" and spawn.levels[1] >= 1 and spawn.levels[2] >= spawn.levels[1]
		assert(fixed or ranged, "spawn level set")
		assert(Balance.enemies[spawn.kind], "known kind " .. spawn.kind)
		assert(WorldData.areas[spawn.area], "known area " .. spawn.area)
	end
	-- Fighting same-level reference creatures, every level takes the designed number of purifies,
	-- and health keeps growing.
	local previousHp = 0
	for level = 1, Progression.MAX_LEVEL - 1 do
		local span = Progression.thresholds[level + 1] - Progression.thresholds[level]
		local stats = Progression.enemyStats(gloom, level)
		local kills = span / stats.reward.xp
		assert(math.abs(kills - Progression.killsPerLevel(level)) < 1, `level {level} needs {kills} same-level purifies`)
		assert(stats.maxHp > previousHp, "health grows every level")
		previousHp = stats.maxHp
	end
end)

test("profile weapons: only owned weapons equip, floating slots, auto picks, sanitize", function()
	local p = Profile.new()
	eq(p.equippedWeapon, "staff")
	eq(p.ownedWeapons.staff, true, "starter owned")
	eq(Profile.equipWeapon(p, 0, "bow"), false, "not owned")
	eq(Profile.equipWeapon(p, 0, "nope"), false, "unknown weapon")
	eq(Profile.equipWeapon(p, 1, "staff"), false, "no floating slot yet")
	local main, companions = Profile.loadout(p)
	eq(main, "staff")
	eq(#companions, 0)

	p.ownedWeapons.bow = true
	p.ownedWeapons.sword = true
	p.ownedWeapons.spear = true
	eq(Profile.equipWeapon(p, 0, "spear"), true)
	p.xp = Progression.thresholds[25]
	main, companions = Profile.loadout(p)
	eq(main, "spear")
	eq(#companions, 1, "one floating slot at 25")
	eq(companions[1], "sword", "auto pick: rarest owned weapon not in use")
	eq(Profile.equipWeapon(p, 2, "bow"), false, "second slot still closed")
	eq(Profile.equipWeapon(p, 1, "hammer"), false, "not owned")
	eq(Profile.equipWeapon(p, 1, "bow"), true)
	main, companions = Profile.loadout(p)
	eq(companions[1], "bow")
	eq(Profile.equipWeapon(p, 1, ""), true, "back to auto")
	main, companions = Profile.loadout(p)
	eq(companions[1], "sword")

	p.xp = Progression.thresholds[100]
	for _, weaponId in WeaponData.order do
		p.ownedWeapons[weaponId] = true
	end
	main, companions = Profile.loadout(p)
	eq(#companions, 4, "four floating slots at 100")
	local seen = { [main] = true }
	for _, weaponId in companions do
		assert(not seen[weaponId], "auto picks do not repeat while owned weapons remain: " .. weaponId)
		seen[weaponId] = true
	end
	local few = Profile.new()
	few.xp = Progression.thresholds[50]
	local _, fewCompanions = Profile.loadout(few)
	eq(#fewCompanions, 2, "slots stay usable with only the starter")
	eq(fewCompanions[1], "staff", "falls back to the main weapon")

	local bad = Profile.sanitize({
		xp = 0,
		coins = 0,
		staffUpgrade = 0,
		equippedWeapon = "hammer",
		companions = { "x", 5, "bow" },
		ownedWeapons = { bow = true, nope = true, sword = "yes" },
		slotLevels = { 3, -1, 999, "x" },
		chests = { { type = "gold", startedAt = 5 }, { type = "nope" }, "x", { type = "wood", startedAt = -3 } },
		chestSpots = { chest_glade_1 = 10, bad = "x" },
	})
	eq(bad.equippedWeapon, "staff", "unowned main weapon reset")
	eq(bad.companions[1], "", "unknown pick cleared")
	eq(bad.companions[2], "", "bad pick cleared")
	eq(bad.companions[3], "bow", "valid pick kept for later")
	eq(bad.ownedWeapons.staff and bad.ownedWeapons.bow and not bad.ownedWeapons.nope and not bad.ownedWeapons.sword, true, "owned weapons cleaned")
	eq(table.concat(bad.slotLevels, ","), "3,0," .. WeaponData.maxSlotLevel .. ",0,0", "slot levels cleaned and capped")
	eq(#bad.chests, 2, "invalid chests dropped")
	eq(bad.chests[2].startedAt, 0, "bad timer reset")
	eq(bad.chestSpots.chest_glade_1, 10)
	eq(bad.chestSpots.bad, nil)
	local missing = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0 })
	eq(missing.equippedWeapon, "staff")
	eq(missing.ownedWeapons.staff, true)
	eq(#missing.slotLevels, 5)
	eq(type(missing.chests), "table")
end)

-- Chests ----------------------------------------------------------------------------------------

local function sequence(values: { number }): () -> number
	local index = 0
	return function()
		index = index % #values + 1
		return values[index]
	end
end

test("chest data: four types from 2 to 20 minutes, strings, valid spots", function()
	eq(#ChestData.order, 4)
	eq(ChestData.chests[ChestData.order[1]].unlockSeconds, 120, "simplest chest: 2 minutes")
	eq(ChestData.chests[ChestData.order[4]].unlockSeconds, 1200, "longest chest: 20 minutes")
	local previous = 0
	for _, chestType in ChestData.order do
		local data = ChestData.chests[chestType]
		assert(data.unlockSeconds > previous, "longer chests for better types")
		previous = data.unlockSeconds
		assert(Strings.has(data.nameKey), "chest string " .. chestType)
		for rarity in data.rarityWeights do
			assert(WeaponData.rarities[rarity], "known rarity " .. rarity)
		end
	end
	eq(#ChestData.slotUnlockLevels, 5, "five chest slots at most")
	eq(ChestData.slotUnlockLevels[1], 1, "one at the start")
	for spotId, spot in WorldData.chests do
		assert(ChestData.chests[spot.type], "spot type " .. spotId)
		local p = spot.position
		local b = WorldData.bounds
		assert(p[1] > b.minX and p[1] < b.maxX and p[3] > b.minZ and p[3] < b.maxZ, "inside the map " .. spotId)
	end
end)

test("chests: pick up into free slots, spots come back after their respawn time", function()
	local p = Profile.new()
	local ok, reason = ChestLogic.collect(p, "chest_glade_1", 1000, 1)
	eq(ok, true)
	eq(#p.chests, 1)
	eq(p.chests[1].type, WorldData.chests.chest_glade_1.type)
	ok, reason = ChestLogic.collect(p, "chest_glade_2", 1000, 1)
	eq(reason, "full", "one slot at level 1")
	eq(p.chestSpots.chest_glade_2, nil, "a full inventory leaves the chest in the world")
	ok, reason = ChestLogic.collect(p, "chest_glade_1", 1001, 10)
	eq(reason, "cooldown", "taken spot is empty for a while")
	eq(ChestLogic.spotReadyAt(p, "chest_glade_1", 1001), 1000 + ChestData.chests.wood.respawnSeconds)
	ok = ChestLogic.collect(p, "chest_glade_1", 1000 + ChestData.chests.wood.respawnSeconds, 10)
	eq(ok, true, "back after respawn")
	eq(select(2, ChestLogic.collect(p, "nope", 1000, 10)), "unknown")
end)

test("chests: one unlock at a time, opening only when the timer is done", function()
	local p = Profile.new()
	p.xp = Progression.thresholds[10]
	ChestLogic.collect(p, "chest_glade_1", 0, 10)
	ChestLogic.collect(p, "chest_grove_1", 0, 10)
	eq(#p.chests, 2)
	eq(select(2, ChestLogic.open(p, 1, 100, math.random, 10)), "locked", "not started")
	eq(ChestLogic.startUnlock(p, 1, 100), true)
	eq(select(2, ChestLogic.startUnlock(p, 1, 101)), "started")
	eq(select(2, ChestLogic.startUnlock(p, 2, 101)), "busy", "only one unlocks at a time")
	eq(select(2, ChestLogic.startUnlock(p, 9, 101)), "empty")
	eq(ChestLogic.remaining(p.chests[1], 160), 60)
	eq(select(2, ChestLogic.open(p, 1, 219, math.random, 10)), "locked", "one second early")
	local reward = ChestLogic.open(p, 1, 220, sequence({ 0.5 }), 10)
	assert(reward, "opened on time")
	eq(#p.chests, 1, "chest removed")
	eq(ChestLogic.startUnlock(p, 1, 221), true, "next one may start")
	eq(select(2, ChestLogic.open(p, 1, 221, math.random, 10)), "locked")
	eq(ChestLogic.open(p, 5, 9999, math.random, 10), nil, "empty slot")
end)

test("chest rewards: coins in range, rarity weights, duplicates to coins, slot levels", function()
	local p = Profile.new()
	-- rng values: coins roll, weapon chance, rarity roll, weapon pick, then slot picks.
	local low = ChestLogic.roll("wood", sequence({ 0 }), p, 1)
	eq(low.coins, ChestData.chests.wood.coins[1], "lowest coins")
	eq(low.weapon, "staff", "weapon chance 0 < 0.25 hits; lowest rarity roll -> common; first common")
	eq(low.duplicate, true, "staff is already owned")
	eq(low.star, 1, "a repeat gives the first star instead of coins")
	eq(low.duplicateCoins, nil)
	p.weaponStars.staff = WeaponData.maxStars
	local maxed = ChestLogic.roll("wood", sequence({ 0 }), p, 1)
	eq(maxed.star, nil, "no star past the maximum")
	eq(maxed.duplicateCoins, ChestData.duplicateCoins.common, "full stars turn a repeat into coins")
	p.weaponStars.staff = nil
	local high = ChestLogic.roll("wood", sequence({ 0.999 }), p, 1)
	eq(high.coins, ChestData.chests.wood.coins[2], "highest coins")
	eq(high.weapon, nil, "no weapon when the chance roll fails")
	eq(high.slots[0], ChestData.chests.wood.slotLevels, "slot levels go to the main slot at low level")
	local mystic = ChestLogic.roll("mystic", sequence({ 0.99, 0.5, 0.99, 0.99 }), p, 1)
	eq(WeaponData.weapons[mystic.weapon].rarity, "legendary", "top of the rarity roll")
	-- Over many opens every weapon appears and rarities follow the chest.
	local seen = {}
	local legendaryFromWood = false
	math.randomseed(7)
	for _ = 1, 2000 do
		for _, chestType in ChestData.order do
			local reward = ChestLogic.roll(chestType, math.random, p, 100)
			if reward.weapon then
				seen[reward.weapon] = true
				if chestType == "wood" and WeaponData.weapons[reward.weapon].rarity == "legendary" then
					legendaryFromWood = true
				end
			end
			local c = ChestData.chests[chestType].coins
			assert(reward.coins >= c[1] and reward.coins <= c[2], "coins in range")
			local total = 0
			for slot, gained in reward.slots do
				assert(slot >= 0 and slot <= 4, "valid slot")
				total += gained
			end
			eq(total, ChestData.chests[chestType].slotLevels, "all slot levels handed out")
		end
	end
	for _, weaponId in WeaponData.order do
		assert(seen[weaponId], "chests can give " .. weaponId)
	end
	eq(legendaryFromWood, false, "wooden chests never give legendary weapons")
end)

test("weapon stars: repeat finds add stars, damage grows per star, profiles are cleaned", function()
	local p = Profile.new()
	table.insert(p.chests, { type = "wood", startedAt = 1 })
	local reward = ChestLogic.open(p, 1, 1 + ChestData.chests.wood.unlockSeconds, sequence({ 0 }), 1) :: any
	eq(reward.star, 1)
	eq(p.weaponStars.staff, 1, "star stored")
	local coins = p.coins
	eq(coins, reward.coins, "a star is not paid in coins as well")
	eq(Progression.starMultiplier(0), 1)
	eq(Progression.starMultiplier(WeaponData.maxStars + 9), Progression.starMultiplier(WeaponData.maxStars), "star cap")
	assert(Progression.weaponDamage("sword", 0, 20, false, 0, 3) > Progression.weaponDamage("sword", 0, 20, false, 0, 0), "stars help")
	local cleaned = Profile.sanitize({
		xp = 0, coins = 0, staffUpgrade = 0,
		weaponStars = { bow = 3, sword = 99, nope = 2, axe = -1, hammer = "x" },
	})
	eq(cleaned.weaponStars.bow, 3)
	eq(cleaned.weaponStars.sword, WeaponData.maxStars, "capped")
	eq(cleaned.weaponStars.nope, nil, "unknown weapon dropped")
	eq(cleaned.weaponStars.axe, nil)
	eq(cleaned.weaponStars.hammer, nil)
	eq(next(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0 }).weaponStars), nil, "missing stars")
end)

test("opening applies rewards: coins, new weapon, capped slot levels", function()
	local p = Profile.new()
	p.slotLevels[1] = WeaponData.maxSlotLevel - 1
	table.insert(p.chests, { type = "mystic", startedAt = 1 })
	local coins = p.coins
	local reward = ChestLogic.open(p, 1, 1 + ChestData.chests.mystic.unlockSeconds, sequence({ 0, 0, 0.99, 0.99 }), 1) :: any
	eq(reward.weapon, "hammer")
	eq(p.ownedWeapons.hammer, true, "weapon owned")
	eq(p.coins, coins + reward.coins, "coins added")
	eq(p.slotLevels[1], WeaponData.maxSlotLevel, "slot level capped")
	eq(reward.slots[0], 1, "only one level fit before the cap")
	eq(Profile.equipWeapon(p, 0, "hammer"), true, "new weapon can be equipped")
end)

-- Crystals, forge stats and skill cards ---------------------------------------------------------

test("pouch: crystals up to capacity, lantern turns them into coins one to one", function()
	local p = Profile.new()
	local added, lost = Profile.addCrystals(p, 50, 60)
	eq(added, 50)
	eq(lost, 0)
	added, lost = Profile.addCrystals(p, 25, 60)
	eq(added, 10, "only what fits")
	eq(lost, 15)
	eq(p.crystals, 60)
	added = Profile.addCrystals(p, 5, 60)
	eq(added, 0, "a full pouch takes nothing")
	eq(Profile.depositCrystals(p), 60)
	eq(p.crystals, 0)
	eq(p.coins, 60)
	eq(Profile.depositCrystals(p), 0, "empty pouch gives nothing")
end)

test("stats: upgrades and skill cards change the right numbers, within their caps", function()
	local base = Stats.of({ xp = 0, staffUpgrade = 0 })
	eq(base.damageMultiplier, 1)
	eq(base.cooldownMultiplier, 1)
	eq(base.critChance, 0)
	eq(base.maxHealth, Progression.maxHealth(1))
	eq(base.pouchCapacity, Balance.pouch.baseCapacity)
	eq(base.regen, 0)
	local strong = Stats.of({
		xp = 0,
		staffUpgrade = 0,
		upgrades = { pouch = 2, health = 5, regen = 3, crit = 4 },
		skills = { swift = 2, sharp = 1, reach = 1, lucky = 1, tough = 1, magnet = 1, feet = 1, wave = 2, wisdom = 1, echo = 1 },
		equippedCharm = "swift",
	})
	assert(strong.damageMultiplier > 1 and strong.cooldownMultiplier < 1 and strong.rangeMultiplier > 1, "combat skills")
	assert(math.abs(strong.critChance - (4 * Balance.upgrades.crit.perLevel + SkillData.skills.lucky.perRank)) < 1e-9, "crit adds up")
	assert(strong.maxHealth > base.maxHealth, "health")
	eq(strong.pouchCapacity, Balance.pouch.baseCapacity + 2 * Balance.upgrades.pouch.perLevel)
	eq(strong.regen, 3 * Balance.upgrades.regen.perLevel)
	assert(strong.walkSpeed > Progression.walkSpeed("swift"), "quick feet on top of the charm")
	assert(strong.crystalMultiplier > 1 and strong.xpMultiplier > 1 and strong.companionMultiplier > 1, "economy skills")
	eq(strong.waveRank, 2)
	local wave = Progression.waveStats(0, 3, nil, strong.waveRank)
	local plain = Progression.waveStats(0, 3, nil)
	assert(wave.cooldown < plain.cooldown and wave.radius > plain.radius, "wave skill")
	-- Tampered numbers are clamped to the caps.
	local capped = Stats.of({ xp = 0, staffUpgrade = 0, skills = { swift = 999 }, upgrades = { crit = 999 } })
	eq(capped.cooldownMultiplier, 1 - SkillData.skills.swift.maxRank * SkillData.skills.swift.perRank)
	eq(capped.critChance, Balance.upgrades.crit.maxLevel * Balance.upgrades.crit.perLevel)
	assert(capped.cooldownMultiplier > 0.5 and capped.critChance < 0.6, "caps stay sane")
	-- Weapon power: the multiplier grows with every level.
	assert(Progression.tierMultiplier(10) > Progression.tierMultiplier(1), "power levels")
	eq(#Progression.powerColor(0), 3)
	eq(#Progression.powerColor(Balance.upgrades.power.maxLevel), 3)
end)

test("skill cards: data, distinct offers, only offered picks, coin card when all maxed", function()
	for _, skillId in SkillData.order do
		local skill = SkillData.skills[skillId]
		assert(skill, "skill " .. skillId)
		assert(Strings.has(skill.nameKey) and Strings.has(skill.descKey), "skill strings " .. skillId)
	end
	local p = Profile.new()
	local rng = sequence({ 0.1, 0.5, 0.9, 0.3 })
	SkillLogic.grantPicks(p, 0, rng)
	eq(#p.skillOffer, 0, "no level, no offer")
	SkillLogic.grantPicks(p, 2, rng)
	eq(p.pendingPicks, 2)
	eq(#p.skillOffer, SkillData.offerCount)
	local seen = {}
	for _, skillId in p.skillOffer do
		assert(not seen[skillId], "distinct cards")
		seen[skillId] = true
	end
	local offered = p.skillOffer[1]
	local notOffered = nil
	for _, skillId in SkillData.order do
		if not seen[skillId] then
			notOffered = skillId
			break
		end
	end
	eq(SkillLogic.pick(p, notOffered, rng), false, "not offered")
	eq(SkillLogic.pick(p, "coins", rng), false, "coin card only when offered")
	eq(SkillLogic.pick(p, offered, rng), true)
	eq(p.skills[offered], 1)
	eq(p.pendingPicks, 1)
	eq(#p.skillOffer, SkillData.offerCount, "a new offer for the remaining pick")
	eq(SkillLogic.pick(p, p.skillOffer[1], rng), true)
	eq(p.pendingPicks, 0)
	eq(#p.skillOffer, 0, "no offer without picks")
	eq(SkillLogic.pick(p, offered, rng), false, "no picks left")
	-- Maxed skills never come back; with only one left the offer shrinks.
	for _, skillId in SkillData.order do
		p.skills[skillId] = SkillData.skills[skillId].maxRank
	end
	p.skills.echo -= 1
	SkillLogic.grantPicks(p, 1, rng)
	eq(table.concat(p.skillOffer, ","), "echo", "only the unfinished skill")
	eq(SkillLogic.pick(p, "echo", rng), true)
	SkillLogic.grantPicks(p, 1, rng)
	eq(table.concat(p.skillOffer, ","), "coins", "everything maxed: coin card")
	local coins = p.coins
	local ok, given = SkillLogic.pick(p, "coins", rng)
	eq(ok, true)
	eq(given, SkillData.fallbackCoins)
	eq(p.coins, coins + SkillData.fallbackCoins)
	-- Enough ranks for a long adventure, fewer than 99 level-ups.
	local total = 0
	for _, skill in SkillData.skills do
		total += skill.maxRank
	end
	assert(total >= 30 and total < Progression.MAX_LEVEL - 1, "rank budget " .. total)
end)

test("sanitize: upgrades, crystals, skills and offers are cleaned", function()
	local p = Profile.sanitize({
		xp = 0,
		coins = 0,
		staffUpgrade = 999,
		upgrades = { pouch = 3, crit = 999, power = 5, nope = 2, health = -1 },
		crystals = -5,
		skills = { swift = 99, nope = 1, sharp = "x" },
		skillOffer = { "swift", "nope", "coins", "sharp", "reach" },
		pendingPicks = 2.5,
	})
	eq(p.staffUpgrade, Balance.upgrades.power.maxLevel, "power capped")
	eq(p.upgrades.pouch, 3)
	eq(p.upgrades.crit, Balance.upgrades.crit.maxLevel, "capped")
	eq(p.upgrades.power, nil, "power lives in staffUpgrade")
	eq(p.upgrades.nope, nil)
	eq(p.upgrades.health, nil)
	eq(p.crystals, 0)
	eq(p.skills.swift, SkillData.skills.swift.maxRank)
	eq(p.skills.nope, nil)
	eq(p.skills.sharp, nil)
	eq(table.concat(p.skillOffer, ","), "swift,coins,sharp", "unknown cards dropped, at most three")
	eq(p.pendingPicks, 0)
end)

-- East lands and Legendary Shadows ------------------------------------------------------------

test("creature zones cover every level from 1 to 100 without big gaps", function()
	local covered = {}
	for _, area in WorldData.areas do
		if area.levels then
			for level = area.levels[1], area.levels[2] do
				covered[level] = true
			end
		end
	end
	local gap = 0
	for level = 1, Progression.MAX_LEVEL do
		gap = if covered[level] then 0 else gap + 1
		assert(gap <= 2, "no creatures near level " .. level)
	end
	-- Spawn level ranges stay inside their zone's range.
	for _, spawn in WorldData.spawns do
		local area = WorldData.areas[spawn.area]
		if spawn.levels and area.levels then
			assert(spawn.levels[1] >= area.levels[1] and spawn.levels[2] <= area.levels[2], "pack fits its zone: " .. spawn.kind)
		end
		assert(spawn.position[1] >= WorldData.bounds.minX and spawn.position[1] <= WorldData.bounds.maxX, "inside the map")
	end
end)

test("legendary shadows: data, level-scaled fights, first win recorded once", function()
	local previousLevel = 0
	for index, kind in Balance.legends do
		local stats = Balance.enemies[kind]
		assert(stats and stats.isBoss, "legend is a boss: " .. kind)
		assert(Strings.has(stats.nameKey), "legend name " .. kind)
		local level = nil
		for _, spawn in WorldData.spawns do
			if spawn.kind == kind then
				level = spawn.level
			end
		end
		assert(level and level > previousLevel, "legends get stronger in order: " .. kind)
		previousLevel = level :: number
		if index > 1 then
			assert(stats.scales, "east-land legends scale with level")
			local scaled = Progression.enemyStats(stats, level :: number)
			assert(scaled.maxHp > stats.maxHp and scaled.damageMultiplier > 1, "scaled " .. kind)
		end
	end
	local p = Profile.new()
	eq(Profile.recordLegend(p, "Warden"), true)
	eq(Profile.recordLegend(p, "Warden"), false, "only the first win counts")
	eq(Profile.recordLegend(p, "Gloomling"), false, "not a legend")
	eq(ChestLogic.give(p, "mystic", 1), true, "legend chest into a free slot")
	eq(ChestLogic.give(p, "mystic", 1), false, "slots full")
	local clean = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, legends = { Warden = true, Gloomling = true, BogMother = "x" } })
	eq(clean.legends.Warden, true)
	eq(clean.legends.Gloomling, nil)
	eq(clean.legends.BogMother, nil)
	-- Chapter 2 quests wait for the right levels, in order.
	local gates = {}
	for _, questId in { "bog_mother", "frost_titan", "shadow_king" } do
		local quest = QuestData.quests[questId]
		assert(quest and quest.minLevel, "chapter 2 quest " .. questId)
		table.insert(gates, quest.minLevel)
		assert(Balance.enemies[quest.objective.enemyType].isBoss, "boss objective " .. questId)
	end
	assert(gates[1] < gates[2] and gates[2] < gates[3] and gates[3] <= Progression.MAX_LEVEL, "rising level gates")
end)

test("short numbers: 950, 12.3K, 150K, 4.5M, 2.1B", function()
	local Format = require("../src/shared/Format")
	eq(Format.short(0), "0")
	eq(Format.short(950), "950")
	eq(Format.short(999.7), "999")
	eq(Format.short(1000), "1K")
	eq(Format.short(12345), "12.3K")
	eq(Format.short(99999), "99.9K", "rounds down, never up to the next unit")
	eq(Format.short(150000), "150K")
	eq(Format.short(4500000), "4.5M")
	eq(Format.short(2100000000), "2.1B")
	eq(Format.short(-2500), "-2.5K")
end)

test("elites: tougher and more rewarding, rare", function()
	local scaled = Progression.enemyStats(Balance.enemies.Gloomling, 10)
	local elite = Progression.eliteStats(scaled)
	eq(elite.maxHp, math.floor(scaled.maxHp * Balance.elite.hpMultiplier + 0.5))
	assert(elite.damageMultiplier > scaled.damageMultiplier, "hits harder")
	assert(elite.reward.xp > scaled.reward.xp and elite.reward.coins > scaled.reward.coins, "pays more")
	assert(Balance.elite.chance > 0 and Balance.elite.chance <= 0.1, "rare")
	for _, chestType in Balance.elite.chests do
		assert(ChestData.chests[chestType], "elite chest " .. chestType)
	end
	assert(Strings.has("enemy_label_elite") and Strings.has("notice_elite_chest"), "elite strings")
end)

test("shadow rifts: every creature zone qualifies, waves grow, fallback coins scale", function()
	local RiftLogic = require("../src/server/RiftLogic")
	local zones = RiftLogic.zones()
	assert(#zones >= 7, "rifts in every creature zone")
	for _, areaId in zones do
		local kinds = RiftLogic.kindsFor(areaId)
		assert(#kinds > 0, "creatures for " .. areaId)
		for _, kind in kinds do
			assert(not Balance.enemies[kind].isBoss, "no bosses from rifts")
		end
	end
	assert(RiftLogic.waveSize(2, 1) > RiftLogic.waveSize(1, 1), "waves grow")
	assert(RiftLogic.waveSize(1, 3) > RiftLogic.waveSize(1, 1), "more players, more creatures")
	assert(RiftLogic.fallbackCoins("keep") > RiftLogic.fallbackCoins("glade"), "deeper zones pay more")
	assert(ChestData.chests[Balance.rifts.chest], "rift chest exists")
	for _, key in { "notice_rift_open", "notice_rift_done", "notice_rift_done_coins", "notice_rift_failed", "banner_rift", "banner_rift_wave" } do
		assert(Strings.has(key), key)
	end
end)

test("adventure log: data, counters, claims in order, chest or coins, never early", function()
	local AchievementData = require("../src/shared/AchievementData")
	local AchievementLogic = require("../src/server/AchievementLogic")
	for _, id in AchievementData.order do
		local def = AchievementData.achievements[id]
		assert(def and Strings.has(def.nameKey) and Strings.has(def.descKey), "achievement " .. id)
		local previous = 0
		for _, tier in def.tiers do
			assert(tier.goal > previous, id .. " goals rise")
			previous = tier.goal
			assert(tier.coins > 0, id .. " pays coins")
			assert(tier.chest == nil or ChestData.chests[tier.chest], id .. " chest type")
		end
	end
	local p = Profile.new()
	eq(AchievementLogic.claimable(p, "friends"), false)
	eq(AchievementLogic.claim(p, "friends", 1), nil, "not before the goal")
	AchievementLogic.count(p, "purifies", 49)
	eq(AchievementLogic.claimable(p, "friends"), false)
	AchievementLogic.count(p, "purifies")
	eq(AchievementLogic.readyCount(p), 1)
	local coins = p.coins
	local claim = AchievementLogic.claim(p, "friends", 1) :: any
	eq(claim.tier, 1)
	eq(p.coins, coins + AchievementData.achievements.friends.tiers[1].coins)
	eq(AchievementLogic.claim(p, "friends", 1), nil, "same tier only once")
	-- Tier 2 gives a chest when a slot is free, coins when not.
	AchievementLogic.count(p, "purifies", 1000)
	table.insert(p.chests, { type = "wood", startedAt = 0 })
	coins = p.coins
	claim = AchievementLogic.claim(p, "friends", 1) :: any
	eq(claim.chest, nil, "slots full")
	eq(claim.chestCoins, AchievementData.chestCoins.wood)
	eq(p.coins, coins + AchievementData.achievements.friends.tiers[2].coins + AchievementData.chestCoins.wood)
	p.chests = {}
	claim = AchievementLogic.claim(p, "friends", 1) :: any
	eq(claim.chest, "silver", "chest into the free slot")
	-- Derived progress.
	p.xp = Progression.thresholds[25]
	eq(AchievementLogic.progress(p, "rising"), 25)
	p.ownedWeapons.bow = true
	eq(AchievementLogic.progress(p, "arsenal"), 2)
	eq(AchievementLogic.claim(Profile.new(), "nope", 1), nil, "unknown id")
	local clean = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, counters = { purifies = 5, bad = -1 }, achievements = { friends = 99, nope = 1 } })
	eq(clean.counters.purifies, 5)
	eq(clean.counters.bad, nil)
	eq(clean.achievements.friends, #AchievementData.achievements.friends.tiers, "capped")
	eq(clean.achievements.nope, nil)
end)

test("team bonus: +10% per nearby ally, capped", function()
	eq(Progression.coopMultiplier(0), 1)
	eq(Progression.coopMultiplier(1), 1 + Balance.coop.bonusPerAlly)
	eq(Progression.coopMultiplier(10), 1 + Balance.coop.maxBonus)
	assert(Strings.has("hud_team_bonus"), "string")
end)

-- Store, Light Pass and costumes ---------------------------------------------------------------

local CosmeticData = require("../src/shared/CosmeticData")
local PassData = require("../src/shared/PassData")
local StoreData = require("../src/shared/StoreData")
local CosmeticLogic = require("../src/server/CosmeticLogic")
local PassLogic = require("../src/server/PassLogic")
local StoreLogic = require("../src/server/StoreLogic")

test("store data: fixed contents only, valid references, strings, no ids invented", function()
	for _, key in StoreData.order do
		local product = StoreData.products[key]
		assert(product, "product " .. key)
		assert(Strings.has(product.nameKey), "product name " .. key)
		eq(product.productId, 0, key .. " id is set on the Creator Dashboard, not invented here")
		assert(product.chest == nil, key .. " never sells a random chest")
		assert(product.costume == nil or CosmeticData.costumes[product.costume], key .. " costume")
		assert(product.weapon == nil or WeaponData.weapons[product.weapon], key .. " weapon")
	end
	for _, id in CosmeticData.order do
		local costume = CosmeticData.costumes[id]
		assert(Strings.has(costume.nameKey), "costume name " .. id)
		assert(table.find(CosmeticData.slots, costume.slot), "slot " .. id)
		local source = costume.source
		assert(source.coins or source.pass or source.robux, "costume source " .. id)
		if source.robux then
			eq(StoreData.products[source.robux].costume, id, "robux costume product " .. id)
		end
		if source.pass then
			eq(PassData.rewards[source.pass][source.track].costume, id, "pass costume " .. id)
		end
	end
	for tier = 1, PassData.tiers do
		for _, track in { "free", "premium" } do
			local reward = PassData.rewards[tier][track]
			assert(reward.costume or (reward.coinMinutes and reward.coinMinutes > 0), "pass reward " .. tier .. track)
			assert(not reward.chest, "no random rewards in the pass")
		end
	end
end)

test("costumes: buy with coins, wear one per slot, remove", function()
	local p = Profile.new()
	eq(select(2, CosmeticLogic.buy(p, "lantern_hat")), "coins")
	p.coins = 10 ^ 6
	eq(CosmeticLogic.buy(p, "lantern_hat"), true)
	eq(p.coins, 10 ^ 6 - CosmeticData.costumes.lantern_hat.source.coins)
	eq(select(2, CosmeticLogic.buy(p, "lantern_hat")), "owned")
	eq(select(2, CosmeticLogic.buy(p, "star_crown")), "notForCoins", "pass costume")
	eq(select(2, CosmeticLogic.buy(p, "golden_aura")), "notForCoins", "robux costume")
	eq(CosmeticLogic.equip(p, "star_crown"), false, "not owned")
	eq(CosmeticLogic.equip(p, "lantern_hat"), true)
	eq(p.equippedCosmetics.hat, "lantern_hat")
	CosmeticLogic.buy(p, "frost_hood")
	CosmeticLogic.equip(p, "frost_hood")
	eq(p.equippedCosmetics.hat, "frost_hood", "one hat at a time")
	eq(CosmeticLogic.equip(p, "", "hat"), true)
	eq(p.equippedCosmetics.hat, nil)
	eq(CosmeticLogic.equip(p, "", "nope"), false)
	local clean = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, ownedCosmetics = { lantern_hat = true, nope = true }, equippedCosmetics = { hat = "lantern_hat", back = "lantern_hat", aura = "golden_aura" } })
	eq(clean.equippedCosmetics.hat, "lantern_hat")
	eq(clean.equippedCosmetics.back, nil, "wrong slot")
	eq(clean.equippedCosmetics.aura, nil, "not owned")
	eq(clean.ownedCosmetics.nope, nil)
end)

test("light pass: xp to tiers, free and premium claims, costumes, season reset", function()
	local p = Profile.new()
	eq(PassLogic.tier(p), 0)
	eq(PassLogic.addXp(p, "rift", 5), 1, "1000 pass xp = 1 tier")
	eq(PassLogic.claimable(p, 1, "free"), true)
	eq(PassLogic.claimable(p, 2, "free"), false, "not reached")
	eq(PassLogic.claimable(p, 1, "premium"), false, "premium needs the pass")
	local coins = p.coins
	local paid = PassLogic.claim(p, 1, "free", 10) :: any
	eq(paid.coins, Progression.incomeCoins(10, PassData.rewards[1].free.coinMinutes))
	eq(p.coins, coins + paid.coins)
	eq(PassLogic.claim(p, 1, "free", 10), nil, "once")
	-- The free costume at its tier.
	PassLogic.addXp(p, "rift", 5 * 5)
	local leaf = CosmeticData.costumes.leaf_crown.source.pass
	local costume = PassLogic.claim(p, leaf, "free", 10) :: any
	eq(costume.costume, "leaf_crown")
	eq(p.ownedCosmetics.leaf_crown, true)
	-- Premium: everything reached so far becomes claimable.
	p.pass.premium = true
	local all = PassLogic.claimAll(p, 10)
	eq(#all, PassLogic.tier(p) * 2 - 2, "the rest of both tracks")
	eq(#PassLogic.claimAll(p, 10), 0, "nothing twice")
	-- Capped at the last tier.
	PassLogic.addXp(p, "rift", 10 ^ 6)
	eq(PassLogic.tier(p), PassData.tiers)
	eq(PassLogic.claimable(p, PassData.tiers + 1, "free"), false)
	-- A new season starts over.
	p.pass.season = PassData.season - 1
	PassLogic.ensureSeason(p)
	eq(p.pass.xp, 0)
	eq(p.pass.premium, false, "premium is per season")
	-- Owned costume from the pass becomes coins.
	local q = Profile.new()
	q.ownedCosmetics.leaf_crown = true
	PassLogic.addXp(q, "rift", 10 ^ 4)
	local dup = PassLogic.claim(q, leaf, "free", 10) :: any
	eq(dup.costume, nil)
	assert(dup.coins > 0, "duplicate costume turns into coins")
	for _, key in { "pass_title", "pass_tier", "notice_pass_tier", "notice_pass_coins" } do
		assert(Strings.has(key), key)
	end
end)

test("store: coin packs scale with level, receipts once, starter once, boost stacks to a cap", function()
	assert(StoreLogic.coinsFor("coins_small", 50) > StoreLogic.coinsFor("coins_small", 1), "packs keep their value at every level")
	eq(StoreLogic.coinsFor("coins_small", 10), Progression.incomeCoins(10, StoreData.products.coins_small.coinMinutes))
	assert(StoreLogic.coinsFor("coins_large", 10) / StoreData.products.coins_large.coinMinutes > StoreLogic.coinsFor("coins_small", 10) / StoreData.products.coins_small.coinMinutes, "bigger packs give a bonus")
	local p = Profile.new()
	eq(StoreLogic.remember(p, "a"), true)
	eq(StoreLogic.remember(p, "a"), false, "a receipt counts once")
	for index = 1, StoreData.purchaseIdCache + 5 do
		StoreLogic.remember(p, "id" .. index)
	end
	eq(#p.purchaseIds, StoreData.purchaseIdCache, "bounded cache")
	-- Starter pack: sword, cape and coins; once.
	local coins = p.coins
	local granted = StoreLogic.grant(p, "starter", 5, 1000) :: any
	eq(granted.weapon, "sword")
	eq(granted.costume, "explorer_cape")
	eq(p.ownedWeapons.sword, true)
	eq(p.coins, coins + granted.coins)
	eq(StoreLogic.available(p, "starter", 1000), false, "once")
	eq(StoreLogic.available(p, "crystal_wings", 1000), true)
	StoreLogic.grant(p, "crystal_wings", 5, 1000)
	eq(StoreLogic.available(p, "crystal_wings", 1000), false, "owned costume not sold twice")
	local again = StoreLogic.grant(p, "crystal_wings", 5, 1000) :: any
	assert(again.coins > 0, "a duplicate receipt still gives something (coins)")
	-- XP boost stacks, capped.
	StoreLogic.grant(p, "xp_boost", 5, 1000)
	eq(p.boostUntil, 1000 + 30 * 60)
	eq(StoreLogic.boostActive(p, 1000 + 30 * 60 - 1), true)
	eq(StoreLogic.boostActive(p, 1000 + 30 * 60), false)
	for _ = 1, 20 do
		StoreLogic.grant(p, "xp_boost", 5, 1000)
	end
	eq(p.boostUntil, 1000 + StoreData.maxBoostMinutes * 60, "capped")
	eq(StoreLogic.available(p, "xp_boost", 1000), false, "no buying past the cap")
	-- Premium pass.
	eq(StoreLogic.available(p, "pass_premium", 1000), true)
	StoreLogic.grant(p, "pass_premium", 5, 1000)
	eq(p.pass.premium, true)
	eq(StoreLogic.available(p, "pass_premium", 1000), false)
	eq(StoreLogic.grant(p, "nope", 5, 1000), nil)
	-- Sanitize keeps store state sane.
	local clean = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, purchaseIds = { "x", 5 }, oneTime = { starter = true, nope = true }, boostUntil = -3 })
	eq(#clean.purchaseIds, 1)
	eq(clean.oneTime.starter, true)
	eq(clean.oneTime.nope, nil)
	eq(clean.boostUntil, 0)
end)

test("store balance: a coin pack is worth minutes of play, never a whole game", function()
	-- The biggest pack at any level buys only a handful of weapon power levels at that point.
	-- Typical weapon power at these levels, from the tests/balance model.
	local typicalPower = { [5] = 5, [25] = 17, [50] = 26, [75] = 33, [99] = 37 }
	for level, power in typicalPower do
		local coins = StoreLogic.coinsFor("coins_large", level)
		local bought = 0
		while coins > 0 and power < Balance.upgrades.power.maxLevel do
			local cost = Progression.upgradeCost("power", power) :: number
			if cost > coins then
				break
			end
			coins -= cost
			power += 1
			bought += 1
		end
		-- Early power levels are cheap, so a small head start is fine; later packs stay modest.
		local limit = if level < 25 then 20 else 10
		assert(bought <= limit, `level {level}: the largest pack buys {bought} power levels`)
	end
end)

test("bounty board: fills three different bounties by level, progress counts from the day taken", function()
	local BountyLogic = require("../src/server/BountyLogic")
	local BountyData = require("../src/shared/BountyData")
	local p = Profile.new()
	BountyLogic.fill(p, 1, math.random)
	eq(#p.bounties, BountyData.slots, "board is full")
	local kinds = {}
	for _, bounty in p.bounties do
		assert(not kinds[bounty.kind], "kinds never repeat on one board")
		kinds[bounty.kind] = true
		assert(BountyData.kinds[bounty.kind].minLevel <= 1, "only kinds open at this level")
	end
	eq(kinds.legend, nil, "no legend bounty at level 1")
	-- Only what happens after taking a bounty counts.
	p.counters.purifies = 100
	p.bounties = { { kind = "purify", goal = 40, base = 100 } }
	eq(BountyLogic.progress(p, p.bounties[1]), 0, "earlier purifies do not count")
	p.counters.purifies = 120
	eq(BountyLogic.progress(p, p.bounties[1]), 20)
	eq(BountyLogic.complete(p, p.bounties[1]), false)
	eq(BountyLogic.encode(p), "purify:40:20")
	p.counters.purifies = 999
	eq(BountyLogic.progress(p, p.bounties[1]), 40, "progress is capped at the goal")
	eq(BountyLogic.readyCount(p), 1)
end)

test("bounty board: claiming pays income minutes once and offers a new bounty", function()
	local BountyLogic = require("../src/server/BountyLogic")
	local BountyData = require("../src/shared/BountyData")
	local p = Profile.new()
	p.counters.chests = 0
	p.bounties = { { kind = "chest", goal = 2, base = 0 }, { kind = "purify", goal = 40, base = 0 } }
	eq(BountyLogic.claim(p, 1, 10, math.random), nil, "not finished yet")
	eq(BountyLogic.claim(p, 5, 10, math.random), nil, "no such slot")
	p.counters.chests = 2
	local coins = p.coins
	local paid = BountyLogic.claim(p, 1, 10, math.random) :: any
	eq(paid.coins, Progression.incomeCoins(10, BountyData.kinds.chest.minutes), "coins are minutes of own income")
	eq(p.coins, coins + paid.coins)
	eq(#p.bounties, BountyData.slots, "the claimed bounty left and the board was topped up")
	for _, bounty in p.bounties do
		assert(bounty.kind ~= "chest" or bounty.base == 2, "a new chest bounty starts from the current count")
	end
	local again = BountyLogic.claim(p, 1, 10, math.random)
	assert(again == nil or again.kind ~= "chest", "the same progress cannot be claimed twice")
	-- Legends only join the board once the player can reach them.
	p.bounties = {}
	local sawLegend = false
	for _ = 1, 50 do
		p.bounties = {}
		BountyLogic.fill(p, BountyData.kinds.legend.minLevel, math.random)
		for _, bounty in p.bounties do
			sawLegend = sawLegend or bounty.kind == "legend"
		end
	end
	assert(sawLegend, "legend bounties appear from their level")
end)

test("bounty board: rewards stay small, saved bounties are cleaned", function()
	local BountyData = require("../src/shared/BountyData")
	for kind, def in BountyData.kinds do
		assert(def.goal >= 1 and def.minutes > 0, kind .. " reward and goal")
		-- Doing the work already earns income; the bounty is a bonus well under that (max 60%).
		assert(def.minutes <= def.effort * 0.6, kind .. " pays " .. def.minutes .. " minutes for " .. def.effort .. " minutes of play")
	end
	assert(BountyData.passAction and require("../src/shared/PassData").xp[BountyData.passAction], "bounties give Pass XP")
	local cleaned = Profile.sanitize({
		xp = 0, coins = 0, staffUpgrade = 0,
		bounties = {
			{ kind = "purify", goal = 9999, base = 5 },
			{ kind = "purify", goal = 40, base = 0 },
			{ kind = "nope", goal = 1, base = 0 },
			{ kind = "elite", goal = -1, base = 0 },
			{ kind = "rift", goal = 1, base = "x" },
			"junk",
			{ kind = "chest", goal = 2, base = 3 },
			{ kind = "legend", goal = 1, base = 0 },
			{ kind = "elite", goal = 3, base = 0 },
		},
	})
	eq(#cleaned.bounties, 3, "at most three bounties")
	eq(cleaned.bounties[1].goal, BountyData.kinds.purify.goal, "goal capped to the current one")
	eq(cleaned.bounties[2].kind, "chest", "duplicates and broken entries dropped")
	eq(#Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0 }).bounties, 0, "missing board")
end)

test("emotes: known ids only, cooldown, only nearby players see it, every text exists", function()
	local EmoteLogic = require("../src/server/EmoteLogic")
	local EmoteData = require("../src/shared/EmoteData")
	eq(#EmoteData.order, 6)
	for _, id in EmoteData.order do
		local emote = EmoteData.emotes[id]
		assert(emote and Strings.has(emote.nameKey) and Strings.has(emote.bubbleKey), id .. " texts")
		assert(emote.action == nil or emote.action == "jump" or emote.action == "sit", id .. " action")
		eq(EmoteLogic.valid(id), true)
	end
	for _, bad in { "", "nope", 5, {}, false } do
		eq(EmoteLogic.valid(bad), false, "unknown emote rejected")
	end
	eq(EmoteLogic.ready(nil, 10), true, "first emote")
	eq(EmoteLogic.ready(10, 10 + EmoteData.cooldown - 0.1), false, "cooldown")
	eq(EmoteLogic.ready(10, 10 + EmoteData.cooldown), true)
	local near = { position = { x = EmoteData.range, z = 0 } }
	local far = { position = { x = EmoteData.range + 1, z = 0 } }
	local seen = EmoteLogic.audience({ x = 0, z = 0 }, { near, far })
	eq(#seen, 1, "only nearby players")
	eq(seen[1], near)
end)

test("shadow tower: floor levels, scaling past level 100, counts, kinds, chests, entry rules", function()
	local TowerLogic = require("../src/server/TowerLogic")
	local tower = Balance.tower
	local level, extra = TowerLogic.floorLevel(10, 1)
	eq(level, 10 + tower.levelOffset + 1, "floor 1 is close to the player's level")
	eq(extra, 0)
	local capped, over = TowerLogic.floorLevel(100, 5)
	eq(capped, Progression.MAX_LEVEL, "creatures never pass level 100")
	eq(over, 100 + tower.levelOffset + 5 - Progression.MAX_LEVEL, "the rest becomes extra strength")
	eq(TowerLogic.floorLevel(1, 1), 1, "never below level 1")
	local hp0, damage0 = TowerLogic.scale(0)
	eq(hp0, 1)
	eq(damage0, 1)
	local hp10, damage10 = TowerLogic.scale(10)
	assert(hp10 > 1 and damage10 > 1 and hp10 > damage10, "health grows faster than damage")
	assert(TowerLogic.count(1, 1) >= tower.baseCount, "a floor is never empty")
	eq(TowerLogic.count(1000, 1), tower.maxCount, "capped for one player")
	eq(TowerLogic.count(1, 3), TowerLogic.count(1, 1) + 2 * tower.extraPerPlayer, "more players, more creatures")
	eq(TowerLogic.eliteCount(1), 0)
	eq(TowerLogic.eliteCount(tower.eliteEvery), 1, "an elite every few floors")
	assert(TowerLogic.eliteCount(500) <= 3, "elite cap")
	for _, testLevel in { 1, 7, 12, 40, 60, 100 } do
		local kinds = TowerLogic.kindsFor(testLevel)
		assert(#kinds > 0, "creatures for level " .. testLevel)
		for _, kind in kinds do
			assert(Balance.enemies[kind] and not Balance.enemies[kind].isBoss, kind .. " is a regular creature")
		end
	end
	eq(contains(TowerLogic.kindsFor(1), "Gloomling"), true, "early floors send early creatures")
	eq(contains(TowerLogic.kindsFor(100), "Gloomling"), false, "late floors do not")
	eq(TowerLogic.chestFor(4), nil)
	eq(TowerLogic.chestFor(5), "silver")
	eq(TowerLogic.chestFor(10), "gold")
	eq(TowerLogic.chestFor(30), "mystic")
	eq(TowerLogic.chestFor(35), "gold", "mystic chests only every tenth floor")
	for floor = 1, 200 do
		local chestType = TowerLogic.chestFor(floor)
		assert(chestType == nil or ChestData.chests[chestType], "real chest type")
	end
	eq(TowerLogic.canEnter(tower.minLevel - 1), false)
	eq(TowerLogic.canEnter(tower.minLevel), true)
	local ok, reason = TowerLogic.canEnter(70, 100)
	eq(ok, false)
	eq(reason, "low", "a much lower level cannot join a high run")
	eq(TowerLogic.canEnter(100 - tower.joinRange, 100), true)
	assert(TowerLogic.floorCoins(50, 1000) <= Progression.incomeCoins(50, tower.floorMinutes.max), "floor coins are capped")
	-- A floor's coins stay a bonus on top of what its creatures already give.
	for floor = 1, 300 do
		local minutes = math.min(tower.floorMinutes.max, tower.floorMinutes.base + tower.floorMinutes.perFloor * floor)
		local effort = TowerLogic.count(floor, 1) / tower.killsPerMinute + tower.floorDelay / 60
		assert(minutes <= effort * 0.85, `floor {floor} pays {minutes} minutes for about {effort} minutes of play`)
	end
	assert(TowerLogic.recordCoins(50) > TowerLogic.floorCoins(50, 1), "a new best pays more than a floor")
	local p = Profile.new()
	eq(TowerLogic.record(p, 3), true)
	eq(TowerLogic.record(p, 3), false, "the same floor is not a new best")
	eq(TowerLogic.record(p, 2), false)
	eq(p.towerBest, 3)
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, towerBest = -5 }).towerBest, 0)
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, towerBest = "x" }).towerBest, 0)
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, towerBest = 12.7 }).towerBest, 0, "fractions are not floors")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, towerBest = 99999 }).towerBest, 10000, "absurd values are capped")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0 }).towerBest, 0, "missing value")
end)

test("pets: earned by progress, equipped only when earned, saved choice is cleaned", function()
	local PetLogic = require("../src/server/PetLogic")
	local PetData = require("../src/shared/PetData")
	local kinds = { level = true, purifies = true, elites = true, rifts = true, chests = true, legend = true, tower = true }
	for _, id in PetData.order do
		local pet = PetData.pets[id]
		assert(pet and Strings.has(pet.nameKey), id .. " name")
		assert(kinds[pet.unlock.kind] and pet.unlock.goal >= 1, id .. " unlock")
		if pet.unlock.kind == "legend" then
			assert(Balance.enemies[pet.unlock.id] and Balance.enemies[pet.unlock.id].scales, id .. " needs a real Legendary Shadow")
		end
		for _, part in pet.color do
			assert(part >= 0 and part <= 255)
		end
	end
	local p = Profile.new()
	eq(#PetLogic.earned(p), 0, "a new player has no pets")
	eq(PetLogic.equip(p, "glowmoth"), false, "cannot follow before it is earned")
	eq(PetLogic.equip(p, "nope"), false)
	p.xp = Progression.thresholds[PetData.pets.glowmoth.unlock.goal] - 1
	eq(PetLogic.unlocked(p, "glowmoth"), false, "one level short")
	p.xp = Progression.thresholds[PetData.pets.glowmoth.unlock.goal]
	eq(PetLogic.unlocked(p, "glowmoth"), true)
	eq(PetLogic.equip(p, "glowmoth"), true)
	eq(PetLogic.active(p), "glowmoth")
	p.counters.purifies = 499
	eq(PetLogic.progress(p, "sproutling"), 499)
	p.counters.purifies = 99999
	eq(PetLogic.progress(p, "sproutling"), PetData.pets.sproutling.unlock.goal, "progress is capped at the goal")
	p.counters.chests = PetData.pets.pebble.unlock.goal
	p.counters.rifts = PetData.pets.ember_fox.unlock.goal
	p.legends.FrostTitan = true
	p.towerBest = PetData.pets.shade_cat.unlock.goal
	eq(#PetLogic.earned(p), #PetData.order, "every kind of unlock works")
	eq(PetLogic.equip(p, ""), true, "sending the pet home")
	eq(PetLogic.active(p), "")
	-- A saved choice that is not earned (tampered data) never follows.
	local tampered = Profile.new()
	tampered.equippedPet = "shade_cat"
	eq(PetLogic.active(tampered), "")
	eq(PetLogic.encode(Profile.new()), "glowmoth:1,sproutling:0,pebble:0,ember_fox:0,frost_pup:0,shade_cat:0", "progress pairs for the menu")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, equippedPet = "nope" }).equippedPet, "")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, equippedPet = 5 }).equippedPet, "")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, equippedPet = "ember_fox" }).equippedPet, "ember_fox")
	eq(Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0 }).equippedPet, "", "missing value")
end)

test("counter quests: count from the day they start; records use the best value; paid once", function()
	local function ready(): any
		local p = Profile.new()
		for _, questId in QuestData.order do
			if questId == "rift_watch" then
				break
			end
			p.questProgress[questId] = { state = "completed", count = 1 }
		end
		return p
	end
	-- rifts already cleared before the quest do not count.
	local p = ready()
	p.counters.rifts = 4
	eq(QuestLogic.start(p, QuestData, "rift_watch", 12), true)
	eq(p.questProgress.rift_watch.base, 4, "the counter value at the start is remembered")
	eq(#QuestLogic.syncCounters(p, QuestData), 0, "nothing new yet")
	eq(p.questProgress.rift_watch.count, 0)
	p.counters.rifts = 5
	local done = QuestLogic.syncCounters(p, QuestData)
	eq(done[1], "rift_watch", "one new rift completes it")
	eq(p.questProgress.rift_watch.state, "completed")
	eq(#QuestLogic.syncCounters(p, QuestData), 0, "a completed quest pays only once")
	-- progress never goes backwards and is capped at the goal
	local q = ready()
	q.questProgress.rift_watch = { state = "completed", count = 1 }
	q.questProgress.bog_mother = { state = "completed", count = 1 }
	q.counters.elites = 10
	QuestLogic.start(q, QuestData, "elite_hunt", 30)
	q.counters.elites = 12
	QuestLogic.syncCounters(q, QuestData)
	eq(q.questProgress.elite_hunt.count, 2)
	q.counters.elites = 11
	QuestLogic.syncCounters(q, QuestData)
	eq(q.questProgress.elite_hunt.count, 2, "progress never goes down")
	q.counters.elites = 500
	QuestLogic.syncCounters(q, QuestData)
	eq(q.questProgress.elite_hunt.state, "completed")
	eq(q.questProgress.elite_hunt.count, QuestData.quests.elite_hunt.objective.count, "capped at the goal")
	-- the tower quest uses the best floor as it stands (a record)
	local t = ready()
	for _, id in { "rift_watch", "bog_mother", "elite_hunt", "frost_titan" } do
		t.questProgress[id] = { state = "completed", count = 1 }
	end
	t.towerBest = 30
	eq(QuestLogic.start(t, QuestData, "tower_climb", 50), true)
	eq(t.questProgress.tower_climb.base, nil, "records have no base")
	eq(QuestLogic.syncCounters(t, QuestData)[1], "tower_climb", "an earlier best floor already counts")
	-- events never touch counter quests, and the saved base is cleaned
	local e = ready()
	QuestLogic.start(e, QuestData, "rift_watch", 12)
	eq(#QuestLogic.record(e, QuestData, { kind = "purify", target = "Mudling" }), 0)
	local cleaned = Profile.sanitize({ xp = 0, coins = 0, staffUpgrade = 0, questProgress = { rift_watch = { state = "active", count = 0, base = -3 }, elite_hunt = { state = "active", count = 0, base = 7 } } })
	eq(cleaned.questProgress.rift_watch.base, nil, "bad base dropped")
	eq(cleaned.questProgress.elite_hunt.base, 7, "good base kept")
end)

test("game content is English only (no Turkish letters in source)", function()
	local offenders = {}
	local function scan(dir: string)
		for _, name in fs.readDir(dir) do
			local path = dir .. "/" .. name
			if fs.isDir(path) then
				if name ~= "Packages" then
					scan(path)
				end
			elseif string.match(name, "%.luau$") then
				local source = fs.readFile(path)
				for _, letter in { "ç", "ğ", "ı", "ö", "ş", "ü", "Ç", "Ğ", "İ", "Ö", "Ş", "Ü" } do
					if string.find(source, letter, 1, true) then
						table.insert(offenders, path .. " (" .. letter .. ")")
						break
					end
				end
			end
		end
	end
	scan("src")
	eq(#offenders, 0, "Turkish text in: " .. table.concat(offenders, ", "))
	eq(Strings.get("hud_level", 3), "Lv 3", "english lookup")
end)

print(`logic tests: {passed} passed, {failed} failed`)
if failed > 0 then
	error("logic tests failed")
end
