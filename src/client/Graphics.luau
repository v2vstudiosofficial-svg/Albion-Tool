-- The game's look on this device: a warm "golden hour" mood and, depending on the quality
-- settings, haze (Atmosphere), a soft glow on neon (Bloom), colour grading, shadows and the
-- engine's own render quality. Everything here is local to this player's screen.
local Lighting = game:GetService("Lighting")

local Graphics = {}

-- The haze when the atmosphere is on (client/Ambience thickens it in a blizzard).
Graphics.HAZE = { density = 0.28, color = Color3.fromRGB(255, 218, 178) }

-- Roblox QualityLevel for each `detail` choice.
local QUALITY_LEVELS = { low = 3, medium = 5, high = 8, ultra = 10 }

local function effect(className: string, name: string): any
	-- The place already ships one of each effect (default.project.json); take those over, or the
	-- quality choices would only switch a copy on and the built-in one would stay on.
	local existing = Lighting:FindFirstChild(name) or Lighting:FindFirstChildOfClass(className)
	if existing then
		return existing
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = Lighting
	return instance
end

-- The base mood, always on (it costs nothing). Sun, sky colours and time of day belong to
-- client/DayNight.
local function applyMood()
	Lighting.EnvironmentDiffuseScale = 0.6
end

-- Applies the graphics choices: { shadows, bloom, atmosphere, detail }.
function Graphics.apply(choices: { shadows: boolean, bloom: boolean, atmosphere: boolean, detail: string })
	pcall(applyMood)
	pcall(function()
		Lighting.GlobalShadows = choices.shadows
		Lighting.ShadowSoftness = if choices.detail == "ultra" then 0.15 else 0.35
	end)
	pcall(function()
		local bloom = effect("BloomEffect", "LvBloom")
		bloom.Enabled = choices.bloom
		bloom.Intensity = 0.55
		bloom.Size = 22
		bloom.Threshold = 1.05
	end)
	pcall(function()
		local haze = effect("Atmosphere", "LvAtmosphere")
		-- (An Atmosphere is always drawn while it exists, so a disabled one is taken away.)
		if choices.atmosphere then
			haze.Density = Graphics.HAZE.density
			haze.Offset = 0.2
			haze.Color = Graphics.HAZE.color
			haze.Decay = Color3.fromRGB(160, 130, 120)
			haze.Glare = 0.1
			haze.Haze = 1.2
		else
			haze:Destroy()
		end
		local grading = effect("ColorCorrectionEffect", "LvGrading")
		grading.Enabled = choices.atmosphere
		grading.Saturation = 0.12
		grading.Contrast = 0.06
		grading.TintColor = Color3.fromRGB(255, 246, 236)
		local rays = effect("SunRaysEffect", "LvRays")
		rays.Enabled = choices.atmosphere and choices.detail == "ultra"
		rays.Intensity = 0.06
		rays.Spread = 0.6
	end)
	-- The engine's own render quality (not every platform lets scripts change it).
	pcall(function()
		local level = QUALITY_LEVELS[choices.detail]
		local rendering = (settings :: any)().Rendering
		rendering.QualityLevel = (Enum.QualityLevel :: any):FromValue(level)
	end)
end

return Graphics
