local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MapBuilder = require(script.MapBuilder)
local PlayerProfiles = require(script.PlayerProfiles)
local CharacterService = require(script.CharacterService)
local QuestService = require(script.QuestService)
local ShopService = require(script.ShopService)
local Projectiles = require(script.Projectiles)
local EnemyService = require(script.EnemyService)
local CombatService = require(script.CombatService)

local map = MapBuilder.build()
CharacterService.start()
PlayerProfiles.start()
QuestService.start(map)
ShopService.start(map)
Projectiles.start()
EnemyService.start()
CombatService.start()

EnemyService.connectPurified(function(enemyType, reward, participants)
	for _, player in participants do
		PlayerProfiles.grant(player, reward, "purify")
		QuestService.onPurified(player, enemyType)
	end
end)

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent
PlayerProfiles.onLevelUp(function(player, level)
	fx:FireAllClients("levelUp", player, level)
end)

print("[LanternValley] Server started")
