-- Idempotent scene builder: only creates instances that are missing by name and never
-- deletes or overwrites anything, so manual Studio edits survive re-runs.
-- Bake into the place from the Studio command bar:
--   require(game.ServerScriptService.Server.MapBuilder).build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Strings = require(Shared.Strings)
local WorldData = require(Shared.WorldData)

local MAP_NAME = "LanternValleyMap"

local COLOR = {
	grass = Color3.fromRGB(125, 195, 95),
	forest = Color3.fromRGB(75, 145, 85),
	ruins = Color3.fromRGB(150, 145, 160),
	path = Color3.fromRGB(220, 185, 130),
	plaza = Color3.fromRGB(200, 195, 185),
	wall = Color3.fromRGB(245, 228, 195),
	roof = Color3.fromRGB(225, 115, 95),
	door = Color3.fromRGB(150, 100, 70),
	trunk = Color3.fromRGB(135, 95, 65),
	leaves = Color3.fromRGB(95, 175, 95),
	leavesDark = Color3.fromRGB(70, 150, 90),
	bush = Color3.fromRGB(110, 185, 100),
	lanternOff = Color3.fromRGB(150, 150, 165),
	stone = Color3.fromRGB(175, 170, 185),
	stoneDark = Color3.fromRGB(125, 120, 140),
	water = Color3.fromRGB(95, 175, 230),
	lily = Color3.fromRGB(90, 170, 95),
	glowPink = Color3.fromRGB(255, 150, 210),
	star = Color3.fromRGB(255, 225, 120),
	fire = Color3.fromRGB(255, 140, 60),
	skin = Color3.fromRGB(240, 200, 160),
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders are X-axis aligned

local MUSHROOM_CAPS = {
	Color3.fromRGB(235, 95, 95),
	Color3.fromRGB(245, 155, 80),
	Color3.fromRGB(175, 115, 215),
}

local function ensure(parent: Instance, name: string, className: string, props: { [string]: any }?): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	if props then
		if props.Shape then
			(instance :: any).Shape = props.Shape
		end
		for key, value in props do
			if key ~= "Shape" then
				(instance :: any)[key] = value
			end
		end
	end
	instance.Parent = parent
	return instance
end

local function part(parent: Instance, name: string, props: { [string]: any }): BasePart
	local className = props.ClassName or "Part"
	props.ClassName = nil
	props.Anchored = true
	return ensure(parent, name, className, props) :: BasePart
end

local function ballPart(parent: Instance, name: string, size: number, position: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	local props = {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		Position = position,
		Color = color,
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return part(parent, name, props)
end

local function cylinder(parent: Instance, name: string, height: number, diameter: number, base: Vector3, color: Color3, extra: { [string]: any }?): BasePart
	local props = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = color,
	}
	for key, value in extra or {} do
		props[key] = value
	end
	return part(parent, name, props)
end

local function disc(parent: Instance, name: string, diameter: number, center: Vector3, color: Color3, material: Enum.Material?): BasePart
	return part(parent, name, {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, diameter, diameter),
		CFrame = CFrame.new(center + Vector3.new(0, 0.1, 0)) * UPRIGHT,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
	})
end

local function pathX(z: number): number
	return math.sin(z * 0.06) * 4
end

local function v(p: { number }): Vector3
	return WorldData.vector(p)
end

local function buildGround(map: Instance)
	local ground = ensure(map, "Ground", "Folder")
	part(ground, "VillageGround", {
		Size = Vector3.new(160, 2, 140),
		Position = Vector3.new(0, -1, 0),
		Color = COLOR.grass,
		Material = Enum.Material.Grass,
	})
	part(ground, "ForestGround", {
		Size = Vector3.new(160, 2, 160),
		Position = Vector3.new(0, -1, -150),
		Color = COLOR.forest,
		Material = Enum.Material.Grass,
	})
	part(ground, "RuinsGround", {
		Size = Vector3.new(160, 2, 100),
		Position = Vector3.new(0, -1, -280),
		Color = COLOR.ruins,
		Material = Enum.Material.Slate,
	})
	local b = WorldData.bounds
	local width, depth = b.maxX - b.minX, b.maxZ - b.minZ
	local midX, midZ = (b.minX + b.maxX) / 2, (b.minZ + b.maxZ) / 2
	local walls = {
		NorthWall = { Vector3.new(width, 40, 2), Vector3.new(midX, 20, b.minZ - 1) },
		SouthWall = { Vector3.new(width, 40, 2), Vector3.new(midX, 20, b.maxZ + 1) },
		WestWall = { Vector3.new(2, 40, depth), Vector3.new(b.minX - 1, 20, midZ) },
		EastWall = { Vector3.new(2, 40, depth), Vector3.new(b.maxX + 1, 20, midZ) },
	}
	for name, spec in walls do
		part(ground, name, { Size = spec[1], Position = spec[2], Transparency = 1 })
	end
end

local function buildHouse(parent: Instance, name: string, base: Vector3)
	local house = ensure(parent, name, "Folder")
	part(house, "Walls", {
		Size = Vector3.new(14, 9, 12),
		Position = base + Vector3.new(0, 4.5, 0),
		Color = COLOR.wall,
	})
	part(house, "Roof", {
		Size = Vector3.new(16, 2, 14),
		Position = base + Vector3.new(0, 10, 0),
		Color = COLOR.roof,
	})
	part(house, "RoofTop", {
		Size = Vector3.new(11, 2, 9),
		Position = base + Vector3.new(0, 12, 0),
		Color = COLOR.roof,
	})
	local chimney = part(house, "Chimney", {
		Size = Vector3.new(2, 4, 2),
		Position = base + Vector3.new(-4 * (if base.X > 0 then -1 else 1), 13, 3),
		Color = COLOR.stoneDark,
		Material = Enum.Material.Slate,
	})
	ensure(chimney, "Smoke", "ParticleEmitter", {
		Rate = 1.5,
		Lifetime = NumberRange.new(3, 4),
		Speed = NumberRange.new(1.5, 2.5),
		SpreadAngle = Vector2.new(10, 10),
		EmissionDirection = Enum.NormalId.Top,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 2.6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(235, 235, 240)),
	})
	local facing = if base.X > 0 then -1 else 1
	part(house, "Door", {
		Size = Vector3.new(0.4, 5, 3),
		Position = base + Vector3.new(facing * 7.1, 2.5, 0),
		Color = COLOR.door,
	})
	for index, z in { -3.5, 3.5 } do
		part(house, "Window" .. index, {
			Size = Vector3.new(0.4, 2.2, 2.2),
			Position = base + Vector3.new(facing * 7.1, 5.5, z),
			Color = Color3.fromRGB(170, 215, 240),
			Material = Enum.Material.Glass,
		})
	end
