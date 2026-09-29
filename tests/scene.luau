-- Run: lune run tests/scene
-- Executes MapBuilder and EnemyModels against real Lune Roblox Instances (which reject unknown
-- properties and wrong value types) and checks the scene builder's re-run guarantees:
-- nothing is duplicated and unrelated manual edits survive.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")

-- Deterministic stand-in for Roblox's Random (only NextNumber/NextInteger are used).
local Random = {}
function Random.new(seed: number)
	local state = seed
	local function step(): number
		state = (state * 1103515245 + 12345) % 2147483648
		return state / 2147483648
	end
	return {
		NextNumber = function(_, min: number, max: number)
			return min + (max - min) * step()
		end,
		NextInteger = function(_, min: number, max: number)
			return math.floor(min + (max - min + 1) * step())
		end,
	}
end

-- Instance-path proxies so `game:GetService("ReplicatedStorage").Shared.X` can be required.
local proxyPaths = setmetatable({}, { __mode = "k" })
local function pathProxy(path: string)
	local proxy = setmetatable({}, {
		__index = function(_, key)
			return pathProxy(path .. "/" .. key)
		end,
	})
	proxyPaths[proxy] = path
	return proxy
end

local fakeGame = {
	GetService = function(_, name: string)
		if name == "ReplicatedStorage" then
			return pathProxy("RS")
		end
		return game:GetService(name)
	end,
}

local modules = {}
local loadModule

local function resolve(fromDir: string, target: any): string
	local proxyPath = proxyPaths[target]
	if proxyPath then
		local shared = string.match(proxyPath, "^RS/Shared/(.+)$")
		assert(shared, "unsupported instance require: " .. proxyPath)
		return "src/shared/" .. shared .. ".luau"
	end
	assert(type(target) == "string", "unsupported require target")
	local path = fromDir
	for segment in string.gmatch(target, "[^/]+") do
		if segment == ".." then
			path = string.match(path, "^(.*)/[^/]+$") or ""
		elseif segment ~= "." then
			path = path .. "/" .. segment
		end
	end
	return path .. ".luau"
end

function loadModule(path: string)
	if modules[path] ~= nil then
		return modules[path]
	end
	local dir = string.match(path, "^(.*)/[^/]+$")
	local env = {
		game = fakeGame,
		workspace = workspace,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Enum = roblox.Enum,
		Random = Random,
		require = function(target)
			return loadModule(resolve(dir, target))
		end,
	}
	local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local result = chunk()
	modules[path] = result
	return result
