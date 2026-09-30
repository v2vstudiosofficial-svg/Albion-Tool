-- Client-side visuals for server events (Fx remote) plus local predictions for the local player.
-- Everything here is cosmetic; gameplay state always comes from the server.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Strings = require(Shared:WaitForChild("Strings"))
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local Progression = require(Shared:WaitForChild("Progression"))
local Format = require(Shared:WaitForChild("Format"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)
local CameraRig = require(script.Parent.CameraRig)
local Settings = require(script.Parent.Settings)
local SettingsData = require(Shared:WaitForChild("SettingsData"))

local fxRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Fx") :: RemoteEvent
local player = Players.LocalPlayer

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local SPORE_COLOR = Color3.fromRGB(255, 130, 200)
local SHADOW_COLOR = Color3.fromRGB(150, 80, 230)
local WARN_COLOR = Color3.fromRGB(255, 120, 90)
local GOLD = Color3.fromRGB(255, 220, 120)
-- Other players' weapon effects farther than this from the local player are skipped.
local ATTACK_FX_DISTANCE = 160

local Effects = {}

local folder: Folder
local billboards: Folder
local shakeUntil, shakeStrength, shakeLength = 0, 0, 1

local function newPart(props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	if props.Shape then
		part.Shape = props.Shape
	end
	for key, value in props do
		if key ~= "Shape" then
			(part :: any)[key] = value
		end
	end
	part.Parent = folder
	return part
end

local function fadeOut(part: BasePart, seconds: number, goal: { [string]: any }?)
	local target = goal or {}
	target.Transparency = 1
	UiKit.tween(part, seconds, target)
	Debris:AddItem(part, seconds + 0.05)
end

local function ringCFrame(position: Vector3): CFrame
	return CFrame.new(position) * UPRIGHT
end

function Effects.burst(position: Vector3, color: Color3, count: number, speed: number?)
	-- Lower effect settings draw fewer sparks (at least a few, so a burst still reads).
	count = math.max(3, math.floor(count * SettingsData.effectDensity[Settings.get("effects")] + 0.5))
	local anchor = newPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 1
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 0) })
	local base = speed or 6
	emitter.Speed = NumberRange.new(base, base * 1.7)
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Drag = 3
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 1.2)
end

function Effects.popup(position: Vector3, text: string, color: Color3, textSize: number?)
	local anchor = newPart({ Size = Vector3.new(0.2, 0.2, 0.2), Position = position, Transparency = 1 })
	local gui = UiKit.create("BillboardGui", {
		Size = UDim2.fromOffset(200, 44),
		StudsOffset = Vector3.new(0, 2, 0),
		AlwaysOnTop = true,
		Adornee = anchor,
		MaxDistance = 120,
	}, anchor)
	local label = UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = text,
		TextColor3 = color,
		TextSize = textSize or 26,
		TextStrokeTransparency = 0.2,
	}, gui)
	UiKit.tween(gui, 0.9, { StudsOffset = Vector3.new(0, 4.5, 0) })
	task.delay(0.35, function()
		UiKit.tween(label, 0.5, { TextTransparency = 1, TextStrokeTransparency = 1 })
	end)
	Debris:AddItem(anchor, 1)
end

function Effects.shake(strength: number, seconds: number)
	if not Settings.get("shake") then
		return
	end
	local now = os.clock()
	shakeStrength = if now < shakeUntil then math.max(shakeStrength, strength) else strength
	if now + seconds > shakeUntil then
		shakeUntil = now + seconds
		shakeLength = seconds
	end
end

local function flash(model: Instance, color: Color3, seconds: number, startTransparency: number)
	if not model or not model.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = color
	highlight.OutlineTransparency = 1
	highlight.FillTransparency = startTransparency
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	UiKit.tween(highlight, seconds, { FillTransparency = 1 })
	Debris:AddItem(highlight, seconds + 0.05)
end

local function tierColor(power: number): Color3
	return UiKit.rgb(Progression.powerColor(power))
end

-- Steps a joint's C0 by hand: TweenService refuses it in Studio ("property named 'C0' ... is read
-- only"). Eases out like the other tweens; stops early when the joint is removed.
local function moveJoint(joint: Motor6D, goal: CFrame, seconds: number)
	local from = joint.C0
	local started = os.clock()
	while joint.Parent do
		local alpha = math.clamp((os.clock() - started) / seconds, 0, 1)
		joint.C0 = from:Lerp(goal, 1 - (1 - alpha) * (1 - alpha))
		if alpha >= 1 then
			return
		end
		task.wait()
	end
