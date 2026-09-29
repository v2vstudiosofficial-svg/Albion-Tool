-- The player's settings on this device: reads the Pref_<key> attributes the server replicates
-- (SettingsData describes them) and applies the ones that change how the game looks and sounds.
-- Other client modules ask `Settings.get(key)` at the moment they need a value.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsData = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SettingsData"))
local Audio = require(script.Parent.Audio)
local Graphics = require(script.Parent.Graphics)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer

local Settings = {}

local listeners: { () -> () } = {}

-- The values saved for this player (defaults for anything not received yet).
function Settings.saved(): { [string]: any }
	local values = SettingsData.defaults()
	for key in SettingsData.settings do
		local value = player:GetAttribute("Pref_" .. key)
		if value ~= nil then
			values[key] = value
		end
	end
	return values
end

-- The value in force right now (a quality preset decides the graphics choices unless "custom").
function Settings.get(key: string): any
	return SettingsData.effective(Settings.saved(), key, UiKit.isTouch())
end

-- Runs `listener` whenever any setting changes.
function Settings.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

local function apply()
	Graphics.apply({
		shadows = Settings.get("shadows"),
		bloom = Settings.get("bloom"),
		atmosphere = Settings.get("atmosphere"),
		detail = Settings.get("detail"),
	})
	UiKit.setScaleFactor(SettingsData.uiScaleFactor[Settings.get("uiScale")] or 1)
	Audio.setEnabled(Settings.get("sound"))
	Audio.setVolumes(Settings.get("master") / 100, Settings.get("sfx") / 100)
	for _, listener in listeners do
		listener()
	end
end

function Settings.start()
	for key in SettingsData.settings do
		player:GetAttributeChangedSignal("Pref_" .. key):Connect(apply)
	end
	apply()
end

return Settings
