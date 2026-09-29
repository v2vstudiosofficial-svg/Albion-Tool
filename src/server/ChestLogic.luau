-- Pure chest rules: picking chests up from world spots, one unlock at a time, opening and
-- rolling rewards. Times are os.time() seconds; `rng` returns a number in [0, 1).
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local ChestData = if Shared then require(Shared.ChestData) else require("../shared/ChestData")
local WeaponData = if Shared then require(Shared.WeaponData) else require("../shared/WeaponData")
local WorldData = if Shared then require(Shared.WorldData) else require("../shared/WorldData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

export type Reward = {
	chest: string,
	coins: number,
	weapon: string?,
	-- True when the weapon was already owned: it gains a star (`star` = the new count) or, at full
	-- stars, turns into coins (`duplicateCoins`).
	duplicate: boolean?,
	star: number?,
	duplicateCoins: number?,
	-- slot (0 = main, 1..4 floating) -> levels gained
	slots: { [number]: number },
}

local ChestLogic = {}

function ChestLogic.spotReady(profile: any, spotId: string, now: number): boolean
	local spot = WorldData.chests[spotId]
	if not spot then
		return false
	end
	local takenAt = profile.chestSpots[spotId]
	return takenAt == nil or now - takenAt >= ChestData.chests[spot.type].respawnSeconds
end

-- os.time() when a taken spot has a chest again (nil when it is ready now).
function ChestLogic.spotReadyAt(profile: any, spotId: string, now: number): number?
	if ChestLogic.spotReady(profile, spotId, now) then
		return nil
	end
	local spot = WorldData.chests[spotId]
	return profile.chestSpots[spotId] + ChestData.chests[spot.type].respawnSeconds
end

-- Returns ok, or false and "unknown" | "cooldown" | "full".
function ChestLogic.collect(profile: any, spotId: string, now: number, level: number): (boolean, string?)
	local spot = WorldData.chests[spotId]
	if not spot then
		return false, "unknown"
	end
	if not ChestLogic.spotReady(profile, spotId, now) then
		return false, "cooldown"
	end
	if #profile.chests >= Progression.chestSlots(level) then
		return false, "full"
	end
	table.insert(profile.chests, { type = spot.type, startedAt = 0 })
	profile.chestSpots[spotId] = now
	return true
end

-- Puts a chest straight into a free chest slot (rewards); false when the slots are full.
function ChestLogic.give(profile: any, chestType: string, level: number): boolean
	if not ChestData.chests[chestType] or #profile.chests >= Progression.chestSlots(level) then
		return false
	end
	table.insert(profile.chests, { type = chestType, startedAt = 0 })
	return true
end

function ChestLogic.unlockSeconds(chest: any): number
	return ChestData.chests[chest.type].unlockSeconds
end

-- Seconds left on an unlocking chest; nil if it has not started, 0 when it can be opened.
function ChestLogic.remaining(chest: any, now: number): number?
	if chest.startedAt == 0 then
		return nil
	end
	return math.max(0, chest.startedAt + ChestLogic.unlockSeconds(chest) - now)
end

-- Index of the chest currently counting down (only one may unlock at a time).
function ChestLogic.unlocking(profile: any, now: number): number?
	for index, chest in profile.chests do
		local left = ChestLogic.remaining(chest, now)
		if left and left > 0 then
			return index
		end
	end
	return nil
end

-- Returns ok, or false and "empty" | "started" | "busy".
function ChestLogic.startUnlock(profile: any, index: number, now: number): (boolean, string?)
	local chest = profile.chests[index]
	if not chest then
		return false, "empty"
	end
	if chest.startedAt ~= 0 then
		return false, "started"
	end
	if ChestLogic.unlocking(profile, now) then
		return false, "busy"
	end
	chest.startedAt = now
	return true
end

local function weighted(weights: { [string]: number }, order: { string }, rng: () -> number): string?
	local total = 0
	for _, key in order do
		total += weights[key] or 0
	end
	if total <= 0 then
		return nil
	end
	local roll = rng() * total
	for _, key in order do
		roll -= weights[key] or 0
		if roll < 0 then
			return key
		end
	end
	return order[#order]
end

-- Rolls a chest's rewards for this profile without changing it.
function ChestLogic.roll(chestType: string, rng: () -> number, profile: any, level: number): Reward
	local data = ChestData.chests[chestType]
	local reward: Reward = {
		chest = chestType,
		coins = data.coins[1] + math.floor(rng() * (data.coins[2] - data.coins[1] + 1)),
		slots = {},
	}
	if rng() < data.weaponChance then
		local rarity = weighted(data.rarityWeights, WeaponData.rarityOrder, rng)
		local choices = {}
		for _, weaponId in WeaponData.order do
			if WeaponData.weapons[weaponId].rarity == rarity then
				table.insert(choices, weaponId)
			end
		end
		if #choices > 0 then
			local weaponId = choices[math.floor(rng() * #choices) + 1]
			reward.weapon = weaponId
			if profile.ownedWeapons[weaponId] then
				reward.duplicate = true
				local stars = profile.weaponStars[weaponId] or 0
				if stars < WeaponData.maxStars then
					reward.star = stars + 1
				else
					reward.duplicateCoins = ChestData.duplicateCoins[rarity :: string]
				end
			end
		end
	end
	-- Slot levels go to random open slots (the main slot plus unlocked floating slots) that are
	-- not maxed yet; when every open slot is maxed they turn into nothing.
	local open = Progression.companionSlots(level)
	local levels = table.clone(profile.slotLevels)
	for _ = 1, data.slotLevels do
		local candidates = {}
		for slot = 0, open do
			if (levels[slot + 1] or 0) < WeaponData.maxSlotLevel then
				table.insert(candidates, slot)
			end
		end
		if #candidates > 0 then
			local slot = candidates[math.floor(rng() * #candidates) + 1]
			levels[slot + 1] = (levels[slot + 1] or 0) + 1
			reward.slots[slot] = (reward.slots[slot] or 0) + 1
		end
	end
	return reward
end

-- Opens a finished chest: removes it, applies and returns the reward.
-- Returns nil and "empty" | "locked" when it cannot be opened.
function ChestLogic.open(profile: any, index: number, now: number, rng: () -> number, level: number): (Reward?, string?)
	local chest = profile.chests[index]
	if not chest then
		return nil, "empty"
	end
	if ChestLogic.remaining(chest, now) ~= 0 then
		return nil, "locked"
	end
	local reward = ChestLogic.roll(chest.type, rng, profile, level)
	table.remove(profile.chests, index)
	profile.coins += reward.coins + (reward.duplicateCoins or 0)
	if reward.weapon and not reward.duplicate then
		profile.ownedWeapons[reward.weapon] = true
	end
	if reward.weapon and reward.star then
		profile.weaponStars[reward.weapon] = reward.star
	end
	for slot, gained in reward.slots do
		profile.slotLevels[slot + 1] = math.min(WeaponData.maxSlotLevel, (profile.slotLevels[slot + 1] or 0) + gained)
	end
	return reward
end

return ChestLogic
