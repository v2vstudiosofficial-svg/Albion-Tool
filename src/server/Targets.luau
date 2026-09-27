-- Living player characters for enemy, projectile and healing logic.
local Players = game:GetService("Players")

export type Target = { player: Player, humanoid: Humanoid, root: BasePart }

local Targets = {}

-- Living player characters right now. Cheap (at most a handful of players), so callers
-- simply ask each frame instead of sharing a cache.
function Targets.get(): { Target }
	local list = {}
	for _, player in Players:GetPlayers() do
		local target = Targets.of(player)
		if target then
			table.insert(list, target)
		end
	end
	return list
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