end

local function swingArm(character: Model?)
	if not character then
		return
	end
	local upperArm = character:FindFirstChild("RightUpperArm")
	local torso = character:FindFirstChild("Torso")
	local shoulder: Motor6D? = (upperArm and upperArm:FindFirstChild("RightShoulder") :: Motor6D?)
		or (torso and torso:FindFirstChild("Right Shoulder") :: Motor6D?)
	if not shoulder or shoulder:GetAttribute("LvSwing") then
		return
	end
	shoulder:SetAttribute("LvSwing", true)
	local original = shoulder.C0
	local raise = if upperArm then CFrame.Angles(math.rad(75), 0, 0) else CFrame.Angles(0, 0, math.rad(75))
	task.spawn(function()
		-- The character can be removed at any moment (respawn, leaving): a destroyed joint just ends the swing.
		pcall(function()
			moveJoint(shoulder, original * raise, 0.07)
			task.wait(0.03)
			moveJoint(shoulder, original, 0.16)
			shoulder.C0 = original
			shoulder:SetAttribute("LvSwing", nil)
		end)
	end)
end

function Effects.bolt(attacker: Player?, from: Vector3, to: Vector3, tier: number)
	local length = (to - from).Magnitude
	if length < 0.1 then
		return
	end
	local color = tierColor(tier)
	local cframe = CFrame.lookAt((from + to) / 2, to)
	local core = newPart({ Size = Vector3.new(0.25, 0.25, length), CFrame = cframe, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon })
	local glow = newPart({ Size = Vector3.new(0.8, 0.8, length), CFrame = cframe, Color = color, Material = Enum.Material.Neon, Transparency = 0.55 })
	fadeOut(core, 0.16)
	fadeOut(glow, 0.22, { Size = Vector3.new(0.1, 0.1, length) })
	Effects.burst(to, color, 8)
	swingArm(attacker and attacker.Character)
	if attacker == player then
		Audio.play("attack")
	end
end

function Effects.wave(attacker: Player?, center: Vector3, radius: number, tier: number)
	local color = tierColor(tier)
	local ground = center - Vector3.new(0, 2.7, 0)
	for index, delay in { 0, 0.08 } do
		task.delay(delay, function()
			local ring = newPart({
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 2, 2),
				CFrame = ringCFrame(ground + Vector3.new(0, 0.2 * index, 0)),
				Color = if index == 1 then color else Color3.new(1, 1, 1),
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			})
			UiKit.tween(ring, 0.35, { Size = Vector3.new(0.3, radius * 2, radius * 2) })
			fadeOut(ring, 0.55)
		end)
	end
	Effects.burst(center, color, 30, 16)
	swingArm(attacker and attacker.Character)
	if attacker == player then
		Audio.play("wave")
		Effects.shake(0.25, 0.25)
	end
end

-- Automatic weapon attacks -------------------------------------------------------------------

local function weaponColor(weaponId: string): Color3
	local weapon = WeaponData.weapons[weaponId]
	return if weapon then UiKit.rgb(weapon.color) else GOLD
end

local function flatUnit(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local offset = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	return if offset.Magnitude > 0.05 then offset.Unit else fallback
end

-- A small glowing streak flying from `from` to `to`.
local function streak(from: Vector3, to: Vector3, color: Color3, thickness: number, length: number, speed: number)
	local distance = (to - from).Magnitude
	if distance < 0.1 then
		return
	end
	local direction = (to - from).Unit
	local travel = math.clamp(distance / speed, 0.05, 0.35)
	local part = newPart({
		Size = Vector3.new(thickness, thickness, length),
		CFrame = CFrame.lookAt(from, to),
		Color = color,
		Material = Enum.Material.Neon,
	})
	UiKit.tween(part, travel, { CFrame = CFrame.lookAt(to - direction * length * 0.5, to + direction) }, Enum.EasingStyle.Linear)
	task.delay(travel, function()
		Effects.burst(to, color, 6)
		fadeOut(part, 0.08)
	end)
end

local function groundRing(center: Vector3, radius: number, color: Color3, seconds: number)
	local ring = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 2, 2),
		CFrame = ringCFrame(center),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
	})
	UiKit.tween(ring, seconds * 0.6, { Size = Vector3.new(0.3, radius * 2, radius * 2) })
	fadeOut(ring, seconds)
