-- Pure costume rules: buying with coins, granting, wearing one costume per slot.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local CosmeticData = if Shared then require(Shared.CosmeticData) else require("../shared/CosmeticData")

local CosmeticLogic = {}

-- Adds a costume; returns false when it is unknown or already owned.
function CosmeticLogic.grant(profile: any, id: string): boolean
	if not CosmeticData.costumes[id] or profile.ownedCosmetics[id] then
		return false
	end
	profile.ownedCosmetics[id] = true
	return true
end

-- Gives every costume the player has earned by progress: rebirths, the best Shadow Tower floor or
-- a purified Legendary Shadow. Returns the ids newly given (in CosmeticData order).
function CosmeticLogic.grantEarned(profile: any): { string }
	local given = {}
	for _, id in CosmeticData.order do
		local source = CosmeticData.costumes[id].source
		local earned = (source.rebirth ~= nil and profile.rebirths >= source.rebirth)
			or (source.tower ~= nil and profile.towerBest >= source.tower)
			or (source.legend ~= nil and profile.legends[source.legend] == true)
		if earned and CosmeticLogic.grant(profile, id) then
			table.insert(given, id)
		end
	end
	return given
end

-- Buys a coin-priced costume. Returns ok, or false and "unknown" | "owned" | "notForCoins" | "coins".
function CosmeticLogic.buy(profile: any, id: string): (boolean, string?)
	local costume = CosmeticData.costumes[id]
	if not costume then
		return false, "unknown"
	end
	if profile.ownedCosmetics[id] then
		return false, "owned"
	end
	local price = costume.source.coins
	if not price then
		return false, "notForCoins"
	end
	if profile.coins < price then
		return false, "coins"
	end
	profile.coins -= price
	profile.ownedCosmetics[id] = true
	return true
end

-- Wears an owned costume in its slot, or clears a slot with id "" (slot required then).
function CosmeticLogic.equip(profile: any, id: string, slot: string?): boolean
	if id == "" then
		if not slot or not table.find(CosmeticData.slots, slot) then
			return false
		end
		profile.equippedCosmetics[slot] = nil
		return true
	end
	local costume = CosmeticData.costumes[id]
	if not costume or not profile.ownedCosmetics[id] then
		return false
	end
	profile.equippedCosmetics[costume.slot] = id
	return true
end

return CosmeticLogic
