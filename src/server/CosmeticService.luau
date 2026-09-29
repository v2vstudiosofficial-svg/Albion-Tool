-- Costumes: buying with coins, wearing, and showing them on characters (built on the server so
-- every player sees them). Coins and ownership are checked here; rules live in CosmeticLogic.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CosmeticData = require(Shared.CosmeticData)
local CosmeticModels = require(Shared.CosmeticModels)
local CosmeticLogic = require(script.Parent.CosmeticLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local Remotes = ReplicatedStorage.Remotes
local buyCosmetic = Remotes.BuyCosmetic :: RemoteEvent
local equipCosmetic = Remotes.EquipCosmetic :: RemoteEvent
local notice = Remotes.Notice :: RemoteEvent

local REQUEST_COOLDOWN = 0.3

local lastRequest: { [Player]: number } = {}

local CosmeticService = {}

local function throttled(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- Where each slot sits on the character: (part name(s), offset from that part).
local function mountFor(character: Model, slot: string): (BasePart?, CFrame)
	if slot == "hat" then
		local head = character:FindFirstChild("Head") :: BasePart?
		return head, CFrame.new(0, if head then head.Size.Y / 2 + 0.05 else 0.6, 0)
	elseif slot == "back" then
		local torso: BasePart? = (character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")) :: any
		return torso, CFrame.new(0, 0.5, if torso then torso.Size.Z / 2 + 0.08 else 0.5)
	end
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?, CFrame.new()
end

-- Makes the character wear exactly the equipped costumes (rebuilding only what changed).
function CosmeticService.refresh(player: Player)
	local character = player.Character
	local profile = PlayerProfiles.get(player)
	if not character or not profile then
		return
	end
	for _, slot in CosmeticData.slots do
		local wanted = profile.equippedCosmetics[slot]
		local existing = character:FindFirstChild("Costume_" .. slot)
		if existing and existing:GetAttribute("CostumeId") ~= wanted then
			existing:Destroy()
			existing = nil
		end
		if wanted and not existing then
			local mount, offset = mountFor(character, slot)
			if mount then
				local model = CosmeticModels.build(wanted, mount.CFrame * offset)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = mount
				weld.Part1 = model.PrimaryPart
				weld.Parent = model.PrimaryPart
				model.Parent = character
			end
		end
	end
end

local function onBuy(player: Player, id: unknown)
	if typeof(id) ~= "string" or #(id :: string) > 32 or throttled(player) then
		return
	end
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local ok, reason = CosmeticLogic.buy(profile, id :: string)
	if ok then
		CosmeticLogic.equip(profile, id :: string)
		PlayerProfiles.sync(player)
		notice:FireClient(player, "notice_costume_new", CosmeticData.costumes[id :: string].nameKey)
	elseif reason == "coins" then
		notice:FireClient(player, "notice_upgrade_no_coins", CosmeticData.costumes[id :: string].source.coins - profile.coins)
	end
end

local function onEquip(player: Player, id: unknown, slot: unknown)
	if typeof(id) ~= "string" or #(id :: string) > 32 or (slot ~= nil and typeof(slot) ~= "string") or throttled(player) then
		return
	end
	local profile = PlayerProfiles.get(player)
	if profile and CosmeticLogic.equip(profile, id :: string, slot :: string?) then
		PlayerProfiles.sync(player)
	end
end

function CosmeticService.start()
	buyCosmetic.OnServerEvent:Connect(onBuy)
	equipCosmetic.OnServerEvent:Connect(onEquip)
	PlayerProfiles.onChanged(CosmeticService.refresh)
	PlayerProfiles.onReady(CosmeticService.refresh)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			-- Wait for the body parts costumes hang on.
			character:WaitForChild("HumanoidRootPart", 10)
			character:WaitForChild("Head", 10)
			CosmeticService.refresh(player)
		end)
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return CosmeticService
