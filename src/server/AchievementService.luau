-- Adventure Log: counts what players do and pays achievement tiers when claimed. Progress is
-- replicated as "id:claimedTiers:progress" pairs; the client only asks to claim.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local AchievementData = require(Shared.AchievementData)
local ChestData = require(Shared.ChestData)
local Progression = require(Shared.Progression)
local AchievementLogic = require(script.Parent.AchievementLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local claimAchievement = Remotes.ClaimAchievement :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local CLAIM_COOLDOWN = 0.3

local lastClaim: { [Player]: number } = {}
local lastReady: { [Player]: number } = {}

local AchievementService = {}

-- Adds to a counter (purifies, elites, rifts, chests, crystals); the caller syncs afterwards.
function AchievementService.count(player: Player, counter: string, amount: number?)
	local profile = PlayerProfiles.get(player)
	if profile then
		AchievementLogic.count(profile, counter, amount)
	end
end

local function onClaim(player: Player, id: unknown)
	local now = os.clock()
	if typeof(id) ~= "string" or not AchievementData.achievements[id :: string] then
		return
	end
	if lastClaim[player] and now - lastClaim[player] < CLAIM_COOLDOWN then
		return
	end
	lastClaim[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local claim = AchievementLogic.claim(profile, id :: string, Progression.levelForXp(profile.xp))
	if claim then
		PlayerProfiles.sync(player)
		local def = AchievementData.achievements[claim.id]
		notice:FireClient(player, "notice_achievement_claimed", def.nameKey, claim.tier, claim.coins)
		if claim.chest then
			notice:FireClient(player, "notice_chest_taken", ChestData.chests[claim.chest].nameKey)
		end
		fx:FireClient(player, "achievementClaimed", claim.id, claim.tier)
	end
end

-- Tells a player once whenever another tier becomes ready to claim.
local function onChanged(player: Player)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ready = AchievementLogic.readyCount(profile)
	if lastReady[player] ~= nil and ready > lastReady[player] then
		notice:FireClient(player, "notice_achievement_ready")
	end
	lastReady[player] = ready
end

function AchievementService.start()
	claimAchievement.OnServerEvent:Connect(onClaim)
	PlayerProfiles.onChanged(onChanged)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
		lastReady[player] = nil
	end)
end

return AchievementService
