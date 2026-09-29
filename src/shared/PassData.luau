-- Light Pass: a season track earned by playing. Every tier needs `xpPerTier` Pass XP. Each tier
-- has a free reward and a premium reward (premium = the pass_premium product for this season).
-- Rewards are fixed (never random): coins as minutes of the player's own income
-- (Progression.coinsPerMinute), or a costume. Bump `season` to start a new season (progress resets).
local PassData = {
	season = 1,
	tiers = 50,
	xpPerTier = 1000,
	-- Pass XP for things players do.
	xp = { purify = 10, elite = 50, rift = 200, quest = 300, chest = 100, legend = 500, levelUp = 100 },
	rewards = {},
}

local costumeTiers = {} -- [track][tier] = costume id
local CosmeticData = if script then require(script.Parent.CosmeticData) else require("./CosmeticData")
for id, costume in CosmeticData.costumes do
	local source = costume.source
	if source.pass then
		costumeTiers[source.track] = costumeTiers[source.track] or {}
		costumeTiers[source.track][source.pass] = id
	end
end

for tier = 1, PassData.tiers do
	local free = costumeTiers.free and costumeTiers.free[tier]
	local premium = costumeTiers.premium and costumeTiers.premium[tier]
	PassData.rewards[tier] = {
		free = if free then { costume = free } else { coinMinutes = if tier % 10 == 0 then 10 else 3 },
		premium = if premium then { costume = premium } else { coinMinutes = if tier % 10 == 0 then 25 else 8 },
	}
end

return PassData
