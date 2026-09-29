-- Pets: choosing which earned pet follows, and telling players when a new one is earned.
-- Rules live in PetLogic; the pet itself is drawn by every client (client/Pets).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PetData = require(Shared.PetData)
local PetLogic = require(script.Parent.PetLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local equipPet = Remotes.EquipPet :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent

local REQUEST_COOLDOWN = 0.3

local lastRequest: { [Player]: number } = {}
-- The pets each player had earned the last time we looked (nil until their profile loads).
local known: { [Player]: { [string]: boolean } } = {}

local PetService = {}

local function onEquip(player: Player, id: unknown)
	if typeof(id) ~= "string" or #(id :: string) > 32 then
		return
	end
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now
	local profile = PlayerProfiles.get(player)
	if profile and PetLogic.equip(profile, id :: string) then
		PlayerProfiles.sync(player)
	end
end

local function earnedSet(profile: any): { [string]: boolean }
	local set = {}
	for _, id in PetLogic.earned(profile) do
		set[id] = true
	end
	return set
end

-- A newly earned pet is announced once and starts following if none does yet.
local function onChanged(player: Player)
	local profile = PlayerProfiles.get(player)
	local before = known[player]
	if not profile or not before then
		return
	end
	local now = earnedSet(profile)
	known[player] = now
	local first: string? = nil
	for _, id in PetData.order do
		if now[id] and not before[id] then
			notice:FireClient(player, "notice_pet_new", PetData.pets[id].nameKey)
			first = first or id
		end
	end
	if first and profile.equippedPet == "" then
		profile.equippedPet = first
		PlayerProfiles.sync(player)
	end
end

function PetService.start()
	equipPet.OnServerEvent:Connect(onEquip)
	PlayerProfiles.onChanged(onChanged)
	PlayerProfiles.onReady(function(player)
		local profile = PlayerProfiles.get(player)
		if profile then
			known[player] = earnedSet(profile)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
		known[player] = nil
	end)
end

return PetService
