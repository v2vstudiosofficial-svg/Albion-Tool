-- Pure skill-card rules: every level-up earns a pick; the player chooses one of up to three
-- offered skills that are not maxed yet. When nothing is left to learn the only card is a coin
-- gift ("coins"). The offer is saved, so leaving and rejoining never rerolls it.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local SkillData = if Shared then require(Shared.SkillData) else require("../shared/SkillData")

local SkillLogic = {}

SkillLogic.COINS = "coins"

-- Skills that can still gain a rank, in SkillData order.
function SkillLogic.available(profile: any): { string }
	local list = {}
	for _, skillId in SkillData.order do
		if (profile.skills[skillId] or 0) < SkillData.skills[skillId].maxRank then
			table.insert(list, skillId)
		end
	end
	return list
end

-- Draws a fresh offer of distinct skills (or the coin card when none are left).
function SkillLogic.roll(profile: any, rng: () -> number): { string }
	local pool = SkillLogic.available(profile)
	if #pool == 0 then
		return { SkillLogic.COINS }
	end
	local offer = {}
	while #offer < SkillData.offerCount and #pool > 0 do
		local index = math.floor(rng() * #pool) + 1
		table.insert(offer, table.remove(pool, index) :: string)
	end
	return offer
end

-- Adds picks for levels gained and makes sure an offer is waiting.
function SkillLogic.grantPicks(profile: any, count: number, rng: () -> number)
	if count <= 0 then
		return
	end
	profile.pendingPicks += count
	if #profile.skillOffer == 0 then
		profile.skillOffer = SkillLogic.roll(profile, rng)
	end
end

-- Picks one card from the current offer. Returns ok and, for the coin card, the coins given.
function SkillLogic.pick(profile: any, choice: string, rng: () -> number): (boolean, number?)
	if profile.pendingPicks <= 0 or not table.find(profile.skillOffer, choice) then
		return false
	end
	local coins = nil
	if choice == SkillLogic.COINS then
		coins = SkillData.fallbackCoins
		profile.coins += coins
	else
		local skill = SkillData.skills[choice]
		local current = profile.skills[choice] or 0
		if current >= skill.maxRank then
			return false
		end
		profile.skills[choice] = current + 1
	end
	profile.pendingPicks -= 1
	profile.skillOffer = if profile.pendingPicks > 0 then SkillLogic.roll(profile, rng) else {}
	return true, coins
end

return SkillLogic
