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

local function eyes(model: Model, body: BasePart, size: number, spread: number, height: number, depth: number, glow: Color3?)
	for _, side in { -1, 1 } do
		local eye = ball("Eye", size, glow or WHITE, Enum.Material.Neon)
		attach(model, body, eye, CFrame.new(side * spread, height, -depth))
		if not glow then
			local pupil = ball("Pupil", size * 0.5, PUPIL)
			attach(model, body, pupil, CFrame.new(side * spread, height, -depth - size * 0.35))
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
