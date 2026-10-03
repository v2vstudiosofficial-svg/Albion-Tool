-- Day and night on this screen. The clock comes from DayCycle and the server time, so everyone
-- shares one sky. The lighting blends from a warm day through an orange dusk to a bright blue
-- night; after dark the village lanterns burn brighter and fireflies drift around the player.
-- With the "Day & night" setting off it stays a golden afternoon.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DayCycle = require(Shared:WaitForChild("DayCycle"))
local Settings = require(script.Parent.Settings)

local player = Players.LocalPlayer

local FIXED_CLOCK = 15.5 -- the afternoon kept when the cycle is off
local UPDATE_SECONDS = 0.25
local LIGHT_SCAN_SECONDS = 20
local LIGHT_BOOST = 1.6 -- added to a lantern's brightness at full night
local FIREFLY_RATE = 30 -- per second around the player at full night

local DAY = {
	brightness = 2.4,
	ambient = Color3.fromRGB(96, 98, 120),
	outdoor = Color3.fromRGB(128, 128, 150),
	top = Color3.fromRGB(255, 236, 200),
}
local DUSK_TOP = Color3.fromRGB(255, 150, 90)
local DUSK_AMBIENT = Color3.fromRGB(150, 110, 120)
-- Roblox's moonlight is dim, so the night leans on bright blue ambient light: it should look like
-- a storybook night, never too dark to play.
local NIGHT = {
	brightness = 2.2,
	ambient = Color3.fromRGB(118, 122, 190),
	outdoor = Color3.fromRGB(150, 155, 215),
	top = Color3.fromRGB(150, 175, 255),
}

local DayNight = {}

-- How much it is night right now (0-1), for other effects (client/Ambience).
DayNight.night = 0

local lights: { PointLight } = {}

-- Sets the sky for one clock time; returns how much it is night (0-1).
function DayNight.apply(clock: number): number
	local night = DayCycle.night(clock)
	local dusk = DayCycle.dusk(clock) * (1 - night)
	Lighting.ClockTime = clock
	Lighting.Brightness = DAY.brightness + (NIGHT.brightness - DAY.brightness) * night
	Lighting.Ambient = DAY.ambient:Lerp(DUSK_AMBIENT, dusk):Lerp(NIGHT.ambient, night)
	Lighting.OutdoorAmbient = DAY.outdoor:Lerp(NIGHT.outdoor, night)
	Lighting.ColorShift_Top = DAY.top:Lerp(DUSK_TOP, dusk):Lerp(NIGHT.top, night)
	for _, light in lights do
		if light.Parent then
			local base = light:GetAttribute("LvBaseBrightness")
			if typeof(base) ~= "number" then
				base = light.Brightness
				light:SetAttribute("LvBaseBrightness", base)
			end
			light.Brightness = base + LIGHT_BOOST * night
		end
	end
	return night
end

-- The lanterns and lamps of the map (the server names their lights "Glow").
local function scanLights()
	local map = workspace:FindFirstChild("LanternValleyMap")
	local found = {}
	if map then
		for _, descendant in map:GetDescendants() do
			if descendant:IsA("PointLight") and descendant.Name == "Glow" then
				table.insert(found, descendant)
			end
		end
	end
	lights = found
end

function DayNight.start()
	-- A box of fireflies that follows the player; it only emits at night.
	local holder = Instance.new("Part")
	holder.Name = "LvNightFireflies"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(90, 14, 90)
	holder.Parent = workspace
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Name = "Fireflies"
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Rate = 0
	fireflies.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	fireflies.LightEmission = 1
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Lifetime = NumberRange.new(3, 5)
	fireflies.Speed = NumberRange.new(0.3, 1.2)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Parent = holder

	local sinceUpdate, sinceScan = UPDATE_SECONDS, LIGHT_SCAN_SECONDS - 3
	RunService.Heartbeat:Connect(function(dt)
		sinceUpdate += dt
		sinceScan += dt
		if sinceScan >= LIGHT_SCAN_SECONDS then
			sinceScan = 0
			scanLights()
		end
		if sinceUpdate < UPDATE_SECONDS then
			return
		end
		sinceUpdate = 0
		local clock = if Settings.get("dayNight") then DayCycle.clock(workspace:GetServerTimeNow()) else FIXED_CLOCK
		local night = DayNight.apply(clock)
		DayNight.night = night
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			holder.CFrame = CFrame.new(root.Position + Vector3.new(0, 4, 0))
		end
		fireflies.Rate = if Settings.get("effects") == "low" then 0 else FIREFLY_RATE * night
	end)
end

return DayNight
