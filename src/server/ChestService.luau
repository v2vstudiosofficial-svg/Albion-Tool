-- Chest spots in the world and the player's chest slots. Picking up, unlocking and opening are
-- all checked here (distance, free slot, one unlock at a time, finished timers); rules live in
-- ChestLogic. Times use os.time() so unlocks keep running while the player is offline.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
local ChestData = require(Shared.ChestData)
local WeaponData = require(Shared.WeaponData)
local Progression = require(Shared.Progression)
local ChestLogic = require(script.Parent.ChestLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local interact = Remotes.Interact :: RemoteEvent
local chestAction = Remotes.ChestAction :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local REQUEST_COOLDOWN = 0.3

local lastRequest: { [Player]: number } = {}
local random = Random.new()

local function rng(): number
	return random:NextNumber()
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function onInteract(player: Player, kind: unknown, spotId: unknown)
	if kind ~= "chest" or typeof(spotId) ~= "string" or #(spotId :: string) > 32 or throttled(player) then
		return
	end
	local spot = WorldData.chests[spotId :: string]
	local profile = PlayerProfiles.get(player)
	local target = Targets.of(player)
	if not spot or not profile or not target then
		return
	end
	if (target.root.Position - WorldData.vector(spot.position)).Magnitude > Balance.interactDistance then
		return
	end
	local ok, reason = ChestLogic.collect(profile, spotId :: string, os.time(), Progression.levelForXp(profile.xp))
	if ok then
		PlayerProfiles.sync(player)
		notice:FireClient(player, "notice_chest_taken", ChestData.chests[spot.type].nameKey)
		fx:FireClient(player, "chestTaken", spotId, WorldData.vector(spot.position), spot.type)
	elseif reason == "full" then
		notice:FireClient(player, "notice_chest_full")
	end
end

local function onChestAction(player: Player, action: unknown, index: unknown)
	if typeof(action) ~= "string" or typeof(index) ~= "number" or index % 1 ~= 0 or throttled(player) then
		return
	end
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local now = os.time()
	if action == "unlock" then
		local ok, reason = ChestLogic.startUnlock(profile, index :: number, now)
		if ok then
			PlayerProfiles.sync(player)
		elseif reason == "busy" then
			notice:FireClient(player, "notice_chest_busy")
		end
	elseif action == "open" then
		local reward = ChestLogic.open(profile, index :: number, now, rng, Progression.levelForXp(profile.xp))
		if reward then
			PlayerProfiles.sync(player)
			local weapon = reward.weapon and WeaponData.weapons[reward.weapon]
			-- Remote tables lose non-array keys (slot 0), so slots travel as a list of pairs.
			local slots = {}
			for slot = 0, WeaponData.maxCompanions do
				if reward.slots[slot] then
					table.insert(slots, { slot, reward.slots[slot], profile.slotLevels[slot + 1] })
				end
			end
			fx:FireClient(player, "chestOpened", {
				chest = reward.chest,
				coins = reward.coins + (reward.duplicateCoins or 0),
				weapon = reward.weapon,
				rarity = weapon and weapon.rarity,
				duplicate = reward.duplicate == true,
				slots = slots,
			})
		end
	end
end

local ChestService = {}

function ChestService.start()
	interact.OnServerEvent:Connect(onInteract)
	chestAction.OnServerEvent:Connect(onChestAction)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ChestService
