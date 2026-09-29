local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapBuilder = require(script.MapBuilder)
local PlayerProfiles = require(script.PlayerProfiles)
local CharacterService = require(script.CharacterService)
local QuestService = require(script.QuestService)
local ShopService = require(script.ShopService)
local Projectiles = require(script.Projectiles)
local EnemyService = require(script.EnemyService)
local CombatService = require(script.CombatService)
local ChestService = require(script.ChestService)

local map = MapBuilder.build()
CharacterService.start()
PlayerProfiles.start()
QuestService.start(map)
ShopService.start(map)
Projectiles.start()
EnemyService.start()
CombatService.start()
ChestService.start()

EnemyService.connectPurified(function(enemyType, reward, participants)
	for _, player in participants do
		PlayerProfiles.grant(player, reward, "purify")
		QuestService.onPurified(player, enemyType)
	end
end)

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent
local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent
PlayerProfiles.onLevelUp(function(player, level, previous)
	fx:FireAllClients("levelUp", player, level)
	if Progression.chestSlots(level) > Progression.chestSlots(previous) then
		notice:FireClient(player, "notice_chest_slot_unlocked")
	end
	if Progression.companionSlots(level) > Progression.companionSlots(previous) then
		notice:FireClient(player, "notice_companion_unlocked")
	end
end)

print("[LanternValley] Server started")
