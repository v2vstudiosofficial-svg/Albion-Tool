-- Persistent player profiles via ProfileStore (session locking, periodic/leave/shutdown saves).
-- A player without a loaded profile earns nothing, so a failed load can never overwrite saved data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Packages.ProfileStore)
local Profile = require(script.Parent.Profile)
local QuestLogic = require(script.Parent.QuestLogic)
local Shared = ReplicatedStorage.Shared
local QuestData = require(Shared.QuestData)
local Progression = require(Shared.Progression)
local Strings = require(Shared.Strings)

local Remotes = ReplicatedStorage.Remotes
local rewardGranted = Remotes.RewardGranted :: RemoteEvent
local retryLoad = Remotes.RetryLoad :: RemoteEvent

-- Studio uses a separate store so test progress never touches live data. Without Studio API
-- access ProfileStore falls back to an in-memory mock automatically.
local STORE_NAME = if RunService:IsStudio() then "LanternValley_Studio_v1" else "LanternValley_Live_v1"
local RETRY_COOLDOWN = 5

local store = ProfileStore.New(STORE_NAME, Profile.new())

local sessions: { [Player]: any } = {}
local loading: { [Player]: boolean } = {}
local lastRetry: { [Player]: number } = {}
local readyListeners: { (Player) -> () } = {}
local changedListeners: { (Player) -> () } = {}
local levelListeners: { (Player, number, number) -> () } = {}

local PlayerProfiles = {}

local function csv(set: { [string]: boolean }?): string
	local keys = {}
	for key, value in set or {} do
		if value == true then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return table.concat(keys, ",")
end

function PlayerProfiles.get(player: Player): Profile.Profile?
	local session = sessions[player]
	return session and session.Data
end

function PlayerProfiles.level(player: Player): number
	local profile = PlayerProfiles.get(player)
	return if profile then Progression.levelForXp(profile.xp) else 1
end

function PlayerProfiles.onReady(listener: (Player) -> ())
	table.insert(readyListeners, listener)
end

function PlayerProfiles.onChanged(listener: (Player) -> ())
	table.insert(changedListeners, listener)
end

-- listener(player, newLevel, previousLevel)
function PlayerProfiles.onLevelUp(listener: (Player, number, number) -> ())
	table.insert(levelListeners, listener)
end

-- Mirrors the display-only view of the profile to replicated player attributes.
function PlayerProfiles.sync(player: Player)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local level = Progression.levelForXp(profile.xp)
	player:SetAttribute("Level", level)
	player:SetAttribute("XP", profile.xp)
	player:SetAttribute("Coins", profile.coins)
	player:SetAttribute("StaffTier", profile.staffUpgrade)
	local main, companions = Profile.loadout(profile)
	player:SetAttribute("Weapon", main)
	player:SetAttribute("Companions", table.concat(companions, ","))
	player:SetAttribute("Charm", profile.equippedCharm or "")
	player:SetAttribute("Charms", csv(profile.ownedCharms))
	player:SetAttribute("Flags", csv(profile.restorationFlags))

	local questId = QuestLogic.tracked(profile, QuestData)
	if questId then
		local progress = profile.questProgress[questId]
		player:SetAttribute("QuestId", questId)
		player:SetAttribute("QuestCount", progress.count)
		player:SetAttribute("QuestGoal", QuestLogic.goal(QuestData.quests[questId]))
		player:SetAttribute("QuestFound", csv(progress.found))
		player:SetAttribute("QuestState", "active")
	else
		local nextId = QuestLogic.nextAvailable(profile, QuestData)
		player:SetAttribute("QuestId", nextId)
		player:SetAttribute("QuestFound", "")
		if nextId == nil then
			player:SetAttribute("QuestState", "done")
		else
			local ok, reason = QuestLogic.canStart(profile, QuestData, nextId, level)
			player:SetAttribute("QuestNeedLevel", QuestData.quests[nextId].minLevel)
			player:SetAttribute("QuestState", if not ok and reason == "level" then "level" else "available")
		end
	end

	for _, listener in changedListeners do
		task.spawn(listener, player)
	end
end

function PlayerProfiles.grant(player: Player, reward: Profile.Reward, reason: string)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local before = Progression.levelForXp(profile.xp)
	Profile.applyReward(profile, reward)
	local after = Progression.levelForXp(profile.xp)
	PlayerProfiles.sync(player)
	rewardGranted:FireClient(player, reason, reward.xp or 0, reward.coins or 0)
	if after > before then
		for _, listener in levelListeners do
			task.spawn(listener, player, after, before)
		end
	end
end

local function load(player: Player)
	if loading[player] or sessions[player] then
		return
	end
	loading[player] = true
	player:SetAttribute("DataState", "loading")

	local session = store:StartSessionAsync(tostring(player.UserId), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})
	loading[player] = nil

	if session == nil then
		if player.Parent == Players then
			player:SetAttribute("DataState", "failed")
		end
		return
	end

	session:AddUserId(player.UserId)
	session:Reconcile()
	Profile.sanitize(session.Data)

	session.OnSessionEnd:Connect(function()
		sessions[player] = nil
		if player.Parent == Players then
			player:SetAttribute("DataState", "ended")
			player:Kick(Strings.get("data_session_ended"))
		end
	end)

	if player.Parent ~= Players then
		session:EndSession()
		return
	end

	sessions[player] = session
	player:SetAttribute("DataState", "ready")
	PlayerProfiles.sync(player)
	for _, listener in readyListeners do
		task.spawn(listener, player)
	end
end

function PlayerProfiles.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		sessions[player] = nil
		lastRetry[player] = nil
		if session then
			session:EndSession()
		end
	end)

	-- Studio-only test helper: set the Workspace attribute LvDebugLevel (server view) to move every
	-- loaded player to that level, e.g. to look at late weapons and floating slots. Never in live games.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("LvDebugLevel"):Connect(function()
			local level = workspace:GetAttribute("LvDebugLevel")
			if typeof(level) ~= "number" then
				return
			end
			local xp = Progression.thresholds[math.clamp(math.floor(level), 1, Progression.MAX_LEVEL)]
			for player, session in sessions do
				session.Data.xp = xp
				PlayerProfiles.sync(player)
			end
		end)
	end

	retryLoad.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if player:GetAttribute("DataState") ~= "failed" or (lastRetry[player] and now - lastRetry[player] < RETRY_COOLDOWN) then
			return
		end
		lastRetry[player] = now
		load(player)
	end)
end

return PlayerProfiles