end

local function buildNpc(parent: Instance, name: string, robe: Color3, hat: Color3, actionKey: string)
	local spec = WorldData.npcs[name]
	local npc = ensure(parent, name, "Model") :: Model
	local bodyCFrame = CFrame.lookAt(v(spec.position), v(spec.lookAt))
	local body = part(npc, "Body", {
		Size = Vector3.new(2.4, 3.2, 1.6),
		CFrame = bodyCFrame,
		Color = robe,
	})
	part(npc, "Head", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = bodyCFrame * CFrame.new(0, 2.5, 0),
		Color = COLOR.skin,
	})
	part(npc, "Hat", {
		Size = Vector3.new(1.4, 1.2, 1.4),
		CFrame = bodyCFrame * CFrame.new(0, 3.9, 0),
		Color = hat,
	})
	for index, x in { -0.35, 0.35 } do
		part(npc, "Eye" .. index, {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.3, 0.3, 0.3),
			CFrame = bodyCFrame * CFrame.new(x, 2.65, -0.85),
			Color = Color3.fromRGB(40, 30, 40),
		})
	end
	if not npc.PrimaryPart then
		npc.PrimaryPart = body
	end
	ensure(body, "TalkPrompt", "ProximityPrompt", {
		ActionText = Strings.get(actionKey),
		ObjectText = Strings.get(spec.nameKey),
		MaxActivationDistance = 10,
		HoldDuration = 0,
		RequiresLineOfSight = false,
	})
	local tag = ensure(body, "NameTag", "BillboardGui", {
		Size = UDim2.fromScale(6, 1),
		StudsOffset = Vector3.new(0, 4.4, 0),
		MaxDistance = 70,
	})
	ensure(tag, "Label", "TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = Strings.get(spec.nameKey),
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
	})
