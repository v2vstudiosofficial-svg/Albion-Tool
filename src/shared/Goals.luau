-- Post-story goals shown once every quest is done: finish staff tiers you can afford, then
-- reach the level cap. Pure so the HUD, waypoint and tests agree.
local Balance = if script then require(script.Parent.Balance) else require("./Balance")
local Progression = if script then require(script.Parent.Progression) else require("./Progression")

local Goals = {}

export type Goal = { kind: "staff" | "level" | "done", target: number?, current: number?, affordable: boolean? }

function Goals.next(xp: number, coins: number, staffUpgrade: number): Goal
	local level = Progression.levelForXp(xp)
	local maxTier = Progression.maxStaffUpgrade()
	local nextTier = Balance.staff.tiers[staffUpgrade + 2]
	if nextTier and coins >= nextTier.cost then
		return { kind = "staff", target = staffUpgrade + 2, current = staffUpgrade + 1, affordable = true }
	end
	if level < Progression.MAX_LEVEL then
		return { kind = "level", target = Progression.MAX_LEVEL, current = level }
	end
	if staffUpgrade < maxTier then
		return { kind = "staff", target = staffUpgrade + 2, current = staffUpgrade + 1, affordable = false }
	end
	return { kind = "done" }
end

return Goals
