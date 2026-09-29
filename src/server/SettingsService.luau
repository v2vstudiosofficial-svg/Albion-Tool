-- Player settings (graphics, audio, gameplay, interface): the client sends a change, the server
-- validates every value against SettingsData, saves it in the profile and replicates it as
-- Pref_<key> attributes. Accepts (key, value), a table of changes, or { reset = category | true }.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local SettingsData = require(Shared.SettingsData)
local Profile = require(script.Parent.Profile)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local setSetting = ReplicatedStorage.Remotes.SetSetting :: RemoteEvent

local REQUEST_COOLDOWN = 0.3
local MAX_CHANGES = 24

local lastRequest: { [Player]: number } = {}

local SettingsService = {}

local function handle(player: Player, first: unknown, second: unknown)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local changed = false
	if typeof(first) == "string" then
		changed = Profile.setSetting(profile, first :: string, second)
	elseif typeof(first) == "table" then
		local changes = first :: { [any]: any }
		local reset = changes.reset
		if reset == true then
			Profile.resetSettings(profile)
			changed = true
		elseif type(reset) == "string" and table.find(SettingsData.categories, reset) then
			Profile.resetSettings(profile, reset)
			changed = true
		else
			-- Only a bounded number of plain string keys is looked at.
			local safe = {}
			local count = 0
			for key, value in changes do
				count += 1
				if count > MAX_CHANGES then
					break
				end
				if type(key) == "string" then
					safe[key] = value
				end
			end
			changed = Profile.applySettings(profile, safe) > 0
		end
	end
	if changed then
		PlayerProfiles.sync(player)
	end
end

function SettingsService.start()
	setSetting.OnServerEvent:Connect(function(player, first: unknown, second: unknown)
		local now = os.clock()
		if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
			return
		end
		lastRequest[player] = now
		handle(player, first, second)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return SettingsService
