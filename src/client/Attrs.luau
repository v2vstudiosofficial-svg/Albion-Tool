-- Reading the replicated player attributes written by PlayerProfiles.sync on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Stats = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Stats"))

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

-- Parses an ordered comma-separated list (Companions).
function Attrs.list(name: string): { string }
	local list = {}
	local value = player:GetAttribute(name)
	if typeof(value) == "string" then
		for item in string.gmatch(value, "[^,]+") do
			table.insert(list, item)
		end
	end
	return list
end

-- Parses "id:number" pairs (Upgrades, Skills).
function Attrs.pairs(name: string): { [string]: number }
	local values = {}
	for _, item in Attrs.list(name) do
		local key, value = string.match(item, "^([^:]+):(%d+)$")
		if key then
			values[key] = tonumber(value) :: number
		end
	end
	return values
end

-- The same derived stats the server uses (Shared/Stats), built from replicated attributes.
-- Cached by its inputs: the camera ring and ability bar read it every frame, and the cache can
-- never be stale because a change to any input changes the key.
local cachedKey: string? = nil
local cachedStats: Stats.PlayerStats? = nil

function Attrs.stats(): Stats.PlayerStats
	local charm = Attrs.get("Charm", "")
	local key = table.concat({
		tostring(Attrs.get("XP", 0)),
		tostring(Attrs.get("StaffTier", 0)),
		Attrs.get("Upgrades", ""),
		Attrs.get("Skills", ""),
		tostring(Attrs.get("Rebirths", 0)),
		charm,
	}, "|")
	if key == cachedKey and cachedStats then
		return cachedStats
	end
	local stats = Stats.of({
		xp = Attrs.get("XP", 0),
		staffUpgrade = Attrs.get("StaffTier", 0),
		upgrades = Attrs.pairs("Upgrades"),
		skills = Attrs.pairs("Skills"),
		equippedCharm = if charm ~= "" then charm else nil,
		rebirths = Attrs.get("Rebirths", 0),
	})
	cachedKey, cachedStats = key, stats
	return stats
end

return Attrs
