-- Pure store rules: what each product gives (fixed contents) and duplicate-receipt protection.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local StoreData = if Shared then require(Shared.StoreData) else require("../shared/StoreData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local CosmeticLogic = if script then require(script.Parent.CosmeticLogic) else require("./CosmeticLogic")
local PassLogic = if script then require(script.Parent.PassLogic) else require("./PassLogic")

export type Granted = { product: string, coins: number, weapon: string?, costume: string?, boostMinutes: number?, passPremium: boolean? }

local StoreLogic = {}

-- Remembers a receipt's purchase id; false if it was already granted.
function StoreLogic.remember(profile: any, purchaseId: string): boolean
	if table.find(profile.purchaseIds, purchaseId) then
		return false
	end
	table.insert(profile.purchaseIds, purchaseId)
	while #profile.purchaseIds > StoreData.purchaseIdCache do
		table.remove(profile.purchaseIds, 1)
	end
	return true
end

-- Coins a coin product gives right now (shown in the store before buying).
function StoreLogic.coinsFor(productKey: string, level: number): number
	local product = StoreData.products[productKey]
	if not product or not product.coinMinutes then
		return 0
	end
	return Progression.incomeCoins(level, product.coinMinutes, product.bonus)
end

-- Can this profile buy the product now? One-time products, owned costumes, an owned premium pass
-- and an XP boost already near its cap can't be bought again (the store greys them out).
function StoreLogic.available(profile: any, productKey: string, now: number): boolean
	local product = StoreData.products[productKey]
	if not product then
		return false
	end
	if product.boostMinutes and profile.boostUntil - now > (StoreData.maxBoostMinutes - product.boostMinutes) * 60 then
		return false
	end
	if product.once and profile.oneTime[productKey] then
		return false
	end
	if product.costume and not product.weapon and profile.ownedCosmetics[product.costume] then
		return false
	end
	if product.passPremium then
		PassLogic.ensureSeason(profile)
		if profile.pass.premium then
			return false
		end
	end
	return true
end

-- Gives a product's contents. Anything that can't be given (already owned) becomes coins, so a
-- paid purchase never gives nothing.
function StoreLogic.grant(profile: any, productKey: string, level: number, now: number): Granted?
	local product = StoreData.products[productKey]
	if not product then
		return nil
	end
	local granted: Granted = { product = productKey, coins = StoreLogic.coinsFor(productKey, level) }
	local refund = Progression.incomeCoins(level, 20)
	if product.once then
		profile.oneTime[productKey] = true
	end
	if product.weapon then
		if profile.ownedWeapons[product.weapon] then
			granted.coins += refund
		else
			profile.ownedWeapons[product.weapon] = true
			granted.weapon = product.weapon
		end
	end
	if product.costume then
		if CosmeticLogic.grant(profile, product.costume) then
			granted.costume = product.costume
		else
			granted.coins += refund
		end
	end
	if product.boostMinutes then
		local start = math.max(now, profile.boostUntil)
		local limit = now + StoreData.maxBoostMinutes * 60
		profile.boostUntil = math.min(limit, start + product.boostMinutes * 60)
		granted.boostMinutes = product.boostMinutes
	end
	if product.passPremium then
		PassLogic.ensureSeason(profile)
		if profile.pass.premium then
			granted.coins += refund
		else
			profile.pass.premium = true
			granted.passPremium = true
		end
	end
	profile.coins += granted.coins
	return granted
end

function StoreLogic.boostActive(profile: any, now: number): boolean
	return profile.boostUntil > now
end

return StoreLogic
