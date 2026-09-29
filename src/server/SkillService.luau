-- Skill card picks. Offers are rolled on level-up (PlayerProfiles.grant); the client may only
-- name one of the cards currently offered, and only while it has picks left.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SkillLogic = require(script.Parent.SkillLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local pickSkill = Remotes.PickSkill :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local PICK_COOLDOWN = 0.3

local lastPick: { [Player]: number } = {}
local random = Random.new()

local function rng(): number
	return random:NextNumber()
end

local function onPick(player: Player, choice: unknown)
	local now = os.clock()
	if typeof(choice) ~= "string" or #(choice :: string) > 16 then
		return
	end
	if lastPick[player] and now - lastPick[player] < PICK_COOLDOWN then
		return
	end
	lastPick[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ok, coins = SkillLogic.pick(profile, choice :: string, rng)
	if ok then
		PlayerProfiles.sync(player)
		if coins then
			notice:FireClient(player, "notice_skill_coins", coins)
		end
		fx:FireAllClients("skillPicked", player, choice)
	end
end

local SkillService = {}

function SkillService.start()
	pickSkill.OnServerEvent:Connect(onPick)
	Players.PlayerRemoving:Connect(function(player)
		lastPick[player] = nil
	end)
end

return SkillService
