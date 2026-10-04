-- Straight-line projectiles. The server resolves hits; clients draw the same deterministic path
-- from a single "projectile" Fx event, so no per-frame replication is needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Targets = require(script.Parent.Targets)

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent

-- Boss orb rings (up to 2 x 16), fanned spores and rifts can overlap; keep room for all of them.
local MAX_ACTIVE = 160
local PLAYER_RADIUS = 1.6

type Projectile = {
	id: number,
	position: Vector3,
	velocity: Vector3,
	radius: number,
	damage: number,
	expires: number,
	source: { kind: string, level: number, id: number? }?,
}

local Projectiles = {}

local active: { Projectile } = {}
local nextId = 0
-- (player, humanoid, damage, where the shot came from, who shot it)
local onHit: (Player, Humanoid, number, Vector3, { kind: string, level: number }?) -> () = function() end

function Projectiles.setHitHandler(handler: (Player, Humanoid, number, Vector3, { kind: string, level: number }?) -> ())
	onHit = handler
end

-- `source` (the shooter's kind and level) tells the player what hit them.
function Projectiles.fire(origin: Vector3, velocity: Vector3, radius: number, damage: number, lifetime: number, style: string, source: { kind: string, level: number }?)
	if #active >= MAX_ACTIVE then
		return
	end
	nextId += 1
	table.insert(active, {
		id = nextId,
		position = origin,
		velocity = velocity,
		radius = radius,
		damage = damage,
		expires = os.clock() + lifetime,
		source = source,
	})
	fx:FireAllClients("projectile", nextId, origin, velocity, lifetime, radius, style)
end

local function step(dt: number)
	if #active == 0 then
		return
	end
	local now = os.clock()
	local targets = Targets.get()
	for index = #active, 1, -1 do
		local projectile = active[index]
		projectile.position += projectile.velocity * dt
		local hit = false
		for _, target in targets do
			if (target.root.Position - projectile.position).Magnitude <= projectile.radius + PLAYER_RADIUS then
				onHit(target.player, target.humanoid, projectile.damage, projectile.position - projectile.velocity, projectile.source)
				fx:FireAllClients("projectileEnd", projectile.id, projectile.position)
				hit = true
				break
			end
		end
		if hit or now >= projectile.expires then
			active[index] = active[#active]
			active[#active] = nil
		end
	end
end

-- A purified creature's shots still in the air fade with it (they used to fly on and could still
-- hurt a player who had just won the fight). `id` is the shooter's enemy id (source.id).
function Projectiles.clearFrom(id: number)
	for index = #active, 1, -1 do
		local projectile = active[index]
		if projectile.source and projectile.source.id == id then
			fx:FireAllClients("projectileEnd", projectile.id, projectile.position)
			active[index] = active[#active]
			active[#active] = nil
		end
	end
end

function Projectiles.start()
	RunService.Heartbeat:Connect(step)
end

return Projectiles