end

local function buildForge(parent: Instance)
	local forge = ensure(parent, "Forge", "Folder")
	local base = Vector3.new(-32, 0, -40)
	part(forge, "Floor", {
		Size = Vector3.new(16, 0.6, 12),
		Position = base + Vector3.new(0, 0.3, 0),
		Color = COLOR.stone,
		Material = Enum.Material.Slate,
	})
	for index, offset in { Vector3.new(-7, 0, -5), Vector3.new(7, 0, -5), Vector3.new(-7, 0, 5), Vector3.new(7, 0, 5) } do
		cylinder(forge, "Post" .. index, 9, 0.9, base + offset, COLOR.trunk)
	end
	part(forge, "Roof", {
		Size = Vector3.new(17, 1.2, 13),
		Position = base + Vector3.new(0, 9.6, 0),
		Color = COLOR.roof,
	})
	part(forge, "Furnace", {
		Size = Vector3.new(5, 6, 4),
		Position = base + Vector3.new(-4, 3.6, -3),
		Color = COLOR.stoneDark,
		Material = Enum.Material.Slate,
	})
	local fire = part(forge, "FurnaceFire", {
		Size = Vector3.new(2.6, 2, 0.4),
		Position = base + Vector3.new(-4, 2.4, -0.9),
		Color = COLOR.fire,
		Material = Enum.Material.Neon,
	})
	ensure(fire, "Glow", "PointLight", { Color = COLOR.fire, Range = 14, Brightness = 1.5, Shadows = false })
	part(forge, "Anvil", {
		Size = Vector3.new(3, 1.2, 1.6),
		Position = base + Vector3.new(4, 2.4, 1),
		Color = Color3.fromRGB(90, 90, 105),
		Material = Enum.Material.Metal,
	})
	part(forge, "AnvilBase", {
		Size = Vector3.new(1.4, 1.8, 1.2),
		Position = base + Vector3.new(4, 1.3, 1),
		Color = COLOR.trunk,
	})
end

