-- Bounty Board: opens from the village board, pays finished bounties and tells players when one
-- is done. Rules live in BountyLogic; progress is replicated as the Bounties attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local BountyData = require(Shared.BountyData)
local Progression = require(Shared.Progression)
local BountyLogic = require(script.Parent.BountyLogic)
local PassService = require(script.Parent.PassService)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local openBoard = Remotes.OpenBoard :: RemoteEvent
local claimBounty = Remotes.ClaimBounty :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local CLAIM_COOLDOWN = 0.3

local lastClaim: { [Player]: number } = {}
local lastReady: { [Player]: number } = {}
local random = Random.new()
local boardBody: BasePart

local function rng(): number
	return random:NextNumber()
end

local function nearBoard(player: Player): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - boardBody.Position).Magnitude <= Balance.shopDistance
end

local function onClaim(player: Player, slot: unknown)
	if typeof(slot) ~= "number" or slot % 1 ~= 0 or slot < 1 or slot > BountyData.slots then
		return
	end
	local now = os.clock()
	if lastClaim[player] and now - lastClaim[player] < CLAIM_COOLDOWN then
		return
	end
	lastClaim[player] = now
	local profile = PlayerProfiles.get(player)
	if not profile or not nearBoard(player) then
		return
	end
	local paid = BountyLogic.claim(profile, slot :: number, Progression.levelForXp(profile.xp), rng)
	if paid then
		PassService.award(player, BountyData.passAction)
		PlayerProfiles.sync(player)
		notice:FireClient(player, "notice_bounty_paid", paid.coins)
		fx:FireClient(player, "bountyPaid", paid.kind)
	end
end

-- Tells a player once whenever another bounty becomes ready to claim.
local function onChanged(player: Player)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ready = BountyLogic.readyCount(profile)
	if lastReady[player] ~= nil and ready > lastReady[player] then
		notice:FireClient(player, "notice_bounty_ready")
	end
	lastReady[player] = ready
end

local BountyService = {}

function BountyService.start(map: Folder)
	boardBody = map.Village.BountyBoard.Body :: BasePart
	local prompt = boardBody.TalkPrompt :: ProximityPrompt
	prompt.Triggered:Connect(function(player)
		local profile = PlayerProfiles.get(player)
		if profile and nearBoard(player) then
			-- Levels may have opened new kinds since the board was last filled.
			BountyLogic.fill(profile, Progression.levelForXp(profile.xp), rng)
			PlayerProfiles.sync(player)
			openBoard:FireClient(player)
		end
	end)
	claimBounty.OnServerEvent:Connect(onClaim)
	PlayerProfiles.onChanged(onChanged)
	Players.PlayerRemoving:Connect(function(player)
		lastClaim[player] = nil
		lastReady[player] = nil
	end)
end

return BountyService
