-- Comfort settings (screen shake, camera scenes): the client asks, the server validates and saves
-- them in the profile so they follow the player between visits.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(script.Parent.Profile)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local setSetting = ReplicatedStorage.Remotes.SetSetting :: RemoteEvent

local REQUEST_COOLDOWN = 0.3

local lastRequest: { [Player]: number } = {}

local SettingsService = {}

function SettingsService.start()
	setSetting.OnServerEvent:Connect(function(player, key: unknown, value: unknown)
		if typeof(key) ~= "string" or typeof(value) ~= "boolean" then
			return
		end
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return
		end
		lastRequest[player] = now
		local profile = PlayerProfiles.get(player)
		if profile and Profile.setSetting(profile, key :: string, value :: boolean) then
			PlayerProfiles.sync(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return SettingsService
