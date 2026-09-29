-- Quest flow: starting quests at their giver (the Elder or Ranger Wren), turning validated world
-- events and counters into progress and paying each completion exactly once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local QuestData = require(Shared.QuestData)
local StoryData = require(Shared.StoryData)
local Stats = require(Shared.Stats)
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
local cinematic = Remotes.Cinematic :: RemoteEvent

local DISCOVERY_INTERVAL = 0.5
local INTERACT_COOLDOWN = 0.25

local QuestService = {}

local lastInteract: { [Player]: number } = {}

local function isNear(player: Player, position: Vector3, distance: number): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - position).Magnitude <= distance
end

-- Plays a story scene on the player's screen (if the story has one); returns whether it did.
local function playScene(player: Player, sceneId: string, delay: number?): boolean
	if not StoryData.scenes[sceneId] then
		return false
	end
	if delay and delay > 0 then
		task.delay(delay, function()
			if player.Parent == Players then
				cinematic:FireClient(player, sceneId)
			end
		end)
	else
		cinematic:FireClient(player, sceneId)
	end
	return true
end

-- Full scenes after a quest (boss victories) wait a moment so the fight is really over.
local END_SCENE_DELAY = 2.5

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
	-- Every finished main quest is a permanent XP blessing (Stats.storyDone).
	local blessing = math.floor(Stats.storyDone(profile) * Balance.story.xpPerQuest * 100 + 0.5)
	notice:FireClient(player, "notice_story_blessing", blessing)
	local endId = questId .. "_end"
	local endScene = StoryData.scenes[endId]
	playScene(player, endId, if endScene and endScene.mode == "full" then END_SCENE_DELAY else nil)
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

-- What each quest giver says (Strings keys): a quest is running, nothing is left, the player is
-- too low a level, or the next quest belongs to the other giver.
local TALK = {
	Elder = { active = "elder_quest_active", done = "elder_all_done", level = "elder_need_level", other = "elder_go_wren" },
	Wren = { active = "wren_quest_active", done = "wren_all_done", level = "wren_need_level", other = "wren_go_elder" },
}

local function onTalk(player: Player, npc: string, body: BasePart)
	local profile = PlayerProfiles.get(player)
	if not profile or not isNear(player, body.Position, Balance.npcTalkDistance) then
		return
	end
	local lines = TALK[npc]
	local tracked = QuestLogic.tracked(profile, QuestData)
	if tracked then
		-- The quest giver tells the story of the running quest again; others just encourage.
		if (QuestData.quests[tracked].giver or "Elder") ~= npc or not playScene(player, tracked) then
			npcSay:FireClient(player, npc, lines.active)
		end
		return
	end
	local nextId = QuestLogic.nextAvailable(profile, QuestData)
	if not nextId then
		npcSay:FireClient(player, npc, lines.done)
		return
	end
	local def = QuestData.quests[nextId]
	if (def.giver or "Elder") ~= npc then
		npcSay:FireClient(player, npc, lines.other)
		return
	end
	local level = Progression.levelForXp(profile.xp)
	local ok, reason = QuestLogic.start(profile, QuestData, nextId, level)
	if ok then
		if not playScene(player, nextId) then
			npcSay:FireClient(player, npc, def.offerKey)
		end
		-- Progress that already happened (e.g. an early staff upgrade) counts right away.
		local changed = record(player, { kind = "upgrade", value = profile.staffUpgrade })
		if not QuestService.syncCounters(player) and not changed then
			PlayerProfiles.sync(player)
		end
	elseif reason == "level" then
		npcSay:FireClient(player, npc, lines.level, def.minLevel)
	end
end

-- Counter quests (rifts, elites, the best tower floor) follow the profile, so they are checked
-- whenever it changes. Returns true when something changed.
function QuestService.syncCounters(player: Player): boolean
	local profile = PlayerProfiles.get(player)
	if not profile then
		return false
	end
	local before = QuestLogic.tracked(profile, QuestData)
	local beforeCount = before and profile.questProgress[before].count
	local completed = QuestLogic.syncCounters(profile, QuestData)
	for _, questId in completed do
		complete(player, profile, questId)
	end
	local changed = #completed > 0 or (before ~= nil and profile.questProgress[before].count ~= beforeCount)
	if changed then
		PlayerProfiles.sync(player)
	end
	return changed
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
	for npc in TALK do
		local body = map.Village[npc].Body :: BasePart
		local prompt = body.TalkPrompt :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			onTalk(player, npc, body)
		end)
	end
	PlayerProfiles.onChanged(QuestService.syncCounters)

	-- A brand-new player gets a short greeting so the first step is obvious.
	PlayerProfiles.onReady(function(player)
		local profile = PlayerProfiles.get(player)
		if profile and profile.xp == 0 and next(profile.questProgress) == nil then
			if not playScene(player, "prologue") then
				npcSay:FireClient(player, "Elder", "elder_welcome")
			end
		end
	end)

	-- Studio-only helper: set the Workspace attribute LvDebugScene to a story scene id (e.g.
	-- "warden_end") to play it for everyone, for checking the writing and the camera.
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("LvDebugScene"):Connect(function()
			local sceneId = workspace:GetAttribute("LvDebugScene")
			if typeof(sceneId) == "string" then
				for _, player in Players:GetPlayers() do
					playScene(player, sceneId)
				end
			end
		end)
	end

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
