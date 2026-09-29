-- Forge upgrades at the Smith and charm equipping. Coins, levels, ownership and distance are
-- checked here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local Profile = require(script.Parent.Profile)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local QuestLogic = require(script.Parent.QuestLogic)
local QuestService = require(script.Parent.QuestService)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local buyUpgrade = Remotes.BuyUpgrade :: RemoteEvent
local equipCharm = Remotes.EquipCharm :: RemoteEvent
local openShop = Remotes.OpenShop :: RemoteEvent
local npcSay = Remotes.NpcSay :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local REQUEST_COOLDOWN = 0.4

local lastRequest: { [Player]: { [string]: number } } = {}
local smithBody: BasePart

local ShopService = {}

-- Each request kind has its own cooldown, so upgrading never swallows a charm change.
local function throttled(player: Player, kind: string): boolean
	local now = os.clock()
	local times = lastRequest[player] or {}
	lastRequest[player] = times
	if times[kind] and now - times[kind] < REQUEST_COOLDOWN then
		return true
	end
	times[kind] = now
	return false
end

local function nearSmith(player: Player): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - smithBody.Position).Magnitude <= Balance.shopDistance
end

local function onUpgrade(player: Player, stat: unknown)
	if typeof(stat) ~= "string" or not Balance.upgrades[stat :: string] then
		return
	end
	if throttled(player, "upgrade") or not nearSmith(player) then
		return
	end
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ok, reason, missing = Profile.buyUpgrade(profile, stat :: string)
	if ok then
		PlayerProfiles.sync(player)
		local upgrade = Balance.upgrades[stat :: string]
		notice:FireClient(player, "notice_upgrade_done", upgrade.nameKey, Profile.upgradeLevel(profile, stat :: string))
		fx:FireAllClients("upgrade", player, profile.staffUpgrade)
		if stat == "power" then
			QuestService.onUpgrade(player)
		end
	elseif reason == "coins" then
		notice:FireClient(player, "notice_upgrade_no_coins", missing)
	else
		notice:FireClient(player, "notice_upgrade_max")
	end
end

local function onEquip(player: Player, charmId: unknown)
	if throttled(player, "equip") or typeof(charmId) ~= "string" or #charmId > 32 then
		return
	end
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local id = if charmId == "" then nil else charmId :: string
	if Profile.equipCharm(profile, id) then
		PlayerProfiles.sync(player)
	end
end

function ShopService.start(map: Folder)
	smithBody = map.Village.Smith.Body :: BasePart
	local prompt = smithBody.TalkPrompt :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		if nearSmith(player) and PlayerProfiles.get(player) then
			-- The Smith talks about the story the player has lived through.
			local profile = PlayerProfiles.get(player)
			local line = "smith_greet"
			if profile and profile.rebirths > 0 then
				line = "smith_greet_reborn"
			elseif profile and QuestLogic.isCompleted(profile, "shadow_king") then
				line = "smith_greet_final"
			elseif profile and QuestLogic.isCompleted(profile, "warden") then
				line = "smith_greet_east"
			end
			npcSay:FireClient(player, "Smith", line)
			openShop:FireClient(player)
		end
	end)
	buyUpgrade.OnServerEvent:Connect(onUpgrade)
	equipCharm.OnServerEvent:Connect(onEquip)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
