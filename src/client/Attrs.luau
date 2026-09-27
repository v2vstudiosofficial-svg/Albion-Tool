-- Reading the replicated player attributes written by PlayerProfiles.sync on the server.
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local Attrs = {}

function Attrs.get(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

-- Parses the comma-separated sets the server sends (Charms, Flags, QuestFound).
function Attrs.set(name: string): { [string]: boolean }
	local set = {}
	local value = player:GetAttribute(name)
	if typeof(value) == "string" then
		for item in string.gmatch(value, "[^,]+") do
			set[item] = true
		end
	end
	return set
end

return Attrs
