-- Titles: choosing which earned title is shown, and telling players when a new one is earned.
-- Rules live in TitleLogic; the title itself is drawn by clients from the Title attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local TitleData = require(Shared.TitleData)
local TitleLogic = require(script.Parent.TitleLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local equipTitle = Remotes.EquipTitle :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent

local REQUEST_COOLDOWN = 0.3

local lastRequest: { [Player]: number } = {}
-- The titles each player had earned the last time we looked (nil until their profile loads).
local known: { [Player]: { [string]: boolean } } = {}

local TitleService = {}

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
	if profile and TitleLogic.equip(profile, id :: string) then
		PlayerProfiles.sync(player)
	end
end

local function earnedSet(profile: any): { [string]: boolean }
	local set = {}
	for _, id in TitleLogic.earned(profile) do
		set[id] = true
	end
	return set
end

-- A newly earned title is announced once (players choose it themselves in the Bag).
local function onChanged(player: Player)
	local profile = PlayerProfiles.get(player)
	local before = known[player]
	if not profile or not before then
		return
	end
	local now = earnedSet(profile)
	known[player] = now
	for _, id in TitleData.order do
		if now[id] and not before[id] then
			notice:FireClient(player, "notice_title_new", TitleData.titles[id].nameKey)
		end
	end
end

function TitleService.start()
	equipTitle.OnServerEvent:Connect(onEquip)
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

return TitleService
