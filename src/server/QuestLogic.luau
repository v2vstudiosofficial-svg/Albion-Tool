-- Pure quest rules; operates on a profile table so it can be unit tested outside Roblox.
local QuestLogic = {}

function QuestLogic.start(profile, questData, questId: string): boolean
	if questData.quests[questId] == nil or profile.questProgress[questId] ~= nil then
		return false
	end
	profile.questProgress[questId] = { state = "active", count = 0 }
	return true
end

-- Returns the ids of quests that became completed by this purification.
function QuestLogic.recordPurify(profile, questData, enemyType: string): { string }
	local completed = {}
	for _, questId in questData.order do
		local progress = profile.questProgress[questId]
		local objective = questData.quests[questId].objective
		if
			progress
			and progress.state == "active"
			and objective.kind == "purify"
			and objective.enemyType == enemyType
		then
			progress.count = math.min(progress.count + 1, objective.count)
			if progress.count >= objective.count then
				progress.state = "completed"
				table.insert(completed, questId)
			end
		end
	end
	return completed
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

function QuestLogic.nextAvailable(profile, questData): string?
	for _, questId in questData.order do
		if profile.questProgress[questId] == nil then
			return questId
		end
	end
	return nil
end

return QuestLogic
