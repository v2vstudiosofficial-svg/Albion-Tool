-- Part-built costumes (no asset ids). Each builds a Model around an invisible "Anchor" part that
-- the server welds to the character: hats sit on the head, back items on the upper back, auras
-- are sparkles around the whole body.
local CosmeticData = if script then require(script.Parent.CosmeticData) else require("./CosmeticData")

local SIDE = CFrame.Angles(0, 0, math.rad(90))

type Spec = { name: string, shape: Enum.PartType?, size: Vector3, at: CFrame, color: Color3, neon: boolean? }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local builders: { [string]: (Color3) -> { Spec } } = {
	lantern_hat = function(color)
		return {
			{ name = "Brim", shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 2.2, 2.2), at = SIDE, color = Color3.fromRGB(120, 85, 60) },
			{ name = "Top", shape = Enum.PartType.Cylinder, size = Vector3.new(1, 1.2, 1.2), at = CFrame.new(0, 0.55, 0) * SIDE, color = Color3.fromRGB(120, 85, 60) },
			{ name = "Glow", shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.6, 0.6), at = CFrame.new(0, 1.3, 0), color = color, neon = true },
		}
	end,
	leaf_crown = function(color)
		local parts = {}
		for index = 1, 6 do
			local angle = index / 6 * math.pi * 2
			table.insert(parts, { name = "Leaf" .. index, size = Vector3.new(0.5, 0.7, 0.15), at = CFrame.new(math.cos(angle) * 0.75, 0.25, math.sin(angle) * 0.75) * CFrame.Angles(0, -angle, 0), color = color })
		end
		return parts
	end,
	frost_hood = function(color)
		return {
			{ name = "Hood", shape = Enum.PartType.Ball, size = Vector3.new(2.1, 1.6, 2.1), at = CFrame.new(0, 0.15, 0.1), color = color },
			{ name = "Glow", shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.4, 0.4), at = CFrame.new(0, 0.95, 0), color = Color3.fromRGB(230, 250, 255), neon = true },
		}
	end,
	star_crown = function(color)
		local parts = { { name = "Band", shape = Enum.PartType.Cylinder, size = Vector3.new(0.35, 1.9, 1.9), at = SIDE, color = color } }
		for index = 1, 5 do
			local angle = index / 5 * math.pi * 2
			table.insert(parts, { name = "Star" .. index, shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.4, 0.4), at = CFrame.new(math.cos(angle) * 0.85, 0.45, math.sin(angle) * 0.85), color = color, neon = true })
		end
		return parts
	end,
	explorer_cape = function(color)
		return { { name = "Cape", size = Vector3.new(1.8, 2.4, 0.12), at = CFrame.new(0, -1, 0.1) * CFrame.Angles(math.rad(8), 0, 0), color = color } }
	end,
	petal_wings = function(color)
		return {
			{ name = "WingL", size = Vector3.new(1.6, 1.1, 0.1), at = CFrame.new(-1, 0, 0) * CFrame.Angles(0, math.rad(25), math.rad(20)), color = color, neon = true },
			{ name = "WingR", size = Vector3.new(1.6, 1.1, 0.1), at = CFrame.new(1, 0, 0) * CFrame.Angles(0, math.rad(-25), math.rad(-20)), color = color, neon = true },
		}
	end,
	shadow_cloak = function(color)
		return {
			{ name = "Cloak", size = Vector3.new(2, 2.8, 0.14), at = CFrame.new(0, -1.2, 0.1) * CFrame.Angles(math.rad(6), 0, 0), color = color },
			{ name = "Trim", size = Vector3.new(2.05, 0.15, 0.16), at = CFrame.new(0, -2.55, 0.25), color = Color3.fromRGB(200, 130, 255), neon = true },
		}
	end,
	moon_hat = function(color)
		return {
			{ name = "Brim", shape = Enum.PartType.Cylinder, size = Vector3.new(0.2, 2.1, 2.1), at = SIDE, color = Color3.fromRGB(70, 70, 120) },
			{ name = "Cone", size = Vector3.new(1.1, 1.5, 1.1), at = CFrame.new(0, 0.85, 0), color = Color3.fromRGB(70, 70, 120) },
			{ name = "Moon", shape = Enum.PartType.Ball, size = Vector3.new(0.7, 0.7, 0.25), at = CFrame.new(0, 1.7, 0), color = color, neon = true },
		}
	end,
	comet_cape = function(color)
		return {
			{ name = "Cape", size = Vector3.new(1.8, 2.6, 0.12), at = CFrame.new(0, -1.1, 0.1) * CFrame.Angles(math.rad(8), 0, 0), color = Color3.fromRGB(40, 50, 100) },
			{ name = "Tail", size = Vector3.new(0.5, 1.4, 0.1), at = CFrame.new(0, -3, 0.25), color = color, neon = true },
			{ name = "Star", shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.5, 0.15), at = CFrame.new(0, -0.9, 0.2), color = color, neon = true },
		}
	end,
	tower_crown = function(color)
		local parts = { { name = "Band", shape = Enum.PartType.Cylinder, size = Vector3.new(0.4, 1.9, 1.9), at = SIDE, color = Color3.fromRGB(60, 50, 80) } }
		for index = 1, 4 do
			local angle = index / 4 * math.pi * 2
			table.insert(parts, { name = "Spike" .. index, size = Vector3.new(0.3, 0.9, 0.3), at = CFrame.new(math.cos(angle) * 0.8, 0.6, math.sin(angle) * 0.8), color = color, neon = true })
		end
		return parts
	end,
	skybound_cape = function(color)
		return {
			{ name = "Cape", size = Vector3.new(2, 2.8, 0.14), at = CFrame.new(0, -1.2, 0.1) * CFrame.Angles(math.rad(6), 0, 0), color = Color3.fromRGB(50, 90, 140) },
			{ name = "Cloud", shape = Enum.PartType.Ball, size = Vector3.new(1.6, 0.6, 0.4), at = CFrame.new(0, -2.7, 0.25), color = color, neon = true },
		}
	end,
	kael_crown = function(color)
		local parts = { { name = "Band", shape = Enum.PartType.Cylinder, size = Vector3.new(0.45, 2, 2), at = SIDE, color = color } }
		for index = 1, 6 do
			local angle = index / 6 * math.pi * 2
			table.insert(parts, { name = "Point" .. index, size = Vector3.new(0.3, 0.8 + (index % 2) * 0.4, 0.3), at = CFrame.new(math.cos(angle) * 0.9, 0.6, math.sin(angle) * 0.9), color = color, neon = true })
		end
		table.insert(parts, { name = "Gem", shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.5, 0.5), at = CFrame.new(0, 0.3, -0.95), color = Color3.fromRGB(255, 255, 255), neon = true })
		return parts
	end,
	phoenix_wings = function(color)
		return {
			{ name = "WingL", size = Vector3.new(2.4, 1.6, 0.1), at = CFrame.new(-1.4, 0.35, 0) * CFrame.Angles(0, math.rad(20), math.rad(35)), color = color, neon = true },
			{ name = "WingR", size = Vector3.new(2.4, 1.6, 0.1), at = CFrame.new(1.4, 0.35, 0) * CFrame.Angles(0, math.rad(-20), math.rad(-35)), color = color, neon = true },
			{ name = "TipL", size = Vector3.new(1.1, 0.7, 0.12), at = CFrame.new(-2.3, 0.9, 0) * CFrame.Angles(0, math.rad(20), math.rad(35)), color = Color3.fromRGB(255, 220, 120), neon = true },
			{ name = "TipR", size = Vector3.new(1.1, 0.7, 0.12), at = CFrame.new(2.3, 0.9, 0) * CFrame.Angles(0, math.rad(-20), math.rad(-35)), color = Color3.fromRGB(255, 220, 120), neon = true },
		}
	end,
	crystal_wings = function(color)
		return {
			{ name = "WingL", size = Vector3.new(2.2, 1.4, 0.1), at = CFrame.new(-1.3, 0.3, 0) * CFrame.Angles(0, math.rad(20), math.rad(30)), color = color, neon = true },
			{ name = "WingR", size = Vector3.new(2.2, 1.4, 0.1), at = CFrame.new(1.3, 0.3, 0) * CFrame.Angles(0, math.rad(-20), math.rad(-30)), color = color, neon = true },
		}
	end,
}

