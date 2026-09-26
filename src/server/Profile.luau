-- Pure profile rules (schema, rewards, purchases, charms). No Roblox APIs, so Lune can test it.
local Balance = if script
	then require(game:GetService("ReplicatedStorage").Shared.Balance)
	else require("../shared/Balance")

export type QuestProgress = {
	state: "active" | "completed",
	count: number,
	found: { [string]: boolean }?,
}

export type Profile = {
	schemaVersion: number,
	xp: number,
	coins: number,
	staffUpgrade: number,
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
