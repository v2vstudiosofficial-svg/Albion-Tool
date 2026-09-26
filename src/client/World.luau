-- Per-player world state drawn locally: quest flowers, landmark beacons, the ruins vine barrier,
-- NPC quest markers and the village restoration decorations. None of it changes other players' world.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestData = require(Shared:WaitForChild("QuestData"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local Effects = require(script.Parent.Effects)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local interact = Remotes:WaitForChild("Interact") :: RemoteEvent
local fxRemote = Remotes:WaitForChild("Fx") :: RemoteEvent

local player = Players.LocalPlayer

local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))
local PLAZA = Vector3.new(0, 0, 12)
local WARM = Color3.fromRGB(255, 200, 110)
local PINK = Color3.fromRGB(255, 150, 210)
local GOLD = Color3.fromRGB(255, 220, 120)
local VINE = Color3.fromRGB(45, 95, 55)
local THORN = Color3.fromRGB(150, 70, 160)

local World = {}

local folder: Folder

local function localPart(props: { [string]: any }, parent: Instance): Part
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
	part.Parent = parent
	return part
end

local function ball(parent: Instance, size: number, position: Vector3, color: Color3, neon: boolean?): Part
	return localPart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * size,
		Position = position,
		Color = color,
		Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic,
	}, parent)
end

local function pillar(parent: Instance, height: number, diameter: number, base: Vector3, color: Color3, props: { [string]: any }?): Part
	local spec = {
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, diameter, diameter),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * UPRIGHT,
		Color = color,
	}
	for key, value in props or {} do
		spec[key] = value
	end
	return localPart(spec, parent)
end

local function csvSet(value: any): { [string]: boolean }
	local set = {}
	if typeof(value) == "string" then
		for item in string.gmatch(value, "[^,]+") do
			set[item] = true
		end
	end
	return set
end

-- True when questId is completed, derived from the tracked/next quest attributes.
local function isCompleted(questId: string): boolean
	if player:GetAttribute("QuestState") == "done" then
		return true
	end
	local current = table.find(QuestData.order, player:GetAttribute("QuestId") or "")
	local target = table.find(QuestData.order, questId)
	return current ~= nil and target ~= nil and current > target
end

local function isActive(questId: string): boolean
	return player:GetAttribute("QuestState") == "active" and player:GetAttribute("QuestId") == questId
end

-- Flowers ---------------------------------------------------------------------------------------

local flowers: { [string]: Model } = {}

local function buildFlower(id: string, position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Flower_" .. id
	pillar(model, 1.8, 0.25, position, Color3.fromRGB(90, 170, 90))
	local head = ball(model, 0.8, position + Vector3.new(0, 2.1, 0), GOLD, true)
	for index = 1, 5 do
		local angle = index / 5 * math.pi * 2
		ball(model, 0.7, position + Vector3.new(math.cos(angle) * 0.6, 2.1, math.sin(angle) * 0.6), PINK, true)
	end
	local light = Instance.new("PointLight")
	light.Color = PINK
	light.Range = 8
	light.Brightness = 1
	light.Shadows = false
	light.Parent = head
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Rate = 3
	sparkle.Color = ColorSequence.new(PINK)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new(0.2)
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.Lifetime = NumberRange.new(1, 1.6)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Parent = head
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = Strings.get("flower_action")
	prompt.ObjectText = Strings.get("flower_name")
	prompt.HoldDuration = 0.25
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = head
	prompt.Triggered:Connect(function()
		interact:FireServer("flower", id)
	end)
	model.Parent = folder
	return model
end

local function refreshFlowers()
	local active = isActive("lantern_flowers")
	local found = csvSet(player:GetAttribute("QuestFound"))
	for id, position in WorldData.flowers do
		local show = active and not found[id]
		if show and not flowers[id] then
			flowers[id] = buildFlower(id, WorldData.vector(position))
		elseif not show and flowers[id] then
			flowers[id]:Destroy()
			flowers[id] = nil
		end
	end
end

-- Landmark beacons ------------------------------------------------------------------------------

local beacons: { [string]: Model } = {}

local function buildBeacon(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Beacon"
	pillar(model, 70, 3, position, GOLD, { Material = Enum.Material.Neon, Transparency = 0.55 })
	localPart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.15, 10, 10),
		CFrame = CFrame.new(position + Vector3.new(0, 0.25, 0)) * UPRIGHT,
		Color = GOLD,
		Material = Enum.Material.Neon,
		Transparency = 0.6,
	}, model)
	model.Parent = folder
	return model
