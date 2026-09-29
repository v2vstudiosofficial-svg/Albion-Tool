-- Every player setting in one table: what it is, its choices and default. The server validates
-- and saves them (Profile.settings), the Settings menu is built from this table, and the client
-- applies them (client/Settings). Nothing here changes what the game rewards or requires.
--   kind "bool"    on/off
--   kind "choice"  one of `options`
--   kind "range"   a number from `min` to `max` in steps of `step`
-- Graphics settings can also be set together with a `quality` preset ("auto" picks by device).
local SettingsData = {}

SettingsData.categories = { "graphics", "audio", "gameplay", "interface" }

SettingsData.order = {
	"quality", "detail", "shadows", "effects", "bloom", "atmosphere", "fov",
	"sound", "master", "sfx",
	"shake", "cinematics", "damageNumbers", "rangeRing",
	"uiScale", "enemyBars", "perf",
}

SettingsData.settings = {
	quality = { category = "graphics", kind = "choice", options = { "auto", "low", "medium", "high", "ultra", "custom" }, default = "auto", nameKey = "set_quality" },
	detail = { category = "graphics", kind = "choice", options = { "low", "medium", "high", "ultra" }, default = "high", nameKey = "set_detail", preset = true },
	shadows = { category = "graphics", kind = "bool", default = true, nameKey = "set_shadows", preset = true },
	effects = { category = "graphics", kind = "choice", options = { "low", "medium", "high" }, default = "high", nameKey = "set_effects", preset = true },
	bloom = { category = "graphics", kind = "bool", default = true, nameKey = "set_bloom", preset = true },
	atmosphere = { category = "graphics", kind = "bool", default = true, nameKey = "set_atmosphere", preset = true },
	fov = { category = "graphics", kind = "range", min = 40, max = 70, step = 5, default = 50, nameKey = "set_fov" },
	sound = { category = "audio", kind = "bool", default = true, nameKey = "set_sound" },
	master = { category = "audio", kind = "range", min = 0, max = 100, step = 10, default = 100, nameKey = "set_master" },
	sfx = { category = "audio", kind = "range", min = 0, max = 100, step = 10, default = 100, nameKey = "set_sfx" },
	shake = { category = "gameplay", kind = "bool", default = true, nameKey = "set_shake" },
	cinematics = { category = "gameplay", kind = "bool", default = true, nameKey = "set_cinematics" },
	damageNumbers = { category = "gameplay", kind = "bool", default = true, nameKey = "set_damage_numbers" },
	rangeRing = { category = "gameplay", kind = "bool", default = true, nameKey = "set_range_ring" },
	uiScale = { category = "interface", kind = "choice", options = { "small", "normal", "large" }, default = "normal", nameKey = "set_ui_scale" },
	enemyBars = { category = "interface", kind = "bool", default = true, nameKey = "set_enemy_bars" },
	perf = { category = "interface", kind = "bool", default = false, nameKey = "set_perf" },
}

-- The graphics settings a preset decides (the `preset = true` ones above).
SettingsData.presets = {
	low = { detail = "low", shadows = false, effects = "low", bloom = false, atmosphere = false },
	medium = { detail = "medium", shadows = false, effects = "medium", bloom = false, atmosphere = true },
	high = { detail = "high", shadows = true, effects = "high", bloom = true, atmosphere = true },
	ultra = { detail = "ultra", shadows = true, effects = "high", bloom = true, atmosphere = true },
}

-- How much of the burst/particle effects to draw for each `effects` choice.
SettingsData.effectDensity = { low = 0.35, medium = 0.7, high = 1 }
-- Multiplier of the whole interface for each `uiScale` choice.
SettingsData.uiScaleFactor = { small = 0.88, normal = 1, large = 1.15 }

function SettingsData.defaults(): { [string]: any }
	local values = {}
	for key, def in SettingsData.settings do
		values[key] = def.default
	end
	return values
end

-- Is `value` allowed for `key`? Returns the cleaned value (ranges snap to their step and stay in
-- bounds) or nil when it is not acceptable at all.
function SettingsData.clean(key: string, value: any): any
	local def = SettingsData.settings[key]
	if not def then
		return nil
	end
	if def.kind == "bool" then
		return if type(value) == "boolean" then value else nil
	elseif def.kind == "choice" then
		return if type(value) == "string" and table.find(def.options, value) then value else nil
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	local snapped = math.floor((math.clamp(value, def.min, def.max) - def.min) / def.step + 0.5) * def.step + def.min
	return math.clamp(snapped, def.min, def.max)
end

-- The preset that actually applies: "auto" chooses by device (phones and tablets get Medium).
function SettingsData.resolveQuality(quality: string, touch: boolean): string
	if quality == "auto" then
		return if touch then "medium" else "high"
	end
	return quality
end

-- The value in force for `key`: a preset decides the preset-controlled graphics settings unless the
-- player chose "custom"; everything else is the saved value.
function SettingsData.effective(values: { [string]: any }, key: string, touch: boolean): any
	local def = SettingsData.settings[key]
	local quality = values.quality
	if def and def.preset and quality ~= "custom" then
		return SettingsData.presets[SettingsData.resolveQuality(quality or "auto", touch)][key]
	end
	local value = values[key]
	if value == nil and def then
		return def.default
	end
	return value
end

return SettingsData
