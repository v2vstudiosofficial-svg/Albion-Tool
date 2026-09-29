-- Pure title rules: what has been earned and which title may be shown. Titles are never stored as
-- owned: they are derived from progress, so they can't be lost or duplicated.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local TitleData = if Shared then require(Shared.TitleData) else require("../shared/TitleData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

local TitleLogic = {}

-- Progress towards a title's unlock (capped at its goal).
function TitleLogic.progress(profile: any, id: string): number
	local title = TitleData.titles[id]
	if not title then
		return 0
	end
	local unlock = title.unlock
	local value = 0
	if unlock.kind == "level" then
		-- A reborn player has already reached every level.
		value = if profile.rebirths > 0 then Progression.MAX_LEVEL else Progression.levelForXp(profile.xp)
	elseif unlock.kind == "tower" then
		value = profile.towerBest
	elseif unlock.kind == "rebirths" then
		value = profile.rebirths
	elseif unlock.kind == "quest" then
		local progress = profile.questProgress[unlock.id]
		value = if progress and progress.state == "completed" then 1 else 0
	else
		value = profile.counters[unlock.kind] or 0
	end
	return math.min(value, unlock.goal)
end

function TitleLogic.unlocked(profile: any, id: string): boolean
	local title = TitleData.titles[id]
	return title ~= nil and TitleLogic.progress(profile, id) >= title.unlock.goal
end

-- Ids of every earned title, in TitleData order.
function TitleLogic.earned(profile: any): { string }
	local list = {}
	for _, id in TitleData.order do
		if TitleLogic.unlocked(profile, id) then
			table.insert(list, id)
		end
	end
	return list
end

-- Chooses the shown title; "" shows none. False for unknown or not yet earned titles.
function TitleLogic.equip(profile: any, id: string): boolean
	if id == "" then
		profile.equippedTitle = ""
		return true
	end
	if not TitleLogic.unlocked(profile, id) then
		return false
	end
	profile.equippedTitle = id
	return true
end

-- The title actually shown (a saved choice that is no longer earned is ignored).
function TitleLogic.active(profile: any): string
	return if profile.equippedTitle ~= "" and TitleLogic.unlocked(profile, profile.equippedTitle) then profile.equippedTitle else ""
end

-- "id:progress" for every title, in order (replicated so the menu can show progress).
function TitleLogic.encode(profile: any): string
	local list = {}
	for _, id in TitleData.order do
		table.insert(list, id .. ":" .. TitleLogic.progress(profile, id))
	end
	return table.concat(list, ",")
end

return TitleLogic
