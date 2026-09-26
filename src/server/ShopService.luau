-- Staff upgrades at Usta Demir and charm equipping. Coins, ownership and distance are checked here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local Profile = require(script.Parent.Profile)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local QuestService = require(script.Parent.QuestService)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local upgradeStaff = Remotes.UpgradeStaff :: RemoteEvent
local equipCharm = Remotes.EquipCharm :: RemoteEvent
local openShop = Remotes.OpenShop :: RemoteEvent
local npcSay = Remotes.NpcSay :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local REQUEST_COOLDOWN = 0.4

local lastRequest: { [Player]: number } = {}
local demirBody: BasePart

local ShopService = {}

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

local function nearDemir(player: Player): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - demirBody.Position).Magnitude <= Balance.shopDistance
end

local function onUpgrade(player: Player)
	if throttled(player) or not nearDemir(player) then
		return
	end
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ok, reason, missing = Profile.tryUpgradeStaff(profile)
	if ok then
		PlayerProfiles.sync(player)
		notice:FireClient(player, "notice_upgrade_done", profile.staffUpgrade + 1)
		fx:FireAllClients("upgrade", player, profile.staffUpgrade)
		QuestService.onUpgrade(player)
	elseif reason == "coins" then
		notice:FireClient(player, "notice_upgrade_no_coins", missing)
	else
		notice:FireClient(player, "notice_upgrade_max")
	end
end

local function onEquip(player: Player, charmId: unknown)
	if throttled(player) or typeof(charmId) ~= "string" or #charmId > 32 then
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
	demirBody = map.Village.Demir.Body :: BasePart
	local prompt = demirBody.TalkPrompt :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		if nearDemir(player) and PlayerProfiles.get(player) then
			npcSay:FireClient(player, "Demir", "demir_greet")
			openShop:FireClient(player)
		end
	end)
	upgradeStaff.OnServerEvent:Connect(onUpgrade)
	equipCharm.OnServerEvent:Connect(onEquip)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
