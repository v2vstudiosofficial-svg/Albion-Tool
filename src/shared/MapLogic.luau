-- Pure minimap maths: where a world point lands on the map. North is up (-Z), east is right (+X).
-- "near" follows the player over a small area; "world" shows the whole valley.
local MapLogic = {}

-- The area the "world" view covers (studs); the Shadow Tower is the far west, the Keep the far east.
MapLogic.bounds = { minX = -375, maxX = 275, minZ = -345, maxZ = 90 }
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
