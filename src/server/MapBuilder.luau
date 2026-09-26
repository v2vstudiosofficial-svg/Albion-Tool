-- Idempotent scene builder: only creates instances that are missing by name and never
-- deletes or overwrites anything, so manual Studio edits survive re-runs.
-- Bake into the place from the Studio command bar:
--   require(game.ServerScriptService.Server.MapBuilder).build()
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Strings = require(ReplicatedStorage.Shared.Strings)

local MAP_NAME = "LanternValleyMap"

local COLOR = {
	grass = Color3.fromRGB(125, 195, 95),
	forest = Color3.fromRGB(75, 145, 85),
	path = Color3.fromRGB(220, 185, 130),
	plaza = Color3.fromRGB(200, 195, 185),
	wall = Color3.fromRGB(245, 228, 195),
	roof = Color3.fromRGB(225, 115, 95),
	door = Color3.fromRGB(150, 100, 70),
	trunk = Color3.fromRGB(135, 95, 65),
	leaves = Color3.fromRGB(95, 175, 95),
	lanternOff = Color3.fromRGB(150, 150, 165),
	robe = Color3.fromRGB(95, 115, 205),
	skin = Color3.fromRGB(240, 200, 160),
}

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90)) -- cylinders are X-axis aligned

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

local function pathX(z: number): number
	return math.sin(z * 0.06) * 4
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
	-- Invisible walls around the playable area (x: -80..80, z: -230..70).
	local walls = {
		NorthWall = { Vector3.new(160, 40, 2), Vector3.new(0, 20, -231) },
		SouthWall = { Vector3.new(160, 40, 2), Vector3.new(0, 20, 71) },
		WestWall = { Vector3.new(2, 40, 300), Vector3.new(-81, 20, -80) },
		EastWall = { Vector3.new(2, 40, 300), Vector3.new(81, 20, -80) },
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
	local facing = if base.X > 0 then -1 else 1
	part(house, "Door", {
		Size = Vector3.new(0.4, 5, 3),
		Position = base + Vector3.new(facing * 7.1, 2.5, 0),
		Color = COLOR.door,
	})
end

local function buildElder(parent: Instance)
	local elder = ensure(parent, "Elder", "Model") :: Model
	local origin = Vector3.new(8, 1.6, 28)
	local bodyCFrame = CFrame.lookAt(origin, Vector3.new(0, 1.6, 40))
	local body = part(elder, "Body", {
		Size = Vector3.new(2.4, 3.2, 1.6),
		CFrame = bodyCFrame,
		Color = COLOR.robe,
	})
	part(elder, "Head", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.8, 1.8, 1.8),
		CFrame = bodyCFrame * CFrame.new(0, 2.5, 0),
		Color = COLOR.skin,
	})
	part(elder, "Hat", {
		Size = Vector3.new(1.4, 1.2, 1.4),
		CFrame = bodyCFrame * CFrame.new(0, 3.9, 0),
		Color = COLOR.robe,
	})
	if not elder.PrimaryPart then
		elder.PrimaryPart = body
	end
	ensure(body, "TalkPrompt", "ProximityPrompt", {
		ActionText = Strings.get("npc_talk_action"),
		ObjectText = Strings.get("npc_elder_name"),
		MaxActivationDistance = 10,
		HoldDuration = 0,
		RequiresLineOfSight = false,
	})
	local tag = ensure(body, "NameTag", "BillboardGui", {
		Size = UDim2.fromScale(6, 1),
		StudsOffset = Vector3.new(0, 4.2, 0),
		MaxDistance = 60,
	})
	ensure(tag, "Label", "TextLabel", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = Strings.get("npc_elder_name"),
		TextScaled = true,
		Font = Enum.Font.FredokaOne,
		TextColor3 = Color3.new(1, 1, 1),
		TextStrokeTransparency = 0.4,
	})
end

local function buildVillage(map: Instance)
	local village = ensure(map, "Village", "Folder")
	part(village, "VillageSpawn", {
		ClassName = "SpawnLocation",
		Size = Vector3.new(10, 1, 10),
		Position = Vector3.new(0, 0.5, 40),
		Color = COLOR.plaza,
		Neutral = true,
	})
	part(village, "Plaza", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 30, 30),
		CFrame = CFrame.new(0, 0.1, 12) * UPRIGHT,
		Color = COLOR.plaza,
		Material = Enum.Material.Slate,
	})
	part(village, "LanternPost", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(10, 1, 1),
		CFrame = CFrame.new(0, 5, 12) * UPRIGHT,
		Color = COLOR.trunk,
	})
	part(village, "LanternLamp", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(2.5, 2.5, 2.5),
		Position = Vector3.new(0, 10.8, 12),
		Color = COLOR.lanternOff,
		Material = Enum.Material.Glass,
		Transparency = 0.2,
	})
	buildHouse(village, "House1", Vector3.new(-35, 0, 0))
	buildHouse(village, "House2", Vector3.new(35, 0, 0))
	buildHouse(village, "House3", Vector3.new(-35, 0, 32))
	buildHouse(village, "House4", Vector3.new(35, 0, 32))
	buildElder(village)
end

local function buildForest(map: Instance)
	local forest = ensure(map, "Forest", "Folder")
	local index = 0
	for z = -12, -120, -10 do
		index += 1
		part(forest, "Path_" .. index, {
			Size = Vector3.new(8, 0.2, 10.5),
			Position = Vector3.new(pathX(z), 0.1, z),
			Color = COLOR.path,
			Material = Enum.Material.Sand,
		})
	end

	local clearing = Vector3.new(0, 0, -112)
	local rng = Random.new(7) -- fixed seed keeps tree names and positions stable across runs
	local trees = 0
	for _ = 1, 120 do
		local x = rng:NextNumber(-74, 74)
		local z = rng:NextNumber(-224, -78)
		local height = rng:NextNumber(7, 11)
		local crown = rng:NextNumber(6, 9)
		local nearPath = math.abs(x - pathX(z)) < 10 and z > -125
		local inClearing = (Vector3.new(x, 0, z) - clearing).Magnitude < 24
		if not nearPath and not inClearing and trees < 45 then
			trees += 1
			part(forest, "Tree_" .. trees .. "_Trunk", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(height, 2, 2),
				CFrame = CFrame.new(x, height / 2, z) * UPRIGHT,
				Color = COLOR.trunk,
			})
			part(forest, "Tree_" .. trees .. "_Leaves", {
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(crown, crown, crown),
				Position = Vector3.new(x, height + crown * 0.3, z),
				Color = COLOR.leaves,
			})
		end
	end

	local spawns = ensure(forest, "EnemySpawns", "Folder")
	local spawnPoints = {
		Vector3.new(-10, 0.5, -104),
		Vector3.new(11, 0.5, -112),
		Vector3.new(0, 0.5, -124),
	}
	for i, position in spawnPoints do
		part(spawns, "EnemySpawn_" .. i, {
			Size = Vector3.new(2, 1, 2),
			Position = position,
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

local MapBuilder = {}

function MapBuilder.build(): Folder
	local map = ensure(workspace, MAP_NAME, "Folder")
	buildGround(map)
	buildVillage(map)
	buildForest(map)
	return map :: Folder
end

return MapBuilder
