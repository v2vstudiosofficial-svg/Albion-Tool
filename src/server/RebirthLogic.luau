-- Pure rebirth rules: who may restart the climb, what resets and what stays, and the cosmetic
-- rewards. See Balance.rebirth for the numbers.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local CosmeticLogic = if script then require(script.Parent.CosmeticLogic) else require("./CosmeticLogic")

local RebirthLogic = {}

-- Returns ok, or false and "level" when the player has not reached the level cap yet.
function RebirthLogic.can(profile: any): (boolean, string?)
	if Progression.levelForXp(profile.xp) < Progression.MAX_LEVEL then
		return false, "level"
	end
	return true
end

-- XP bonus from creatures for this many rebirths (fraction, e.g. 0.1).
function RebirthLogic.xpBonus(rebirths: number): number
	return Balance.rebirth.xpPerRebirth * math.clamp(rebirths, 0, Balance.rebirth.maxBonusRebirths)
end

-- Gives every costume earned by progress (rebirths included); returns the ones newly given.
function RebirthLogic.grantRewards(profile: any): { string }
	return CosmeticLogic.grantEarned(profile)
end

-- Restarts the climb: level, weapon power, forge upgrades, skills and the pouch reset; coins become
-- Balance.rebirth.startCoins. Everything else stays. Returns the costumes earned, or nil and
-- the reason when the player may not rebirth yet.
function RebirthLogic.perform(profile: any): ({ string }?, string?)
	local ok, reason = RebirthLogic.can(profile)
	if not ok then
		return nil, reason
	end
	profile.rebirths += 1
	profile.xp = 0
	profile.staffUpgrade = 0
	profile.upgrades = {}
	profile.skills = {}
	profile.skillOffer = {}
	profile.pendingPicks = 0
	profile.crystals = 0
	profile.coins = Balance.rebirth.startCoins
	return RebirthLogic.grantRewards(profile)
end

return RebirthLogic
