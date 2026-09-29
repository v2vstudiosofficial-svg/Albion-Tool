-- Pure emote rules: a known id, the cooldown and who is close enough to see it.
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local EmoteData = if Shared then require(Shared.EmoteData) else require("../shared/EmoteData")

local EmoteLogic = {}

function EmoteLogic.valid(id: any): boolean
	return type(id) == "string" and EmoteData.emotes[id] ~= nil
end

-- `last` is the time of the player's previous emote (nil for the first one).
function EmoteLogic.ready(last: number?, now: number): boolean
	return last == nil or now - last >= EmoteData.cooldown
end

-- Keeps the entries whose position is within range of the origin (x, z; height is ignored).
function EmoteLogic.audience(origin: { x: number, z: number }, entries: { any }): { any }
	local list = {}
	for _, entry in entries do
		local dx, dz = entry.position.x - origin.x, entry.position.z - origin.z
		if math.sqrt(dx * dx + dz * dz) <= EmoteData.range then
			table.insert(list, entry)
		end
	end
	return list
end

return EmoteLogic