local CosmeticModels = {}

-- Builds the costume at `base`; parts are welded to the Anchor. Auras also get a ParticleEmitter.
function CosmeticModels.build(id: string, base: CFrame): Model
	local costume = CosmeticData.costumes[id]
	local color = rgb(costume.color)
	local model = Instance.new("Model")
	model.Name = "Costume_" .. costume.slot
	model:SetAttribute("CostumeId", id)
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Transparency = 1
	anchor.CFrame = base
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Massless = true
	anchor.Parent = model
	model.PrimaryPart = anchor
	local builder = builders[id]
	if builder then
		for _, spec in builder(color) do
			local part = Instance.new("Part")
			part.Name = spec.name
			if spec.shape then
				part.Shape = spec.shape
			end
			part.Size = spec.size
			part.CFrame = base * spec.at
			part.Color = spec.color
			part.Material = if spec.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = anchor
			weld.Part1 = part
			weld.Parent = part
			part.Parent = model
		end
	end
	if costume.slot == "aura" then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Aura"
		sparkle.Color = if id == "rainbow_aura"
			then ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(120, 255, 160)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(140, 150, 255)),
			})
			else ColorSequence.new(color)
		sparkle.LightEmission = 1
		sparkle.Rate = 12
		sparkle.Lifetime = NumberRange.new(0.8, 1.4)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new(0.25)
		sparkle.Parent = anchor
	end
	return model
end

return CosmeticModels