local function buildVillageProps(village: Instance)
	local props = ensure(village, "Props", "Folder")

	local well = Vector3.new(-14, 0, 24)
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		part(props, "WellStone" .. index, {
			Size = Vector3.new(1.4, 1.6, 1.4),
			CFrame = CFrame.new(well + Vector3.new(math.cos(angle) * 2.2, 0.8, math.sin(angle) * 2.2)) * CFrame.Angles(0, -angle, 0),
			Color = COLOR.stone,
			Material = Enum.Material.Slate,
		})
	end
	disc(props, "WellWater", 3.4, well + Vector3.new(0, 0.5, 0), COLOR.water, Enum.Material.Glass)
	for index, side in { -1, 1 } do
		cylinder(props, "WellPost" .. index, 4.6, 0.4, well + Vector3.new(side * 2.4, 0, 0), COLOR.trunk)
	end
	part(props, "WellRoof", {
		Size = Vector3.new(6, 0.6, 3.4),
		Position = well + Vector3.new(0, 4.9, 0),
		Color = COLOR.roof,
	})

	local plaza = Vector3.new(0, 0, 12)
	for index, position in { Vector3.new(-20, 0, 6), Vector3.new(20, 0, 6) } do
		local facing = CFrame.lookAt(position, Vector3.new(plaza.X, 0, plaza.Z))
		part(props, "BenchSeat" .. index, {
			Size = Vector3.new(4.5, 0.5, 1.5),
			CFrame = facing * CFrame.new(0, 1.2, 0),
			Color = COLOR.trunk,
			Material = Enum.Material.Wood,
		})
		part(props, "BenchBack" .. index, {
			Size = Vector3.new(4.5, 1.4, 0.4),
			CFrame = facing * CFrame.new(0, 2, 0.6),
			Color = COLOR.trunk,
			Material = Enum.Material.Wood,
		})
		for leg, x in { -1.8, 1.8 } do
			part(props, "BenchLeg" .. index .. "_" .. leg, {
				Size = Vector3.new(0.4, 1, 1.2),
				CFrame = facing * CFrame.new(x, 0.5, 0),
				Color = COLOR.stoneDark,
			})
		end
	end

	for houseIndex, base in { Vector3.new(-35, 0, 0), Vector3.new(35, 0, 0), Vector3.new(-35, 0, 32), Vector3.new(35, 0, 32) } do
		local facing = if base.X > 0 then -1 else 1
		for potIndex, z in { -2.6, 2.6 } do
			local potBase = base + Vector3.new(facing * 8.4, 0, z)
			local name = "Pot" .. houseIndex .. "_" .. potIndex
			cylinder(props, name, 0.9, 1.4, potBase, Color3.fromRGB(200, 110, 70))
			ballPart(props, name .. "_Plant", 1.3, potBase + Vector3.new(0, 1.3, 0), COLOR.bush, { CanCollide = false })
			ballPart(props, name .. "_Bloom", 0.6, potBase + Vector3.new(0, 1.9, 0), MUSHROOM_CAPS[(houseIndex + potIndex) % 3 + 1], {
				CanCollide = false,
			})
		end
	end

	for index, z in { -24, -42, -60 } do
		local side = if index % 2 == 0 then -1 else 1
		local base = Vector3.new(pathX(z) + side * 6, 0, z)
		cylinder(props, "PathLampPost" .. index, 6, 0.4, base, COLOR.stoneDark)
		ballPart(props, "PathLamp" .. index, 1.3, base + Vector3.new(0, 6.5, 0), COLOR.lanternOff, {
			Material = Enum.Material.Glass,
			Transparency = 0.2,
		})
	end
end

