-- Weather-like particles around the camera that tell you where you are, using the same places as
-- the music (MusicLogic.theme): pollen in the village, drifting leaves in the woods, green spores
-- in the marsh, snow on the peaks, embers at the citadel and violet motes in the Shadow Tower.
-- Now and then it rains in the marsh (DayCycle.rain, the same for everyone), with little splashes
-- at your feet and the sound of rain on water (and lightning while it pours); between the showers a blizzard blows over the peaks
-- (more snow, driven sideways, a whistling wind and a cold white haze). Only this screen draws them; "Low" effects turns them off.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local MusicLogic = require(Shared:WaitForChild("MusicLogic"))
local SettingsData = require(Shared:WaitForChild("SettingsData"))
local Audio = require(script.Parent.Audio)
local Graphics = require(script.Parent.Graphics)
local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

local UPDATE_SECONDS = 0.5
local RAIN_RATE = 550 -- drops per second at full rain and High effects
local SPLASH_RATE = 140
-- Blizzard: extra snow (times the place's own rate), a push on the flakes, and thicker, colder haze.
local STORM_SNOW = 3
local STORM_WIND = Vector3.new(16, -2, 5)
local STORM_FOG = 0.25
local STORM_HAZE = Color3.fromRGB(225, 235, 250)
local FOG_STEP = 0.1 -- per update, so the haze takes a few seconds to come and go
-- While it pours in the marsh, lightning strikes every LIGHTNING_EVERY seconds of server time (the
-- same moment for everyone): the sky flickers (not with Screen flashes off) and thunder follows.
local LIGHTNING_EVERY = 17
local THUNDER_DELAY = 1.4
local FLICKER = { { 0, 0.35 }, { 0.08, 0 }, { 0.16, 0.25 }, { 0.3, 0.1 }, { 0.45, 0 } } -- (seconds, brightness)
-- Unlit, so the rain still shows at night.
local RAIN_COLOR = Color3.fromRGB(170, 195, 225)

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

-- An invisible, non-solid part that only carries particles.
local function holderPart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = size
	part.Parent = workspace
	return part
end

-- Rain falls from a sheet above the player as thin upright streaks (the default particle squashed
-- tall, kept upright on screen), and splashes flick up from a sheet at their feet.
local function rainEmitters(): (Part, ParticleEmitter, Part, ParticleEmitter)
	local sky = holderPart("LvRain", Vector3.new(80, 1, 80))
	local rain = Instance.new("ParticleEmitter")
	rain.Name = "Rain"
	rain.Shape = Enum.ParticleEmitterShape.Box
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	rain.Speed = NumberRange.new(70, 80)
	rain.Lifetime = NumberRange.new(0.45, 0.55)
	rain.Size = NumberSequence.new(0.45)
	rain.Squash = NumberSequence.new(2.8)
	rain.Transparency = NumberSequence.new(0.45)
	rain.Color = ColorSequence.new(RAIN_COLOR)
	rain.LightInfluence = 0
	rain.Rate = 0
	rain.Parent = sky
	local ground = holderPart("LvSplashes", Vector3.new(50, 0.2, 50))
	local splash = Instance.new("ParticleEmitter")
	splash.Name = "Splashes"
	splash.Shape = Enum.ParticleEmitterShape.Box
	splash.EmissionDirection = Enum.NormalId.Top
	splash.Speed = NumberRange.new(0)
	splash.Lifetime = NumberRange.new(0.2, 0.3)
	splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.9) })
	splash.Squash = NumberSequence.new(-1.5)
	splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	splash.Color = ColorSequence.new(RAIN_COLOR)
	splash.LightInfluence = 0
	splash.Rate = 0
	splash.Parent = ground
	return sky, rain, ground, splash
end

Ambience.looks = LOOKS

function Ambience.start()
	local holder = holderPart("LvAmbience", Vector3.new(70, 24, 70))
	local sky, rain, ground, splash = rainEmitters()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Ambience"
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.Parent = holder

	local shown: string? = nil
	local fog = 0
	-- On the camera, not in Lighting (Graphics takes over Lighting's colour corrections).
	local flash = Instance.new("ColorCorrectionEffect")
	flash.Name = "LvLightning"
	flash.Parent = workspace.CurrentCamera
	local lastStrike: number? = nil
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
			emitter.Rate, rain.Rate, splash.Rate = 0, 0, 0
			Audio.setAmbient("rain", 0)
			return
		end
		holder.CFrame = CFrame.new(root.Position + Vector3.new(0, 8, 0))
		sky.CFrame = CFrame.new(root.Position + Vector3.new(0, 30, 0))
		ground.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.9, 0))
		local theme = MusicLogic.theme(root.Position.X, root.Position.Z)
		local look = LOOKS[theme]
		local density = SettingsData.effectDensity[Settings.get("effects")] or 1
		local now = workspace:GetServerTimeNow()
		local wet = if theme == "marsh" then DayCycle.rain(now) else 0
		local storm = if theme == "peaks" then DayCycle.blizzard(now) else 0
		-- Weather is heard even with Low effects (only the drops and flakes are not drawn).
		Audio.setAmbient("rain", wet)
		Audio.setAmbient("wind", storm)
		local strike = math.floor(now / LIGHTNING_EVERY)
		if wet >= 1 and lastStrike and strike ~= lastStrike then
			if Settings.get("flashes") then
				for _, step in FLICKER do
					task.delay(step[1], function()
						flash.Brightness = step[2]
					end)
				end
			end
			task.delay(THUNDER_DELAY, function()
				Audio.play("thunder")
			end)
		end
		lastStrike = strike
		fog += math.clamp(storm - fog, -FOG_STEP, FOG_STEP)
		local haze = Lighting:FindFirstChildOfClass("Atmosphere")
		if haze then
			haze.Density = Graphics.HAZE.density + STORM_FOG * fog
			haze.Color = Graphics.HAZE.color:Lerp(STORM_HAZE, fog)
		end
		if not look or Settings.get("effects") == "low" then
			emitter.Rate, rain.Rate, splash.Rate = 0, 0, 0
			shown = nil
			return
		end
		rain.Rate = RAIN_RATE * wet * density
		splash.Rate = SPLASH_RATE * wet * density
		if shown ~= theme then
			shown = theme
			emitter.Color = look.color
			emitter.Size = look.size
			emitter.Lifetime = look.lifetime
			emitter.Speed = look.speed
			emitter.LightEmission = look.light
			emitter.Rotation = look.rotation or NumberRange.new(0)
			emitter.RotSpeed = if look.rotation then NumberRange.new(-90, 90) else NumberRange.new(0)
		end
		emitter.Rate = look.rate * density * (1 + STORM_SNOW * storm)
		emitter.Acceleration = look.acceleration + STORM_WIND * storm
	end)
end

return Ambience