end

-- Short neon blades placed along an arc in front of the attacker, lit one after another.
local function sweep(origin: Vector3, direction: Vector3, radius: number, arcDegrees: number, color: Color3)
	local steps = 7
	for index = 0, steps - 1 do
		local angle = math.rad(-arcDegrees / 2 + arcDegrees * index / (steps - 1))
		local dir = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, direction)).LookVector
		task.delay(index * 0.018, function()
			local blade = newPart({
				Size = Vector3.new(0.35, 0.35, radius * 0.55),
				CFrame = CFrame.lookAt(origin + dir * radius * 0.6, origin + dir * radius * 2),
				Color = color,
				Material = Enum.Material.Neon,
				Transparency = 0.2,
			})
			fadeOut(blade, 0.2)
		end)
	end
end

local STAR_COLOR = Color3.fromRGB(255, 225, 110)
local HEAL_COLOR = Color3.fromRGB(130, 245, 170)

-- Star Fall (a star drops onto `position`) and Lantern Glow (a green glow at the caster's feet).
function Effects.ability(attacker: Player?, id: string, position: Vector3, amount: number?)
	local mine = attacker == player
	if id == "star" then
		local star = newPart({
			Size = Vector3.new(2.4, 2.4, 2.4),
			CFrame = CFrame.new(position + Vector3.new(6, 32, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
			Color = STAR_COLOR,
			Material = Enum.Material.Neon,
		})
		local trail = newPart({ Size = Vector3.new(0.6, 0.6, 14), CFrame = CFrame.lookAt(star.Position, position), Color = STAR_COLOR, Material = Enum.Material.Neon, Transparency = 0.4 })
		UiKit.tween(star, 0.28, { CFrame = CFrame.new(position) * CFrame.Angles(math.rad(225), 0, math.rad(45)) }, Enum.EasingStyle.Quad)
		UiKit.tween(trail, 0.28, { CFrame = CFrame.lookAt(position + (star.Position - position).Unit * 7, position) }, Enum.EasingStyle.Quad)
		task.delay(0.28, function()
			fadeOut(star, 0.15, { Size = Vector3.one * 6 })
			fadeOut(trail, 0.1)
			groundRing(position - Vector3.new(0, 2, 0), 7, STAR_COLOR, 0.5)
			Effects.burst(position, STAR_COLOR, 36, 18)
			if mine then
				Audio.play("wave")
				Effects.shake(0.35, 0.25)
			end
		end)
	elseif id == "heal" then
		local feet = position - Vector3.new(0, 2.7, 0)
		groundRing(feet, 6, HEAL_COLOR, 0.7)
		Effects.burst(position, HEAL_COLOR, 24, 6)
		local column = newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 5, 5),
			CFrame = CFrame.new(feet + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = HEAL_COLOR,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
		})
		UiKit.tween(column, 0.6, { Size = Vector3.new(9, 5, 5), CFrame = CFrame.new(feet + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, math.rad(90)) })
		fadeOut(column, 0.7)
		if amount and amount > 0 then
			Effects.popup(position + Vector3.new(0, 2, 0), "+" .. Format.short(amount), HEAL_COLOR, 26)
		end
		if mine then
			Audio.play("pickup")
		end
	end
	swingArm(attacker and attacker.Character)
end

function Effects.attack(attacker: Player?, weaponId: string, slot: number, origin: Vector3, aim: Vector3, tier: number)
	local weapon = WeaponData.weapons[weaponId]
	if not weapon then
		return
	end
	if attacker ~= player then
		local own = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if own and (own.Position - origin).Magnitude > ATTACK_FX_DISTANCE then
			return
		end
	end
	local color = weaponColor(weaponId)
	local character = attacker and attacker.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local facing = if root then root.CFrame.LookVector else Vector3.new(0, 0, -1)
	local direction = flatUnit(origin, aim, facing)
	local style = weapon.style
	if style == "bolt" then
		Effects.bolt(nil, origin, aim, tier)
	elseif style == "arrow" then
		streak(origin, aim, color, 0.18, 2.2, 140)
	elseif style == "fan" then
		for index = 1, weapon.count do
			local angle = math.rad((index - (weapon.count + 1) / 2) * weapon.spread)
			local dir = (CFrame.Angles(0, angle, 0) * CFrame.lookAt(Vector3.zero, direction)).LookVector
			local reach = if index == (weapon.count + 1) / 2 then (aim - origin).Magnitude else weapon.range
			streak(origin, origin + dir * reach + Vector3.new(0, aim.Y - origin.Y, 0), color, 0.22, 1.1, 110)
		end
	elseif style == "pierce" then
		streak(origin, origin + direction * weapon.range + Vector3.new(0, aim.Y - origin.Y, 0), color, 0.3, 3, 170)
	elseif style == "arc" then
		sweep(origin, direction, weapon.range, weapon.arc, color)
	elseif style == "thrust" then
		local line = newPart({
			Size = Vector3.new(0.5, 0.5, 1),
			CFrame = CFrame.lookAt(origin + direction * 0.5, origin + direction * 2),
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
		})
		UiKit.tween(line, 0.1, {
			Size = Vector3.new(0.5, 0.5, weapon.range),
			CFrame = CFrame.lookAt(origin + direction * weapon.range * 0.5, origin + direction * weapon.range),
		})
		fadeOut(line, 0.25)
	elseif style == "spin" then
		groundRing(origin - Vector3.new(0, 3.5, 0), weapon.range, color, 0.35)
		sweep(origin, direction, weapon.range, 360, color)
	elseif style == "slam" then
		local ground = aim - Vector3.new(0, 2, 0)
		groundRing(ground, weapon.radius, color, 0.45)
		Effects.burst(ground, color, 18, 12)
		if attacker == player and slot == 0 then
			Effects.shake(0.3, 0.2)
		end
	end
	if slot == 0 then
		swingArm(character)
		if attacker == player then
			Audio.play("attack")
		end
	end
end

local CRIT_COLOR = Color3.fromRGB(255, 120, 90)
local CRYSTAL_COLOR = Color3.fromRGB(150, 210, 255)

local function onHit(model: Model?, position: Vector3, amount: number, crit: boolean?)
	if model then
		flash(model, Color3.new(1, 1, 1), 0.15, 0.2)
		-- The creature squashes flat for a moment and springs back (bigger on a critical hit).
		local body = model:FindFirstChild("Body")
		if body and body:IsA("BasePart") and not body:GetAttribute("LvSquash") then
			body:SetAttribute("LvSquash", true)
			local size = body.Size
			local stretch = if crit then 1.3 else 1.16
			body.Size = Vector3.new(size.X * stretch, size.Y * (2 - stretch), size.Z * stretch)
			UiKit.tween(body, 0.18, { Size = size }, Enum.EasingStyle.Back).Completed:Connect(function()
				body:SetAttribute("LvSquash", nil)
			end)
		end
	end
	local jitter = Vector3.new(math.random() * 2 - 1, 0, math.random() * 2 - 1)
	if not Settings.get("damageNumbers") then
		Audio.play("hit")
		return
	end
	if crit then
		Effects.popup(position + jitter, Format.short(amount) .. "!", CRIT_COLOR, 34)
	else
		Effects.popup(position + jitter, Format.short(amount), GOLD, 24)
	end
	Audio.play("hit")
end

-- A few little crystals fly from the purified creature into the local player.
local function onCrystals(from: Vector3, amount: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for index = 1, math.clamp(amount, 1, 6) do
		local gem = newPart({
			Size = Vector3.new(0.5, 0.5, 0.5),
			CFrame = CFrame.new(from + Vector3.new(math.random() * 2 - 1, 1 + math.random(), math.random() * 2 - 1)) * CFrame.Angles(0, 0, math.rad(45)),
			Color = CRYSTAL_COLOR,
			Material = Enum.Material.Neon,
		})
		task.delay(0.1 + index * 0.05, function()
			if root.Parent then
				UiKit.tween(gem, 0.35, { CFrame = CFrame.new(root.Position + Vector3.new(0, 1, 0)), Size = Vector3.new(0.2, 0.2, 0.2) })
			end
			fadeOut(gem, 0.45)
		end)
	end
	Audio.play("pickup")
end

-- Shadow Rift portals: spinning purple rings above the ground until the rift closes.
local RIFT_COLOR = Color3.fromRGB(170, 90, 255)
local portals: { [string]: { parts: { BasePart }, center: Vector3 } } = {}

local function onRiftOpened(areaId: string, center: Vector3)
	if portals[areaId] then
		return
	end
	local parts = {}
	for index = 1, 3 do
		local ring = newPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.3, 5 + index * 2, 5 + index * 2),
			CFrame = CFrame.new(center + Vector3.new(0, 0.2 * index, 0)) * UPRIGHT,
			Color = if index == 2 then Color3.new(1, 1, 1) else RIFT_COLOR,
			Material = Enum.Material.Neon,
			Transparency = 0.35 + index * 0.1,
		})
		table.insert(parts, ring)
	end
	local core = newPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(center + Vector3.new(0, 3, 0)),
		Color = RIFT_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	table.insert(parts, core)
	portals[areaId] = { parts = parts, center = center }
	Effects.burst(center + Vector3.new(0, 3, 0), RIFT_COLOR, 40, 12)
