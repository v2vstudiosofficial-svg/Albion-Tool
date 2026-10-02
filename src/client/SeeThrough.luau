-- Trees, roofs and rocks that come between the camera and the player fade out on this screen only
-- (LocalTransparencyModifier), so the hero is never hidden behind the valley. Parts fade back in
-- once they no longer block the view. Only parts of the map fade, never creatures or players.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local CHECK_SECONDS = 0.1
local FADED = 0.7 -- how see-through a blocking part becomes
local FADE_SPEED = 6 -- per second, towards faded or back to solid
local MAX_HITS = 6 -- blocking parts looked through per check
local AIM_HEIGHT = 1.5 -- aim at the chest, not the feet

local SeeThrough = {}

-- part -> current fade (0 solid .. FADED)
local fading: { [BasePart]: number } = {}

-- The map parts between `from` and `to`, nearest first.
function SeeThrough.blockers(map: Instance, from: Vector3, to: Vector3): { BasePart }
	local found = {}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { map }
	local origin = from
	for _ = 1, MAX_HITS do
		local offset = to - origin
		if offset.Magnitude < 0.5 then
			break
		end
		local result = workspace:Raycast(origin, offset, params)
		if not result then
			break
		end
		local part = result.Instance
		if part:IsA("BasePart") and part.Transparency < 0.95 then
			table.insert(found, part)
		end
		-- Continue just past this hit.
		origin = result.Position + offset.Unit * 0.1
	end
	return found
end

function SeeThrough.start()
	local since = 0
	local blocking: { [BasePart]: boolean } = {}
	RunService.RenderStepped:Connect(function(dt)
		since += dt
		if since >= CHECK_SECONDS then
			since = 0
			blocking = {}
			local camera = workspace.CurrentCamera
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local map = workspace:FindFirstChild("LanternValleyMap")
			if camera and root and map then
				for _, part in SeeThrough.blockers(map, camera.CFrame.Position, root.Position + Vector3.new(0, AIM_HEIGHT, 0)) do
					blocking[part] = true
					if fading[part] == nil then
						fading[part] = 0
					end
				end
			end
		end
		for part, amount in fading do
			local goal = if blocking[part] then FADED else 0
			local nextAmount = if goal > amount then math.min(goal, amount + FADE_SPEED * dt) else math.max(goal, amount - FADE_SPEED * dt)
			if part.Parent then
				part.LocalTransparencyModifier = nextAmount
			end
			if nextAmount <= 0 or not part.Parent then
				fading[part] = nil
			else
				fading[part] = nextAmount
			end
		end
	end)
end

return SeeThrough
