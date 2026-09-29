-- Pure Adventure Log rules: counters, progress per achievement and claiming tier rewards.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local AchievementData = if Shared then require(Shared.AchievementData) else require("../shared/AchievementData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local ChestLogic = if script then require(script.Parent.ChestLogic) else require("./ChestLogic")

export type Claim = { id: string, tier: number, coins: number, chest: string?, chestCoins: number? }

local AchievementLogic = {}

-- Counters kept in profile.counters (the rest are derived from the profile).
AchievementLogic.COUNTERS = { "purifies", "elites", "rifts", "chests", "crystals", "legendWins" }

function AchievementLogic.count(profile: any, counter: string, amount: number?)
	profile.counters[counter] = (profile.counters[counter] or 0) + (amount or 1)
end

function AchievementLogic.progress(profile: any, id: string): number
	local counter = AchievementData.achievements[id].counter
	if counter == "level" then
		return Progression.levelForXp(profile.xp)
	elseif counter == "power" then
		return profile.staffUpgrade
	elseif counter == "legends" or counter == "weapons" then
		local set = if counter == "legends" then profile.legends else profile.ownedWeapons
		local total = 0
		for _, value in set do
			if value then
				total += 1
			end
		end
		return total
	end
	return profile.counters[counter] or 0
end

-- Tiers already claimed for an achievement.
function AchievementLogic.claimed(profile: any, id: string): number
	return profile.achievements[id] or 0
end

-- The next tier (table) to reach, or nil when every tier is claimed.
function AchievementLogic.nextTier(profile: any, id: string)
	return AchievementData.achievements[id].tiers[AchievementLogic.claimed(profile, id) + 1]
end

function AchievementLogic.claimable(profile: any, id: string): boolean
	local tier = AchievementData.achievements[id] and AchievementLogic.nextTier(profile, id)
	return tier ~= nil and AchievementLogic.progress(profile, id) >= tier.goal
end

-- Claims the next tier and pays it out; nil when there is nothing to claim.
function AchievementLogic.claim(profile: any, id: string, level: number): Claim?
	if not AchievementLogic.claimable(profile, id) then
		return nil
	end
	local tier = AchievementLogic.nextTier(profile, id)
	local number = AchievementLogic.claimed(profile, id) + 1
	profile.achievements[id] = number
	profile.coins += tier.coins
	local claim: Claim = { id = id, tier = number, coins = tier.coins }
	if tier.chest then
		if ChestLogic.give(profile, tier.chest, level) then
			claim.chest = tier.chest
		else
			claim.chestCoins = AchievementData.chestCoins[tier.chest]
			profile.coins += claim.chestCoins :: number
		end
	end
	return claim
end

-- How many tiers are waiting to be claimed (for the "!" badge).
function AchievementLogic.readyCount(profile: any): number
	local total = 0
	for _, id in AchievementData.order do
		if AchievementLogic.claimable(profile, id) then
			total += 1
		end
	end
	return total
end

return AchievementLogic