end

local function onRiftClosed(areaId: string, center: Vector3, success: boolean)
	local portal = portals[areaId]
	portals[areaId] = nil
	if portal then
		for _, part in portal.parts do
			fadeOut(part, 0.5)
		end
	end
	Effects.burst(center + Vector3.new(0, 3, 0), if success then GOLD else RIFT_COLOR, 60, 16)
end

local function spinPortals()
	local now = os.clock()
	for _, portal in portals do
		for index, part in portal.parts do
			if part.Parent then
				local height = if index == #portal.parts then 3 + math.sin(now * 3) * 0.5 else 0.2 * index
				local tilt = if index == #portal.parts then CFrame.new() else UPRIGHT
				part.CFrame = CFrame.new(portal.center + Vector3.new(0, height, 0)) * CFrame.Angles(0, now * (0.8 + index * 0.4), 0) * tilt
			end
		end
	end
end

local function onBlink(from: Vector3, to: Vector3)
	Effects.burst(from, RIFT_COLOR, 14, 8)
	Effects.burst(to, RIFT_COLOR, 14, 8)
end

local function onDespawn(position: Vector3)
	Effects.burst(position, RIFT_COLOR, 12, 6)
end

local function onDeposit(lantern: Vector3, _coins: number)
	Effects.burst(lantern + Vector3.new(0, 6, 0), GOLD, 40, 12)
	Effects.burst(lantern + Vector3.new(0, 6, 0), CRYSTAL_COLOR, 20, 10)
	Audio.play("levelUp")
