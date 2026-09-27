-- Post-story goals shown once every quest is done: an upgrade you can afford now, then the
-- level cap, then the remaining staff tiers. Pure so the HUD, waypoint and tests agree.
-- Staff values are StaffTier indices (0-based, like the profile); add 1 when displaying.
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
		return { kind = "level", target = Progression.MAX_LEVEL, current = level }
	end
	if cost then
		return { kind = "staff", target = staffUpgrade + 1, current = staffUpgrade, affordable = false, missing = cost - coins }
	end
	return { kind = "done" }
end

return Goals
