-- Chunky, friendly part models for the eight weapons. The server welds one into the player's
-- hand; clients build anchored copies that float behind players. Every model is built around an
-- invisible "Grip" part (its PrimaryPart) at the grip point, pointing up (+Y).
local WeaponData = if script then require(script.Parent.WeaponData) else require("./WeaponData")

local WOOD = Color3.fromRGB(150, 105, 70)
local METAL = Color3.fromRGB(205, 210, 222)
local DARK = Color3.fromRGB(90, 80, 95)
local SIDE = CFrame.Angles(0, 0, math.rad(90)) -- turns a cylinder's X axis to Y

type Spec = { name: string, shape: Enum.PartType?, size: Vector3, at: CFrame, color: Color3, material: Enum.Material? }

local function glow(weaponId: string): Color3
	local c = WeaponData.weapons[weaponId].color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function dagger(prefix: string, turn: CFrame, color: Color3): { Spec }
	return {
		{ name = prefix .. "Handle", shape = Enum.PartType.Cylinder, size = Vector3.new(0.9, 0.3, 0.3), at = turn * SIDE, color = WOOD, material = Enum.Material.Wood },
		{ name = prefix .. "Guard", size = Vector3.new(0.8, 0.15, 0.25), at = turn * CFrame.new(0, 0.5, 0), color = DARK },
		{ name = prefix .. "Blade", size = Vector3.new(0.14, 1.4, 0.36), at = turn * CFrame.new(0, 1.25, 0), color = color, material = Enum.Material.Neon },
	}
end

