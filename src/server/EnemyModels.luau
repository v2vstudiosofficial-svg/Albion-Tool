-- Builds rounded, friendly-looking enemy models from basic parts. The anchored Body is the root;
-- every other part is welded to it, so moving Body moves (and replicates) the whole model at once.
local EnemyModels = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local PUPIL = Color3.fromRGB(35, 25, 45)

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function ball(name: string, size: number, color: Color3, material: Enum.Material?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(size, size, size)
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanTouch = false
	part.Anchored = false
	part.Massless = true
	part.CastShadow = false
	return part
end

local function squash(part: BasePart, scale: Vector3)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale
	mesh.Parent = part
end

local function attach(model: Model, body: BasePart, part: BasePart, offset: CFrame)
	part.CFrame = body.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = part
	weld.Parent = part
	part.Parent = model
end

-- A rounded spike: a ball stretched along its own Y axis (`length` tall, `thickness` wide).
local function spike(model: Model, body: BasePart, name: string, length: number, thickness: number, color: Color3, material: Enum.Material?, offset: CFrame): BasePart
	local part = ball(name, length, color, material)
	squash(part, Vector3.new(thickness / length, 1, thickness / length))
	attach(model, body, part, offset)
	return part
end

local function eyes(model: Model, body: BasePart, size: number, spread: number, height: number, depth: number, glow: Color3?)
	for _, side in { -1, 1 } do
		local eye = ball("Eye", size, glow or WHITE, Enum.Material.Neon)
		attach(model, body, eye, CFrame.new(side * spread, height, -depth))
		if not glow then
			local pupil = ball("Pupil", size * 0.5, PUPIL)
			attach(model, body, pupil, CFrame.new(side * spread, height, -depth - size * 0.35))
			-- A tiny highlight makes the look lively.
			local glint = ball("Glint", size * 0.22, WHITE, Enum.Material.Neon)
			attach(model, body, glint, CFrame.new(side * spread + size * 0.12, height + size * 0.14, -depth - size * 0.52))
		end
	end
end

local builders = {}

function builders.Gloomling(model: Model, body: BasePart, stats)
	local s = stats.size
	eyes(model, body, 0.75, 0.62, 0.35, s * 0.42)
	local ear = rgb(stats.color):Lerp(Color3.new(0, 0, 0), 0.25)
	for _, side in { -1, 1 } do
		attach(model, body, ball("Ear", 1, ear), CFrame.new(side * 1.1, s * 0.42, 0.2))
		attach(model, body, ball("Foot", s * 0.28, ear), CFrame.new(side * s * 0.26, -s * 0.4, -s * 0.12))
	end
end

function builders.Sporeling(model: Model, body: BasePart, stats)
	local s = stats.size
	body.Color = Color3.fromRGB(245, 230, 205)
	squash(body, Vector3.new(0.85, 0.8, 0.85))
	local cap = ball("Cap", s * 1.35, rgb(stats.color))
	squash(cap, Vector3.new(1, 0.55, 1))
	attach(model, body, cap, CFrame.new(0, s * 0.42, 0))
	for index, offset in { Vector3.new(0.9, 0.35, -0.6), Vector3.new(-0.8, 0.4, 0.5), Vector3.new(0.1, 0.55, 0.9) } do
		local spot = ball("Spot" .. index, 0.6, WHITE)
		attach(model, body, spot, CFrame.new(offset * s * 0.5 + Vector3.new(0, s * 0.55, 0)))
	end
	eyes(model, body, 0.6, 0.5, 0, s * 0.36)
end

function builders.Rockling(model: Model, body: BasePart, stats)
	local s = stats.size
	body.Material = Enum.Material.Slate
	squash(body, Vector3.new(1.15, 0.9, 1.05))
	eyes(model, body, 0.7, 0.75, 0.3, s * 0.45, Color3.fromRGB(255, 170, 80))
	for _, side in { -1, 1 } do
		local pebble = ball("Pebble", 1.1, rgb(stats.color):Lerp(WHITE, 0.2), Enum.Material.Slate)
		attach(model, body, pebble, CFrame.new(side * 1.5, s * 0.35, 0.4))
	end
end

function builders.Warden(model: Model, body: BasePart, stats)
	local s = stats.size
	local accent = if stats.accent then rgb(stats.accent) else Color3.fromRGB(150, 90, 220)
	eyes(model, body, 1.6, 1.6, 1, s * 0.44, accent:Lerp(WHITE, 0.5))
	for index = 1, 5 do
		local angle = (index - 3) * 0.45
		local flame = ball("Flame" .. index, 1.8, accent, Enum.Material.Neon)
		attach(model, body, flame, CFrame.new(math.sin(angle) * s * 0.3, s * 0.5, math.cos(angle) * s * 0.1))
	end
	for _, side in { -1, 1 } do
		local hand = ball("Hand", 3, rgb(stats.color):Lerp(WHITE, 0.1))
		attach(model, body, hand, CFrame.new(side * (s * 0.68), -1.2, -1))
		local glow = ball("HandGlow", 1.2, accent:Lerp(WHITE, 0.3), Enum.Material.Neon)
		attach(model, body, glow, CFrame.new(side * (s * 0.68), -1.2, -2.4))
	end
end

-- Extra details that tell the east-land creatures and legends apart from their base shape.
-- Keyed by creature kind; each runs after the base builder.
local accessories = {}

local function around(count: number, radius: number, height: number, place: (number, CFrame) -> ())
	for index = 1, count do
		local angle = index / count * math.pi * 2
		-- Yaw so local +X points away from the middle, then lean the piece outward.
		place(index, CFrame.new(math.cos(angle) * radius, height, math.sin(angle) * radius) * CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, math.rad(-22)))
	end
