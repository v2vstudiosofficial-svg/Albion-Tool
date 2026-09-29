-- Persistent player profiles via ProfileStore (session locking, periodic/leave/shutdown saves).
-- A player without a loaded profile earns nothing, so a failed load can never overwrite saved data.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ProfileStore = require(script.Parent.Packages.ProfileStore)
local Profile = require(script.Parent.Profile)
local QuestLogic = require(script.Parent.QuestLogic)
local ChestLogic = require(script.Parent.ChestLogic)
local SkillLogic = require(script.Parent.SkillLogic)
local AchievementLogic = require(script.Parent.AchievementLogic)
local StoreLogic = require(script.Parent.StoreLogic)
local PassLogic = require(script.Parent.PassLogic)
local BountyLogic = require(script.Parent.BountyLogic)
local PetLogic = require(script.Parent.PetLogic)
local Shared = ReplicatedStorage.Shared
local QuestData = require(Shared.QuestData)
local AchievementData = require(Shared.AchievementData)
local Progression = require(Shared.Progression)
local WeaponData = require(Shared.WeaponData)
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
local random = Random.new()

local function rng(): number
	return random:NextNumber()
end

-- The Bounty Board has its own generator so it never shifts other random rolls.
local bountyRandom = Random.new()
local function bountyRng(): number
	return bountyRandom:NextNumber()
end

-- "id:value" pairs for small replicated tables (upgrade levels, skill ranks).
local function pairsCsv(values: { [string]: number }): string
	local list = {}
	for key, value in values do
		table.insert(list, key .. ":" .. value)
	end
	table.sort(list)
	return table.concat(list, ",")
end
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
	player:SetAttribute("Upgrades", pairsCsv(profile.upgrades))
	player:SetAttribute("Crystals", profile.crystals)
	player:SetAttribute("Skills", pairsCsv(profile.skills))
	player:SetAttribute("SkillOffer", table.concat(profile.skillOffer, ","))
	player:SetAttribute("PendingPicks", profile.pendingPicks)
	local main, companions = Profile.loadout(profile)
	player:SetAttribute("Weapon", main)
	player:SetAttribute("Companions", table.concat(companions, ","))
	player:SetAttribute("Weapons", csv(profile.ownedWeapons))
	player:SetAttribute("SlotLevels", table.concat(profile.slotLevels, ","))
	player:SetAttribute("Stars", pairsCsv(profile.weaponStars))
	-- Chests as "type:startedAt" in slot order; spots as "spotId:readyAt" for taken spots only.
	local chests = {}
	for _, chest in profile.chests do
		table.insert(chests, chest.type .. ":" .. chest.startedAt)
	end
	player:SetAttribute("Chests", table.concat(chests, ","))
	local now = os.time()
	local spots = {}
	for spotId in profile.chestSpots do
		local readyAt = ChestLogic.spotReadyAt(profile, spotId, now)
		if readyAt then
			table.insert(spots, spotId .. ":" .. readyAt)
		end
	end
	table.sort(spots)
	player:SetAttribute("ChestSpots", table.concat(spots, ","))
	player:SetAttribute("Legends", csv(profile.legends))
	player:SetAttribute("Bounties", BountyLogic.encode(profile))
	player:SetAttribute("TowerBest", profile.towerBest)
	player:SetAttribute("Pet", PetLogic.active(profile))
	player:SetAttribute("PetProgress", PetLogic.encode(profile))
	local log = {}
	for _, id in AchievementData.order do
		table.insert(log, id .. ":" .. AchievementLogic.claimed(profile, id) .. ":" .. AchievementLogic.progress(profile, id))
	end
	player:SetAttribute("Achievements", table.concat(log, ","))
	-- Costumes, Light Pass and store state.
	player:SetAttribute("Costumes", csv(profile.ownedCosmetics))
	local worn = {}
	for slot, id in profile.equippedCosmetics do
		table.insert(worn, slot .. ":" .. id)
	end
	table.sort(worn)
	player:SetAttribute("Worn", table.concat(worn, ","))
	player:SetAttribute("PassSeason", profile.pass.season)
	player:SetAttribute("PassXp", profile.pass.xp)
	player:SetAttribute("PassPremium", profile.pass.premium)
	player:SetAttribute("PassFree", csv(profile.pass.free))
	player:SetAttribute("PassPremiumClaimed", csv(profile.pass.premiumClaimed))
	player:SetAttribute("BoostUntil", profile.boostUntil)
	player:SetAttribute("OneTime", csv(profile.oneTime))
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

-- Robux purchase flow (ProfileStore's recommended pattern): remember the receipt's purchase id
-- and grant once, then report success only after the id is saved. Returns true when the receipt
-- may be marked granted; false means "try again later" (Roblox retries the receipt).
local SAVE_WAIT_LIMIT = 30

function PlayerProfiles.processPurchase(player: Player, purchaseId: string, grant: (any) -> ()): boolean
	local session = sessions[player]
	if not session or not session:IsActive() then
		return false
	end
	if StoreLogic.remember(session.Data, purchaseId) then
		grant(session.Data)
		PlayerProfiles.sync(player)
	end
	local function saved(data: any): boolean
		return type(data) == "table" and type(data.purchaseIds) == "table" and table.find(data.purchaseIds, purchaseId) ~= nil
	end
	if saved(session.LastSavedData) then
		return true
	end
	local done = false
	local connection = session.OnAfterSave:Connect(function(data)
		if saved(data) then
			done = true
		end
	end)
	session:Save()
	local waited = 0
	while not done and session:IsActive() and waited < SAVE_WAIT_LIMIT do
		waited += task.wait(0.1)
	end
	connection:Disconnect()
	return done
end

function PlayerProfiles.grant(player: Player, reward: Profile.Reward, reason: string)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local before = Progression.levelForXp(profile.xp)
	Profile.applyReward(profile, reward)
	local after = Progression.levelForXp(profile.xp)
	-- Every level gained earns a skill card pick.
	SkillLogic.grantPicks(profile, after - before, rng)
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
	PassLogic.ensureSeason(session.Data)
	BountyLogic.fill(session.Data, Progression.levelForXp(session.Data.xp), bountyRng)
	if session.Data.pendingPicks > 0 and #session.Data.skillOffer == 0 then
		session.Data.skillOffer = SkillLogic.roll(session.Data, rng)
	end

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

	-- Studio-only test helpers (server view, Workspace attributes). Never in live games:
	-- LvDebugLevel (number) moves every loaded player to that level; LvDebugAllWeapons (true)
	-- gives them every weapon, so late weapons and floating slots can be checked quickly.
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
		workspace:GetAttributeChangedSignal("LvDebugAllWeapons"):Connect(function()
			if workspace:GetAttribute("LvDebugAllWeapons") ~= true then
				return
			end
			for player, session in sessions do
				for weaponId in WeaponData.weapons do
					session.Data.ownedWeapons[weaponId] = true
				end
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
