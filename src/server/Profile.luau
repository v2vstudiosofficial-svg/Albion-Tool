-- Pure profile rules (schema, rewards, purchases, charms). No Roblox APIs, so Lune can test it.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local WeaponData = if Shared then require(Shared.WeaponData) else require("../shared/WeaponData")
local ChestData = if Shared then require(Shared.ChestData) else require("../shared/ChestData")
local SkillData = if Shared then require(Shared.SkillData) else require("../shared/SkillData")
local AchievementData = if Shared then require(Shared.AchievementData) else require("../shared/AchievementData")
local CosmeticData = if Shared then require(Shared.CosmeticData) else require("../shared/CosmeticData")
local PassData = if Shared then require(Shared.PassData) else require("../shared/PassData")
local StoreData = if Shared then require(Shared.StoreData) else require("../shared/StoreData")
local BountyData = if Shared then require(Shared.BountyData) else require("../shared/BountyData")
local PetData = if Shared then require(Shared.PetData) else require("../shared/PetData")
local SettingsData = if Shared then require(Shared.SettingsData) else require("../shared/SettingsData")

export type QuestProgress = {
	state: "active" | "completed",
	count: number,
	-- Counter quests: the counter's value when the quest started.
	base: number?,
	found: { [string]: boolean }?,
}

-- A chest waiting in a chest slot; startedAt is the os.time() its unlock began (0 = not yet).
export type Chest = { type: string, startedAt: number }

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	-- Weapon power level (the "power" forge upgrade; named for save compatibility).
	staffUpgrade: number,
	-- Other forge upgrade levels: pouch, health, regen, crit.
	upgrades: { [string]: number },
	-- Light Crystals carried in the pouch (turned into coins at the Great Lantern).
	crystals: number,
	-- Skill card ranks, the current offer (skill ids, or "coins") and level-ups not yet spent.
	skills: { [string]: number },
	skillOffer: { string },
	pendingPicks: number,
	-- Main weapon, and explicit picks for floating slots (empty slots are auto-filled).
	equippedWeapon: string,
	companions: { string },
	ownedWeapons: { [string]: boolean },
	-- Stars per weapon (1..WeaponData.maxStars) from repeat finds in chests.
	weaponStars: { [string]: number },
	-- slotLevels[slot + 1]: level of weapon slot 0 (main) .. 4 (floating).
	slotLevels: { number },
	chests: { Chest },
	-- os.time() when this player last took the chest at each world spot.
	chestSpots: { [string]: number },
	-- Legendary Shadows purified at least once (boss kind -> true).
	legends: { [string]: boolean },
	-- Adventure Log: counters (purifies, elites, rifts, chests, crystals) and claimed tiers.
	counters: { [string]: number },
	-- Bounty Board: open bounties (see BountyLogic).
	bounties: { { kind: string, goal: number, base: number } },
	-- Highest Shadow Tower floor cleared.
	towerBest: number,
	-- The pet following the player ("" = none); pets themselves are derived from progress (PetLogic).
	equippedPet: string,
	-- Comfort settings the player chose (see Profile.setSetting).
	settings: { [string]: any },
	-- Times the player restarted the climb at level 100 (see Balance.rebirth).
	rebirths: number,
	achievements: { [string]: number },
	-- Costumes owned and worn (slot -> costume id).
	ownedCosmetics: { [string]: boolean },
	equippedCosmetics: { [string]: string },
	-- Light Pass for `season`: Pass XP, premium, and claimed tiers per track.
	pass: { season: number, xp: number, premium: boolean, free: { [string]: boolean }, premiumClaimed: { [string]: boolean } },
	-- Store: recent purchase ids (duplicate receipts), one-time products bought, XP boost end (os.time).
	purchaseIds: { string },
	oneTime: { [string]: boolean },
	boostUntil: number,
	ownedCharms: { [string]: boolean },
	equippedCharm: string?,
	questProgress: { [string]: QuestProgress },
	restorationFlags: { [string]: boolean },
}

export type Reward = {
	xp: number?,
	coins: number?,
}

local Profile = {}

Profile.SCHEMA_VERSION = 1
local MAX_UPGRADE = Balance.upgrades.power.maxLevel

function Profile.new(): Profile
	return {
		schemaVersion = Profile.SCHEMA_VERSION,
		xp = 0,
		coins = 0,
		staffUpgrade = 0,
		upgrades = {},
		crystals = 0,
		skills = {},
		skillOffer = {},
		pendingPicks = 0,
		equippedWeapon = "staff",
		companions = {},
		ownedWeapons = { staff = true },
		weaponStars = {},
		slotLevels = { 0, 0, 0, 0, 0 },
		chests = {},
		chestSpots = {},
		legends = {},
		counters = {},
		bounties = {},
		towerBest = 0,
		equippedPet = "",
		settings = SettingsData.defaults(),
		rebirths = 0,
		achievements = {},
		ownedCosmetics = {},
		equippedCosmetics = {},
		pass = { season = PassData.season, xp = 0, premium = false, free = {}, premiumClaimed = {} },
		purchaseIds = {},
		oneTime = {},
		boostUntil = 0,
		ownedCharms = {},
		equippedCharm = nil,
		questProgress = {},
		restorationFlags = {},
	}
end

local function isValidAmount(value: any): boolean
	return type(value) == "number" and value >= 0 and value == math.floor(value) and value < math.huge
end

-- Repairs a loaded profile in place so bad or tampered values can never crash gameplay code.
-- Unknown quest ids and flags are kept for forward compatibility.
function Profile.sanitize(data: any): Profile
	if type(data.schemaVersion) ~= "number" then
		data.schemaVersion = Profile.SCHEMA_VERSION
	end
	if not isValidAmount(data.xp) then
		data.xp = 0
	end
	if not isValidAmount(data.coins) then
		data.coins = 0
	end
	if not isValidAmount(data.staffUpgrade) then
		data.staffUpgrade = 0
	end
	data.staffUpgrade = math.min(data.staffUpgrade, MAX_UPGRADE)

	local upgrades = {}
	for _, stat in Balance.upgradeOrder do
		local value = type(data.upgrades) == "table" and data.upgrades[stat]
		if stat ~= "power" and isValidAmount(value) and value > 0 then
			upgrades[stat] = math.min(value, Balance.upgrades[stat].maxLevel)
		end
	end
	data.upgrades = upgrades
	if not isValidAmount(data.crystals) then
		data.crystals = 0
	end
	local skills = {}
	if type(data.skills) == "table" then
		for skillId, value in data.skills do
			local skill = SkillData.skills[skillId]
			if skill and isValidAmount(value) and value > 0 then
				skills[skillId] = math.min(value, skill.maxRank)
			end
		end
	end
	data.skills = skills
	local offer = {}
	if type(data.skillOffer) == "table" then
		for _, skillId in data.skillOffer do
			if (skillId == "coins" or SkillData.skills[skillId]) and #offer < SkillData.offerCount then
				table.insert(offer, skillId)
			end
		end
	end
	data.skillOffer = offer
	if not isValidAmount(data.pendingPicks) then
		data.pendingPicks = 0
	end

	local weapons = {}
	if type(data.ownedWeapons) == "table" then
		for weaponId, value in data.ownedWeapons do
			if value == true and WeaponData.weapons[weaponId] then
				weapons[weaponId] = true
			end
		end
	end
	weapons[WeaponData.starter] = true
	data.ownedWeapons = weapons
	if type(data.equippedWeapon) ~= "string" or not weapons[data.equippedWeapon] then
		data.equippedWeapon = WeaponData.starter
	end

	local stars = {}
	if type(data.weaponStars) == "table" then
		for weaponId, value in data.weaponStars do
			if WeaponData.weapons[weaponId] and isValidAmount(value) and value >= 1 then
				stars[weaponId] = math.min(WeaponData.maxStars, math.floor(value))
			end
		end
	end
	data.weaponStars = stars

	local slotLevels = {}
	for index = 1, WeaponData.maxCompanions + 1 do
		local value = type(data.slotLevels) == "table" and data.slotLevels[index]
		slotLevels[index] = if isValidAmount(value) then math.min(value, WeaponData.maxSlotLevel) else 0
	end
	data.slotLevels = slotLevels

	local chests = {}
	if type(data.chests) == "table" then
		for _, chest in data.chests do
			if #chests < #ChestData.slotUnlockLevels and type(chest) == "table" and ChestData.chests[chest.type] then
				table.insert(chests, { type = chest.type, startedAt = if isValidAmount(chest.startedAt) then chest.startedAt else 0 })
			end
		end
	end
	data.chests = chests

	local spots = {}
	if type(data.chestSpots) == "table" then
		for spotId, takenAt in data.chestSpots do
			if type(spotId) == "string" and isValidAmount(takenAt) then
				spots[spotId] = takenAt
			end
		end
	end
	data.chestSpots = spots

	local legends = {}
	if type(data.legends) == "table" then
		for kind, value in data.legends do
			if value == true and table.find(Balance.legends, kind) then
				legends[kind] = true
			end
		end
	end
	data.legends = legends

	local counters = {}
	if type(data.counters) == "table" then
		for key, value in data.counters do
			if type(key) == "string" and isValidAmount(value) then
				counters[key] = value
			end
		end
	end
	data.counters = counters

	local bounties = {}
	if type(data.bounties) == "table" then
		local seen = {}
		for _, bounty in data.bounties do
			local def = type(bounty) == "table" and BountyData.kinds[bounty.kind]
			if def and #bounties < BountyData.slots and not seen[bounty.kind] and isValidAmount(bounty.goal) and isValidAmount(bounty.base) then
				seen[bounty.kind] = true
				table.insert(bounties, { kind = bounty.kind, goal = math.clamp(math.floor(bounty.goal), 1, def.goal), base = math.floor(bounty.base) })
			end
		end
	end
	data.bounties = bounties
	local saved = if type(data.settings) == "table" then data.settings else {}
	local settings = SettingsData.defaults()
	for key in SettingsData.settings do
		local cleaned = SettingsData.clean(key, saved[key])
		if cleaned ~= nil then
			settings[key] = cleaned
		end
	end
	data.settings = settings
	data.equippedPet = if type(data.equippedPet) == "string" and PetData.pets[data.equippedPet] then data.equippedPet else ""
	data.rebirths = if isValidAmount(data.rebirths) then math.min(math.floor(data.rebirths), 1000) else 0
	data.towerBest = if isValidAmount(data.towerBest) then math.min(math.floor(data.towerBest), 10000) else 0
	local achievements = {}
	if type(data.achievements) == "table" then
		for id, tier in data.achievements do
			local def = AchievementData.achievements[id]
			if def and isValidAmount(tier) and tier > 0 then
				achievements[id] = math.min(tier, #def.tiers)
			end
		end
	end
	data.achievements = achievements

	local cosmetics = {}
	if type(data.ownedCosmetics) == "table" then
		for id, value in data.ownedCosmetics do
			if value == true and CosmeticData.costumes[id] then
				cosmetics[id] = true
			end
		end
	end
	data.ownedCosmetics = cosmetics
	local worn = {}
	if type(data.equippedCosmetics) == "table" then
		for _, slot in CosmeticData.slots do
			local id = data.equippedCosmetics[slot]
			if type(id) == "string" and cosmetics[id] and CosmeticData.costumes[id].slot == slot then
				worn[slot] = id
			end
		end
	end
	data.equippedCosmetics = worn

	local pass = if type(data.pass) == "table" then data.pass else {}
	local function tierSet(value: any): { [string]: boolean }
		local set = {}
		if type(value) == "table" then
			for key, claimed in value do
				local tier = tonumber(key)
				if claimed == true and tier and tier >= 1 and tier <= PassData.tiers and tier % 1 == 0 then
					set[tostring(tier)] = true
				end
			end
		end
		return set
	end
	data.pass = {
		season = if isValidAmount(pass.season) then pass.season else PassData.season,
		xp = if isValidAmount(pass.xp) then pass.xp else 0,
		premium = pass.premium == true,
		free = tierSet(pass.free),
		premiumClaimed = tierSet(pass.premiumClaimed),
	}

	local ids = {}
	if type(data.purchaseIds) == "table" then
		for _, id in data.purchaseIds do
			if type(id) == "string" and #ids < StoreData.purchaseIdCache then
				table.insert(ids, id)
			end
		end
	end
	data.purchaseIds = ids
	local oneTime = {}
	if type(data.oneTime) == "table" then
		for key, value in data.oneTime do
			if value == true and StoreData.products[key] then
				oneTime[key] = true
			end
		end
	end
	data.oneTime = oneTime
	if not isValidAmount(data.boostUntil) then
		data.boostUntil = 0
	end
	local companions = {}
	if type(data.companions) == "table" then
		for slot = 1, WeaponData.maxCompanions do
			local weaponId = data.companions[slot]
			companions[slot] = if type(weaponId) == "string" and WeaponData.weapons[weaponId] then weaponId else ""
		end
	end
	data.companions = companions

	if type(data.ownedCharms) ~= "table" then
		data.ownedCharms = {}
	end
	for charmId, owned in data.ownedCharms do
		if Balance.charms[charmId] == nil or owned ~= true then
			data.ownedCharms[charmId] = nil
		end
	end
	if data.equippedCharm ~= nil and data.ownedCharms[data.equippedCharm] ~= true then
		data.equippedCharm = nil
	end

	if type(data.questProgress) ~= "table" then
		data.questProgress = {}
	end
	for questId, progress in data.questProgress do
		local valid = type(progress) == "table"
			and (progress.state == "active" or progress.state == "completed")
			and isValidAmount(progress.count)
		if not valid then
			data.questProgress[questId] = nil
		elseif progress.found ~= nil and type(progress.found) ~= "table" then
			progress.found = nil
		end
		if valid and progress.base ~= nil and not isValidAmount(progress.base) then
			progress.base = nil
		end
	end

	if type(data.restorationFlags) ~= "table" then
		data.restorationFlags = {}
	end
	for flag, value in data.restorationFlags do
		if value ~= true then
			data.restorationFlags[flag] = nil
		end
	end
	return data
end

-- Saves one setting (see SettingsData). Returns false for an unknown key or a bad value.
function Profile.setSetting(profile: Profile, key: string, value: any): boolean
	local cleaned = SettingsData.clean(key, value)
	if cleaned == nil then
		return false
	end
	profile.settings[key] = cleaned
	return true
end

-- Saves several settings at once (the menu sends a preset and its values together). Keys that are
-- not valid are skipped; returns how many were saved.
function Profile.applySettings(profile: Profile, changes: { [string]: any }): number
	local saved = 0
	for key, value in changes do
		if type(key) == "string" and Profile.setSetting(profile, key, value) then
			saved += 1
		end
	end
	return saved
end

-- Puts one category (or every setting) back to its defaults.
function Profile.resetSettings(profile: Profile, category: string?)
	for key, def in SettingsData.settings do
		if category == nil or def.category == category then
			profile.settings[key] = def.default
		end
	end
end

function Profile.applyReward(profile: Profile, reward: Reward)
	local xp = reward.xp or 0
	local coins = reward.coins or 0
	assert(isValidAmount(xp) and isValidAmount(coins), "invalid reward amount")
	profile.xp += xp
	profile.coins += coins
end

function Profile.upgradeLevel(profile: Profile, stat: string): number
	if stat == "power" then
		return profile.staffUpgrade
	end
	return profile.upgrades[stat] or 0
end

-- Buys one level of a forge upgrade. Returns ok, and on failure a reason: "unknown", "max" or
-- "coins" (with the missing amount).
function Profile.buyUpgrade(profile: Profile, stat: string): (boolean, string?, number?)
	if not Balance.upgrades[stat] then
		return false, "unknown"
	end
	local level = Profile.upgradeLevel(profile, stat)
	local cost = Progression.upgradeCost(stat, level)
	if not cost then
		return false, "max"
	end
	if profile.coins < cost then
		return false, "coins", cost - profile.coins
	end
	profile.coins -= cost
	if stat == "power" then
		profile.staffUpgrade += 1
	else
		profile.upgrades[stat] = level + 1
	end
	return true
end

-- Puts crystals into the pouch up to its capacity; returns added, lost.
function Profile.addCrystals(profile: Profile, amount: number, capacity: number): (number, number)
	local added = math.clamp(capacity - profile.crystals, 0, amount)
	profile.crystals += added
	return added, amount - added
end

-- Empties the pouch into coins (one coin per crystal); returns the coins gained.
function Profile.depositCrystals(profile: Profile): number
	local amount = profile.crystals
	profile.crystals = 0
	profile.coins += amount
	return amount
end

function Profile.ownsWeapon(profile: Profile, weaponId: string): boolean
	return WeaponData.weapons[weaponId] ~= nil and profile.ownedWeapons[weaponId] == true
end

-- slot 0 is the main weapon, 1..n the floating slots unlocked at this level; "" clears a
-- floating slot back to the automatic pick. Only owned weapons can be equipped.
function Profile.equipWeapon(profile: Profile, slot: number, weaponId: string): boolean
	local level = Progression.levelForXp(profile.xp)
	if slot == 0 then
		if not Profile.ownsWeapon(profile, weaponId) then
			return false
		end
		profile.equippedWeapon = weaponId
		return true
	end
	if slot < 1 or slot > Progression.companionSlots(level) or slot % 1 ~= 0 then
		return false
	end
	if weaponId ~= "" and not Profile.ownsWeapon(profile, weaponId) then
		return false
	end
	for index = #profile.companions + 1, slot - 1 do
		profile.companions[index] = ""
	end
	profile.companions[slot] = weaponId
	return true
end

-- The weapons actually in use: the main one plus one per unlocked floating slot. Empty or
-- no-longer-valid slots take the rarest owned weapon that is not already in use.
function Profile.loadout(profile: Profile): (string, { string })
	local level = Progression.levelForXp(profile.xp)
	local main = if Profile.ownsWeapon(profile, profile.equippedWeapon) then profile.equippedWeapon else WeaponData.starter
	local used = { [main] = true }
	local companions = {}
	local slots = Progression.companionSlots(level)
	for slot = 1, slots do
		local picked = profile.companions[slot]
		if picked and picked ~= "" and Profile.ownsWeapon(profile, picked) then
			companions[slot] = picked
			used[picked] = true
		end
	end
	for slot = 1, slots do
		if not companions[slot] then
			local choice = main
			for index = #WeaponData.order, 1, -1 do
				local weaponId = WeaponData.order[index]
				if not used[weaponId] and Profile.ownsWeapon(profile, weaponId) then
					choice = weaponId
					break
				end
			end
			companions[slot] = choice
			used[choice] = true
		end
	end
	return main, companions
end

-- Records a Legendary Shadow; returns true only the first time.
function Profile.recordLegend(profile: Profile, kind: string): boolean
	if not table.find(Balance.legends, kind) or profile.legends[kind] then
		return false
	end
	profile.legends[kind] = true
	return true
end

function Profile.grantCharm(profile: Profile, charmId: string): boolean
	if Balance.charms[charmId] == nil or profile.ownedCharms[charmId] then
		return false
	end
	profile.ownedCharms[charmId] = true
	if profile.equippedCharm == nil then
		profile.equippedCharm = charmId
	end
	return true
end

-- charmId nil unequips.
function Profile.equipCharm(profile: Profile, charmId: string?): boolean
	if charmId ~= nil and profile.ownedCharms[charmId] ~= true then
		return false
	end
	profile.equippedCharm = charmId
	return true
end

function Profile.setFlag(profile: Profile, flag: string): boolean
	if profile.restorationFlags[flag] then
		return false
	end
	profile.restorationFlags[flag] = true
	return true
end

return Profile
