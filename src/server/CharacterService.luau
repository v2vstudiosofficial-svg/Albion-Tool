-- Applies profile-derived stats to characters, puts the main weapon in the hand and routes all
-- damage to players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
local WeaponModels = require(Shared.WeaponModels)
local Stats = require(Shared.Stats)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Profile = require(script.Parent.Profile)
local Targets = require(script.Parent.Targets)

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent

local CharacterService = {}

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function findHand(character: Model): (BasePart?, CFrame)
	local hand = character:FindFirstChild("RightHand")
	if hand and hand:IsA("BasePart") then
		return hand, CFrame.new()
	end
	local arm = character:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		return arm, CFrame.new(0, -1, 0)
	end
	return nil, CFrame.new()
end

-- Swaps the model in the hand when the main weapon changed; returns the current model.
local function attachWeapon(character: Model, weaponId: string): Model?
	local existing = character:FindFirstChild("Weapon")
	if existing and existing:GetAttribute("WeaponId") == weaponId then
		return existing :: Model
	end
	local hand, gripOffset = findHand(character)
	if not hand then
		return nil
	end
	if existing then
		existing:Destroy()
	end
	local model = WeaponModels.build(weaponId, hand.CFrame * gripOffset * WeaponModels.hold(weaponId), false)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hand
	weld.Part1 = model.PrimaryPart
	weld.Parent = model.PrimaryPart
	local glow = model:FindFirstChild("Glow")
	if glow then
		local light = Instance.new("PointLight")
		light.Range = 9
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = glow
	end
	model.Parent = character
	return model
end

local function applyStats(player: Player, fullHeal: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = PlayerProfiles.get(player)
	-- A defeated character must stay defeated until respawn (no healing a corpse on level-up).
	if not humanoid or not profile or humanoid.Health <= 0 then
		return
	end
	local stats = Stats.of(profile)
	local maxHealth = stats.maxHealth
	if humanoid.MaxHealth ~= maxHealth then
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = maxHealth
		humanoid.Health = if fullHeal then maxHealth else math.max(1, maxHealth * ratio)
	elseif fullHeal then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = stats.walkSpeed

	local main = Profile.loadout(profile)
	local weapon = attachWeapon(character :: Model, main)
	local glow = weapon and weapon:FindFirstChild("Glow")
	local light = glow and glow:FindFirstChildOfClass("PointLight")
	if light then
		light.Color = rgb(Progression.powerColor(profile.staffUpgrade))
	end
end

function CharacterService.refresh(player: Player)
	applyStats(player, false)
end

function CharacterService.onLevelUp(player: Player)
	applyStats(player, true)
end

-- All enemy damage to players goes through here so charms apply consistently. `from` (where the
-- hit came from) lets the player's screen point at it; `source` (the creature's kind and level)
-- names it on the defeat screen.
function CharacterService.damage(player: Player, humanoid: Humanoid, amount: number, from: Vector3, source: { kind: string, level: number }?)
	local profile = PlayerProfiles.get(player)
	humanoid:TakeDamage(Progression.damageTaken(amount, profile and profile.equippedCharm))
	fx:FireClient(player, "hurt", from, source and source.kind, source and source.level)
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.BreakJointsOnDeath = false
	if humanoid.RigType == Enum.HumanoidRigType.R15 then
		character:WaitForChild("RightHand", 5)
	end
	-- CharacterAdded fires before Roblox parents the character to the workspace; until then the
	-- level's health and the weapon could not be applied (respawns came back with 100 health).
	while character.Parent == nil and player.Character == character and player.Parent do
		task.wait()
	end
	if character.Parent == nil then
		return
	end
	applyStats(player, true)
end

local HEAL_INTERVAL = 0.5
local PLAZA = WorldData.vector(WorldData.plaza)

local function healPlayers(dt: number)
	local village = Balance.village
	for _, target in Targets.get() do
		local humanoid = target.humanoid
		local offset = target.root.Position - PLAZA
		if humanoid.Health < humanoid.MaxHealth then
			-- Fast healing in the village; the regen upgrade heals a little everywhere else.
			local inVillage = Vector3.new(offset.X, 0, offset.Z).Magnitude <= village.radius
			local profile = PlayerProfiles.get(target.player)
			local rate = if inVillage then village.healPerSecond elseif profile then Stats.of(profile).regen else 0
			if rate > 0 then
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + rate * dt)
			end
		end
	end
end

function CharacterService.start()
	Players.RespawnTime = Balance.player.respawnTime
	task.spawn(function()
		while true do
			healPlayers(task.wait(HEAL_INTERVAL))
		end
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	PlayerProfiles.onReady(function(player)
		applyStats(player, true)
	end)
	PlayerProfiles.onChanged(CharacterService.refresh)
	PlayerProfiles.onLevelUp(CharacterService.onLevelUp)
end

return CharacterService
