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
local AchievementService = require(script.AchievementService)
local BountyService = require(script.BountyService)
local EmoteService = require(script.EmoteService)
local TowerService = require(script.TowerService)
local PetService = require(script.PetService)
local RebirthService = require(script.RebirthService)
local Targets = require(script.Targets)
local CosmeticService = require(script.CosmeticService)
local PassService = require(script.PassService)
local StoreService = require(script.StoreService)
local StoreLogic = require(script.StoreLogic)
local StoreData = require(Shared.StoreData)

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
AchievementService.start()
BountyService.start(map)
EmoteService.start()
TowerService.start(map)
PetService.start()
RebirthService.start(map)
CosmeticService.start()
PassService.start()
StoreService.start()

-- Creatures give XP (boosted by the Wisdom skill) and Light Crystals for the pouch; coins come
-- from turning crystals in at the Great Lantern.
local eliteRandom = Random.new()

-- Other living players close enough to share the team bonus.
local function alliesNear(player: Player): number
	local own = Targets.of(player)
	if not own then
		return 0
	end
	local count = 0
	for _, other in Targets.get() do
		if other.player ~= player and (other.root.Position - own.root.Position).Magnitude <= Balance.coop.radius then
			count += 1
		end
	end
	return count
end

EnemyService.connectPurified(function(enemyType, reward, participants, position, enemy)
	for _, player in participants do
		local profile = PlayerProfiles.get(player)
		AchievementService.count(player, "purifies")
		if enemy.elite then
			AchievementService.count(player, "elites")
		end
		-- Bounties count the level-scaled Legendary Shadows, not the intro Warden.
		if Balance.enemies[enemyType].scales then
			AchievementService.count(player, "legendWins")
		end
		-- Elites may drop a chest for everyone who helped.
		if profile and enemy.elite and eliteRandom:NextNumber() < Balance.elite.chestChance then
			local chests = Balance.elite.chests
			local chestType = chests[eliteRandom:NextInteger(1, #chests)]
			if ChestLogic.give(profile, chestType, Progression.levelForXp(profile.xp)) then
				notice:FireClient(player, "notice_elite_chest", ChestData.chests[chestType].nameKey)
			end
		end
		local xpMultiplier = if profile then Stats.of(profile).xpMultiplier else 1
		local teamBonus = Progression.coopMultiplier(alliesNear(player))
		xpMultiplier *= teamBonus
		if profile and StoreLogic.boostActive(profile, os.time()) then
			xpMultiplier *= StoreData.xpBoostMultiplier
		end
		PassService.award(player, "purify")
		if enemy.elite then
			PassService.award(player, "elite")
		end
		-- Bosses pay coins straight away (a boss payout would overflow an early pouch).
		local isBoss = Balance.enemies[enemyType].isBoss == true
		PlayerProfiles.grant(player, { xp = math.floor(reward.xp * xpMultiplier + 0.5), coins = if isBoss then reward.coins else 0 }, "purify")
		if not isBoss then
			PouchService.give(player, math.floor(reward.coins * teamBonus + 0.5), position)
		end
		QuestService.onPurified(player, enemyType)
		if profile and Profile.recordLegend(profile, enemyType) then
			PassService.award(player, "legend")
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
