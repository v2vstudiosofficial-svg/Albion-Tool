-- Pure pet rules: what has been earned so far and which pet may follow the player. Pets are never
-- stored as owned: they are derived from progress, so they can't be lost or duplicated.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local PetData = if Shared then require(Shared.PetData) else require("../shared/PetData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

local PetLogic = {}

-- Progress towards a pet's unlock (capped at its goal).
function PetLogic.progress(profile: any, id: string): number
	local pet = PetData.pets[id]
	if not pet then
		return 0
	end
	local unlock = pet.unlock
	local value = 0
	if unlock.kind == "level" then
		-- A reborn player has already reached every level.
		value = if profile.rebirths > 0 then Progression.MAX_LEVEL else Progression.levelForXp(profile.xp)
	elseif unlock.kind == "legend" then
		value = if profile.legends[unlock.id] then 1 else 0
	elseif unlock.kind == "tower" then
		value = profile.towerBest
	else
		value = profile.counters[unlock.kind] or 0
	end
	return math.min(value, unlock.goal)
end

function PetLogic.unlocked(profile: any, id: string): boolean
	local pet = PetData.pets[id]
	return pet ~= nil and PetLogic.progress(profile, id) >= pet.unlock.goal
end

-- Ids of every earned pet, in PetData order.
function PetLogic.earned(profile: any): { string }
	local list = {}
	for _, id in PetData.order do
		if PetLogic.unlocked(profile, id) then
			table.insert(list, id)
		end
	end
	return list
end

-- Chooses the following pet; "" sends it home. False for unknown or not yet earned pets.
function PetLogic.equip(profile: any, id: string): boolean
	if id == "" then
		profile.equippedPet = ""
		return true
	end
	if not PetLogic.unlocked(profile, id) then
		return false
	end
	profile.equippedPet = id
	return true
end

-- The pet actually following (a saved choice that is no longer earned is ignored).
function PetLogic.active(profile: any): string
	return if profile.equippedPet ~= "" and PetLogic.unlocked(profile, profile.equippedPet) then profile.equippedPet else ""
end

-- "id:progress" for every pet, in order (replicated so the menu can show progress).
function PetLogic.encode(profile: any): string
	local list = {}
	for _, id in PetData.order do
		table.insert(list, id .. ":" .. PetLogic.progress(profile, id))
	end
	return table.concat(list, ",")
end

return PetLogic
