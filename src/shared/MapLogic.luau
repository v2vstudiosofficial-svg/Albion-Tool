-- Pure minimap maths: where a world point lands on the map. North is up (-Z), east is right (+X).
-- "near" follows the player over a small area; "world" shows the whole valley.
local WorldData = if script then require(script.Parent.WorldData) else require("./WorldData")

local MapLogic = {}

-- The area the "world" view covers (studs): every enemy zone (center +- radius), the spawn and the
-- NPCs, plus a margin. Derived from WorldData so new zones are never cropped.
local BOUNDS_MARGIN = 15
local function computeBounds()
	local bounds = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	local function include(x: number, z: number, radius: number)
		bounds.minX = math.min(bounds.minX, x - radius)
		bounds.maxX = math.max(bounds.maxX, x + radius)
		bounds.minZ = math.min(bounds.minZ, z - radius)
		bounds.maxZ = math.max(bounds.maxZ, z + radius)
	end
	for _, area in WorldData.areas do
		include(area.center[1], area.center[3], area.radius)
	end
	include(WorldData.spawn[1], WorldData.spawn[3], 0)
	for _, npc in WorldData.npcs do
		include(npc.position[1], npc.position[3], 0)
	end
	return {
		minX = bounds.minX - BOUNDS_MARGIN,
		maxX = bounds.maxX + BOUNDS_MARGIN,
		minZ = bounds.minZ - BOUNDS_MARGIN,
		maxZ = bounds.maxZ + BOUNDS_MARGIN,
	}
end
MapLogic.bounds = computeBounds()
-- How many studs the "near" view shows from the player to each edge.
MapLogic.nearRadius = 90

export type View = { centerX: number, centerZ: number, studsPerPixel: number }

-- mode "near" (centered on the player) or "world" (the whole valley); `size` is the map's side in pixels.
function MapLogic.view(mode: string, playerX: number, playerZ: number, size: number): View
	if mode == "world" then
		local b = MapLogic.bounds
		return {
			centerX = (b.minX + b.maxX) / 2,
			centerZ = (b.minZ + b.maxZ) / 2,
			studsPerPixel = math.max(b.maxX - b.minX, b.maxZ - b.minZ) / size,
		}
	end
	return { centerX = playerX, centerZ = playerZ, studsPerPixel = MapLogic.nearRadius * 2 / size }
end

-- Map pixel (from the top-left corner) of a world point.
function MapLogic.toMap(view: View, size: number, x: number, z: number): (number, number)
	return size / 2 + (x - view.centerX) / view.studsPerPixel, size / 2 + (z - view.centerZ) / view.studsPerPixel
end

function MapLogic.inside(size: number, px: number, py: number, margin: number): boolean
	return px >= margin and px <= size - margin and py >= margin and py <= size - margin
end

-- Does a disc of `radius` pixels centered at (px, py) touch the square map at all?
function MapLogic.circleVisible(size: number, px: number, py: number, radius: number): boolean
	return px >= -radius and px <= size + radius and py >= -radius and py <= size + radius
end

-- A point outside the map is pulled onto its edge along the line from the center (so a goal that is
-- far away still shows which way to go). Points inside stay where they are.
function MapLogic.clamp(size: number, px: number, py: number, margin: number): (number, number, boolean)
	if MapLogic.inside(size, px, py, margin) then
		return px, py, false
	end
	local half = size / 2
	local dx, dy = px - half, py - half
	local limit = half - margin
	local scale = limit / math.max(math.abs(dx), math.abs(dy))
	return half + dx * scale, half + dy * scale, true
end

-- Compass heading of a look direction, in degrees clockwise from north (0 = -Z, 90 = +X).
function MapLogic.heading(lookX: number, lookZ: number): number
	return math.deg(math.atan2(lookX, -lookZ)) % 360
end

return MapLogic
