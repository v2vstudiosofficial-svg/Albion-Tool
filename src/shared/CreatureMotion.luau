-- How a creature's body is posed each frame (pure maths, no Roblox API; EnemyService applies it).
-- `motion` is the creature's idle style (EnemyModels.motions), `t` its own clock, and `action`
-- the attack it is getting ready for or doing, with `progress` 0..1 through a wind-up:
--   "charge"  crouches and rears back, trembling harder, then leans into the dash ("dash")
--   "shoot"   puffs up and tips back, then snaps forward when the shot leaves
--   "blink"   sinks and spins faster and faster before hopping
--   "lunge"   close to its target: leans in and hops quicker (contact attackers)
--   "slam"    a boss rises high and tilts back, then drops as the slam lands
--   "orbs"    a boss rises a little and spins, gathering its ring of orbs
--   "dizzy"   knocked back (light wave, after a dash): wobbles in place
-- Returns height (studs), roll, pitch and yaw (radians; negative pitch leans forward) and shake
-- (studs of sideways tremble).
local CreatureMotion = {}

export type Pose = { height: number, roll: number, pitch: number, yaw: number, shake: number }

local function idle(motion: string, t: number): Pose
	local height, roll, pitch = 0, 0, 0
	if motion == "hop" then
		local hop = math.abs(math.sin(t * 4))
		height, pitch = hop * 1.2, (hop - 0.5) * 0.15
	elseif motion == "waddle" then
		height, roll = math.abs(math.sin(t * 6)) * 0.25, math.sin(t * 6) * 0.2
	elseif motion == "float" then
		height, roll = 0.6 + math.sin(t * 1.8) * 0.7, math.sin(t * 1.1) * 0.12
	elseif motion == "wobble" then
		height, roll, pitch = math.abs(math.sin(t * 3)) * 0.5, math.sin(t * 3) * 0.1, math.cos(t * 3) * 0.1
	elseif motion == "bounce" then
		height = math.abs(math.sin(t * 4.5)) * 1.1
	elseif motion == "stomp" then
		height, roll = math.abs(math.sin(t * 2.5)) * 0.35, math.sin(t * 2.5) * 0.07
	else -- hover
		height, roll = math.sin(t * 3) * 0.7, math.sin(t * 1.5) * 0.05
	end
	return { height = height, roll = roll, pitch = pitch, yaw = 0, shake = 0 }
end

function CreatureMotion.pose(motion: string, t: number, action: string?, progress: number?): Pose
	local pose = idle(motion, t)
	local p = math.clamp(progress or 0, 0, 1)
	if action == "charge" then
		-- Idle motion fades out while the creature digs in.
		pose.height = pose.height * (1 - p) - 0.35 * p
		pose.roll *= 1 - p
		pose.pitch = 0.35 * p
		pose.shake = 0.05 + 0.2 * p
	elseif action == "dash" then
		pose.height, pose.roll, pose.pitch = 0, 0, -0.35
	elseif action == "shoot" then
		pose.height = pose.height * (1 - p) + 0.9 * p
		pose.pitch = 0.3 * p
		-- Right at the end it snaps forward, as if spitting the spores out.
		if p > 0.85 then
			pose.pitch = -0.3
		end
		pose.shake = 0.06 * p
	elseif action == "blink" then
		pose.height = -0.6 * p
		pose.yaw = p * p * math.pi * 4
		pose.roll = 0
	elseif action == "lunge" then
		local hop = math.abs(math.sin(t * 7))
		pose.height = hop * 0.8
		pose.pitch = -0.25 - hop * 0.1
	elseif action == "slam" then
		if p < 0.8 then
			pose.height += 3 * (p / 0.8)
			pose.pitch = 0.25 * (p / 0.8)
		else
			-- The last fifth: a fast drop, leaning forward into the ground.
			local drop = (p - 0.8) / 0.2
			pose.height += 3 * (1 - drop)
			pose.pitch = 0.25 - 0.55 * drop
		end
		pose.shake = 0.1 * p
	elseif action == "orbs" then
		pose.height += 1.2 * p
		pose.yaw = p * math.pi * 2
		pose.shake = 0.08 * p
	elseif action == "dizzy" then
		pose.height = 0
		pose.roll = math.sin(t * 12) * 0.2
		pose.pitch = math.cos(t * 9) * 0.1
	end
	return pose
end

return CreatureMotion
