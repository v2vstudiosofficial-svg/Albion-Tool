-- Quest flow: starting quests at the Elder, turning validated world events into progress and
-- paying each completion exactly once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local QuestData = require(Shared.QuestData)
local WorldData = require(Shared.WorldData)
local Progression = require(Shared.Progression)
local Profile = require(script.Parent.Profile)
local QuestLogic = require(script.Parent.QuestLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local PassService = require(script.Parent.PassService)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local npcSay = Remotes.NpcSay :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local interact = Remotes.Interact :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local DISCOVERY_INTERVAL = 0.5
local INTERACT_COOLDOWN = 0.25

local QuestService = {}

local lastInteract: { [Player]: number } = {}

local function isNear(player: Player, position: Vector3, distance: number): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - position).Magnitude <= distance
end

local function complete(player: Player, profile, questId: string)
	local def = QuestData.quests[questId]
	local reward = def.reward
	if reward.charm and Profile.grantCharm(profile, reward.charm) then
		notice:FireClient(player, "notice_charm_gained", Balance.charms[reward.charm].nameKey)
	end
	if reward.flag and Profile.setFlag(profile, reward.flag) then
		notice:FireClient(player, "notice_restore_" .. reward.flag)
	end
	PassService.award(player, "quest")
	PlayerProfiles.grant(player, reward, "quest")
	fx:FireClient(player, "questComplete", questId)
end

-- Records an event for one player and pays out any quests it completes.
local function record(player: Player, event): boolean
	local profile = PlayerProfiles.get(player)
	if not profile then
		return false
	end
	local before = QuestLogic.tracked(profile, QuestData)
	local beforeCount = before and profile.questProgress[before].count
	local completed = QuestLogic.record(profile, QuestData, event)
	for _, questId in completed do
		complete(player, profile, questId)
	end
	local changed = #completed > 0 or (before ~= nil and profile.questProgress[before].count ~= beforeCount)
	if changed then
		PlayerProfiles.sync(player)
	end
	return changed
end

local function activeObjective(profile, kind: string)
	local questId = QuestLogic.tracked(profile, QuestData)
	local def = questId and QuestData.quests[questId]
	if def and def.objective.kind == kind then
		return questId, def.objective
	end
	return nil, nil
end

local function onTalkElder(player: Player, elderBody: BasePart)
	local profile = PlayerProfiles.get(player)
	if not profile or not isNear(player, elderBody.Position, Balance.npcTalkDistance) then
		return
	end
	if QuestLogic.tracked(profile, QuestData) then
		npcSay:FireClient(player, "Elder", "elder_quest_active")
		return
	end
	local nextId = QuestLogic.nextAvailable(profile, QuestData)
	if not nextId then
		npcSay:FireClient(player, "Elder", "elder_all_done")
		return
	end
	local level = Progression.levelForXp(profile.xp)
	local ok, reason = QuestLogic.start(profile, QuestData, nextId, level)
	if ok then
		npcSay:FireClient(player, "Elder", QuestData.quests[nextId].offerKey)
		-- Progress that already happened (e.g. an early staff upgrade) counts right away.
		if not record(player, { kind = "upgrade", value = profile.staffUpgrade }) then
			PlayerProfiles.sync(player)
		end
	elseif reason == "level" then
		npcSay:FireClient(player, "Elder", "elder_need_level", QuestData.quests[nextId].minLevel)
	end
end

local function onInteract(player: Player, kind: unknown, id: unknown)
	local now = os.clock()
	if lastInteract[player] and now - lastInteract[player] < INTERACT_COOLDOWN then
		return
	end
	lastInteract[player] = now
	if kind ~= "flower" or typeof(id) ~= "string" or #id > 32 then
		return
	end
	local position = WorldData.flowers[id :: string]
	local profile = PlayerProfiles.get(player)
	if not position or not profile then
		return
	end
	local questId = activeObjective(profile, "collect")
	if not questId or QuestLogic.isFound(profile, questId, id :: string) then
		return
	end
	if not isNear(player, WorldData.vector(position), Balance.interactDistance) then
		return
	end
	if record(player, { kind = "collect", id = id }) then
		notice:FireClient(player, "notice_flower")
		fx:FireClient(player, "collected", id, WorldData.vector(position))
	end
end

function QuestService.onPurified(player: Player, enemyType: string)
	record(player, { kind = "purify", target = enemyType })
end

function QuestService.onUpgrade(player: Player)
	local profile = PlayerProfiles.get(player)
	if profile then
		record(player, { kind = "upgrade", value = profile.staffUpgrade })
	end
end

function QuestService.onWave(player: Player, center: Vector3, radius: number)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local questId, objective = activeObjective(profile, "vine")
	if not questId then
		return
	end
	for _, vineId in objective.ids do
		local position = WorldData.vector(WorldData.vines[vineId])
		local distance = Vector3.new(position.X - center.X, 0, position.Z - center.Z).Magnitude
		if distance <= radius + Balance.vineHitTolerance and not QuestLogic.isFound(profile, questId, vineId) then
			if record(player, { kind = "vine", id = vineId }) then
				notice:FireClient(player, "notice_vine")
				fx:FireClient(player, "vineCleared", vineId)
			end
		end
	end
end

local function checkDiscoveries()
	for _, player in Players:GetPlayers() do
		local profile = PlayerProfiles.get(player)
		local questId, objective
		if profile then
			questId, objective = activeObjective(profile, "explore")
		end
		local target = questId and Targets.of(player)
		if target and objective then
			for _, landmarkId in objective.ids do
				local landmark = WorldData.landmarks[landmarkId]
				local position = WorldData.vector(landmark.position)
				local flatDistance = Vector3.new(target.root.Position.X - position.X, 0, target.root.Position.Z - position.Z).Magnitude
				if flatDistance <= Balance.discoverRadius and not QuestLogic.isFound(profile, questId, landmarkId) then
					if record(player, { kind = "explore", id = landmarkId }) then
						notice:FireClient(player, "notice_discovered", landmark.nameKey)
						fx:FireClient(player, "discovered", landmarkId, position)
					end
				end
			end
		end
	end
end

function QuestService.start(map: Folder)
	local elderBody = map.Village.Elder.Body :: BasePart
	local prompt = elderBody.TalkPrompt :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		onTalkElder(player, elderBody)
	end)

	-- A brand-new player gets a short greeting so the first step is obvious.
	PlayerProfiles.onReady(function(player)
		local profile = PlayerProfiles.get(player)
		if profile and profile.xp == 0 and next(profile.questProgress) == nil then
			npcSay:FireClient(player, "Elder", "elder_welcome")
		end
	end)

	interact.OnServerEvent:Connect(onInteract)
	Players.PlayerRemoving:Connect(function(player)
		lastInteract[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(DISCOVERY_INTERVAL)
			checkDiscoveries()
		end
	end)
end

return QuestService