end

local function refreshBeacons()
	local active = isActive("forest_explore")
	local found = csvSet(player:GetAttribute("QuestFound"))
	for id, landmark in WorldData.landmarks do
		local show = active and not found[id]
		if show and not beacons[id] then
			beacons[id] = buildBeacon(WorldData.vector(landmark.position))
		elseif not show and beacons[id] then
			beacons[id]:Destroy()
			beacons[id] = nil
		end
	end
end

-- Ruins vines (a personal barrier: local parts only collide with this player's character) --------

local vines: { [string]: Model } = {}
local barrier: BasePart? = nil

local function buildVine(position: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Vine"
	local offsets = {
		Vector3.new(0, 2, 0),
		Vector3.new(-1.2, 4.2, 0.3),
		Vector3.new(1.1, 6, -0.2),
		Vector3.new(-0.4, 8.4, 0.2),
		Vector3.new(0.8, 10.5, 0),
	}
	for index, offset in offsets do
		ball(model, 3.4 - index * 0.25, position + offset, VINE)
		ball(model, 0.7, position + offset + Vector3.new(0.9, 0.4, -1.2), THORN, true)
	end
	model.Parent = folder
	return model
end

local function refreshVines()
	local done = isCompleted("ruin_vines")
	local active = isActive("ruin_vines")
	local found = if active then csvSet(player:GetAttribute("QuestFound")) else {}
	local remaining = 0
	for id, position in WorldData.vines do
		local show = not done and not found[id]
		if show then
			remaining += 1
		end
		if show and not vines[id] then
			vines[id] = buildVine(WorldData.vector(position))
		elseif not show and vines[id] then
			vines[id]:Destroy()
			vines[id] = nil
		end
	end
	if remaining > 0 and not barrier then
		local gate = WorldData.gate
		barrier = localPart({
			Size = Vector3.new(gate.halfWidth * 2, 24, 2),
			Position = Vector3.new(0, 12, gate.z),
			Transparency = 1,
			CanCollide = true,
		}, folder)
	elseif remaining == 0 and barrier then
		barrier:Destroy()
		barrier = nil
	end
end

-- NPC markers -----------------------------------------------------------------------------------

local markers: { [string]: BillboardGui } = {}

local function buildMarker(npcName: string): BillboardGui?
	local map = workspace:WaitForChild("LanternValleyMap", 10)
	local npc = map and map:WaitForChild("Village"):WaitForChild(npcName, 10)
	local body = npc and npc:WaitForChild("Body", 5)
	if not body then
		return nil
	end
	local gui = UiKit.create("BillboardGui", {
		Size = UDim2.fromOffset(60, 70),
		StudsOffset = Vector3.new(0, 6.2, 0),
		AlwaysOnTop = true,
		Adornee = body,
		Enabled = false,
		MaxDistance = 250,
	}, player:WaitForChild("PlayerGui"))
	UiKit.label({
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		TextSize = 60,
		TextColor3 = GOLD,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = Color3.fromRGB(120, 70, 20),
	}, gui)
	task.spawn(function()
		while gui.Parent do
			UiKit.tween(gui, 0.6, { StudsOffset = Vector3.new(0, 6.8, 0) }, Enum.EasingStyle.Sine).Completed:Wait()
			UiKit.tween(gui, 0.6, { StudsOffset = Vector3.new(0, 6.2, 0) }, Enum.EasingStyle.Sine).Completed:Wait()
		end
	end)
	return gui
end

local function refreshMarkers()
	local elder = markers.Elder
	if elder then
		elder.Enabled = player:GetAttribute("QuestState") == "available"
	end
	local demir = markers.Demir
	if demir then
		demir.Enabled = isActive("first_upgrade")
	end
end

-- NPC idle life: a gentle breathing bob and turning toward a nearby local player (local only).

local NPC_LOOK_DISTANCE = 16

local function animateNpcs()
	local map = workspace:WaitForChild("LanternValleyMap", 10)
	local village = map and map:WaitForChild("Village", 10)
	if not village then
		return
	end
	local npcs = {}
	for name in WorldData.npcs do
		local model = village:WaitForChild(name, 10)
		if model and model:IsA("Model") and model.PrimaryPart then
			table.insert(npcs, { model = model, base = model:GetPivot(), yaw = 0, phase = #npcs * 1.7 })
		end
	end
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local now = os.clock()
		for _, npc in npcs do
			if not npc.model.Parent then
				continue
			end
			local base: CFrame = npc.base
			local targetYaw = 0
			if root then
				local offset = root.Position - base.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude < NPC_LOOK_DISTANCE and flat.Magnitude > 0.5 then
					local localDir = base:VectorToObjectSpace(flat.Unit)
					targetYaw = math.atan2(-localDir.X, -localDir.Z)
				end
			end
			local difference = (targetYaw - npc.yaw + math.pi) % (2 * math.pi) - math.pi
			npc.yaw += difference * math.min(dt * 6, 1)
			local bob = math.sin(now * 2 + npc.phase) * 0.08
			npc.model:PivotTo(base * CFrame.new(0, bob, 0) * CFrame.Angles(0, npc.yaw, 0))
		end
	end)
end

-- Restoration -----------------------------------------------------------------------------------

local builtFlags: { [string]: boolean } = {}
local restorationBuilders = {}

function restorationBuilders.gardens(parent: Instance)
	local palette = {
		Color3.fromRGB(255, 130, 170),
		Color3.fromRGB(255, 220, 100),
		Color3.fromRGB(170, 140, 255),
		Color3.fromRGB(255, 160, 90),
		Color3.fromRGB(120, 210, 255),
	}
	for bed, degrees in { 0, 45, 135, 180, 225, 315 } do
		local angle = math.rad(degrees)
		local center = PLAZA + Vector3.new(math.cos(angle) * 19, 0, math.sin(angle) * 19)
		localPart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.35, 5, 5),
			CFrame = CFrame.new(center + Vector3.new(0, 0.18, 0)) * UPRIGHT,
			Color = Color3.fromRGB(120, 85, 60),
		}, parent)
		for index = 1, 7 do
			local a = index / 7 * math.pi * 2
			local r = if index % 2 == 0 then 1.6 else 0.8
			ball(parent, 0.9, center + Vector3.new(math.cos(a) * r, 0.8, math.sin(a) * r), palette[(bed + index) % #palette + 1])
		end
	end
	for line, z in { 0, 32 } do
		for index = 0, 12 do
			local t = index / 12
			local x = -27 + t * 54
			local y = 11 - math.sin(t * math.pi) * 2.2
			localPart({
				Size = Vector3.new(1, 1, 0.1),
				CFrame = CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(45)),
				Color = palette[(index + line) % #palette + 1],
			}, parent)
		end
	end
end

function restorationBuilders.lanterns(parent: Instance)
	for _, base in { Vector3.new(-35, 0, 0), Vector3.new(35, 0, 0), Vector3.new(-35, 0, 32), Vector3.new(35, 0, 32) } do
		local facing = if base.X > 0 then -1 else 1
		local lamp = ball(parent, 1.2, base + Vector3.new(facing * 7.9, 6.2, 2.6), WARM, true)
		local light = Instance.new("PointLight")
		light.Color = WARM
		light.Range = 12
		light.Brightness = 1.3
		light.Shadows = false
		light.Parent = lamp
	end
	for index = 1, 8 do
		local angle = index / 8 * math.pi * 2 + math.pi / 8
		local base = PLAZA + Vector3.new(math.cos(angle) * 16, 0, math.sin(angle) * 16)
		pillar(parent, 4, 0.4, base, Color3.fromRGB(135, 95, 65))
		ball(parent, 1, base + Vector3.new(0, 4.4, 0), WARM, true)
	end
end

function restorationBuilders.festival(parent: Instance)
	local lamp = ball(parent, 3.2, PLAZA + Vector3.new(0, 10.8, 0), WARM, true)
	local light = Instance.new("PointLight")
	light.Color = WARM
	light.Range = 36
	light.Brightness = 2
	light.Shadows = false
	light.Parent = lamp
	pillar(parent, 60, 1.4, PLAZA + Vector3.new(0, 12, 0), WARM, { Material = Enum.Material.Neon, Transparency = 0.55 })

	local area = localPart({ Size = Vector3.new(40, 6, 40), Position = PLAZA + Vector3.new(0, 4, 0), Transparency = 1 }, parent)
	local fireflies = Instance.new("ParticleEmitter")
	fireflies.Shape = Enum.ParticleEmitterShape.Box
	fireflies.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	fireflies.Rate = 10
	fireflies.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	fireflies.LightEmission = 1
	fireflies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.3), NumberSequenceKeypoint.new(1, 0) })
	fireflies.Lifetime = NumberRange.new(3, 5)
	fireflies.Speed = NumberRange.new(0.5, 1.5)
	fireflies.SpreadAngle = Vector2.new(180, 180)
	fireflies.Parent = area

	local banners = { Color3.fromRGB(255, 130, 170), Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 220, 100), Color3.fromRGB(170, 140, 255) }
	for index, degrees in { 45, 135, 225, 315 } do
		local angle = math.rad(degrees)
		local base = PLAZA + Vector3.new(math.cos(angle) * 22, 0, math.sin(angle) * 22)
		pillar(parent, 9, 0.5, base, Color3.fromRGB(135, 95, 65))
		localPart({
			Size = Vector3.new(0.2, 4, 2.4),
			CFrame = CFrame.lookAt(base + Vector3.new(0, 6.6, 0), PLAZA + Vector3.new(0, 6.6, 0)) * CFrame.new(0, 0, -1.3) * CFrame.Angles(0, math.rad(90), 0),
			Color = banners[index],
		}, parent)
	end
