-- Pure derived stats (level, damage, wave, charms). Works in Roblox and in Lune tests.
local Balance = if script
	then require(script.Parent.Balance)
	else require("./Balance")

local Progression = {}

local WeaponData = if script
	then require(script.Parent.WeaponData)
	else require("./WeaponData")
local ChestData = if script
	then require(script.Parent.ChestData)
	else require("./ChestData")
local SkillData = if script
	then require(script.Parent.SkillData)
	else require("./SkillData")

local levels = Balance.levels
Progression.MAX_LEVEL = levels.maxLevel

-- thresholds[level] = total XP needed to reach that level.
local thresholds = { 0 }
for level = 1, levels.maxLevel - 1 do
	thresholds[level + 1] = thresholds[level] + math.floor(levels.xpBase + levels.xpScale * level ^ levels.xpPower)
end
Progression.thresholds = thresholds

function Progression.levelForXp(xp: number): number
	-- Binary search: the highest level whose threshold is reached.
	local low, high = 1, #thresholds
	while low < high do
		local mid = (low + high + 1) // 2
		if xp >= thresholds[mid] then
			low = mid
		else
			high = mid - 1
		end
	end
	return low
end

-- Returns level, xp earned inside the level, xp span of the level (nil at max level).
function Progression.levelProgress(xp: number): (number, number, number?)
	local level = Progression.levelForXp(xp)
	local start = thresholds[level]
	local nextThreshold = thresholds[level + 1]
	if nextThreshold == nil then
		return level, xp - start, nil
	end
	return level, xp - start, nextThreshold - start
end

function Progression.maxHealth(level: number): number
	return Balance.levels.baseHealth + Balance.levels.healthPerLevel * (level - 1)
end

-- Forge upgrade cost to go from `level` to `level + 1`; nil when already at max.
function Progression.upgradeCost(stat: string, level: number): number?
	local upgrade = Balance.upgrades[stat]
	if not upgrade or level >= upgrade.maxLevel then
		return nil
	end
	return math.floor(upgrade.baseCost * upgrade.growth ^ level)
end

function Progression.maxStaffUpgrade(): number
	return Balance.upgrades.power.maxLevel
end

-- Coins for the next weapon power level, or nil at max.
function Progression.nextStaffCost(power: number): number?
	return Progression.upgradeCost("power", power)
end

-- Weapon glow color for a power level ({r, g, b}).
function Progression.powerColor(power: number): { number }
	local colors = Balance.powerColors
	return colors[math.clamp(power // 10 + 1, 1, #colors)]
end

local function levelMultiplier(level: number): number
	return 1 + Balance.levels.damageBonusPerLevel * (level - 1)
end

-- Weapon power multiplier (power level 0 = 1).
function Progression.tierMultiplier(power: number): number
	return 1 + Balance.upgrades.power.perLevel * power
end

-- Damage of the light wave's base (the staff's damage at this power and level).
function Progression.staffDamage(power: number, level: number): number
	return math.floor(WeaponData.weapons.staff.damage * Progression.tierMultiplier(power) * levelMultiplier(level) + 0.5)
end

-- Bonus from a weapon slot's level (slot levels come from chests).
function Progression.slotMultiplier(slotLevel: number?): number
	return 1 + WeaponData.slotLevelBonus * math.clamp(slotLevel or 0, 0, WeaponData.maxSlotLevel)
end

function Progression.weaponDamage(weaponId: string, staffUpgrade: number, level: number, companion: boolean?, slotLevel: number?): number
	local weapon = WeaponData.weapons[weaponId]
	local damage = weapon.damage * Progression.tierMultiplier(staffUpgrade) * levelMultiplier(level) * Progression.slotMultiplier(slotLevel)
	if companion then
		damage *= WeaponData.companionDamage
	end
	return math.max(1, math.floor(damage + 0.5))
end

function Progression.weaponCooldown(weaponId: string, companion: boolean?): number
	local cooldown = WeaponData.weapons[weaponId].cooldown
	return if companion then cooldown * WeaponData.companionCooldown else cooldown
end

-- Floating weapon slots unlocked at this level (one every WeaponData.companionEvery levels).
function Progression.companionSlots(level: number): number
	return math.min(WeaponData.maxCompanions, level // WeaponData.companionEvery)
end

-- Chest slots open at this level (1 at the start, 5 at most).
function Progression.chestSlots(level: number): number
	local count = 0
	for _, needed in ChestData.slotUnlockLevels do
		if level >= needed then
			count += 1
		end
	end
	return count
end

-- The next level that opens a chest slot or a floating weapon slot (or the level cap).
function Progression.nextMilestone(level: number): number
	local best = Progression.MAX_LEVEL
	for _, needed in ChestData.slotUnlockLevels do
		if needed > level and needed < best then
			best = needed
		end
	end
	local nextSlot = (level // WeaponData.companionEvery + 1) * WeaponData.companionEvery
	if nextSlot > level and nextSlot < best then
		best = nextSlot
	end
	return math.max(best, math.min(level + 1, Progression.MAX_LEVEL))
end

-- Level-scaled stats for a regular enemy; bosses keep their hand-tuned values.
function Progression.enemyStats(stats: any, level: number)
	local scaling = Balance.enemyScaling
	if stats.isBoss then
		return { maxHp = stats.maxHp, damageMultiplier = 1, reward = stats.reward }
	end
	local steps = level - 1
	return {
		maxHp = math.floor(stats.maxHp * (1 + scaling.hpPerLevel * steps) + 0.5),
		damageMultiplier = 1 + scaling.damagePerLevel * steps,
		reward = {
			xp = math.floor(stats.reward.xp * level ^ scaling.xpPower + 0.5),
			coins = math.floor(stats.reward.coins * (1 + scaling.coinsPerLevel * steps) + 0.5),
		},
	}
end

function Progression.waveUnlocked(level: number): boolean
	return level >= Balance.wave.unlockLevel
end

-- waveRank: rank of the "wave" skill card (shorter cooldown, bigger radius).
function Progression.waveStats(staffUpgrade: number, level: number, charmId: string?, waveRank: number?)
	local charm = charmId and Balance.charms[charmId]
	local skill = (waveRank or 0) * SkillData.skills.wave.perRank
	local cooldown = Balance.wave.cooldown * (charm and charm.waveCooldownMultiplier or 1) * (1 - skill)
	local radius = Balance.wave.radius * (charm and charm.waveRadiusMultiplier or 1) * (1 + skill)
	local damage = math.floor(Progression.staffDamage(staffUpgrade, level) * Balance.wave.damageMultiplier + 0.5)
	return { cooldown = cooldown, radius = radius, damage = damage, knockback = Balance.wave.knockback }
end

function Progression.damageTaken(amount: number, charmId: string?): number
	local charm = charmId and Balance.charms[charmId]
	return math.max(1, math.floor(amount * (charm and charm.damageTakenMultiplier or 1) + 0.5))
end

function Progression.walkSpeed(charmId: string?): number
	local charm = charmId and Balance.charms[charmId]
	return Balance.player.walkSpeed * (charm and charm.walkSpeedMultiplier or 1)
end

return Progression