end

function accessories.Mudling(model, body, stats)
	local s = stats.size
	for index, at in { Vector3.new(0.28, 0.42, -0.1), Vector3.new(-0.3, 0.4, 0.15), Vector3.new(0.02, 0.47, 0.3) } do
		attach(model, body, ball("MudLump" .. index, s * 0.28, Color3.fromRGB(88, 68, 42), Enum.Material.Slate), CFrame.new(at * s))
	end
end

function accessories.Snowpuff(model, body, stats)
	local s = stats.size
	for index, at in { Vector3.new(0.28, 0.42, -0.1), Vector3.new(-0.3, 0.4, 0.15), Vector3.new(0.02, 0.47, 0.3) } do
		attach(model, body, ball("Tuft" .. index, s * 0.3, WHITE), CFrame.new(at * s))
	end
	for _, side in { -1, 1 } do
		attach(model, body, ball("Cheek", s * 0.16, Color3.fromRGB(255, 170, 175)), CFrame.new(side * s * 0.3, -s * 0.05, -s * 0.42))
	end
end

function accessories.Shade(model, body, stats)
	local s = stats.size
	for index, size in { 0.3, 0.22, 0.15 } do
		local wisp = ball("Wisp" .. index, s * size, Color3.fromRGB(150, 90, 230), Enum.Material.Neon)
		wisp.Transparency = 0.35 + index * 0.1
		attach(model, body, wisp, CFrame.new(0, -s * (0.1 + index * 0.08), s * (0.35 + index * 0.25)))
	end
end

function accessories.Bubbler(model, body, stats)
	local s = stats.size
	for index, at in { Vector3.new(0.8, 0.9, 0.2), Vector3.new(-0.7, 1.05, -0.3), Vector3.new(0.2, 1.2, -0.7), Vector3.new(-0.3, 0.85, 0.7) } do
		local bubble = ball("Bubble" .. index, s * 0.2, Color3.fromRGB(200, 255, 220), Enum.Material.Glass)
		bubble.Transparency = 0.45
		attach(model, body, bubble, CFrame.new(at * s))
	end
end

function accessories.Hexcap(model, body, stats)
	local s = stats.size
	around(3, s * 0.95, s * 0.3, function(index, offset)
		attach(model, body, ball("Rune" .. index, s * 0.14, Color3.fromRGB(215, 140, 255), Enum.Material.Neon), CFrame.new(offset.Position))
	end)
end

function accessories.Frostling(model, body, stats)
	local s = stats.size
	local ice = Color3.fromRGB(190, 230, 255)
	for index, at in { Vector3.new(-0.25, 0.5, 0.2), Vector3.new(0.25, 0.5, 0.2), Vector3.new(0, 0.55, 0.32) } do
		local lean = CFrame.Angles(math.rad(-18), 0, math.rad((index - 2) * -22))
		spike(model, body, "Crystal" .. index, s * 0.75, s * 0.22, ice, Enum.Material.Ice, CFrame.new(at * s) * lean)
	end