end

-- A rebirth at the Great Lantern: a big golden and crystal burst for everyone nearby.
local function onRebirth(position: Vector3)
	groundRing(position - Vector3.new(0, 5.5, 0), 22, GOLD, 1.1)
	CameraRig.punch(6)
	Effects.burst(position, GOLD, 80, 18)
	Effects.burst(position, CRYSTAL_COLOR, 40, 14)
	Audio.play("levelUp")
end

local function onPurify(position: Vector3, kind: string, facing: Vector3?)
	local stats = Balance.enemies[kind]
	if not stats then
		return
	end
	local color = UiKit.rgb(stats.friendColor)
	local size = math.min(stats.size, 6)
	local look = facing or Vector3.new(0, 0, 1)
	local start = CFrame.lookAt(position, position + look)
	local spirit = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * size, CFrame = start, Color = color, Material = Enum.Material.Neon, Transparency = 0.05 })
	local face = UiKit.create("BillboardGui", { Size = UDim2.fromScale(size, size * 0.6), AlwaysOnTop = false, Adornee = spirit, LightInfluence = 0 }, spirit)
	local smile = UiKit.label({ Size = UDim2.fromScale(1, 1), Text = "^ ^", TextScaled = true, TextColor3 = Color3.fromRGB(80, 60, 90) }, face)
	UiKit.tween(spirit, 1.4, { CFrame = start * CFrame.new(0, 7, 0) * CFrame.Angles(0, math.pi, 0) }, Enum.EasingStyle.Sine)
	task.delay(0.7, function()
		UiKit.tween(spirit, 0.7, { Transparency = 1, Size = Vector3.one * size * 0.4 })
		UiKit.tween(smile, 0.5, { TextTransparency = 1 })
	end)
	Debris:AddItem(spirit, 1.5)
	Effects.burst(position, color, if stats.isBoss then 80 else 26, if stats.isBoss then 18 else 8)
	Effects.popup(position + Vector3.new(0, size * 0.5, 0), Strings.get("friend_popup"), color, 24)
	Audio.play("purify")
	if stats.isBoss then
		Effects.shake(0.5, 0.6)
	end
end

