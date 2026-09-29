local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Stats = require(Shared.Stats)

local MapBuilder = require(script.MapBuilder)
local PlayerProfiles = require(script.PlayerProfiles)
local CharacterService = require(script.CharacterService)
local QuestService = require(script.QuestService)
local ShopService = require(script.ShopService)
local Projectiles = require(script.Projectiles)
local EnemyService = require(script.EnemyService)
local CombatService = require(script.CombatService)
local ChestService = require(script.ChestService)
local PouchService = require(script.PouchService)
local Profile = require(script.Profile)
local ChestLogic = require(script.ChestLogic)
local Balance = require(Shared.Balance)
local SkillService = require(script.SkillService)

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent
local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local map = MapBuilder.build()
CharacterService.start()
PlayerProfiles.start()
QuestService.start(map)
ShopService.start(map)
Projectiles.start()
EnemyService.start()
CombatService.start()
ChestService.start()
PouchService.start()
SkillService.start()

-- Creatures give XP (boosted by the Wisdom skill) and Light Crystals for the pouch; coins come
-- from turning crystals in at the Great Lantern.
EnemyService.connectPurified(function(enemyType, reward, participants, position)
	for _, player in participants do
		local profile = PlayerProfiles.get(player)
		local xpMultiplier = if profile then Stats.of(profile).xpMultiplier else 1
		PlayerProfiles.grant(player, { xp = math.floor(reward.xp * xpMultiplier + 0.5), coins = 0 }, "purify")
		PouchService.give(player, reward.coins, position)
		QuestService.onPurified(player, enemyType)
		if profile and Profile.recordLegend(profile, enemyType) then
			local nameKey = Balance.enemies[enemyType].nameKey
			if ChestLogic.give(profile, "mystic", Progression.levelForXp(profile.xp)) then
				notice:FireClient(player, "notice_legend", nameKey)
			else
				profile.coins += Balance.legendCoins
				notice:FireClient(player, "notice_legend_coins", nameKey, Balance.legendCoins)
			end
			PlayerProfiles.sync(player)
		end
	end
end)

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
