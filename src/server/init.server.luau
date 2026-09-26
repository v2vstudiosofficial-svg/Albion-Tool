local MapBuilder = require(script.MapBuilder)
local PlayerProfiles = require(script.PlayerProfiles)
local QuestService = require(script.QuestService)
local EnemyService = require(script.EnemyService)
local CombatService = require(script.CombatService)

local map = MapBuilder.build()
PlayerProfiles.start()
QuestService.start(map)
EnemyService.start(map)
CombatService.start()

EnemyService.connectPurified(function(enemyType, reward, participants)
	for _, player in participants do
		PlayerProfiles.grant(player, reward, "purify")
		QuestService.onPurified(player, enemyType)
	end
end)

print("[LanternValley] Server started")
