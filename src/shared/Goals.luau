-- Post-story goals shown once every quest is done: a weapon power level you can afford now,
-- then the next level milestone (chest or floating slot) up to the cap, then the remaining power
-- levels. Pure so the HUD, waypoint and tests agree. Power values are weapon power levels.
local Progression = if script then require(script.Parent.Progression) else require("./Progression")

local Goals = {}

export type Goal = {
	kind: "staff" | "level" | "done",
	target: number?,
	current: number?,
	affordable: boolean?,
	missing: number?,
}

function Goals.next(xp: number, coins: number, staffUpgrade: number): Goal
	local level = Progression.levelForXp(xp)
	local cost = Progression.nextStaffCost(staffUpgrade)
	if cost and coins >= cost then
		return { kind = "staff", target = staffUpgrade + 1, current = staffUpgrade, affordable = true, missing = 0 }
	end
	if level < Progression.MAX_LEVEL then
		return { kind = "level", target = Progression.nextMilestone(level), current = level }
	end
	if cost then
		return { kind = "staff", target = staffUpgrade + 1, current = staffUpgrade, affordable = false, missing = cost - coins }
	end
	return { kind = "done" }
end

return Goals