local function buildVillage(map: Instance)
	local village = ensure(map, "Village", "Folder")
	part(village, "VillageSpawn", {
		ClassName = "SpawnLocation",
		Size = Vector3.new(10, 1, 10),
		Position = v(WorldData.spawn),
		Color = COLOR.plaza,
		Neutral = true,
	})
	disc(village, "Plaza", 30, Vector3.new(0, 0, 12), COLOR.plaza, Enum.Material.Slate)
	cylinder(village, "LanternPost", 10, 1, Vector3.new(0, 0, 12), COLOR.trunk)
	ballPart(village, "LanternLamp", 2.5, Vector3.new(0, 10.8, 12), COLOR.lanternOff, {
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	buildHouse(village, "House1", Vector3.new(-35, 0, 0))
	buildHouse(village, "House2", Vector3.new(35, 0, 0))
	buildHouse(village, "House3", Vector3.new(-35, 0, 32))
	buildHouse(village, "House4", Vector3.new(35, 0, 32))
	buildNpc(village, "Elder", Color3.fromRGB(95, 115, 205), Color3.fromRGB(95, 115, 205), "npc_talk_action")
	buildNpc(village, "Demir", Color3.fromRGB(190, 115, 60), Color3.fromRGB(80, 70, 80), "npc_shop_action")
	buildForge(village)
	buildVillageProps(village)

	local bushes = {
		Vector3.new(-24, 0, 44),
		Vector3.new(24, 0, 44),
		Vector3.new(-50, 0, 16),
		Vector3.new(50, 0, 16),
		Vector3.new(-18, 0, -8),
		Vector3.new(18, 0, -8),
		Vector3.new(-55, 0, -30),
		Vector3.new(55, 0, -30),
		Vector3.new(40, 0, -50),
	}
	for index, position in bushes do
		ballPart(village, "Bush" .. index, 4, position + Vector3.new(0, 1.2, 0), COLOR.bush)
	end
end

local function buildLandmarks(forest: Instance)
	local marks = ensure(forest, "Landmarks", "Folder")

	local oak = v(WorldData.landmarks.old_oak.position)
	cylinder(marks, "OldOak_Trunk", 18, 5, oak, COLOR.trunk)
	ballPart(marks, "OldOak_Crown1", 16, oak + Vector3.new(0, 20, 0), COLOR.leavesDark)
	ballPart(marks, "OldOak_Crown2", 12, oak + Vector3.new(5, 17, 3), COLOR.leaves)
	ballPart(marks, "OldOak_Crown3", 11, oak + Vector3.new(-5, 17, -2), COLOR.leaves)
	for index, angle in { 0, 2.1, 4.2 } do
		ballPart(marks, "OldOak_Root" .. index, 3, oak + Vector3.new(math.cos(angle) * 3.2, 0.6, math.sin(angle) * 3.2), COLOR.trunk)
	end

	local pond = v(WorldData.landmarks.glow_pond.position)
	local water = disc(marks, "Pond_Water", 18, pond, COLOR.water, Enum.Material.Glass)
	ensure(water, "Sparkles", "ParticleEmitter", {
		Rate = 3,
		EmissionDirection = Enum.NormalId.Right, -- the disc is rotated, so local +X points up
		Lifetime = NumberRange.new(1.5, 2.5),
		Speed = NumberRange.new(0.3, 0.8),
		SpreadAngle = Vector2.new(20, 20),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }),
		Color = ColorSequence.new(COLOR.glowPink),
	})
	for index = 1, 10 do
		local angle = index / 10 * math.pi * 2
		ballPart(marks, "Pond_Stone" .. index, 2.4, pond + Vector3.new(math.cos(angle) * 9.6, 0.5, math.sin(angle) * 9.6), COLOR.stone)
	end
	for index, offset in { Vector3.new(3, 0, 2), Vector3.new(-4, 0, -1), Vector3.new(1, 0, -4), Vector3.new(-2, 0, 4) } do
		local pad = pond + offset
		part(marks, "Pond_Lily" .. index, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.15, 2.4, 2.4),
			CFrame = CFrame.new(pad + Vector3.new(0, 0.25, 0)) * UPRIGHT,
			Color = COLOR.lily,
		})
		ballPart(marks, "Pond_Bloom" .. index, 0.8, pad + Vector3.new(0, 0.6, 0), COLOR.glowPink, { Material = Enum.Material.Neon })
	end

	local rock = v(WorldData.landmarks.star_rock.position)
	ballPart(marks, "StarRock_A", 9, rock + Vector3.new(0, 3.5, 0), COLOR.stoneDark, { Material = Enum.Material.Slate })
	ballPart(marks, "StarRock_B", 6, rock + Vector3.new(4.5, 2.2, 2), COLOR.stone, { Material = Enum.Material.Slate })
	ballPart(marks, "StarRock_C", 5, rock + Vector3.new(-4, 1.8, -2.5), COLOR.stone, { Material = Enum.Material.Slate })
	local star = part(marks, "StarRock_Star", {
		Size = Vector3.new(2, 2, 2),
		CFrame = CFrame.new(rock + Vector3.new(0, 9, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		Color = COLOR.star,
		Material = Enum.Material.Neon,
	})
	ensure(star, "Glow", "PointLight", { Color = COLOR.star, Range = 16, Brightness = 1.2, Shadows = false })
end

-- Circles (x, z, radius) that trees must stay out of.
local function treeExclusions(): { { number } }
	local list = {}
	for _, area in WorldData.areas do
		table.insert(list, { area.center[1], area.center[3], area.radius + 3 })
	end
	for _, landmark in WorldData.landmarks do
		table.insert(list, { landmark.position[1], landmark.position[3], 13 })
	end
	for _, flower in WorldData.flowers do
		table.insert(list, { flower[1], flower[3], 5 })
	end
	return list
end

-- Deterministically places up to `count` props in a rectangle, avoiding the path (if clearance > 0)
-- and every (x, z, radius) circle in `avoid`. A fixed seed keeps names and positions stable.
local function scatter(seed: number, count: number, rect: { number }, clearance: number, avoid: { { number } }, place: (number, number, number, any) -> ())
	local rng = Random.new(seed)
	local placed = 0
	for _ = 1, count * 6 do
		if placed >= count then
			break
		end
		local x = rng:NextNumber(rect[1], rect[2])
		local z = rng:NextNumber(rect[3], rect[4])
		local blocked = clearance > 0 and z < -6 and math.abs(x - pathX(z)) < clearance
		for _, circle in avoid do
			local dx, dz = x - circle[1], z - circle[2]
			if dx * dx + dz * dz < circle[3] * circle[3] then
				blocked = true
			end
		end
		if not blocked then
			placed += 1
			place(placed, x, z, rng)
		end
	end
end

local function buildForestProps(forest: Instance, avoid: { { number } })
	local props = ensure(forest, "Props", "Folder")
	scatter(11, 24, { -74, 74, -224, -78 }, 7, avoid, function(index, x, z, rng)
		local height = rng:NextNumber(1.2, 2.2)
		local capSize = rng:NextNumber(2, 3.2)
		cylinder(props, "Mushroom_" .. index .. "_Stem", height, 0.6, Vector3.new(x, 0, z), Color3.fromRGB(245, 235, 215), { CanCollide = false })
		local cap = ballPart(props, "Mushroom_" .. index .. "_Cap", capSize, Vector3.new(x, height + 0.2, z), MUSHROOM_CAPS[index % #MUSHROOM_CAPS + 1], {
			CanCollide = false,
		})
		ensure(cap, "Squash", "SpecialMesh", { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 0.55, 1) })
	end)
	scatter(13, 18, { -74, 74, -224, -78 }, 7, avoid, function(index, x, z, rng)
		local size = rng:NextNumber(2, 4)
		ballPart(props, "Rock_" .. index, size, Vector3.new(x, size * 0.3, z), if index % 2 == 0 then COLOR.stone else COLOR.stoneDark, {
			Material = Enum.Material.Slate,
		})
	end)
end

local function buildForest(map: Instance)
	local forest = ensure(map, "Forest", "Folder")
	local index = 0
	for z = -12, -222, -10 do
		index += 1
		part(forest, "Path_" .. index, {
			Size = Vector3.new(8, 0.2, 10.5),
			Position = Vector3.new(pathX(z), 0.1, z),
			Color = COLOR.path,
			Material = Enum.Material.Sand,
		})
	end

	local exclusions = treeExclusions()
	local rng = Random.new(7) -- fixed seed keeps tree names and positions stable across runs
	local trees = 0
	for _ = 1, 220 do
		local x = rng:NextNumber(-74, 74)
		local z = rng:NextNumber(-224, -78)
		local height = rng:NextNumber(7, 12)
		local crown = rng:NextNumber(6, 10)
		local blocked = math.abs(x - pathX(z)) < 10
		for _, circle in exclusions do
			local dx, dz = x - circle[1], z - circle[2]
			if dx * dx + dz * dz < circle[3] * circle[3] then
				blocked = true
			end
		end
		if not blocked and trees < 60 then
			trees += 1
			cylinder(forest, "Tree_" .. trees .. "_Trunk", height, 2, Vector3.new(x, 0, z), COLOR.trunk)
			ballPart(forest, "Tree_" .. trees .. "_Leaves", crown, Vector3.new(x, height + crown * 0.3, z), if trees % 3 == 0 then COLOR.leavesDark else COLOR.leaves)
			table.insert(exclusions, { x, z, 3 })
		end
	end

	buildLandmarks(forest)
	buildForestProps(forest, exclusions)
end

local function buildRuins(map: Instance)
	local ruins = ensure(map, "Ruins", "Folder")
	local gate = WorldData.gate
	local b = WorldData.bounds
	local sideLength = (b.maxX - gate.halfWidth) - 1.5
	for index, side in { -1, 1 } do
		local centerX = side * (gate.halfWidth + 1.5 + sideLength / 2)
		part(ruins, "Wall" .. index, {
			Size = Vector3.new(sideLength, 14, 3),
			Position = Vector3.new(centerX, 7, gate.z - 1),
			Color = COLOR.stone,
			Material = Enum.Material.Slate,
		})
		for block = 0, math.floor(sideLength / 8) - 1 do
			part(ruins, "Crenel" .. index .. "_" .. block, {
				Size = Vector3.new(3, 2, 3),
				Position = Vector3.new(side * (gate.halfWidth + 5 + block * 8), 15, gate.z - 1),
				Color = COLOR.stone,
				Material = Enum.Material.Slate,
			})
		end
		part(ruins, "GatePillar" .. index, {
			Size = Vector3.new(3, 17, 4),
			Position = Vector3.new(side * (gate.halfWidth + 1.5), 8.5, gate.z - 1),
			Color = COLOR.stoneDark,
			Material = Enum.Material.Slate,
		})
	end
	part(ruins, "GateArch", {
		Size = Vector3.new(gate.halfWidth * 2 + 6, 3, 4),
		Position = Vector3.new(0, 18.5, gate.z - 1),
		Color = COLOR.stoneDark,
		Material = Enum.Material.Slate,
	})

	local arena = WorldData.areas.arena
	local center = v(arena.center)
	disc(ruins, "ArenaFloor", arena.radius * 2, center, Color3.fromRGB(185, 175, 200), Enum.Material.Slate)
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2
		local height = if index % 3 == 0 then 6 else 11
		cylinder(ruins, "ArenaPillar" .. index, height, 3, center + Vector3.new(math.cos(angle) * 38, 0, math.sin(angle) * 38), COLOR.stone, {
			Material = Enum.Material.Slate,
		})
	end
	local props = ensure(ruins, "Props", "Folder")
	local arenaAvoid = {
		{ arena.center[1], arena.center[3], 42 },
		{ 0, gate.z, gate.halfWidth + 6 },
	}
	scatter(17, 16, { -72, 72, -326, -236 }, 0, arenaAvoid, function(index, x, z, rng)
		local size = rng:NextNumber(1, 2.6)
		ballPart(props, "Rubble_" .. index, size, Vector3.new(x, size * 0.35, z), if index % 2 == 0 then COLOR.stone else COLOR.stoneDark, {
			Material = Enum.Material.Slate,
			CanCollide = false,
		})
	end)
	for index, spec in { { Vector3.new(-50, 0, -270), 0.4 }, { Vector3.new(52, 0, -258), -0.6 } } do
		part(props, "FallenPillar" .. index, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(12, 2.6, 2.6),
			CFrame = CFrame.new(spec[1] + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, spec[2], 0),
			Color = COLOR.stoneDark,
			Material = Enum.Material.Slate,
		})
	end

	local broken = {
		Vector3.new(-40, 0, -245),
		Vector3.new(42, 0, -250),
		Vector3.new(-55, 0, -300),
		Vector3.new(58, 0, -310),
		Vector3.new(-25, 0, -320),
	}
	for index, position in broken do
		cylinder(ruins, "BrokenPillar" .. index, 4 + index, 2.6, position, COLOR.stoneDark, { Material = Enum.Material.Slate })
	end
end

local MapBuilder = {}

function MapBuilder.build(): Folder
	local map = ensure(workspace, MAP_NAME, "Folder")
	buildGround(map)
	buildVillage(map)
	buildForest(map)
	buildRuins(map)
	return map :: Folder
end

return MapBuilder
