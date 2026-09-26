-- Living player characters, gathered at most once per frame for all enemy/projectile logic.
local Players = game:GetService("Players")

export type Target = { player: Player, humanoid: Humanoid, root: BasePart }

local Targets = {}

local cache: { Target } = {}
local cacheStamp = -1

function Targets.get(now: number): { Target }
	if now == cacheStamp then
		return cache
	end
	cacheStamp = now
	cache = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			table.insert(cache, { player = player, humanoid = humanoid, root = root })
		end
	end
	return cache
end

function Targets.of(player: Player): Target?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if humanoid and root and humanoid.Health > 0 then
		return { player = player, humanoid = humanoid, root = root }
	end
	return nil
end

return Targets
