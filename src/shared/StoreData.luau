-- Robux store. Every product has fixed, visible contents (no random rewards). `productId` must be
-- a Developer Product created on the Roblox Creator Dashboard; 0 means "not set up yet" and the
-- store shows it as coming soon. `suggestedPrice` (Robux) is for the dashboard only; the store
-- always shows the live price from Roblox.
return {
	order = { "coins_small", "coins_medium", "coins_large", "xp_boost", "starter", "pass_premium", "crystal_wings", "golden_aura" },
	products = {
		-- Coins worth `coinMinutes` of the buyer's own income at their level, plus a bonus.
		coins_small = { productId = 0, suggestedPrice = 49, nameKey = "store_coins_small", coinMinutes = 10, bonus = 0 },
		coins_medium = { productId = 0, suggestedPrice = 129, nameKey = "store_coins_medium", coinMinutes = 30, bonus = 0.1 },
		coins_large = { productId = 0, suggestedPrice = 349, nameKey = "store_coins_large", coinMinutes = 90, bonus = 0.2 },
		-- Double purify XP for `boostMinutes` (stacks up to maxBoostMinutes).
		xp_boost = { productId = 0, suggestedPrice = 79, nameKey = "store_xp_boost", boostMinutes = 30 },
		-- Once per player: a Brave Sword, the Explorer Cape and 15 minutes of coins.
		starter = { productId = 0, suggestedPrice = 99, nameKey = "store_starter", once = true, weapon = "sword", costume = "explorer_cape", coinMinutes = 15 },
		-- Light Pass premium track for the current season.
		pass_premium = { productId = 0, suggestedPrice = 299, nameKey = "store_pass_premium", passPremium = true },
		-- Costumes sold for Robux.
		crystal_wings = { productId = 0, suggestedPrice = 149, nameKey = "costume_crystal_wings", costume = "crystal_wings" },
		golden_aura = { productId = 0, suggestedPrice = 199, nameKey = "costume_golden_aura", costume = "golden_aura" },
	},
	maxBoostMinutes = 240,
	xpBoostMultiplier = 2,
	-- How many recent purchase ids a profile remembers (duplicate receipt protection).
	purchaseIdCache = 100,
}
