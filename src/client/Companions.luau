-- Floating weapons that hover behind players, one per unlocked slot (every 25 levels). Purely
-- visual: the server attacks from the same hover spots (WeaponData.companionOffsets) and tells
-- clients through the Fx "attack" event, which makes the matching weapon lunge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local WeaponModels = require(Shared:WaitForChild("WeaponModels"))

local fxRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx") :: RemoteEvent

local LUNGE_TIME = 0.25
local HIDDEN = CFrame.new(0, -500, 0)
-- Weapon models extend up from their grip; this centers them on the hover spot.
local CENTER = CFrame.new(0, -1.6, 0)

type View = { key: string, models: { [number]: Model } }

local Companions = {}

local views: { [Player]: View } = {}
local lunges: { [Player]: { [number]: number } } = {}
local folder: Folder

local function clear(owner: Player)
	local view = views[owner]
	if view then
		for _, model in view.models do
			model:Destroy()
		end
		views[owner] = nil
	end
end

-- Rebuilds an owner's models only when their Companions attribute changed.
local function viewFor(owner: Player): View
	local key = owner:GetAttribute("Companions")
	key = if typeof(key) == "string" then key else ""
	local view = views[owner]
	if view and view.key == key then
		return view
	end
	clear(owner)
	view = { key = key, models = {} }
	local slot = 0
	for weaponId in string.gmatch(key, "[^,]+") do
		slot += 1
		if slot <= WeaponData.maxCompanions and WeaponData.weapons[weaponId] then
			local model = WeaponModels.build(weaponId, HIDDEN, true, true)
			model.Parent = folder
			view.models[slot] = model
		end
	end
	views[owner] = view
	return view
end

-- Hover frame for one slot: gentle bob and sway, tipping forward while it attacks.
function Companions.hoverCFrame(rootCFrame: CFrame, slot: number, now: number, lungeAt: number?): CFrame
	local offset = WeaponData.companionOffsets[slot]
	local bob = math.sin(now * 2.2 + slot * 1.3) * 0.35
	local sway = math.sin(now * 1.3 + slot) * math.rad(8)
	local lunge = 0
	if lungeAt and now - lungeAt < LUNGE_TIME then
		lunge = math.sin((now - lungeAt) / LUNGE_TIME * math.pi)
	end
	return rootCFrame
		* CFrame.new(offset[1], offset[2] + bob, offset[3] - lunge * 1.2)
		* CFrame.Angles(math.rad(-12) - lunge * math.rad(70), sway, 0)
end

local function update()
	local now = os.clock()
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not humanoid or not root or humanoid.Health <= 0 then
			clear(owner)
		else
			local view = viewFor(owner)
			local ownerLunges = lunges[owner]
			for slot, model in view.models do
				local frame = Companions.hoverCFrame(root.CFrame, slot, now, ownerLunges and ownerLunges[slot])
				model:PivotTo(frame * CENTER)
			end
		end
	end
end

function Companions.start()
	folder = Instance.new("Folder")
	folder.Name = "Companions"
	folder.Parent = workspace

	fxRemote.OnClientEvent:Connect(function(kind, owner, _weaponId, slot)
		if kind == "attack" and typeof(owner) == "Instance" and typeof(slot) == "number" and slot > 0 then
			local ownerLunges = lunges[owner :: Player] or {}
			lunges[owner :: Player] = ownerLunges
			ownerLunges[slot] = os.clock()
		end
	end)
	Players.PlayerRemoving:Connect(function(owner)
		clear(owner)
		lunges[owner] = nil
	end)
	RunService.RenderStepped:Connect(update)
end

return Companions
