local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Balance = require(ReplicatedStorage.Shared.Balance)
local QuestData = require(ReplicatedStorage.Shared.QuestData)
local QuestLogic = require(script.Parent.QuestLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local npcSay = ReplicatedStorage.Remotes.NpcSay :: RemoteEvent

local QuestService = {}

local function isNear(player: Player, target: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - target.Position).Magnitude <= Balance.npcTalkDistance
end

local function onTalk(player: Player, elderBody: BasePart)
	local profile = PlayerProfiles.get(player)
	if not profile or not isNear(player, elderBody) then
		return
	end
	if QuestLogic.tracked(profile, QuestData) then
		npcSay:FireClient(player, "elder_quest_active")
		return
	end
	local nextId = QuestLogic.nextAvailable(profile, QuestData)
	if nextId and QuestLogic.start(profile, QuestData, nextId) then
		PlayerProfiles.sync(player)
		npcSay:FireClient(player, QuestData.quests[nextId].offerKey)
	else
		npcSay:FireClient(player, "elder_all_done")
	end
end

function QuestService.onPurified(player: Player, enemyType: string)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local completed = QuestLogic.recordPurify(profile, QuestData, enemyType)
	for _, questId in completed do
		PlayerProfiles.grant(player, QuestData.quests[questId].reward, "quest")
	end
	PlayerProfiles.sync(player)
end

function QuestService.start(map: Folder)
	local elderBody = map.Village.Elder.Body :: BasePart
	local prompt = elderBody.TalkPrompt :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		onTalk(player, elderBody)
	end)
end

return QuestService
