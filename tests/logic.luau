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

test("staff upgrade spends coins once per tier and stops at max", function()
	local p = Profile.new()
	local ok, reason, missing = Profile.tryUpgradeStaff(p)
	eq(ok, false)
	eq(reason, "coins")
	eq(missing, Balance.staff.tiers[2].cost)
	eq(p.staffUpgrade, 0)
	p.coins = 10000
	local spent = 0
	for tier = 1, Progression.maxStaffUpgrade() do
		eq(Profile.tryUpgradeStaff(p), true, "tier " .. tier)
		spent += Balance.staff.tiers[tier + 1].cost
	end
	eq(p.staffUpgrade, Progression.maxStaffUpgrade())
	eq(p.coins, 10000 - spent)
	local okMax, reasonMax = Profile.tryUpgradeStaff(p)
	eq(okMax, false)
	eq(reasonMax, "max")
	eq(p.coins, 10000 - spent, "no charge at max")
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
	local thresholds = Balance.levels.xpThresholds
	eq(Progression.levelForXp(0), 1)
	eq(Progression.levelForXp(thresholds[2] - 1), 1)
	eq(Progression.levelForXp(thresholds[2]), 2)
	eq(Progression.levelForXp(10 ^ 7), Progression.MAX_LEVEL)
	eq(Progression.MAX_LEVEL, 10)
	local lvl, into, span = Progression.levelProgress(thresholds[3] + 50)
	eq(lvl, 3)
	eq(into, 50)
	eq(span, thresholds[4] - thresholds[3])
	local _, _, maxSpan = Progression.levelProgress(10 ^ 7)
	eq(maxSpan, nil, "no span at max level")
	local previous = -1
	for _, needed in Balance.levels.xpThresholds do
		assert(needed > previous, "thresholds must increase")
		previous = needed
	end
end)

test("derived stats: health, damage, wave, charms", function()
	eq(Progression.maxHealth(1), 100)
	eq(Progression.maxHealth(10), 190)
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
	local tiers = Balance.staff.tiers
	local maxXp = Balance.levels.xpThresholds[Progression.MAX_LEVEL]
	local g = Goals.next(0, tiers[2].cost, 0)
	eq(g.kind, "staff", "affordable upgrade first")
	eq(g.affordable, true)
	eq(Goals.next(0, 0, 0).kind, "level", "otherwise level up")
	local lastTier = Progression.maxStaffUpgrade()
	local staffOnly = Goals.next(maxXp, 0, lastTier - 1)
	eq(staffOnly.kind, "staff", "at max level, remaining tiers")
	eq(staffOnly.affordable, false)
	eq(staffOnly.missing, tiers[lastTier + 1].cost, "missing coins")
	eq(Goals.next(maxXp, 0, lastTier).kind, "done")
	eq(Goals.next(maxXp, 10 ^ 6, lastTier).kind, "done", "max tier with lots of coins")
	local capped = Goals.next(maxXp, tiers[2].cost, 0)
	eq(capped.kind, "staff", "affordable tier at the level cap")
	eq(capped.affordable, true)
	eq(capped.target, 1, "tier index, not display number")
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
	local function purify(kind: string)
		Profile.applyReward(p, Balance.enemies[kind].reward)
		event({ kind = "purify", target = kind })
	end

	start("first_purify")
	for _ = 1, QuestData.quests.first_purify.objective.count do
		purify("Gloomling")
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
	assert(Profile.tryUpgradeStaff(p), "enough coins for the first upgrade without grinding")
	event({ kind = "upgrade", value = p.staffUpgrade })
	start("ruin_vines")
	for _, id in QuestData.quests.ruin_vines.objective.ids do
		event({ kind = "vine", id = id })
	end
	-- The boss quest is level-gated; a player may need a few extra fights on the way.
	local extraFights = 0
	while not QuestLogic.canStart(p, QuestData, "warden", level(p)) do
		purify("Gloomling")
		extraFights += 1
	end
	assert(extraFights <= 15, "grind before the boss stays short: " .. extraFights .. " Gloomlings")
	start("warden")
	purify("Warden")
	purify("Warden")

	for _, questId in QuestData.order do
		eq(QuestLogic.isCompleted(p, questId), true, questId)
	end
	eq(QuestLogic.nextAvailable(p, QuestData), nil)
	eq(p.ownedCharms.swift and p.ownedCharms.guard and p.ownedCharms.glow, true, "all charms")
	eq(p.restorationFlags.gardens and p.restorationFlags.lanterns and p.restorationFlags.festival, true, "all flags")

	local expectedXp, expectedCoins = 0, -Balance.staff.tiers[2].cost
	for _, questId in QuestData.order do
		local reward = QuestData.quests[questId].reward
		expectedXp += reward.xp or 0
		expectedCoins += reward.coins or 0
	end
	local fights = { "Warden", "Warden" }
	for _ = 1, QuestData.quests.first_purify.objective.count + extraFights do
		table.insert(fights, "Gloomling")
	end
	for _, kind in fights do
		expectedXp += Balance.enemies[kind].reward.xp
		expectedCoins += Balance.enemies[kind].reward.coins
	end
	eq(p.xp, expectedXp, "xp")
	eq(p.coins, expectedCoins, "coins")
	assert(level(p) >= 5, "reaches a satisfying level by the end of the chain")
	assert(level(p) < Progression.MAX_LEVEL, "the level cap stays a post-game goal")
	local topTiers = Balance.staff.tiers[3].cost + Balance.staff.tiers[4].cost
	assert(p.coins < topTiers, "the last staff tiers stay a post-game goal")
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
		if EnemyLogic.applyHit(state, who, Balance.staff.tiers[1].damage, i) then
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
