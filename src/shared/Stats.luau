-- Everything that makes a player stronger, combined in one place: level, weapon power, forge
-- upgrades, skill cards and the equipped charm. Pure, so the server, the client and tests agree.
local Balance = if script then require(script.Parent.Balance) else require("./Balance")
local SkillData = if script then require(script.Parent.SkillData) else require("./SkillData")
local Progression = if script then require(script.Parent.Progression) else require("./Progression")

export type Input = {
	xp: number,
	staffUpgrade: number,
	upgrades: { [string]: number }?,
	skills: { [string]: number }?,
	equippedCharm: string?,
	rebirths: number?,
	-- Main quests completed: either the number itself (client) or the profile's quest progress (server).
	storyDone: number?,
	questProgress: { [string]: { state: string } }?,
}

export type PlayerStats = {
	level: number,
	damageMultiplier: number,
	cooldownMultiplier: number,
	rangeMultiplier: number,
	critChance: number,
	companionMultiplier: number,
	maxHealth: number,
	regen: number,
	walkSpeed: number,
	crystalMultiplier: number,
	xpMultiplier: number,
	pouchCapacity: number,
	waveRank: number,
	-- Share of max health healed per purified creature.
	healOnPurify: number,
	-- Extra damage share while at or below Balance.fury.healthShare of max health.
	furyDamage: number,
	-- Multiplier on the coins a chest gives.
	chestCoins: number,
}

local Stats = {}

-- Main quests completed (the story blessing counts each one).
function Stats.storyDone(input: Input): number
	if input.storyDone then
		return input.storyDone
	end
	local count = 0
	for _, progress in input.questProgress or {} do
		if progress.state == "completed" then
			count += 1
		end
	end
	return count
end

local function rank(input: Input, skillId: string): number
	local skills = input.skills or {}
	return math.clamp(skills[skillId] or 0, 0, SkillData.skills[skillId].maxRank)
end

local function upgrade(input: Input, stat: string): number
	local upgrades = input.upgrades or {}
	return math.clamp(upgrades[stat] or 0, 0, Balance.upgrades[stat].maxLevel)
end

local function bonus(input: Input, skillId: string): number
	return rank(input, skillId) * SkillData.skills[skillId].perRank
end

function Stats.of(input: Input): PlayerStats
	local level = Progression.levelForXp(input.xp)
	local ups = Balance.upgrades
	return {
		level = level,
		damageMultiplier = 1 + bonus(input, "sharp"),
		cooldownMultiplier = 1 - bonus(input, "swift"),
		rangeMultiplier = 1 + bonus(input, "reach"),
		critChance = upgrade(input, "crit") * ups.crit.perLevel + bonus(input, "lucky"),
		companionMultiplier = 1 + bonus(input, "echo"),
		maxHealth = math.floor(
			Progression.maxHealth(level) * (1 + upgrade(input, "health") * ups.health.perLevel) * (1 + bonus(input, "tough")) + 0.5
		),
		regen = upgrade(input, "regen") * ups.regen.perLevel,
		walkSpeed = Progression.walkSpeed(input.equippedCharm) * (1 + bonus(input, "feet")),
		crystalMultiplier = 1 + bonus(input, "magnet"),
		xpMultiplier = 1 + bonus(input, "wisdom") + Balance.rebirth.xpPerRebirth * math.clamp(input.rebirths or 0, 0, Balance.rebirth.maxBonusRebirths) + Balance.story.xpPerQuest * Stats.storyDone(input),
		pouchCapacity = math.floor(
			(Balance.pouch.baseCapacity + upgrade(input, "pouch") * ups.pouch.perLevel) * (1 + Balance.pouch.perLevel * (level - 1)) + 0.5
		),
		waveRank = rank(input, "wave"),
		healOnPurify = bonus(input, "healing"),
		furyDamage = bonus(input, "fury"),
		chestCoins = 1 + bonus(input, "treasure"),
	}
end

return Stats
