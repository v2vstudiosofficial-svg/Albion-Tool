-- Weather-like particles around the camera that tell you where you are, using the same places as
-- the music (MusicLogic.theme): pollen in the village, drifting leaves in the woods, green spores
-- in the marsh, snow on the peaks, embers at the citadel and violet motes in the Shadow Tower.
-- Only this screen draws them; "Low" effects turns them off.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MusicLogic = require(Shared:WaitForChild("MusicLogic"))
local SettingsData = require(Shared:WaitForChild("SettingsData"))
local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.5

type Look = {
	color: ColorSequence,
	size: NumberSequence,
	rate: number,
	lifetime: NumberRange,
	speed: NumberRange,
	acceleration: Vector3,
	light: number,
	rotation: NumberRange?,
}

local function sizes(peak: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.2, peak), NumberSequenceKeypoint.new(0.8, peak), NumberSequenceKeypoint.new(1, 0) })
end

local LOOKS: { [string]: Look } = {
	village = { color = ColorSequence.new(Color3.fromRGB(255, 245, 190)), size = sizes(0.4), rate = 14, lifetime = NumberRange.new(5, 8), speed = NumberRange.new(0.3, 0.8), acceleration = Vector3.new(0.3, 0.15, 0), light = 0.6 },
	wilds = { color = ColorSequence.new(Color3.fromRGB(150, 205, 90), Color3.fromRGB(230, 170, 70)), size = sizes(0.7), rate = 12, lifetime = NumberRange.new(5, 7), speed = NumberRange.new(0.5, 1.2), acceleration = Vector3.new(0.6, -0.8, 0.2), light = 0, rotation = NumberRange.new(-120, 120) },
	marsh = { color = ColorSequence.new(Color3.fromRGB(150, 255, 170)), size = sizes(0.45), rate = 16, lifetime = NumberRange.new(4, 7), speed = NumberRange.new(0.2, 0.6), acceleration = Vector3.new(0, 0.5, 0), light = 0.8 },
	peaks = { color = ColorSequence.new(Color3.fromRGB(240, 248, 255)), size = sizes(0.55), rate = 45, lifetime = NumberRange.new(4, 6), speed = NumberRange.new(1, 2), acceleration = Vector3.new(0.8, -3, 0.4), light = 0.3, rotation = NumberRange.new(-60, 60) },
	citadel = { color = ColorSequence.new(Color3.fromRGB(255, 160, 80), Color3.fromRGB(255, 80, 60)), size = sizes(0.35), rate = 18, lifetime = NumberRange.new(3, 5), speed = NumberRange.new(0.5, 1.5), acceleration = Vector3.new(0.2, 1.5, 0), light = 1 },
	tower = { color = ColorSequence.new(Color3.fromRGB(190, 130, 255)), size = sizes(0.4), rate = 20, lifetime = NumberRange.new(4, 6), speed = NumberRange.new(0.3, 0.9), acceleration = Vector3.new(0, 0.6, 0), light = 1 },
}

local Ambience = {}

Ambience.looks = LOOKS

function Ambience.start()
	local holder = Instance.new("Part")
	holder.Name = "LvAmbience"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(70, 24, 70)
	holder.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Ambience"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder

	local shown: string? = nil
	local since = UPDATE_SECONDS
	RunService.Heartbeat:Connect(function(dt)
		since += dt
		if since < UPDATE_SECONDS then
			return
		end
		since = 0
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			emitter.Rate = 0
			return
		end
		holder.CFrame = CFrame.new(root.Position + Vector3.new(0, 8, 0))
		local theme = MusicLogic.theme(root.Position.X, root.Position.Z)
		local look = LOOKS[theme]
		local density = SettingsData.effectDensity[Settings.get("effects")] or 1
		if not look or Settings.get("effects") == "low" then
			emitter.Rate = 0
			shown = nil
			return
		end
		if shown ~= theme then
			shown = theme
			emitter.Color = look.color
			emitter.Size = look.size
			emitter.Lifetime = look.lifetime
			emitter.Speed = look.speed
			emitter.Acceleration = look.acceleration
			emitter.LightEmission = look.light
			emitter.Rotation = look.rotation or NumberRange.new(0)
			emitter.RotSpeed = if look.rotation then NumberRange.new(-90, 90) else NumberRange.new(0)
		end
		emitter.Rate = look.rate * density
	end)
end

return Ambience
