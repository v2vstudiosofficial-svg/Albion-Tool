-- Applies profile-derived stats to characters, attaches the light staff and routes all damage to players.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Progression = require(Shared.Progression)
local Balance = require(Shared.Balance)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local SHAFT_COLOR = Color3.fromRGB(150, 105, 70)

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

local function decorPart(name: string, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function attachStaff(character: Model): Model?
	local existing = character:FindFirstChild("LightStaff")
	if existing then
		return existing :: Model
	end
	local hand, gripOffset = findHand(character)
	if not hand then
		return nil
	end
	local grip = hand.CFrame * gripOffset

	local staff = Instance.new("Model")
	staff.Name = "LightStaff"
	local shaft = decorPart("Shaft", {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 0.35, 0.35),
		CFrame = grip * CFrame.new(0, 1.4, 0) * UPRIGHT,
		Color = SHAFT_COLOR,
		Material = Enum.Material.Wood,
	})
	shaft.Parent = staff
	local orb = decorPart("Orb", {
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.95, 0.95, 0.95),
		CFrame = grip * CFrame.new(0, 4.6, 0),
		Material = Enum.Material.Neon,
	})
	orb.Parent = staff
	local light = Instance.new("PointLight")
	light.Range = 9
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = orb

	local toHand = Instance.new("WeldConstraint")
	toHand.Part0 = hand
	toHand.Part1 = shaft
	toHand.Parent = shaft
	local toShaft = Instance.new("WeldConstraint")
	toShaft.Part0 = shaft
	toShaft.Part1 = orb
	toShaft.Parent = orb

	staff.PrimaryPart = shaft
	staff.Parent = character
	return staff
end

local function applyStats(player: Player, fullHeal: boolean)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = PlayerProfiles.get(player)
	if not humanoid or not profile then
		return
	end
	local level = Progression.levelForXp(profile.xp)
	local maxHealth = Progression.maxHealth(level)
	if humanoid.MaxHealth ~= maxHealth then
		local ratio = if humanoid.MaxHealth > 0 then humanoid.Health / humanoid.MaxHealth else 1
		humanoid.MaxHealth = maxHealth
		humanoid.Health = if fullHeal then maxHealth else math.max(1, maxHealth * ratio)
	elseif fullHeal then
		humanoid.Health = maxHealth
	end
	humanoid.WalkSpeed = Progression.walkSpeed(profile.equippedCharm)

	local staff = character and character:FindFirstChild("LightStaff")
	local orb = staff and staff:FindFirstChild("Orb") :: BasePart?
	if orb then
		local color = rgb(Progression.staffTier(profile.staffUpgrade).color)
		orb.Color = color
		local light = orb:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = color
		end
	end
end

function CharacterService.refresh(player: Player)
	applyStats(player, false)
end

function CharacterService.onLevelUp(player: Player)
	applyStats(player, true)
end

-- All enemy damage to players goes through here so charms apply consistently.
function CharacterService.damage(player: Player, humanoid: Humanoid, amount: number)
	local profile = PlayerProfiles.get(player)
	humanoid:TakeDamage(Progression.damageTaken(amount, profile and profile.equippedCharm))
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
	if character.Parent == nil then
		return
	end
	attachStaff(character)
	applyStats(player, true)
end

function CharacterService.start()
	Players.RespawnTime = Balance.player.respawnTime
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
