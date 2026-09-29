-- Pure Bounty Board rules: filling the board, progress from profile counters, claiming.
-- profile.bounties = { { kind, goal, base } }: `base` is the counter value when the bounty was
-- taken, so progress is what the player did since. `rng` returns a number in [0, 1).
local Shared = if script then game:GetService("ReplicatedStorage").Shared else nil
local BountyData = if Shared then require(Shared.BountyData) else require("../shared/BountyData")
local Progression = if Shared then require(Shared.Progression) else require("../shared/Progression")

export type Bounty = { kind: string, goal: number, base: number }
export type Paid = { kind: string, coins: number }

local BountyLogic = {}

local function counterOf(profile: any, kind: string): number
	return profile.counters[BountyData.kinds[kind].counter] or 0
end

function BountyLogic.progress(profile: any, bounty: Bounty): number
	return math.clamp(counterOf(profile, bounty.kind) - bounty.base, 0, bounty.goal)
end

function BountyLogic.complete(profile: any, bounty: Bounty): boolean
	return BountyLogic.progress(profile, bounty) >= bounty.goal
end

local function offer(profile: any, level: number, rng: () -> number): Bounty?
	local taken = {}
	for _, bounty in profile.bounties do
		taken[bounty.kind] = true
	end
	local choices = {}
	for _, kind in BountyData.order do
		if not taken[kind] and level >= BountyData.kinds[kind].minLevel then
			table.insert(choices, kind)
		end
	end
	if #choices == 0 then
		return nil
	end
	local kind = choices[math.floor(rng() * #choices) + 1]
	return { kind = kind, goal = BountyData.kinds[kind].goal, base = counterOf(profile, kind) }
end

-- Tops the board up to BountyData.slots bounties (kinds never repeat on one board).
function BountyLogic.fill(profile: any, level: number, rng: () -> number)
	while #profile.bounties < BountyData.slots do
		local bounty = offer(profile, level, rng)
		if not bounty then
			return
		end
		table.insert(profile.bounties, bounty)
	end
end

-- Pays a finished bounty and replaces it; nil when the slot is empty or not finished.
function BountyLogic.claim(profile: any, slot: number, level: number, rng: () -> number): Paid?
	local bounty = profile.bounties[slot]
	if not bounty or not BountyLogic.complete(profile, bounty) then
		return nil
	end
	local coins = Progression.incomeCoins(level, BountyData.kinds[bounty.kind].minutes)
	profile.coins += coins
	table.remove(profile.bounties, slot)
	BountyLogic.fill(profile, level, rng)
	return { kind = bounty.kind, coins = coins }
end

function BountyLogic.readyCount(profile: any): number
	local total = 0
	for _, bounty in profile.bounties do
		if BountyLogic.complete(profile, bounty) then
			total += 1
		end
	end
	return total
end

-- "kind:goal:progress" per bounty, in board order (replicated as the Bounties attribute).
function BountyLogic.encode(profile: any): string
	local list = {}
	for _, bounty in profile.bounties do
		table.insert(list, bounty.kind .. ":" .. bounty.goal .. ":" .. BountyLogic.progress(profile, bounty))
	end
	return table.concat(list, ",")
end

return BountyLogic
