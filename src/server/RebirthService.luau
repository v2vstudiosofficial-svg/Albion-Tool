-- Rebirth: at level 100 a player may restart the climb from the Great Lantern. The prompt only
-- opens the confirmation panel; the reset itself is checked and done here (level, distance).
-- Rules live in RebirthLogic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local CosmeticData = require(Shared.CosmeticData)
local Progression = require(Shared.Progression)
local RebirthLogic = require(script.Parent.RebirthLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local openRebirth = Remotes.OpenRebirth :: RemoteEvent
local confirmRebirth = Remotes.ConfirmRebirth :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local CONFIRM_COOLDOWN = 2

local lastConfirm: { [Player]: number } = {}
local lanternPost: BasePart

local RebirthService = {}

local function nearLantern(player: Player): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - lanternPost.Position).Magnitude <= Balance.shopDistance
end

local function onPrompt(player: Player)
	local profile = PlayerProfiles.get(player)
	if not profile or not nearLantern(player) then
		return
	end
	if RebirthLogic.can(profile) then
		openRebirth:FireClient(player)
	else
		notice:FireClient(player, "notice_rebirth_level", Progression.MAX_LEVEL)
	end
end

local function onConfirm(player: Player)
	local now = os.clock()
	if lastConfirm[player] and now - lastConfirm[player] < CONFIRM_COOLDOWN then
		return
	end
	lastConfirm[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile or not nearLantern(player) then
		return
	end
	local costumes = RebirthLogic.perform(profile)
	if not costumes then
		return
	end
	PlayerProfiles.sync(player)
	notice:FireClient(player, "notice_rebirth_done", profile.rebirths)
	for _, id in costumes do
		notice:FireClient(player, "notice_costume_new", CosmeticData.costumes[id].nameKey)
	end
	fx:FireAllClients("rebirth", lanternPost.Position + Vector3.new(0, 6, 0))
end

function RebirthService.start(map: Folder)
	lanternPost = map.Village.LanternPost :: BasePart
	local prompt = lanternPost.RebirthPrompt :: ProximityPrompt
	prompt.Triggered:Connect(onPrompt)
	confirmRebirth.OnServerEvent:Connect(onConfirm)
	Players.PlayerRemoving:Connect(function(player)
		lastConfirm[player] = nil
	end)
end

return RebirthService
