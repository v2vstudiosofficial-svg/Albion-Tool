-- Pure target selection for automatic attacks (no Roblox APIs, tested in Lune).
-- Positions are flat {x, z}; enemies are { id, x, z, size }.
export type Point = { x: number, z: number }
export type Foe = { id: number, x: number, z: number, size: number }
export type Attack = {
	primary: Foe,
	hits: { number },
	-- Unit aim direction and, for "slam", the impact center.
	dirX: number,
	dirZ: number,
	center: Point,
}

local WeaponLogic = {}

local function distance(ax: number, az: number, bx: number, bz: number): number
	local dx, dz = bx - ax, bz - az
	return math.sqrt(dx * dx + dz * dz)
end

-- Nearest foe whose edge is within `range` of the origin; `accept` can veto (line of sight).
function WeaponLogic.nearest(origin: Point, range: number, foes: { Foe }, accept: ((Foe) -> boolean)?): Foe?
	local candidates = {}
	for _, foe in foes do
		local d = distance(origin.x, origin.z, foe.x, foe.z)
		if d <= range + foe.size * 0.5 then
			table.insert(candidates, { foe = foe, d = d })
		end
	end
	table.sort(candidates, function(a, b)
		return a.d < b.d
	end)
	for _, candidate in candidates do
		if accept == nil or accept(candidate.foe) then
			return candidate.foe
		end
	end
	return nil
end

-- Foes along a ray from the origin (sorted by distance), for arrows, thrusts and piercing bolts.
local function alongLine(origin: Point, dirX: number, dirZ: number, length: number, width: number, foes: { Foe }, maxHits: number): { number }
	local found = {}
	for _, foe in foes do
		local rx, rz = foe.x - origin.x, foe.z - origin.z
		local along = rx * dirX + rz * dirZ
		local across = math.abs(rx * dirZ - rz * dirX)
		local reach = foe.size * 0.5
		if along >= -reach and along <= length + reach and across <= width + reach then
			table.insert(found, { id = foe.id, along = along })
		end
	end
	table.sort(found, function(a, b)
		return a.along < b.along
	end)
	local hits = {}
	for index = 1, math.min(#found, maxHits) do
		table.insert(hits, found[index].id)
	end
	return hits
end

local function rotate(dirX: number, dirZ: number, degrees: number): (number, number)
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return dirX * c - dirZ * s, dirX * s + dirZ * c
end

-- Picks the primary target and every foe the attack hits. `facing` is used when the primary
-- target stands exactly on the origin. Returns nil when nothing is in range.
function WeaponLogic.plan(weapon: any, origin: Point, facing: Point, foes: { Foe }, accept: ((Foe) -> boolean)?): Attack?
	local primary = WeaponLogic.nearest(origin, weapon.range, foes, accept)
	if not primary then
		return nil
	end
	local dirX, dirZ = primary.x - origin.x, primary.z - origin.z
	local length = math.sqrt(dirX * dirX + dirZ * dirZ)
	if length < 0.01 then
		dirX, dirZ = facing.x, facing.z
		length = math.max(math.sqrt(dirX * dirX + dirZ * dirZ), 0.01)
	end
	dirX, dirZ = dirX / length, dirZ / length

	local hits: { number } = {}
	local center = { x = primary.x, z = primary.z }
	local style = weapon.style
	if style == "bolt" or style == "arrow" then
		hits = { primary.id }
	elseif style == "fan" then
		-- The middle dagger always flies at the target; the side ones hit whatever they meet first.
		local count = weapon.count or 3
		for index = 1, count do
			local angle = (index - (count + 1) / 2) * weapon.spread
			if angle == 0 then
				table.insert(hits, primary.id)
			else
				local x, z = rotate(dirX, dirZ, angle)
				local first = alongLine(origin, x, z, weapon.range, weapon.width, foes, 1)[1]
				if first then
					table.insert(hits, first)
				end
			end
		end
	elseif style == "thrust" or style == "pierce" then
		hits = alongLine(origin, dirX, dirZ, weapon.range, weapon.width, foes, weapon.maxHits)
		if #hits == 0 then
			hits = { primary.id }
		end
	elseif style == "arc" then
		local halfArc = math.cos(math.rad(weapon.arc / 2))
		for _, foe in foes do
			local rx, rz = foe.x - origin.x, foe.z - origin.z
			local d = math.sqrt(rx * rx + rz * rz)
			if d <= weapon.range + foe.size * 0.5 and (d < 0.01 or (rx * dirX + rz * dirZ) / d >= halfArc) then
				table.insert(hits, foe.id)
			end
		end
	elseif style == "spin" then
		for _, foe in foes do
			if distance(origin.x, origin.z, foe.x, foe.z) <= weapon.range + foe.size * 0.5 then
				table.insert(hits, foe.id)
			end
		end
	elseif style == "slam" then
		for _, foe in foes do
			if distance(center.x, center.z, foe.x, foe.z) <= weapon.radius + foe.size * 0.5 then
				table.insert(hits, foe.id)
			end
		end
	else
		error("unknown weapon style " .. tostring(style))
	end
	return { primary = primary, hits = hits, dirX = dirX, dirZ = dirZ, center = center }
end

return WeaponLogic