end

function accessories.Obsidian(model, body, stats)
	local s = stats.size
	for _, side in { -1, 1 } do
		spike(model, body, "Horn", s * 0.6, s * 0.2, Color3.fromRGB(35, 30, 45), Enum.Material.Slate, CFrame.new(side * s * 0.32, s * 0.5, -s * 0.05) * CFrame.Angles(0, 0, math.rad(side * -20)))
		spike(model, body, "Crack", s * 0.5, s * 0.1, Color3.fromRGB(255, 110, 40), Enum.Material.Neon, CFrame.new(side * s * 0.36, s * 0.05, -s * 0.36) * CFrame.Angles(math.rad(10), 0, math.rad(side * 25)))
	end
end

function accessories.BogMother(model, body, stats)
	local s = stats.size
	for index, at in { Vector3.new(-0.25, 0.5, -0.1), Vector3.new(0.22, 0.52, 0.05), Vector3.new(0, 0.55, 0.25) } do
		local base = at * s
		spike(model, body, "MushroomStem" .. index, s * 0.2, s * 0.05, Color3.fromRGB(245, 235, 215), nil, CFrame.new(base + Vector3.new(0, s * 0.08, 0)))
		local cap = ball("MushroomCap" .. index, s * 0.17, if index == 2 then Color3.fromRGB(245, 155, 80) else Color3.fromRGB(235, 95, 95))
		squash(cap, Vector3.new(1, 0.55, 1))
		attach(model, body, cap, CFrame.new(base + Vector3.new(0, s * 0.2, 0)))
	end
	for _, side in { -1, 1 } do
		attach(model, body, ball("Moss", s * 0.14, Color3.fromRGB(110, 160, 70)), CFrame.new(side * s * 0.45, s * 0.15, s * 0.3))
	end
end

function accessories.FrostTitan(model, body, stats)
	local s = stats.size
	around(6, s * 0.3, s * 0.55, function(index, offset)
		spike(model, body, "IceSpike" .. index, s * 0.4, s * 0.09, Color3.fromRGB(215, 240, 255), Enum.Material.Ice, offset)
	end)
end

function accessories.ShadowKing(model, body, stats)
	local s = stats.size
	local accent = if stats.accent then rgb(stats.accent) else Color3.fromRGB(255, 120, 220)
	around(7, s * 0.3, s * 0.55, function(index, offset)
		local neon = index % 2 == 0
		spike(model, body, "CrownSpike" .. index, s * 0.4, s * 0.08, if neon then accent else Color3.fromRGB(60, 30, 90), if neon then Enum.Material.Neon else Enum.Material.Slate, offset)
	end)
	for index, at in { Vector3.new(0, -0.1, 0.6), Vector3.new(-0.35, -0.2, 0.7), Vector3.new(0.35, -0.2, 0.7) } do
		local cape = ball("Cape" .. index, s * (if index == 1 then 0.5 else 0.35), Color3.fromRGB(30, 10, 55))
		cape.Transparency = 0.5
		attach(model, body, cape, CFrame.new(at * s))
	end
end

function EnemyModels.build(kind: string, stats, cframe: CFrame): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = kind
	local body = ball("Body", stats.size, rgb(stats.color))
	body.Anchored = true
	body.Massless = false
	body.CastShadow = true
	body.CFrame = cframe
	body.Parent = model
	model.PrimaryPart = body
	-- Variants (east-land creatures, legends) share a base creature's shape.
	local builder = builders[stats.model or kind]
	if builder then
		builder(model, body, stats)
	end
	local accessory = accessories[kind]
	if accessory then
		accessory(model, body, stats)
	end
	if stats.elite then
		-- A little golden crown marks elites.
		local gold = Color3.fromRGB(255, 205, 70)
		for index = 1, 5 do
			local angle = index / 5 * math.pi * 2
			local spike = ball("Crown" .. index, 0.7, gold, Enum.Material.Neon)
			attach(model, body, spike, CFrame.new(math.cos(angle) * stats.size * 0.22, stats.size * 0.55, math.sin(angle) * stats.size * 0.22))
		end
	end
	return model, body
end

return EnemyModels
