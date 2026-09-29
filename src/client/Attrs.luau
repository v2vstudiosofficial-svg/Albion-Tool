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
-- Cached: the camera ring and ability bar read it every frame; it is rebuilt only after one of
-- its inputs changes.
local cachedStats: Stats.PlayerStats? = nil
for _, name in { "XP", "StaffTier", "Upgrades", "Skills", "Charm" } do
	player:GetAttributeChangedSignal(name):Connect(function()
		cachedStats = nil
	end)
end

function Attrs.stats(): Stats.PlayerStats
	if cachedStats then
		return cachedStats
	end
	local charm = Attrs.get("Charm", "")
	cachedStats = Stats.of({
		xp = Attrs.get("XP", 0),
		staffUpgrade = Attrs.get("StaffTier", 0),
		upgrades = Attrs.pairs("Upgrades"),
		skills = Attrs.pairs("Skills"),
		equippedCharm = if charm ~= "" then charm else nil,
	})
	return cachedStats :: Stats.PlayerStats
end

return Attrs
