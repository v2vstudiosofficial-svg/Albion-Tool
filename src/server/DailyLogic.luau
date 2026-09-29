-- Pure daily-gift rules: one small coin gift per calendar day (UTC), no streaks and nothing lost
-- by skipping days. The gift is worth a few minutes of the player's current income.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

local DailyLogic = {}

local DAY_SECONDS = 86400

-- Whole days since 1970 (UTC) for an os.time() value.
function DailyLogic.dayOf(now: number): number
	return math.floor(now / DAY_SECONDS)
end

-- A saved day that is still ahead of tomorrow (a bad clock when it was saved) never blocks gifts.
function DailyLogic.ready(profile: any, now: number): boolean
	local today = DailyLogic.dayOf(now)
	return profile.dailyDay < today or profile.dailyDay > today + 1
end

function DailyLogic.reward(level: number): number
	return Progression.incomeCoins(level, Balance.daily.coinMinutes)
end

-- Takes today's gift. Returns the coins paid, or nil when today's gift was already taken.
function DailyLogic.claim(profile: any, now: number, level: number): number?
	if not DailyLogic.ready(profile, now) then
		return nil
	end
	local coins = DailyLogic.reward(level)
	profile.dailyDay = DailyLogic.dayOf(now)
	profile.coins += coins
	return coins
end

return DailyLogic
