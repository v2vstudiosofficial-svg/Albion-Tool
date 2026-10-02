-- Pure helpers for how fights read on screen (no Roblox API; the client draws them):
--   threat: how a creature's level compares with the player's, for the color of its name.
--   streak: purifications chained close together (a "combo" counter; cosmetic only).
local CombatFeel = {}

-- A creature this many levels above the player is "tough", this many more is "deadly"; this many
-- below is "trivial".
CombatFeel.TOUGH = 3
CombatFeel.DEADLY = 6
CombatFeel.TRIVIAL = -5

function CombatFeel.threat(playerLevel: number, enemyLevel: number): string
	local diff = enemyLevel - playerLevel
	if diff >= CombatFeel.DEADLY then
		return "deadly"
	elseif diff >= CombatFeel.TOUGH then
		return "tough"
	elseif diff <= CombatFeel.TRIVIAL then
		return "trivial"
	end
	return "even"
end

-- A streak keeps going while each purification comes within WINDOW seconds of the last one.
CombatFeel.WINDOW = 4
-- Counts that earn a little celebration.
CombatFeel.MILESTONES = { 10, 25, 50, 100, 250, 500 }

export type Streak = { count: number, last: number }

function CombatFeel.newStreak(): Streak
	return { count = 0, last = -math.huge }
end

function CombatFeel.alive(streak: Streak, now: number): boolean
	return streak.count > 0 and now - streak.last <= CombatFeel.WINDOW
end

-- Adds `amount` purifications at time `now`; returns the new count and the milestone reached on
-- the way (the largest one passed), if any.
function CombatFeel.add(streak: Streak, now: number, amount: number): (number, number?)
	if not CombatFeel.alive(streak, now) then
		streak.count = 0
	end
	local before = streak.count
	streak.count += math.max(0, amount)
	streak.last = now
	local reached = nil
	for _, milestone in CombatFeel.MILESTONES do
		if before < milestone and streak.count >= milestone then
			reached = milestone
		end
	end
	return streak.count, reached
end

return CombatFeel