local projectiles: { [number]: { part: BasePart, origin: Vector3, velocity: Vector3, born: number, lifetime: number } } = {}

local function onProjectile(id: number, origin: Vector3, velocity: Vector3, lifetime: number, radius: number, style: string)
	local color = if style == "spore" then SPORE_COLOR else SHADOW_COLOR
	local part = newPart({ Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 1.5, Position = origin, Color = color, Material = Enum.Material.Neon })
	projectiles[id] = { part = part, origin = origin, velocity = velocity, born = os.clock(), lifetime = lifetime }
end

local function onProjectileEnd(id: number, position: Vector3)
	local projectile = projectiles[id]
	if projectile then
		Effects.burst(position, projectile.part.Color, 10)
		projectile.part:Destroy()
		projectiles[id] = nil
	end
end

local function updateProjectiles()
	local now = os.clock()
	for id, projectile in projectiles do
		local age = now - projectile.born
		if age >= projectile.lifetime then
			projectile.part:Destroy()
			projectiles[id] = nil
		else
			projectile.part.Position = projectile.origin + projectile.velocity * age
		end
	end
end

local function disc(position: Vector3, diameter: number, color: Color3, transparency: number, height: number): BasePart
	return newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, diameter, diameter),
		CFrame = ringCFrame(position + Vector3.new(0, height, 0)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = transparency,
	})
end

local activeTelegraphs: { BasePart } = {}

local function onTelegraph(position: Vector3, radius: number, duration: number)
	local outline = disc(position, radius * 2, WARN_COLOR, 0.65, 0.12)
	local fill = disc(position, 0.5, WARN_COLOR, 0.35, 0.16)
	for index = #activeTelegraphs, 1, -1 do
		if activeTelegraphs[index].Parent == nil then
			table.remove(activeTelegraphs, index)
		end
	end
	table.insert(activeTelegraphs, outline)
	table.insert(activeTelegraphs, fill)
	UiKit.tween(fill, duration, { Size = Vector3.new(0.15, radius * 2, radius * 2) }, Enum.EasingStyle.Linear)
	Debris:AddItem(outline, duration + 0.05)
	Debris:AddItem(fill, duration + 0.05)
	Audio.play("slamWarn")
end

