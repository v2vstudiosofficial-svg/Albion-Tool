-- Run: lune run tests/balance
-- Level 1-100 balance model. It follows a "typical" player who always fights creatures of their
-- own level and spends coins at the forge, and checks that the game stays fun at every level:
-- creatures die fast, packs are still a little dangerous, levels come at a steady pace and the
-- whole journey is long but not endless. The numbers are a model (no real players yet); the
-- targets are the design intent. Prints a table and fails if a level falls outside the targets.
local Balance = require("../src/shared/Balance")
local Progression = require("../src/shared/Progression")
local WeaponData = require("../src/shared/WeaponData")
local SkillData = require("../src/shared/SkillData")
local Stats = require("../src/shared/Stats")
local ChestData = require("../src/shared/ChestData")

local verbose = (...) == "verbose"

-- Design targets.
local TARGET = {
	-- One same-level creature, main weapon plus floating weapons. Packs melting fast is the fun of
	-- an auto-battler; the challenge comes from higher-level zones and bosses.
	killSeconds = { 0.3, 3.5 },
	surviveSeconds = { 8, 90 }, -- three same-level creatures hitting at once
	minutesPerLevel = { 0.3, 13 }, -- the last levels are a long-term goal
	totalHours = { 6, 30 },
	bossSeconds = { 20, 150 }, -- a solo legend fight at the boss's own level (single target)
}

-- Model assumptions.
local PACK_TARGETS = { bolt = 1, arrow = 1, fan = 1.5, arc = 2, thrust = 1.8, pierce = 1.8, spin = 2.4, slam = 2.4 }
local TRAVEL_SECONDS = 2 -- walking to the next creature
local DEPOSIT_TRIP_SECONDS = 45 -- to the Great Lantern and back
local CHEST_EVERY_MINUTES = 8 -- a chest found and opened
local COMBAT_PICK_SHARE = 0.5 -- share of skill picks going to sharp / swift / lucky
local REFERENCE = Balance.enemies.Gloomling
local FIGHTERS = 3 -- creatures hitting at once in the survival check

-- Weapons a player can expect to own by a level (chests get rarer weapons over time).
local function expectedRarity(level: number): number
	if level >= 50 then
		return 4
	elseif level >= 25 then
		return 3
	elseif level >= 8 then
		return 2
	end
	return 1
end

local function weaponDps(weaponId: string): number
	local weapon = WeaponData.weapons[weaponId]
	return weapon.damage / weapon.cooldown * PACK_TARGETS[weapon.style]
end

-- The strongest (packs included) and second strongest weapons available at this level.
local function bestWeapons(level: number): (string, string)
	local list = {}
	for _, weaponId in WeaponData.order do
		if table.find(WeaponData.rarityOrder, WeaponData.weapons[weaponId].rarity) <= expectedRarity(level) then
			table.insert(list, weaponId)
		end
	end
	table.sort(list, function(a, b)
		return weaponDps(a) > weaponDps(b)
	end)
	return list[1], list[2] or list[1]
end

-- Greedy forge shopping: cheapest weighted upgrade first.
local WEIGHTS = { power = 1, health = 1.6, crit = 1.5, pouch = 2.5, regen = 3 }
local function shop(state)
	while true do
		local best, bestScore = nil, math.huge
		for stat, weight in WEIGHTS do
			local level = if stat == "power" then state.power else state.upgrades[stat] or 0
			local cost = Progression.upgradeCost(stat, level)
			if cost and cost * weight < bestScore then
				best, bestScore = stat, cost * weight
			end
		end
		local level = if best == "power" then state.power else state.upgrades[best] or 0
		local cost = best and Progression.upgradeCost(best, level)
		if not cost or cost > state.coins then
			return
		end
		state.coins -= cost
		if best == "power" then
			state.power += 1
		else
			state.upgrades[best] = level + 1
		end
	end
end

local function skillsAt(level: number): { [string]: number }
	local combat = math.floor((level - 1) * COMBAT_PICK_SHARE)
	local skills = {}
	local order = { "sharp", "swift", "lucky", "echo", "tough", "reach" }
	local index = 0
	while combat > 0 do
		index = index % #order + 1
		local id = order[index]
		if (skills[id] or 0) < SkillData.skills[id].maxRank then
			skills[id] = (skills[id] or 0) + 1
			combat -= 1
		elseif index == #order then
			local full = true
			for _, other in order do
				if (skills[other] or 0) < SkillData.skills[other].maxRank then
					full = false
				end
			end
			if full then
				break
			end
		end
	end
	-- The other half of the picks go to wisdom and magnet first.
	local other = math.floor((level - 1) * (1 - COMBAT_PICK_SHARE))
	skills.wisdom = math.min(SkillData.skills.wisdom.maxRank, other)
	skills.magnet = math.min(SkillData.skills.magnet.maxRank, math.max(0, other - skills.wisdom))
	return skills
end

local function averageChestCoins(): number
	local total = 0
	for _, chestType in ChestData.order do
		local c = ChestData.chests[chestType].coins
		total += (c[1] + c[2]) / 2
	end
	return total / #ChestData.order
