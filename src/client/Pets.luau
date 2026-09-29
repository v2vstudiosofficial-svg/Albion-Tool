-- Pets: draws the pet each player has chosen (their Pet attribute) and lets it trot after its
-- owner. Purely visual; the server only stores which pet is chosen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PetData = require(Shared:WaitForChild("PetData"))
local PetModels = require(Shared:WaitForChild("PetModels"))

type View = { id: string, model: Model, position: Vector3 }

local Pets = {}

local views: { [Player]: View } = {}
local folder: Folder

local function clear(owner: Player)
	local view = views[owner]
	if view then
		view.model:Destroy()
		views[owner] = nil
	end
end

-- Where the pet wants to be: behind and beside its owner, on the ground (flying pets higher,
-- with a gentle bob).
function Pets.goal(rootCFrame: CFrame, fly: boolean, now: number): Vector3
	local follow = PetData.follow
	local lift = if fly then follow.flyLift + math.sin(now * 3) * 0.3 else math.abs(math.sin(now * 4)) * 0.25
	local spot = rootCFrame * Vector3.new(follow.offset[1], follow.offset[2], follow.offset[3])
	return Vector3.new(spot.X, spot.Y + lift, spot.Z)
end

local function update(dt: number)
	local now = os.clock()
	for _, owner in Players:GetPlayers() do
		local character = owner.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local wanted = owner:GetAttribute("Pet")
		local pet = if typeof(wanted) == "string" then PetData.pets[wanted] else nil
		if not pet or not humanoid or not root or humanoid.Health <= 0 then
			clear(owner)
		else
			local existing = views[owner]
			if existing and existing.id ~= wanted then
				clear(owner)
				existing = nil
			end
			local goal = Pets.goal(root.CFrame, pet.fly == true, now)
			local view: View
			if existing then
				view = existing
			else
				local model = PetModels.build(wanted :: string, CFrame.new(goal))
				model.Parent = folder
				view = { id = wanted :: string, model = model, position = goal }
				views[owner] = view
			end
			-- Far away (a teleport, e.g. into the tower): snap instead of sliding across the map.
			if (goal - view.position).Magnitude > PetData.follow.snapDistance then
				view.position = goal
			else
				view.position = view.position:Lerp(goal, 1 - math.exp(-PetData.follow.catchUp * dt))
			end
			-- Face the way the owner faces (the pet's front is -Z, like the player's).
			local look = root.CFrame.LookVector
			local at = view.position
			view.model:PivotTo(CFrame.lookAt(at, at + Vector3.new(look.X, 0, look.Z)))
		end
	end
end

function Pets.start()
	folder = Instance.new("Folder")
	folder.Name = "Pets"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(clear)
	RunService.RenderStepped:Connect(update)
end

return Pets
