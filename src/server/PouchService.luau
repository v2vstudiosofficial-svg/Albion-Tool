-- Light Crystals: purified creatures drop crystals straight into each participant's pouch (up to
-- its capacity); standing by the Great Lantern in the village plaza turns them into coins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
local Stats = require(Shared.Stats)
local Profile = require(script.Parent.Profile)
local AchievementLogic = require(script.Parent.AchievementLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local DEPOSIT_INTERVAL = 0.5
local FULL_NOTICE_COOLDOWN = 20
local LANTERN = WorldData.vector(WorldData.plaza)

local lastFullNotice: { [Player]: number } = {}

local PouchService = {}

-- Adds a purified creature's crystals for one participant; returns crystals added.
function PouchService.give(player: Player, amount: number, from: Vector3): number
	local profile = PlayerProfiles.get(player)
	if not profile or amount <= 0 then
		return 0
	end
	local stats = Stats.of(profile)
	local scaled = math.max(1, math.floor(amount * stats.crystalMultiplier + 0.5))
	local added, lost = Profile.addCrystals(profile, scaled, stats.pouchCapacity)
	if added > 0 then
		PlayerProfiles.sync(player)
		fx:FireClient(player, "crystals", from, added)
	end
	if lost > 0 then
		local now = os.clock()
		if not lastFullNotice[player] or now - lastFullNotice[player] >= FULL_NOTICE_COOLDOWN then
			lastFullNotice[player] = now
			notice:FireClient(player, "notice_pouch_full")
		end
	end
	return added
end

local function depositNearLantern()
	for _, target in Targets.get() do
		local profile = PlayerProfiles.get(target.player)
		local offset = target.root.Position - LANTERN
		if profile and profile.crystals > 0 and Vector3.new(offset.X, 0, offset.Z).Magnitude <= Balance.pouch.lanternRadius then
			local coins = Profile.depositCrystals(profile)
			AchievementLogic.count(profile, "crystals", coins)
			PlayerProfiles.sync(target.player)
			notice:FireClient(target.player, "notice_deposit", coins)
			fx:FireClient(target.player, "deposit", LANTERN, coins)
		end
	end
end

function PouchService.start()
	task.spawn(function()
		while true do
			task.wait(DEPOSIT_INTERVAL)
			depositNearLantern()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastFullNotice[player] = nil
	end)
end

return PouchService