end

local WorldData = require("../src/shared/WorldData")
local bossLevels = {}
for _, spawn in WorldData.spawns do
	if spawn.level and Balance.enemies[spawn.kind].isBoss then
		-- The last level is 100; fights at 100 are modelled with level-99 power.
		bossLevels[spawn.kind] = math.min(spawn.level, Progression.MAX_LEVEL - 1)
	end
end

local state = { power = 0, upgrades = {}, coins = 0, slotLevel = 0, minutes = 0 }
local rows = {}
local failures = {}

local function check(level: number, name: string, value: number, range: { number })
	if value < range[1] or value > range[2] then
		table.insert(failures, string.format("level %d %s = %.2f (target %.1f-%.1f)", level, name, value, range[1], range[2]))
	end
end

for level = 1, Progression.MAX_LEVEL - 1 do
	local skills = skillsAt(level)
	local stats = Stats.of({
		xp = Progression.thresholds[level],
		staffUpgrade = state.power,
		upgrades = state.upgrades,
		skills = skills,
	})
	local main, second = bestWeapons(level)
	local enemy = Progression.enemyStats(REFERENCE, level)

	-- Damage per second against a pack: main weapon + floating weapons, crits included.
	local critBonus = 1 + stats.critChance * (Balance.critDamage - 1)
	local function slotDps(weaponId: string, companion: boolean): number
		local weapon = WeaponData.weapons[weaponId]
		local hit = Progression.weaponDamage(weaponId, state.power, level, companion, state.slotLevel)
		local cooldown = Progression.weaponCooldown(weaponId, companion) * stats.cooldownMultiplier
		return hit / cooldown * PACK_TARGETS[weapon.style]
	end
	local dps = slotDps(main, false)
	for _ = 1, Progression.companionSlots(level) do
		dps += slotDps(second, true) * stats.companionMultiplier
	end
	dps *= stats.damageMultiplier * critBonus
	local killSeconds = enemy.maxHp / dps

	-- Three same-level creatures in contact at once.
	local incoming = FIGHTERS * REFERENCE.contactDamage * enemy.damageMultiplier / REFERENCE.contactCooldown
	local surviveSeconds = stats.maxHealth / math.max(0.1, incoming - stats.regen)

	-- Time for this level: fights, walking, trips to the lantern.
	local span = Progression.thresholds[level + 1] - Progression.thresholds[level]
	local xpPerKill = math.floor(enemy.reward.xp * stats.xpMultiplier + 0.5)
	local kills = span / xpPerKill
	local crystals = kills * enemy.reward.coins * stats.crystalMultiplier
	local trips = crystals / stats.pouchCapacity
	local seconds = kills * (killSeconds + TRAVEL_SECONDS) + trips * DEPOSIT_TRIP_SECONDS
	local minutes = seconds / 60
	state.minutes += minutes

	-- Income: crystals, chests; chests also level the weapon slots (shared by the open slots).
	local chests = minutes / CHEST_EVERY_MINUTES
	state.coins += crystals + chests * averageChestCoins()
	state.slotLevel = math.min(WeaponData.maxSlotLevel, state.slotLevel + chests * 2.5 / (1 + Progression.companionSlots(level)))
	shop(state)

	-- Legendary Shadows of this level: a solo fight against one big target (no pack bonus).
	for _, kind in Balance.legends do
		local boss = Balance.enemies[kind]
		if boss.scales and bossLevels[kind] == level then
			local single = dps / PACK_TARGETS[WeaponData.weapons[main].style]
			local seconds = Progression.enemyStats(boss, level).maxHp / single
			check(level, kind .. " fight seconds", seconds, TARGET.bossSeconds)
			table.insert(rows, string.format("     %s fight: %.0f s", kind, seconds))
		end
	end

	check(level, "kill seconds", killSeconds, TARGET.killSeconds)
	check(level, "survive seconds", surviveSeconds, TARGET.surviveSeconds)
	check(level, "minutes per level", minutes, TARGET.minutesPerLevel)

	if verbose or level == 1 or level % 10 == 0 or level == 5 or level == 25 or level == 99 then
		table.insert(rows, string.format(
			"%3d  %-8s  pow %2d  slot %4.1f  dps %8.0f  hp %8.0f  kill %4.1fs  survive %5.1fs  %5.1f min  total %5.1f h",
			level, main, state.power, state.slotLevel, dps, enemy.maxHp, killSeconds, surviveSeconds, minutes, state.minutes / 60
		))
	end
end

check(100, "total hours", state.minutes / 60, TARGET.totalHours)

print(" lvl  weapon    power  slot  dps           enemy hp     kill     survive     per level  so far")
for _, row in rows do
	print(row)
end
if #failures > 0 then
	for index = 1, math.min(#failures, 25) do
		print("OUT OF TARGET: " .. failures[index])
	end
	error(#failures .. " balance targets missed")
end
print("balance: every level within the targets")
