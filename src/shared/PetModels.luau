-- Small, round, friendly pet models built from a few parts. Clients build one anchored copy per
-- following pet and move it with PivotTo. The model's PrimaryPart is the round "Body".
local PetData = if script then require(script.Parent.PetData) else require("./PetData")

local DARK = Color3.fromRGB(45, 40, 55)
local SIDE = CFrame.Angles(0, 0, math.rad(90))

type Spec = { name: string, shape: Enum.PartType?, size: Vector3, at: CFrame, color: Color3, material: Enum.Material? }

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- Extra parts per look, in body space (the body is a 1.6-stud ball; +Z is behind the pet).
local looks: { [string]: (Color3) -> { Spec } } = {
	moth = function(color)
		return {
			{ name = "WingL", size = Vector3.new(1.5, 0.12, 1.2), at = CFrame.new(-1.05, 0.45, 0.2) * CFrame.Angles(0, 0, math.rad(20)), color = color, material = Enum.Material.Neon },
			{ name = "WingR", size = Vector3.new(1.5, 0.12, 1.2), at = CFrame.new(1.05, 0.45, 0.2) * CFrame.Angles(0, 0, math.rad(-20)), color = color, material = Enum.Material.Neon },
		}
	end,
	sprout = function(color)
		return {
			{ name = "Stem", shape = Enum.PartType.Cylinder, size = Vector3.new(0.7, 0.12, 0.12), at = CFrame.new(0, 1, 0) * SIDE, color = Color3.fromRGB(90, 150, 80) },
			{ name = "LeafL", size = Vector3.new(0.7, 0.1, 0.4), at = CFrame.new(-0.4, 1.4, 0) * CFrame.Angles(0, 0, math.rad(25)), color = color },
			{ name = "LeafR", size = Vector3.new(0.7, 0.1, 0.4), at = CFrame.new(0.4, 1.4, 0) * CFrame.Angles(0, 0, math.rad(-25)), color = color },
		}
	end,
	pebble = function(color)
		return {
			{ name = "BumpA", shape = Enum.PartType.Ball, size = Vector3.new(0.6, 0.6, 0.6), at = CFrame.new(-0.5, 0.75, 0.2), color = color },
			{ name = "BumpB", shape = Enum.PartType.Ball, size = Vector3.new(0.5, 0.5, 0.5), at = CFrame.new(0.5, 0.7, 0.3), color = color },
		}
	end,
	fox = function(color)
		return {
			{ name = "EarL", size = Vector3.new(0.4, 0.7, 0.2), at = CFrame.new(-0.45, 0.95, -0.1), color = color },
			{ name = "EarR", size = Vector3.new(0.4, 0.7, 0.2), at = CFrame.new(0.45, 0.95, -0.1), color = color },
			{ name = "Tail", shape = Enum.PartType.Ball, size = Vector3.new(0.7, 0.7, 1.4), at = CFrame.new(0, 0.1, 1.1), color = Color3.fromRGB(255, 235, 200) },
		}
	end,
	pup = function(color)
		return {
			{ name = "EarL", size = Vector3.new(0.5, 0.6, 0.25), at = CFrame.new(-0.6, 0.6, -0.1) * CFrame.Angles(0, 0, math.rad(25)), color = color },
			{ name = "EarR", size = Vector3.new(0.5, 0.6, 0.25), at = CFrame.new(0.6, 0.6, -0.1) * CFrame.Angles(0, 0, math.rad(-25)), color = color },
			{ name = "Tail", shape = Enum.PartType.Ball, size = Vector3.new(0.45, 0.45, 0.8), at = CFrame.new(0, 0.2, 1), color = color },
		}
	end,
	cat = function(color)
		return {
			{ name = "EarL", size = Vector3.new(0.4, 0.6, 0.2), at = CFrame.new(-0.45, 0.95, -0.1), color = color },
			{ name = "EarR", size = Vector3.new(0.4, 0.6, 0.2), at = CFrame.new(0.45, 0.95, -0.1), color = color },
			{ name = "Tail", shape = Enum.PartType.Cylinder, size = Vector3.new(1.3, 0.25, 0.25), at = CFrame.new(0, 0.5, 1.1) * CFrame.Angles(math.rad(50), 0, math.rad(90)), color = color },
		}
	end,
}

local PetModels = {}

function PetModels.build(petId: string, base: CFrame): Model
	local pet = PetData.pets[petId]
	local model = Instance.new("Model")
	model.Name = "Pet"
	model:SetAttribute("PetId", petId)
	local color = rgb(pet.color)
	local specs: { Spec } = {
		{ name = "Body", shape = Enum.PartType.Ball, size = Vector3.new(1.6, 1.6, 1.6), at = CFrame.new(), color = color },
		{ name = "EyeL", shape = Enum.PartType.Ball, size = Vector3.new(0.25, 0.25, 0.25), at = CFrame.new(-0.3, 0.15, -0.72), color = DARK },
		{ name = "EyeR", shape = Enum.PartType.Ball, size = Vector3.new(0.25, 0.25, 0.25), at = CFrame.new(0.3, 0.15, -0.72), color = DARK },
	}
	for _, spec in looks[pet.look](color) do
		table.insert(specs, spec)
	end
	for _, spec in specs do
		local part = Instance.new("Part")
		part.Name = spec.name
		if spec.shape then
			part.Shape = spec.shape
		end
		part.Size = spec.size
		part.CFrame = base * spec.at
		part.Color = spec.color
		part.Material = spec.material or Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		part.Parent = model
		if spec.name == "Body" then
			model.PrimaryPart = part
		end
	end
	return model
end

return PetModels
