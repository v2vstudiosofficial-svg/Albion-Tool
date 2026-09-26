-- Run: lune run tests/logic
local Profile = require("../src/server/Profile")
local QuestLogic = require("../src/server/QuestLogic")
local EnemyLogic = require("../src/server/EnemyLogic")
local QuestData = require("../src/shared/QuestData")
local Balance = require("../src/shared/Balance")
local Strings = require("../src/shared/Strings")

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

test("purify before accepting the quest does not count", function()
	local p = Profile.new()
	eq(#QuestLogic.recordPurify(p, QuestData, "Gloomling"), 0)
	eq(p.questProgress.first_purify, nil)
end)

test("quest starts once, completes once", function()
	local p = Profile.new()
	eq(QuestLogic.nextAvailable(p, QuestData), "first_purify")
	eq(QuestLogic.start(p, QuestData, "first_purify"), true)
	eq(QuestLogic.start(p, QuestData, "first_purify"), false, "second start")
	eq(QuestLogic.tracked(p, QuestData), "first_purify")

	eq(#QuestLogic.recordPurify(p, QuestData, "Unknown"), 0, "wrong enemy")
	local completed = QuestLogic.recordPurify(p, QuestData, "Gloomling")
	eq(#completed, 1)
	eq(completed[1], "first_purify")
	eq(#QuestLogic.recordPurify(p, QuestData, "Gloomling"), 0, "second purify")
	eq(QuestLogic.start(p, QuestData, "first_purify"), false, "restart after completion")
	eq(QuestLogic.tracked(p, QuestData), nil)
	eq(QuestLogic.nextAvailable(p, QuestData), nil)
	eq(p.questProgress.first_purify.count, 1)
end)

test("unknown quest id cannot be started", function()
	eq(QuestLogic.start(Profile.new(), QuestData, "nope"), false)
end)

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
	EnemyLogic.forget(state, "a")
	eq(#EnemyLogic.participants(state, 50, 30, function()
		return true
	end), 2, "after forget")
end)

test("two co-op players each get one enemy reward and one quest reward", function()
	local stats = Balance.enemies.Gloomling
	local profiles = { a = Profile.new(), b = Profile.new() }
	QuestLogic.start(profiles.a, QuestData, "first_purify")
	QuestLogic.start(profiles.b, QuestData, "first_purify")
	local state = EnemyLogic.new(stats.maxHp)
	local hits = math.ceil(stats.maxHp / Balance.staff.damage) + 3
	for i = 1, hits do
		local who = if i % 2 == 0 then "a" else "b"
		if EnemyLogic.applyHit(state, who, Balance.staff.damage, i) then
			for _, player in EnemyLogic.participants(state, i, Balance.participationWindow, function()
				return true
			end) do
				Profile.applyReward(profiles[player], stats.reward)
				for _, questId in QuestLogic.recordPurify(profiles[player], QuestData, "Gloomling") do
					Profile.applyReward(profiles[player], QuestData.quests[questId].reward)
				end
			end
		end
	end
	local quest = QuestData.quests.first_purify.reward
	for _, p in profiles do
		eq(p.xp, stats.reward.xp + quest.xp, "xp")
		eq(p.coins, stats.reward.coins + quest.coins, "coins")
	end
end)

test("data tables reference existing enemies and strings", function()
	local tr = Strings.tables.tr
	for _, questId in QuestData.order do
		local quest = QuestData.quests[questId]
		assert(quest, "missing quest " .. questId)
		eq(quest.id, questId, "quest id")
		assert(tr[quest.offerKey], "missing string " .. quest.offerKey)
		assert(tr[quest.objectiveKey], "missing string " .. quest.objectiveKey)
		assert(Balance.enemies[quest.objective.enemyType], "missing enemy " .. quest.objective.enemyType)
	end
	for kind, stats in Balance.enemies do
		assert(tr[stats.nameKey], "missing name string for " .. kind)
	end
	eq(Strings.get("hud_coins", 7), "Sikke: 7")
	eq(Strings.get("no_such_key"), "no_such_key")
end)

print(`logic tests: {passed} passed, {failed} failed`)
if failed > 0 then
	error("logic tests failed")
end
