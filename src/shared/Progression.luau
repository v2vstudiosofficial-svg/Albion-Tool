-- Pure derived stats (level, damage, wave, charms). Works in Roblox and in Lune tests.
local Balance = if script
	then require(script.Parent.Balance)
	else require("./Balance")

local Progression = {}

local thresholds = Balance.levels.xpThresholds
Progression.MAX_LEVEL = #thresholds

function Progression.levelForXp(xp: number): number
	local level = 1
	for index, needed in thresholds do
		if xp >= needed then
			level = index
		end
	end
	return level
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

function Progression.staffTier(staffUpgrade: number)
	return Balance.staff.tiers[staffUpgrade + 1]
end

function Progression.maxStaffUpgrade(): number
	return #Balance.staff.tiers - 1
end

function Progression.staffDamage(staffUpgrade: number, level: number): number
	local tier = Progression.staffTier(staffUpgrade)
	return math.floor(tier.damage * (1 + Balance.levels.damageBonusPerLevel * (level - 1)) + 0.5)
end

function Progression.waveUnlocked(level: number): boolean
	return level >= Balance.wave.unlockLevel
end

function Progression.waveStats(staffUpgrade: number, level: number, charmId: string?)
	local charm = charmId and Balance.charms[charmId]
	local cooldown = Balance.wave.cooldown * (charm and charm.waveCooldownMultiplier or 1)
	local radius = Balance.wave.radius * (charm and charm.waveRadiusMultiplier or 1)
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
