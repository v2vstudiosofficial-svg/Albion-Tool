-- In-memory profiles for M1. Nothing is persisted yet; progress resets when the player leaves.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Profile = require(script.Parent.Profile)
local QuestLogic = require(script.Parent.QuestLogic)
local QuestData = require(ReplicatedStorage.Shared.QuestData)

local rewardGranted = ReplicatedStorage.Remotes.RewardGranted :: RemoteEvent

local profiles: { [Player]: Profile.Profile } = {}

local PlayerProfiles = {}

function PlayerProfiles.get(player: Player): Profile.Profile?
	return profiles[player]
end

-- Mirrors the display-only view of the profile to replicated player attributes.
function PlayerProfiles.sync(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("XP", profile.xp)

	local questId = QuestLogic.tracked(profile, QuestData)
	if questId then
		local progress = profile.questProgress[questId]
		player:SetAttribute("QuestId", questId)
		player:SetAttribute("QuestCount", progress.count)
		player:SetAttribute("QuestGoal", QuestData.quests[questId].objective.count)
		player:SetAttribute("QuestState", "active")
	else
		player:SetAttribute("QuestId", nil)
		local hasNext = QuestLogic.nextAvailable(profile, QuestData) ~= nil
		player:SetAttribute("QuestState", if hasNext then "available" else "done")
	end
end

function PlayerProfiles.grant(player: Player, reward: Profile.Reward, reason: string)
	local profile = profiles[player]
	if not profile then
		return
	end
	Profile.applyReward(profile, reward)
	PlayerProfiles.sync(player)
	rewardGranted:FireClient(player, reason, reward.xp or 0, reward.coins or 0)
end

local function onPlayerAdded(player: Player)
	if profiles[player] then
		return
	end
	profiles[player] = Profile.new()
	PlayerProfiles.sync(player)
end

function PlayerProfiles.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		profiles[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlayerProfiles
