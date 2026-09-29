-- Pure profile rules (schema, rewards, purchases, charms). No Roblox APIs, so Lune can test it.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local Balance = if Shared then require(Shared.Balance) else require("../shared/Balance")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")
local WeaponData = if Shared then require(Shared.WeaponData) else require("../shared/WeaponData")
local ChestData = if Shared then require(Shared.ChestData) else require("../shared/ChestData")

export type QuestProgress = {
	state: "active" | "completed",
	count: number,
	found: { [string]: boolean }?,
}

-- A chest waiting in a chest slot; startedAt is the os.time() its unlock began (0 = not yet).
export type Chest = { type: string, startedAt: number }

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	staffUpgrade: number,
	-- Main weapon, and explicit picks for floating slots (empty slots are auto-filled).
	equippedWeapon: string,
	companions: { string },
	ownedWeapons: { [string]: boolean },
	-- slotLevels[slot + 1]: level of weapon slot 0 (main) .. 4 (floating).
	slotLevels: { number },
	chests: { Chest },
	-- os.time() when this player last took the chest at each world spot.
	chestSpots: { [string]: number },
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
local MAX_UPGRADE = #Balance.staff.tiers - 1

function Profile.new(): Profile
	return {
		schemaVersion = Profile.SCHEMA_VERSION,
		xp = 0,
		coins = 0,
		staffUpgrade = 0,
		equippedWeapon = "staff",
		companions = {},
		ownedWeapons = { staff = true },
		slotLevels = { 0, 0, 0, 0, 0 },
		chests = {},
		chestSpots = {},
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

function Profile.applyReward(profile: Profile, reward: Reward)
	local xp = reward.xp or 0
	local coins = reward.coins or 0
	assert(isValidAmount(xp) and isValidAmount(coins), "invalid reward amount")
	profile.xp += xp
	profile.coins += coins
end

-- Returns ok, and on failure a reason: "max" or "coins" (with the missing amount).
function Profile.tryUpgradeStaff(profile: Profile): (boolean, string?, number?)
	if profile.staffUpgrade >= MAX_UPGRADE then
		return false, "max"
	end
	local cost = Balance.staff.tiers[profile.staffUpgrade + 2].cost
	if profile.coins < cost then
		return false, "coins", cost - profile.coins
	end
	profile.coins -= cost
	profile.staffUpgrade += 1
	return true
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
