-- Straight-line projectiles. The server resolves hits; clients draw the same deterministic path
-- from a single "projectile" Fx event, so no per-frame replication is needed.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Targets = require(script.Parent.Targets)

local fx = ReplicatedStorage.Remotes.Fx :: RemoteEvent

local MAX_ACTIVE = 48
local PLAYER_RADIUS = 1.6

type Projectile = {
	id: number,
	position: Vector3,
	velocity: Vector3,
	radius: number,
	damage: number,
	expires: number,
}

local Projectiles = {}

local active: { Projectile } = {}
local nextId = 0
local onHit: (Player, Humanoid, number) -> () = function() end

function Projectiles.setHitHandler(handler: (Player, Humanoid, number) -> ())
	onHit = handler
end

function Projectiles.fire(origin: Vector3, velocity: Vector3, radius: number, damage: number, lifetime: number, style: string)
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
				onHit(target.player, target.humanoid, projectile.damage)
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

function Projectiles.start()
	RunService.Heartbeat:Connect(step)
end

return Projectiles
