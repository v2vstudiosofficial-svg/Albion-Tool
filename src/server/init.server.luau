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
local ChestData = require(Shared.ChestData)
local SkillService = require(script.SkillService)
local RiftService = require(script.RiftService)

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
RiftService.start()

-- Creatures give XP (boosted by the Wisdom skill) and Light Crystals for the pouch; coins come
-- from turning crystals in at the Great Lantern.
local eliteRandom = Random.new()

EnemyService.connectPurified(function(enemyType, reward, participants, position, enemy)
	for _, player in participants do
		local profile = PlayerProfiles.get(player)
		-- Elites may drop a chest for everyone who helped.
		if profile and enemy.elite and eliteRandom:NextNumber() < Balance.elite.chestChance then
			local chests = Balance.elite.chests
			local chestType = chests[eliteRandom:NextInteger(1, #chests)]
			if ChestLogic.give(profile, chestType, Progression.levelForXp(profile.xp)) then
				notice:FireClient(player, "notice_elite_chest", ChestData.chests[chestType].nameKey)
			end
		end
		local xpMultiplier = if profile then Stats.of(profile).xpMultiplier else 1
		-- Bosses pay coins straight away (a boss payout would overflow an early pouch).
		local isBoss = Balance.enemies[enemyType].isBoss == true
		PlayerProfiles.grant(player, { xp = math.floor(reward.xp * xpMultiplier + 0.5), coins = if isBoss then reward.coins else 0 }, "purify")
		if not isBoss then
			PouchService.give(player, reward.coins, position)
		end
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