end

local function refreshRestoration(celebrate: boolean)
	local flags = csvSet(player:GetAttribute("Flags"))
	for flag, builder in restorationBuilders do
		if flags[flag] and not builtFlags[flag] then
			builtFlags[flag] = true
			local group = Instance.new("Folder")
			group.Name = "Restoration_" .. flag
			group.Parent = folder
			builder(group)
			if celebrate then
				Effects.burst(PLAZA + Vector3.new(0, 8, 0), WARM, 80, 16)
			end
		end
	end
end

-- Wiring ----------------------------------------------------------------------------------------

local function refreshQuestVisuals()
	refreshFlowers()
	refreshBeacons()
	refreshVines()
	refreshMarkers()
end

function World.start()
	folder = Instance.new("Folder")
	folder.Name = "ClientWorld"
	folder.Parent = workspace

	for _, name in { "QuestState", "QuestId", "QuestFound" } do
		player:GetAttributeChangedSignal(name):Connect(refreshQuestVisuals)
	end
	player:GetAttributeChangedSignal("Flags"):Connect(function()
		refreshRestoration(true)
	end)
	refreshQuestVisuals()
	refreshRestoration(false)

	fxRemote.OnClientEvent:Connect(function(kind, id, position)
		if kind == "collected" then
			Effects.burst(position + Vector3.new(0, 2, 0), PINK, 30, 8)
			Audio.play("pickup")
		elseif kind == "discovered" then
			local landmark = WorldData.landmarks[id]
			Effects.burst(position + Vector3.new(0, 4, 0), GOLD, 60, 14)
			if landmark then
				Effects.popup(position + Vector3.new(0, 8, 0), Strings.get(landmark.nameKey), GOLD, 30)
			end
			Audio.play("pickup")
		elseif kind == "vineCleared" then
			local vine = WorldData.vines[id]
			if vine then
				Effects.burst(WorldData.vector(vine) + Vector3.new(0, 5, 0), Color3.fromRGB(120, 220, 120), 40, 12)
			end
		end
	end)

	task.spawn(function()
		markers.Elder = buildMarker("Elder")
		markers.Demir = buildMarker("Demir")
		refreshMarkers()
	end)
	task.spawn(animateNpcs)
end

return World
