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

-- An arrow on the screen edge toward a point that is off screen. `px, py` is the point's screen
-- position, `inFront` false when it is behind the camera (its projection is then mirrored).
-- Returns where the arrow sits (inside the edge by `margin`, `top` from the top edge and `side`
-- from the left and right ones, which can keep it clear of the HUD there) and its angle in degrees
-- (0 = right, 90 = down), or nil when the point is inside that frame anyway.
function MapLogic.edgeArrow(px: number, py: number, inFront: boolean, width: number, height: number, margin: number, top: number?, side: number?): (number?, number?, number?)
	local cx, cy = width / 2, height / 2
	local topMargin = math.min(top or margin, cy - 1)
	local sideMargin = math.min(side or margin, cx - 1)
	if not inFront then
		px, py = width - px, height - py
	elseif px >= sideMargin and px <= width - sideMargin and py >= topMargin and py <= height - margin then
		return nil, nil, nil
	end
	local dx, dy = px - cx, py - cy
	if dx == 0 and dy == 0 then
		dy = 1
	end
	local reachY = if dy < 0 then cy - topMargin else cy - margin
	local scale = math.min((cx - sideMargin) / math.max(math.abs(dx), 1e-6), reachY / math.max(math.abs(dy), 1e-6))
	return cx + dx * scale, cy + dy * scale, math.deg(math.atan2(dy, dx))
end

-- Compass heading of a look direction, in degrees clockwise from north (0 = -Z, 90 = +X).
function MapLogic.heading(lookX: number, lookZ: number): number
	return math.deg(math.atan2(lookX, -lookZ)) % 360
end

-- The creature levels of a place (by its music theme, see MusicLogic): the lowest and highest
-- over its zones, or nil for places without creature zones (the village, lairs, the tower).
local THEME_AREAS = { wilds = { "glade", "grove", "hollow" }, marsh = { "marsh" }, peaks = { "peaks" }, citadel = { "citadel", "keep" } }
function MapLogic.placeLevels(theme: string): (number?, number?)
	local low, high = nil, nil
	for _, areaId in THEME_AREAS[theme] or {} do
		local levels = WorldData.areas[areaId].levels
		low = math.min(low or math.huge, levels[1])
		high = math.max(high or 0, levels[2])
	end
	return low, high
end

-- Entering a place whose weakest creatures are this many levels above the player warns them.
MapLogic.DANGER_GAP = 5

return MapLogic