local function nearLocal(position: Vector3, distance: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and (root.Position - position).Magnitude <= distance
end

local function onSlam(position: Vector3, radius: number)
	local blast = disc(position, radius * 2, SHADOW_COLOR, 0.15, 0.2)
	fadeOut(blast, 0.45, { Size = Vector3.new(0.15, radius * 2.4, radius * 2.4) })
	Effects.burst(position + Vector3.new(0, 1, 0), SHADOW_COLOR, 30, 14)
	Audio.play("slam")
	if nearLocal(position, radius + 14) then
		Effects.shake(0.45, 0.35)
	end
end

-- The server dropped a pending attack: clear its warnings so nothing hints at a hit that won't come.
local function onAttackCancel(model: Model?)
	for _, part in activeTelegraphs do
		if part.Parent then
			part:Destroy()
		end
	end
	table.clear(activeTelegraphs)
	if model then
		for _, child in model:GetChildren() do
			if child.Name == "LvWindup" then
				child:Destroy()
			end
		end
	end
end

local function onWindup(model: Model?, duration: number)
	if not model or not model.Parent then
		return
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "LvWindup"
	highlight.FillColor = Color3.fromRGB(255, 170, 80)
	highlight.OutlineColor = Color3.fromRGB(255, 230, 160)
	highlight.FillTransparency = 0.75
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = model
	UiKit.tween(highlight, duration, { FillTransparency = 0.15 }, Enum.EasingStyle.Linear)
	Debris:AddItem(highlight, duration + 0.05)
end

local function onBossPhase(model: Model?)
	if model then
		flash(model, SHADOW_COLOR, 0.8, 0)
		local body = model:FindFirstChild("Body") :: BasePart?
		if body and nearLocal(body.Position, 80) then
			Effects.shake(0.4, 0.5)
		end
	end
end

local function onLevelUp(who: Player, _level: number)
	local character = who.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = root.Position - Vector3.new(0, 3, 0)
	local column = newPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(14, 5, 5),
		CFrame = CFrame.new(base + Vector3.new(0, 7, 0)) * UPRIGHT,
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	fadeOut(column, 0.9, { Size = Vector3.new(20, 1, 1) })
	Effects.burst(root.Position, GOLD, 45, 12)
	-- A ring of light spreads over the ground around whoever levelled up.
	groundRing(root.Position - Vector3.new(0, 2.9, 0), 12, GOLD, 0.8)
	if who == player then
		Audio.play("levelUp")
		Effects.shake(0.2, 0.3)
		CameraRig.punch(4)
	end
end

local function onUpgrade(who: Player, tier: number)
	local character = who.Character
	local weapon = character and character:FindFirstChild("Weapon")
	local orb = weapon and weapon:FindFirstChild("Glow") :: BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = (orb and orb.Position) or (root and root.Position)
	if position then
		Effects.burst(position, tierColor(tier), 40, 10)
	end
end

-- Creature decorations the server marked with LvAnim (EnemyModels.animate) move here, on this
-- screen only: ears flap, runes circle, bubbles rise, flames flicker. Only creatures near the camera
-- are animated, and nothing moves with the "Low" effects setting.
local ANIM_DISTANCE = 120
type AnimPart = { part: BasePart, weld: Weld?, base: CFrame?, style: string, speed: number, amount: number, phase: number, transparency: number }
local animated: { [Instance]: { body: BasePart, parts: { AnimPart } } } = {}

local function watchAnimations(model: Instance)
	local body = model:WaitForChild("Body", 5) :: BasePart?
	if not body then
		return
	end
	local entry = { body = body, parts = {} }
	local function add(part: Instance)
		if part:IsA("BasePart") and part:GetAttribute("LvAnim") then
			local weld = part:FindFirstChildOfClass("Weld")
			table.insert(entry.parts, {
				part = part,
				weld = weld,
				base = weld and weld.C0,
				style = part:GetAttribute("LvAnim"),
				speed = part:GetAttribute("LvAnimSpeed") or 1,
				amount = part:GetAttribute("LvAnimAmount") or 0,
				phase = part:GetAttribute("LvAnimPhase") or 0,
				transparency = part.Transparency,
			})
		end
	end
	for _, child in model:GetChildren() do
		add(child)
	end
	model.ChildAdded:Connect(add)
	animated[model] = entry
end

local function animateCreatures()
	if Settings.get("effects") == "low" then
		return
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	local t = os.clock()
	for model, entry in animated do
		if not model.Parent then
			animated[model] = nil
		elseif not eye or (entry.body.CFrame.Position - eye).Magnitude <= ANIM_DISTANCE then
			for _, a in entry.parts do
				local wave = t * a.speed + a.phase
				if a.style == "flicker" then
					a.part.Transparency = math.clamp(a.transparency + (math.sin(wave) * 0.5 + 0.5) * a.amount, 0, 1)
				elseif a.weld and a.base then
					if a.style == "bob" then
						a.weld.C0 = CFrame.new(0, math.sin(wave) * a.amount, 0) * a.base
					elseif a.style == "orbit" then
						a.weld.C0 = CFrame.Angles(0, wave, 0) * a.base
					elseif a.style == "rise" then
						local lift = wave % 1
						a.weld.C0 = CFrame.new(0, lift * a.amount, 0) * a.base
						a.part.Transparency = a.transparency + (1 - a.transparency) * lift
					end
				end
			end
		end
	end
end

local function attachEnemyUi(model: Instance)
	if not model:IsA("Model") or model:GetAttribute("Boss") then
		return
	end
	local body = model:WaitForChild("Body", 5) :: BasePart?
	local stats = Balance.enemies[model:GetAttribute("EnemyType") or ""]
	if not body or not stats or not model.Parent then
		return
	end
	local gui = UiKit.create("BillboardGui", {
		Size = UDim2.fromOffset(140, 34),
		StudsOffset = Vector3.new(0, body.Size.Y * 0.5 + 1.6, 0),
		MaxDistance = 90,
		Adornee = body,
		Enabled = Settings.get("enemyBars"),
	}, billboards)
	UiKit.label({
		Size = UDim2.new(1, 0, 0, 18),
		Text = Strings.get(
			if model:GetAttribute("Elite") then "enemy_label_elite" else "enemy_label",
			model:GetAttribute("Level") or 1,
			Strings.get(stats.nameKey)
		),
		TextColor3 = if model:GetAttribute("Elite") then Color3.fromRGB(255, 205, 70) else nil,
		TextSize = 16,
		TextStrokeTransparency = 0.4,
	}, gui)
	local bar = UiKit.create("Frame", {
		Position = UDim2.fromOffset(10, 21),
		Size = UDim2.new(1, -20, 0, 9),
		BackgroundColor3 = Color3.fromRGB(40, 30, 60),
		BorderSizePixel = 0,
	}, gui)
	UiKit.corner(bar, 5)
	local fill = UiKit.create("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		BorderSizePixel = 0,
	}, bar)
	UiKit.corner(fill, 5)
	local function refresh()
		local hp = model:GetAttribute("Hp") or 0
		local maxHp = model:GetAttribute("MaxHp") or 1
		UiKit.tween(fill, 0.15, { Size = UDim2.fromScale(math.clamp(hp / maxHp, 0, 1), 1) })
	end
	model:GetAttributeChangedSignal("Hp"):Connect(refresh)
	refresh()
	model:GetAttributeChangedSignal("Aggro"):Connect(function()
		if model:GetAttribute("Aggro") and model:GetAttribute("Alive") then
			Effects.popup(body.Position + Vector3.new(0, stats.size * 0.5 + 1, 0), "!", Color3.fromRGB(255, 150, 80), 34)
		end
	end)
	model.Destroying:Connect(function()
		gui:Destroy()
	end)
