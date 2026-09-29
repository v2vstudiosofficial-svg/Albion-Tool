-- Light Pass: Pass XP for playing and claiming tier rewards. Rules live in PassLogic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local CosmeticData = require(Shared.CosmeticData)
local PassLogic = require(script.Parent.PassLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local claimPass = Remotes.ClaimPass :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local CLAIM_COOLDOWN = 0.3

local lastClaim: { [Player]: number } = {}

local PassService = {}

-- Adds Pass XP for an action (PassData.xp key); tells the player about new tiers. The caller
-- syncs the profile (most actions already do).
function PassService.award(player: Player, action: string, times: number?)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	if PassLogic.addXp(profile, action, times) > 0 then
		notice:FireClient(player, "notice_pass_tier", PassLogic.tier(profile))
	end
end

-- tier = a number (one reward on `track`) or "all".
local function onClaim(player: Player, tier: unknown, track: unknown)
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < CLAIM_COOLDOWN then
		return
	end
	lastClaim[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local level = Progression.levelForXp(profile.xp)
	local paid = {}
	if tier == "all" then
		paid = PassLogic.claimAll(profile, level)
	elseif typeof(tier) == "number" and (track == "free" or track == "premium") then
		local one = PassLogic.claim(profile, tier :: number, track :: string, level)
		if one then
			paid = { one }
		end
	end
	if #paid == 0 then
		return
	end
	PlayerProfiles.sync(player)
	local coins = 0
	for _, entry in paid do
		coins += entry.coins
		if entry.costume then
			notice:FireClient(player, "notice_costume_new", CosmeticData.costumes[entry.costume].nameKey)
		end
	end
	if coins > 0 then
		notice:FireClient(player, "notice_pass_coins", coins)
	end
	fx:FireClient(player, "passClaimed", #paid)
end

function PassService.start()
	claimPass.OnServerEvent:Connect(onClaim)
	PlayerProfiles.onLevelUp(function(player, level, previous)
		-- Levels of a first climb count for the pass; climbing again after a rebirth does not
		-- (otherwise every rebirth would refill a fifth of the season).
		local profile = PlayerProfiles.get(player)
		if profile and profile.rebirths == 0 then
			PassService.award(player, "levelUp", level - previous)
		end
		PlayerProfiles.sync(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
	end)
end

return PassService
