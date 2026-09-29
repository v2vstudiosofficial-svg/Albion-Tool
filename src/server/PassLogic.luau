-- Pure Light Pass rules: Pass XP, tiers, claiming free/premium rewards, season resets.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local PassData = if Shared then require(Shared.PassData) else require("../shared/PassData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local CosmeticLogic = if script then require(script.Parent.CosmeticLogic) else require("./CosmeticLogic")

export type Paid = { tier: number, track: string, coins: number, costume: string? }

local PassLogic = {}

-- A saved pass from an older season starts over (premium is per season too).
function PassLogic.ensureSeason(profile: any)
	if profile.pass.season ~= PassData.season then
		profile.pass = { season = PassData.season, xp = 0, premium = false, free = {}, premiumClaimed = {} }
	end
end

function PassLogic.tier(profile: any): number
	return math.min(PassData.tiers, profile.pass.xp // PassData.xpPerTier)
end

-- Adds Pass XP for an action (PassData.xp key); returns the tiers gained.
function PassLogic.addXp(profile: any, action: string, times: number?): number
	PassLogic.ensureSeason(profile)
	local amount = (PassData.xp[action] or 0) * (times or 1)
	local before = PassLogic.tier(profile)
	local cap = PassData.tiers * PassData.xpPerTier
	profile.pass.xp = math.min(cap, profile.pass.xp + amount)
	return PassLogic.tier(profile) - before
end

local function claimedSet(profile: any, track: string): { [string]: boolean }
	return if track == "premium" then profile.pass.premiumClaimed else profile.pass.free
end

function PassLogic.claimable(profile: any, tier: number, track: string): boolean
	if track ~= "free" and track ~= "premium" then
		return false
	end
	if tier < 1 or tier > PassLogic.tier(profile) or tier % 1 ~= 0 then
		return false
	end
	if track == "premium" and not profile.pass.premium then
		return false
	end
	return claimedSet(profile, track)[tostring(tier)] ~= true
end

-- Pays one tier's reward. A costume already owned turns into 10 minutes of coins.
function PassLogic.claim(profile: any, tier: number, track: string, level: number): Paid?
	PassLogic.ensureSeason(profile)
	if not PassLogic.claimable(profile, tier, track) then
		return nil
	end
	claimedSet(profile, track)[tostring(tier)] = true
	local reward = PassData.rewards[tier][track]
	local paid: Paid = { tier = tier, track = track, coins = 0 }
	if reward.costume then
		if CosmeticLogic.grant(profile, reward.costume) then
			paid.costume = reward.costume
		else
			paid.coins = Progression.incomeCoins(level, 10)
		end
	else
		paid.coins = Progression.incomeCoins(level, reward.coinMinutes)
	end
	profile.coins += paid.coins
	return paid
end

-- Claims everything reachable on both tracks.
function PassLogic.claimAll(profile: any, level: number): { Paid }
	local list = {}
	for tier = 1, PassLogic.tier(profile) do
		for _, track in { "free", "premium" } do
			local paid = PassLogic.claim(profile, tier, track, level)
			if paid then
				table.insert(list, paid)
			end
		end
	end
	return list
end

return PassLogic
