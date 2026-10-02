-- The valley's day and night (pure; client/DayNight applies it). Everyone sees the same sky: the
-- time comes from the server clock. Days are long, dusk is golden, and the short night is blue
-- and bright enough to play - the lanterns and fireflies are what make it night.
local DayCycle = {}

DayCycle.LENGTH = 20 * 60 -- seconds for a whole day

-- (share of the cycle, clock time) keyframes; times past 24 run on into the next morning.
DayCycle.keys = {
	{ 0, 7 },
	{ 0.55, 16.5 },
	{ 0.66, 18.5 },
	{ 0.72, 20 },
	{ 0.88, 28.5 },
	{ 0.94, 30 },
	{ 1, 31 },
}

-- Clock time (0-24) at a server time in seconds.
function DayCycle.clock(serverTime: number): number
	local share = (serverTime % DayCycle.LENGTH) / DayCycle.LENGTH
	for index = 2, #DayCycle.keys do
		local before, after = DayCycle.keys[index - 1], DayCycle.keys[index]
		if share <= after[1] then
			local t = (share - before[1]) / (after[1] - before[1])
			return (before[2] + (after[2] - before[2]) * t) % 24
		end
	end
	return DayCycle.keys[1][2]
end

local function ramp(value: number, from: number, to: number): number
	return math.clamp((value - from) / (to - from), 0, 1)
end

-- How much it is night (0 = day, 1 = deep night) at a clock time.
function DayCycle.night(clock: number): number
	if clock >= 12 then
		return ramp(clock, 18.8, 20.6)
	end
	return 1 - ramp(clock, 5, 7)
end

-- How much it is sunset or sunrise (0-1), for the warm orange sky.
function DayCycle.dusk(clock: number): number
	local function bump(center: number, width: number): number
		return math.max(0, 1 - math.abs(clock - center) / width)
	end
	return math.max(bump(18.8, 1.4), bump(6, 1))
end

return DayCycle