end

local CONFETTI = {
	Color3.fromRGB(255, 130, 170),
	Color3.fromRGB(120, 210, 255),
	Color3.fromRGB(255, 220, 100),
	Color3.fromRGB(150, 230, 150),
}

local function onQuestComplete()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		for _, color in CONFETTI do
			Effects.burst(root.Position + Vector3.new(0, 3, 0), color, 16, 14)
		end
	end
end

local handlers = {
	attack = Effects.attack,
	wave = function(attacker, center, radius, tier)
		if attacker ~= player then
			Effects.wave(attacker, center, radius, tier)
		end
	end,
	ability = Effects.ability,
	hit = onHit,
	crystals = onCrystals,
	riftOpened = onRiftOpened,
	riftClosed = onRiftClosed,
	despawn = onDespawn,
	blink = onBlink,
	deposit = onDeposit,
	rebirth = onRebirth,
	purify = onPurify,
	projectile = onProjectile,
	projectileEnd = onProjectileEnd,
	telegraph = onTelegraph,
	slam = onSlam,
	windup = onWindup,
	attackCancel = onAttackCancel,
	bossPhase = onBossPhase,
	levelUp = onLevelUp,
	upgrade = onUpgrade,
	questComplete = onQuestComplete,
}

function Effects.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientFx"
	folder.Parent = workspace
	billboards = Instance.new("Folder")
	billboards.Name = "EnemyBillboards"
	billboards.Parent = player:WaitForChild("PlayerGui")

	fxRemote.OnClientEvent:Connect(function(kind, ...)
		local handler = handlers[kind]
		if handler then
			handler(...)
		end
	end)

	local enemies = workspace:WaitForChild("Enemies")
	enemies.ChildAdded:Connect(function(child)
		task.spawn(attachEnemyUi, child)
		task.spawn(watchAnimations, child)
		task.spawn(function()
			local body = child:WaitForChild("Body", 5) :: BasePart?
			if body then
				Effects.burst(body.Position, Color3.fromRGB(170, 120, 230), if child:GetAttribute("Boss") then 60 else 18, 7)
			end
		end)
	end)
	for _, child in enemies:GetChildren() do
		task.spawn(attachEnemyUi, child)
		task.spawn(watchAnimations, child)
	end

	-- Turning the creature name/health bars on or off applies to the ones already showing.
	Settings.onChanged(function()
		local show = Settings.get("enemyBars")
		for _, gui in billboards:GetChildren() do
			if gui:IsA("BillboardGui") then
				gui.Enabled = show
			end
		end
	end)

	RunService.RenderStepped:Connect(updateProjectiles)
	RunService.RenderStepped:Connect(spinPortals)
	RunService.RenderStepped:Connect(animateCreatures)
	RunService:BindToRenderStep("LvCameraShake", Enum.RenderPriority.Camera.Value + 1, function()
		local now = os.clock()
		if now >= shakeUntil then
			return
		end
		local camera = workspace.CurrentCamera
		local strength = shakeStrength * ((shakeUntil - now) / shakeLength)
		camera.CFrame *= CFrame.new(
			(math.random() - 0.5) * strength,
			(math.random() - 0.5) * strength,
			0
		)
	end)
end

return Effects
