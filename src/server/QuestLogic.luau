-- Pure quest rules; operates on a profile table so it can be unit tested outside Roblox.
-- Events: { kind = "purify", target = enemyType } | { kind = "collect" | "explore" | "vine", id = string }
--         | { kind = "upgrade", value = staffUpgrade }
local QuestLogic = {}

-- Current value of the profile counter a "counter" objective measures.
local function counterValue(profile, objective): number
	if objective.counter == "towerBest" then
		return profile.towerBest
	end
	return profile.counters[objective.counter] or 0
end

function QuestLogic.goal(def): number
	local objective = def.objective
	if objective.ids then
		return #objective.ids
	end
	return objective.count
end

-- Whether questId may be started now; reason is "unknown", "started", "locked" or "level".
function QuestLogic.canStart(profile, questData, questId: string, level: number): (boolean, string?)
	local def = questData.quests[questId]
	if def == nil then
		return false, "unknown"
	end
	if profile.questProgress[questId] ~= nil then
		return false, "started"
	end
	local index = table.find(questData.order, questId)
	if index == nil then
		return false, "unknown"
	end
	if index > 1 then
		local previous = profile.questProgress[questData.order[index - 1]]
		if previous == nil or previous.state ~= "completed" then
			return false, "locked"
		end
	end
	if def.minLevel and level < def.minLevel then
		return false, "level"
	end
	return true
end

function QuestLogic.start(profile, questData, questId: string, level: number): (boolean, string?)
	local ok, reason = QuestLogic.canStart(profile, questData, questId, level)
	if not ok then
		return false, reason
	end
	local progress = { state = "active", count = 0 } :: any
	local objective = questData.quests[questId].objective
	if objective.kind == "counter" and not objective.absolute then
		-- Only what the player does from now on counts.
		progress.base = counterValue(profile, objective)
	end
	profile.questProgress[questId] = progress
	return true
end

-- Updates every active counter quest from the profile; returns ids of quests it completed. Counter
-- quests are not driven by events, so callers run this whenever the profile may have changed.
function QuestLogic.syncCounters(profile, questData): { string }
	local completed = {}
	for _, questId in questData.order do
		local progress = profile.questProgress[questId]
		local def = questData.quests[questId]
		if progress and progress.state == "active" and def.objective.kind == "counter" then
			local goal = QuestLogic.goal(def)
			local value = counterValue(profile, def.objective) - (if def.objective.absolute then 0 else (progress.base or 0))
			progress.count = math.clamp(value, progress.count, goal)
			if progress.count >= goal then
				progress.state = "completed"
				table.insert(completed, questId)
			end
		end
	end
	return completed
end

local function matches(objective, event): boolean
	if objective.kind ~= event.kind then
		return false
	end
	if event.kind == "purify" then
		return objective.enemyType == event.target
	elseif event.kind == "upgrade" then
		return type(event.value) == "number"
	end
	return type(event.id) == "string" and table.find(objective.ids, event.id) ~= nil
end

-- Applies an event to every active quest; returns ids of quests completed by it (each at most once).
function QuestLogic.record(profile, questData, event): { string }
	local completed = {}
	for _, questId in questData.order do
		local progress = profile.questProgress[questId]
		local def = questData.quests[questId]
		if progress and progress.state == "active" and matches(def.objective, event) then
			local goal = QuestLogic.goal(def)
			if event.kind == "purify" then
				progress.count = math.min(progress.count + 1, goal)
			elseif event.kind == "upgrade" then
				progress.count = math.min(math.max(progress.count, event.value), goal)
			else
				local found = progress.found or {}
				progress.found = found
				if not found[event.id] then
					found[event.id] = true
					progress.count = math.min(progress.count + 1, goal)
				end
			end
			if progress.count >= goal then
				progress.state = "completed"
				table.insert(completed, questId)
			end
		end
	end
	return completed
end

function QuestLogic.isFound(profile, questId: string, id: string): boolean
	local progress = profile.questProgress[questId]
	return progress ~= nil and progress.found ~= nil and progress.found[id] == true
end

function QuestLogic.tracked(profile, questData): string?
	for _, questId in questData.order do
		local progress = profile.questProgress[questId]
		if progress and progress.state == "active" then
			return questId
		end
	end
	return nil
end

-- First quest in the chain that has not been started yet (it may still be level-gated).
function QuestLogic.nextAvailable(profile, questData): string?
	for _, questId in questData.order do
		if profile.questProgress[questId] == nil then
			return questId
		end
	end
	return nil
end

function QuestLogic.isCompleted(profile, questId: string): boolean
	local progress = profile.questProgress[questId]
	return progress ~= nil and progress.state == "completed"
end

return QuestLogic
