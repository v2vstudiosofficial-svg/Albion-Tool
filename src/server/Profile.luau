export type QuestProgress = {
	state: "active" | "completed",
	count: number,
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

local function isValidAmount(value: number): boolean
	return value >= 0 and value == math.floor(value) and value < math.huge
end

function Profile.applyReward(profile: Profile, reward: Reward)
	local xp = reward.xp or 0
	local coins = reward.coins or 0
	assert(isValidAmount(xp) and isValidAmount(coins), "invalid reward amount")
	profile.xp += xp
	profile.coins += coins
end

return Profile
