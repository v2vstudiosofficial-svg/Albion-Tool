-- Pure Creature Codex rules: counting purified creatures per kind and paying each milestone once.
-- Counts only go up by one per purification, so a milestone can be crossed exactly once.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local BestiaryData = if Shared then require(Shared.BestiaryData) else require("../shared/BestiaryData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

local BestiaryLogic = {}

-- The milestone list for a kind (nil for an unknown kind).
function BestiaryLogic.tiers(kind: string): { { goal: number, minutes: number } }?
	local enemy = Balance.enemies[kind]
	if not enemy or not table.find(BestiaryData.order, kind) then
		return nil
	end
	return if enemy.isBoss then BestiaryData.tiers.boss else BestiaryData.tiers.regular
end

function BestiaryLogic.count(profile: any, kind: string): number
	return profile.bestiary[kind] or 0
end

-- Counts one purified creature. Returns the milestone reached (index, goal, coins paid) or nil.
function BestiaryLogic.record(profile: any, kind: string, level: number): { index: number, goal: number, coins: number }?
	local tiers = BestiaryLogic.tiers(kind)
	if not tiers then
		return nil
	end
	local count = BestiaryLogic.count(profile, kind)
	if count >= BestiaryData.maxCount then
		return nil
	end
	count += 1
	profile.bestiary[kind] = count
	for index, tier in tiers do
		if tier.goal == count then
			local coins = Progression.incomeCoins(level, tier.minutes)
			profile.coins += coins
			return { index = index, goal = tier.goal, coins = coins }
		end
	end
	return nil
end

-- "Kind:count" for every kind purified at least once (replicated for the codex tab).
function BestiaryLogic.encode(profile: any): string
	local list = {}
	for _, kind in BestiaryData.order do
		local count = BestiaryLogic.count(profile, kind)
		if count > 0 then
			table.insert(list, kind .. ":" .. count)
		end
	end
	return table.concat(list, ",")
end

return BestiaryLogic