end

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function eq(actual, expected, message: string?)
	if actual ~= expected then
		error(`{message or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

-- Lune keeps Position and CFrame as separate stored properties; read whichever was set.
local function positionOf(part): any
	local ok, value = pcall(function()
		return part.Position
	end)
	if ok and value then
		return value
	end
	return part.CFrame.Position
end

local MapBuilder = loadModule("src/server/MapBuilder.luau")
local EnemyModels = loadModule("src/server/EnemyModels.luau")
local WeaponModels = loadModule("src/shared/WeaponModels.luau")
local WeaponData = loadModule("src/shared/WeaponData.luau")
local WorldData = loadModule("src/shared/WorldData.luau")
local Balance = loadModule("src/shared/Balance.luau")

local map
test("MapBuilder builds without runtime errors", function()
	map = MapBuilder.build()
	eq(map.Name, "LanternValleyMap")
	eq(map.Parent, workspace)
end)

test("rebuilding does not duplicate anything", function()
	local before = #map:GetDescendants()
	MapBuilder.build()
	MapBuilder.build()
	eq(#map:GetDescendants(), before, "descendant count")
	eq(#workspace:GetChildren(), 1, "single map folder")
end)

test("rebuilding keeps manual edits and restores only missing generated parts", function()
	local custom = roblox.Instance.new("Part")
	custom.Name = "MyCustomRock"
	custom.Parent = map.Forest
	local walls = map.Village.House1.Walls
	local editedColor = roblox.Color3.fromRGB(10, 200, 30)
	walls.Color = editedColor
	map.Village.Bush1:Destroy()
	MapBuilder.build()
	eq(map.Forest:FindFirstChild("MyCustomRock"), custom, "custom part kept")
	eq(walls.Color, editedColor, "edited property kept")
	assert(map.Village:FindFirstChild("Bush1"), "missing generated part restored")
end)

test("key gameplay objects exist with the right classes", function()
	eq(map.Village.VillageSpawn.ClassName, "SpawnLocation")
	for name in WorldData.npcs do
		local npc = map.Village:FindFirstChild(name)
		assert(npc and npc:IsA("Model"), "npc " .. name)
		eq(npc.PrimaryPart, npc.Body, name .. " primary part")
		eq(npc.Body.TalkPrompt.ClassName, "ProximityPrompt", name .. " prompt")
		eq(npc.Body.Anchored, true, name .. " anchored")
	end
	assert(map.Ruins:FindFirstChild("GateArch"), "gate")
	assert(map.Ruins:FindFirstChild("ArenaFloor"), "arena")
	for _, name in { "NorthWall", "SouthWall", "WestWall", "EastWall" } do
		assert(map.Ground:FindFirstChild(name), name)
	end
end)

test("every generated part is anchored", function()
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "MyCustomRock" then
			assert(descendant.Anchored, descendant:GetFullName() .. " is not anchored")
		end
	end
end)

test("trees keep clear of the path, zones, landmarks and flowers", function()
	local trees = 0
	for _, child in map.Forest:GetChildren() do
		local index = string.match(child.Name, "^Tree_(%d+)_Trunk$")
		if index then
			trees += 1
			local position = positionOf(child)
			for _, flower in WorldData.flowers do
				local dx, dz = position.X - flower[1], position.Z - flower[3]
				assert(math.sqrt(dx * dx + dz * dz) >= 5, "tree on a flower: " .. child.Name)
			end
			for _, landmark in WorldData.landmarks do
				local p = landmark.position
				local dx, dz = position.X - p[1], position.Z - p[3]
				assert(math.sqrt(dx * dx + dz * dz) >= 13, "tree on a landmark: " .. child.Name)
			end
			for name, area in WorldData.areas do
				local c = area.center
				local dx, dz = position.X - c[1], position.Z - c[3]
				assert(math.sqrt(dx * dx + dz * dz) >= area.radius, "tree in zone " .. name)
			end
			assert(math.abs(position.X - math.sin(position.Z * 0.06) * 4) >= 10, "tree on the path: " .. child.Name)
		end
	end
	assert(trees >= 30 and trees <= 60, "tree count " .. trees)
end)

test("props keep clear of the path and fight zones", function()
	local checked = 0
	for _, child in map.Forest.Props:GetChildren() do
		if string.match(child.Name, "^Mushroom_%d+_Stem$") or string.match(child.Name, "^Rock_%d+$") then
			checked += 1
			local position = positionOf(child)
			assert(math.abs(position.X - math.sin(position.Z * 0.06) * 4) >= 7, "prop on the path: " .. child.Name)
			for name, area in WorldData.areas do
				local c = area.center
				local dx, dz = position.X - c[1], position.Z - c[3]
				assert(math.sqrt(dx * dx + dz * dz) >= area.radius, "prop in zone " .. name .. ": " .. child.Name)
			end
		end
	end
	assert(checked >= 30, "forest props placed: " .. checked)
	local arena = WorldData.areas.arena.center
	for _, child in map.Ruins.Props:GetChildren() do
		if string.match(child.Name, "^Rubble_") then
			local position = positionOf(child)
			local dx, dz = position.X - arena[1], position.Z - arena[3]
			assert(math.sqrt(dx * dx + dz * dz) >= 40, "rubble in the arena: " .. child.Name)
		end
	end
end)

test("map stays within a mobile-friendly part budget", function()
	local parts, lights, emitters = 0, 0, 0
	for _, descendant in map:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		elseif descendant:IsA("Light") then
			lights += 1
		elseif descendant:IsA("ParticleEmitter") then
			emitters += 1
		end
	end
	print(`  map budget: {parts} parts, {lights} lights, {emitters} particle emitters`)
	assert(parts <= 900, "too many parts: " .. parts)
	assert(lights <= 6, "too many static lights: " .. lights)
	assert(emitters <= 10, "too many static emitters: " .. emitters)
end)

test("gate opening lines up with the vine barrier", function()
	local gate = WorldData.gate
	for _, vine in WorldData.vines do
		assert(math.abs(vine[1]) < gate.halfWidth, "vine inside opening")
		eq(vine[3], gate.z, "vine on gate line")
	end
	for _, pillar in { map.Ruins.GatePillar1, map.Ruins.GatePillar2 } do
		assert(math.abs(positionOf(pillar).X) >= gate.halfWidth, "pillar outside opening")
	end
end)

test("enemy models build for every enemy kind", function()
	for kind, stats in Balance.enemies do
		local model, body = EnemyModels.build(kind, stats, roblox.CFrame.new(0, 5, 0))
		eq(model.PrimaryPart, body, kind .. " primary")
		eq(body.Anchored, true, kind .. " body anchored")
		local welded = 0
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") and descendant ~= body then
				eq(descendant.Anchored, false, kind .. " decoration unanchored")
				eq(descendant.CanCollide, false, kind .. " decoration no collide")
				local weld = descendant:FindFirstChildOfClass("WeldConstraint")
				assert(weld and weld.Part0 == body and weld.Part1 == descendant, kind .. " decoration welded to body")
				welded += 1
			end
		end
		assert(welded >= 2, kind .. " has decorations")
		model:Destroy()
	end
end)

test("weapon models build for all eight weapons, welded in hand or anchored when floating", function()
	for _, weaponId in WeaponData.order do
		for _, anchored in { false, true } do
			local base = roblox.CFrame.new(3, 4, 5)
			local model = WeaponModels.build(weaponId, base, anchored, anchored)
			local grip = model.PrimaryPart
			assert(grip and grip.Name == "Grip", weaponId .. " grip")
			eq(grip.CFrame, base, weaponId .. " grip at the base frame")
			eq(model:GetAttribute("WeaponId"), weaponId)
			local parts, glow = 0, false
			for _, part in model:GetChildren() do
				if part:IsA("BasePart") and part ~= grip then
					parts += 1
					glow = glow or part.Name == "Glow" or string.find(part.Name, "Blade") ~= nil
					eq(part.CanCollide, false, weaponId .. " no collide")
					eq(part.Anchored, anchored, weaponId .. " anchored flag")
					local weld = part:FindFirstChildOfClass("WeldConstraint")
					if anchored then
						eq(weld, nil, weaponId .. " floating parts need no welds")
					else
						assert(weld and weld.Part0 == grip and weld.Part1 == part, weaponId .. " welded to grip")
					end
				end
			end
			assert(parts >= 2 and parts <= 12, weaponId .. " stays cheap: " .. parts .. " parts")
			assert(glow, weaponId .. " has a glowing part")
			model:Destroy()
		end
	end
end)

test("chest spots sit on open ground (not inside walls, trees or rocks)", function()
	local WorldData = loadModule("src/shared/WorldData.luau")
	local map = workspace:FindFirstChild("LanternValleyMap")
	assert(map, "map built")
	for spotId, spot in WorldData.chests do
		local x, z = spot.position[1], spot.position[3]
		for _, part in map:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide and part.Size.X < 40 and part.Size.Z < 40 then
				local position = positionOf(part)
				-- Upright cylinders lie along X (height) with Y/Z as the diameter; blocks are
				-- treated as unrotated boxes.
				local cylinder = part:IsA("Part") and part.Shape == roblox.Enum.PartType.Cylinder
				local width = if cylinder then math.max(part.Size.Y, part.Size.Z) else math.max(part.Size.X, part.Size.Z)
				local height = if cylinder then part.Size.X else part.Size.Y
				local reach = width / 2 + 1.6
				local bottom = position.Y - height / 2
				local dx, dz = position.X - x, position.Z - z
				if bottom < 2 and math.sqrt(dx * dx + dz * dz) < reach then
					error(`{spotId} overlaps {part:GetFullName()}`)
				end
			end
		end
	end
end)

print(`scene tests: {passed} passed, {failed} failed`)
if failed > 0 then
	error("scene tests failed")
end