-- Parts of each weapon in grip space. `floating` versions may look a little grander.
local builders: { [string]: (Color3, boolean) -> { Spec } } = {
	staff = function(color)
		return {
			{ name = "Shaft", shape = Enum.PartType.Cylinder, size = Vector3.new(6, 0.35, 0.35), at = CFrame.new(0, 1.4, 0) * SIDE, color = WOOD, material = Enum.Material.Wood },
			{ name = "Glow", shape = Enum.PartType.Ball, size = Vector3.new(0.95, 0.95, 0.95), at = CFrame.new(0, 4.6, 0), color = color, material = Enum.Material.Neon },
		}
	end,
	bow = function(color)
		return {
			{ name = "Handle", size = Vector3.new(0.3, 1, 0.35), at = CFrame.new(), color = WOOD, material = Enum.Material.Wood },
			{ name = "UpperLimb", size = Vector3.new(0.25, 2.3, 0.3), at = CFrame.new(0, 1.55, -0.3) * CFrame.Angles(math.rad(-18), 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "LowerLimb", size = Vector3.new(0.25, 2.3, 0.3), at = CFrame.new(0, -1.55, -0.3) * CFrame.Angles(math.rad(18), 0, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Glow", size = Vector3.new(0.07, 5.2, 0.07), at = CFrame.new(0, 0, 0.3), color = color, material = Enum.Material.Neon },
		}
	end,
	daggers = function(color, floating)
		if not floating then
			return dagger("", CFrame.new(), color)
		end
		local parts = {}
		for index, degrees in { -28, 0, 28 } do
			for _, spec in dagger("D" .. index, CFrame.Angles(0, 0, math.rad(degrees)), color) do
				table.insert(parts, spec)
			end
		end
		return parts
	end,
	sword = function(color)
		return {
			{ name = "Handle", shape = Enum.PartType.Cylinder, size = Vector3.new(1.1, 0.32, 0.32), at = SIDE, color = WOOD, material = Enum.Material.Wood },
			{ name = "Pommel", shape = Enum.PartType.Ball, size = Vector3.new(0.4, 0.4, 0.4), at = CFrame.new(0, -0.65, 0), color = color, material = Enum.Material.Neon },
			{ name = "Guard", size = Vector3.new(1.6, 0.25, 0.35), at = CFrame.new(0, 0.62, 0), color = DARK },
			{ name = "Blade", size = Vector3.new(0.2, 4, 0.55), at = CFrame.new(0, 2.75, 0), color = METAL, material = Enum.Material.Metal },
			{ name = "Glow", size = Vector3.new(0.24, 3.4, 0.14), at = CFrame.new(0, 2.6, 0), color = color, material = Enum.Material.Neon },
		}
	end,
	spear = function(color)
		return {
			{ name = "Shaft", shape = Enum.PartType.Cylinder, size = Vector3.new(7, 0.3, 0.3), at = CFrame.new(0, 1.5, 0) * SIDE, color = WOOD, material = Enum.Material.Wood },
			{ name = "Glow", shape = Enum.PartType.Cylinder, size = Vector3.new(0.3, 0.42, 0.42), at = CFrame.new(0, 4.85, 0) * SIDE, color = color, material = Enum.Material.Neon },
			{ name = "Head", size = Vector3.new(0.22, 1.5, 0.7), at = CFrame.new(0, 5.7, 0) * CFrame.Angles(0, math.rad(45), 0), color = METAL, material = Enum.Material.Metal },
		}
	end,
	crossbow = function(color)
		return {
			{ name = "Stock", size = Vector3.new(0.45, 2.6, 0.45), at = CFrame.new(0, 0.8, 0), color = WOOD, material = Enum.Material.Wood },
			{ name = "Limbs", size = Vector3.new(3.2, 0.25, 0.3), at = CFrame.new(0, 1.85, 0), color = DARK, material = Enum.Material.Metal },
			{ name = "String", size = Vector3.new(3, 0.07, 0.07), at = CFrame.new(0, 1.5, 0), color = METAL },
			{ name = "Glow", size = Vector3.new(0.14, 1.7, 0.14), at = CFrame.new(0, 1.55, -0.3), color = color, material = Enum.Material.Neon },
		}
	end,
	axe = function(color)
		return {
			{ name = "Handle", shape = Enum.PartType.Cylinder, size = Vector3.new(3.6, 0.32, 0.32), at = CFrame.new(0, 1.1, 0) * SIDE, color = WOOD, material = Enum.Material.Wood },
			{ name = "Blade", size = Vector3.new(1.4, 1.6, 0.22), at = CFrame.new(0.8, 2.6, 0), color = METAL, material = Enum.Material.Metal },
			{ name = "Back", size = Vector3.new(0.55, 0.65, 0.3), at = CFrame.new(-0.35, 2.6, 0), color = DARK },
			{ name = "Glow", size = Vector3.new(0.16, 1.7, 0.26), at = CFrame.new(1.52, 2.6, 0), color = color, material = Enum.Material.Neon },
		}
	end,
	hammer = function(color)
		return {
			{ name = "Handle", shape = Enum.PartType.Cylinder, size = Vector3.new(3.8, 0.34, 0.34), at = CFrame.new(0, 1.2, 0) * SIDE, color = WOOD, material = Enum.Material.Wood },
			{ name = "Head", size = Vector3.new(1.7, 1.1, 1.1), at = CFrame.new(0, 3.3, 0), color = DARK, material = Enum.Material.Metal },
			{ name = "Glow", size = Vector3.new(0.35, 1.18, 1.18), at = CFrame.new(0, 3.3, 0), color = color, material = Enum.Material.Neon },
		}
	end,
}

-- How the main weapon sits in the hand, applied on top of the hand's grip frame.
local HOLDS = {
	staff = CFrame.new(),
	spear = CFrame.new(),
	bow = CFrame.new(),
	daggers = CFrame.Angles(math.rad(-90), 0, 0),
	crossbow = CFrame.Angles(math.rad(-90), 0, 0),
	sword = CFrame.Angles(math.rad(-45), 0, 0),
	axe = CFrame.Angles(math.rad(-45), 0, 0),
	hammer = CFrame.Angles(math.rad(-45), 0, 0),
}

local WeaponModels = {}

function WeaponModels.hold(weaponId: string): CFrame
	return HOLDS[weaponId] or CFrame.new()
end

-- Builds the model at `base` (the grip frame). Welded models (anchored = false) are held
-- together by WeldConstraints to their Grip; anchored ones are moved with PivotTo.
function WeaponModels.build(weaponId: string, base: CFrame, anchored: boolean, floating: boolean?): Model
	local model = Instance.new("Model")
	model.Name = "Weapon"
	model:SetAttribute("WeaponId", weaponId)
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.2, 0.2, 0.2)
	grip.Transparency = 1
	grip.CFrame = base
	grip.Anchored = anchored
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.Parent = model
	model.PrimaryPart = grip

	for _, spec in builders[weaponId](glow(weaponId), floating == true) do
		local part = Instance.new("Part")
		part.Name = spec.name
		if spec.shape then
			part.Shape = spec.shape
		end
		part.Size = spec.size
		part.CFrame = base * spec.at
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.Anchored = anchored
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		if not anchored then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = grip
			weld.Part1 = part
			weld.Parent = part
		end
		part.Parent = model
	end
	return model
end

return WeaponModels
