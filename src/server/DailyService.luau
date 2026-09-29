-- Daily gift: validates the claim (once per UTC day, coins paid here) and keeps the "ready" flag
-- fresh for players who stay online past midnight. Rules live in DailyLogic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local DailyLogic = require(script.Parent.DailyLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local claimDaily = Remotes.ClaimDailyGift :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent

local REQUEST_COOLDOWN = 1
local RECHECK_SECONDS = 60

local lastRequest: { [Player]: number } = {}

local DailyService = {}

-- The request carries nothing: anything else is not from the real client.
local function onClaim(player: Player, ...)
	if select("#", ...) > 0 then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local coins = DailyLogic.claim(profile, os.time(), Progression.levelForXp(profile.xp))
	if coins then
		PlayerProfiles.sync(player)
		notice:FireClient(player, "notice_daily_gift", Format.short(coins))
	end
end

-- Players who stay online past midnight get the new gift without rejoining.
local function recheck()
	for _, player in Players:GetPlayers() do
		local profile = PlayerProfiles.get(player)
		if profile and DailyLogic.ready(profile, os.time()) ~= (player:GetAttribute("DailyReady") == true) then
			PlayerProfiles.sync(player)
		end
	end
end

function DailyService.start()
	claimDaily.OnServerEvent:Connect(onClaim)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(RECHECK_SECONDS)
			recheck()
		end
	end)
end

return DailyService
