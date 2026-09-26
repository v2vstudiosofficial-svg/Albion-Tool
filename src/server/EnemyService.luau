local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Balance = require(ReplicatedStorage.Shared.Balance)
local Strings = require(ReplicatedStorage.Shared.Strings)
local EnemyLogic = require(script.Parent.EnemyLogic)

local BODY_COLOR = Color3.fromRGB(115, 75, 175)
local FLASH_COLOR = Color3.fromRGB(255, 255, 255)
local PURIFIED_COLOR = Color3.fromRGB(255, 235, 160)

type Enemy = {
	id: number,
	kind: string,
	stats: any,
	model: Model,
	body: BasePart,
	fill: Frame,
	spawnPoint: BasePart,
	home: Vector3,
	position: Vector3,
	logic: EnemyLogic.State,
	lastContact: { [Player]: number },
}

type PlayerTarget = { player: Player, humanoid: Humanoid, root: BasePart }

local EnemyService = {}

local enemies: { [number]: Enemy } = {}
local purifiedListeners: { (string, any, { Player }) -> () } = {}
local folder: Folder
local nextId = 0

local function newPart(name: string, props: { [string]: any }): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

local function buildModel(kind: string, stats, cframe: CFrame): (Model, BasePart, Frame)
	local model = Instance.new("Model")
	model.Name = kind

	local body = newPart("Body", {
		Size = Vector3.new(3.5, 3.5, 3.5),
		CFrame = cframe,
		Color = BODY_COLOR,
		Material = Enum.Material.SmoothPlastic,
	})
	body.Parent = model
	for index, x in { -0.6, 0.6 } do
		local eye = newPart("Eye" .. index, {
			Size = Vector3.new(0.7, 0.7, 0.7),
			CFrame = cframe * CFrame.new(x, 0.4, -1.45),
			Color = Color3.new(1, 1, 1),
			Material = Enum.Material.Neon,
		})
		eye.Parent = model
	end
	model.PrimaryPart = body

	local info = Instance.new("BillboardGui")
	info.Name = "Info"
	info.Size = UDim2.fromScale(4, 1.2)
	info.StudsOffset = Vector3.new(0, 3.2, 0)
	info.MaxDistance = 80
	info.Adornee = body
	info.Parent = body

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 0.55)
	label.BackgroundTransparency = 1
	label.Text = Strings.get(stats.nameKey)
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = info

	local bar = Instance.new("Frame")
	bar.Position = UDim2.fromScale(0, 0.65)
	bar.Size = UDim2.fromScale(1, 0.3)
	bar.BackgroundColor3 = Color3.fromRGB(40, 30, 60)
	bar.BorderSizePixel = 0
	bar.Parent = info
	Instance.new("UICorner").Parent = bar

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(255, 220, 120)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner").Parent = fill

	return model, body, fill
end

local function spawnAt(spawnPoint: BasePart, kind: string)
	local stats = Balance.enemies[kind]
	nextId += 1
	local home = spawnPoint.Position + Vector3.new(0, stats.hoverHeight, 0)
	local model, body, fill = buildModel(kind, stats, CFrame.new(home))
	model:SetAttribute("EnemyId", nextId)
	model:SetAttribute("EnemyType", kind)
	model:SetAttribute("Alive", true)
	model.Parent = folder

	enemies[nextId] = {
		id = nextId,
		kind = kind,
		stats = stats,
		model = model,
		body = body,
		fill = fill,
		spawnPoint = spawnPoint,
		home = home,
		position = home,
		logic = EnemyLogic.new(stats.maxHp),
		lastContact = {},
	}
end

local function collectTargets(): { PlayerTarget }
	local targets = {}
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if humanoid and root and humanoid.Health > 0 then
			table.insert(targets, { player = player, humanoid = humanoid, root = root })
		end
	end
	return targets
end

local function updateEnemy(enemy: Enemy, targets: { PlayerTarget }, dt: number, now: number)
	local stats = enemy.stats
	local target: PlayerTarget? = nil
	local nearest = stats.aggroRadius
	for _, candidate in targets do
		local distance = (candidate.root.Position - enemy.position).Magnitude
		local withinLeash = (candidate.root.Position - enemy.home).Magnitude <= stats.leashRadius
		if distance < nearest and withinLeash then
			target, nearest = candidate, distance
		end
	end

	local goal = if target then target.root.Position else enemy.home
	local flatGoal = Vector3.new(goal.X, enemy.home.Y, goal.Z)
	local offset = flatGoal - enemy.position
	local distance = offset.Magnitude
	local stopDistance = if target then stats.contactRange * 0.6 else 0.2
	if distance > stopDistance then
		enemy.position += offset.Unit * math.min(stats.speed * dt, distance - stopDistance)
	end

	local bob = Vector3.new(0, math.sin(now * 3 + enemy.id) * 0.4, 0)
	local position = enemy.position + bob
	local facing = flatGoal + bob
	if (facing - position).Magnitude > 0.1 then
		enemy.model:PivotTo(CFrame.lookAt(position, facing))
	else
		enemy.model:PivotTo(CFrame.new(position) * enemy.body.CFrame.Rotation)
	end

	if target and nearest <= stats.contactRange then
		local last = enemy.lastContact[target.player]
		if not last or now - last >= stats.contactCooldown then
			enemy.lastContact[target.player] = now
			target.humanoid:TakeDamage(stats.contactDamage)
		end
	end
end

local function purify(enemy: Enemy)
	enemies[enemy.id] = nil
	local participants = EnemyLogic.participants(enemy.logic, os.clock(), Balance.participationWindow, function(player)
		return player.Parent == Players
	end)

	enemy.model:SetAttribute("Alive", false)
	local info = enemy.body:FindFirstChild("Info") :: BillboardGui?
	if info then
		info.Enabled = false
	end
	enemy.body.Color = PURIFIED_COLOR
	enemy.body.Material = Enum.Material.Neon
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Rate = 0
	sparkles.Color = ColorSequence.new(PURIFIED_COLOR)
	sparkles.Speed = NumberRange.new(4, 8)
	sparkles.Lifetime = NumberRange.new(0.6, 1)
	sparkles.Parent = enemy.body
	sparkles:Emit(25)
	for _, descendant in enemy.model:GetDescendants() do
		if descendant:IsA("BasePart") then
			TweenService:Create(descendant, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.5, function()
		enemy.model:Destroy()
	end)
	task.delay(enemy.stats.respawnDelay, function()
		spawnAt(enemy.spawnPoint, enemy.kind)
	end)

	for _, listener in purifiedListeners do
		task.spawn(listener, enemy.kind, enemy.stats.reward, participants)
	end
end

local function flash(enemy: Enemy)
	enemy.body.Color = FLASH_COLOR
	task.delay(0.1, function()
		if enemy.logic.alive then
			enemy.body.Color = BODY_COLOR
		end
	end)
end

function EnemyService.get(id: number): Enemy?
	return enemies[id]
end

function EnemyService.getFolder(): Folder
	return folder
end

function EnemyService.connectPurified(listener: (string, any, { Player }) -> ())
	table.insert(purifiedListeners, listener)
end

-- Server-validated damage entry point; returns true when the hit was applied.
function EnemyService.damage(id: number, player: Player, amount: number): boolean
	local enemy = enemies[id]
	if not enemy or not enemy.logic.alive then
		return false
	end
	local purified = EnemyLogic.applyHit(enemy.logic, player, amount, os.clock())
	enemy.fill.Size = UDim2.fromScale(enemy.logic.hp / enemy.logic.maxHp, 1)
	if purified then
		purify(enemy)
	else
		flash(enemy)
	end
	return true
end

function EnemyService.start(map: Folder)
	folder = Instance.new("Folder")
	folder.Name = "Enemies"
	folder.Parent = workspace

	for _, spawnPoint in map.Forest.EnemySpawns:GetChildren() do
		if spawnPoint:IsA("BasePart") then
			spawnAt(spawnPoint, "Gloomling")
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		for _, enemy in enemies do
			EnemyLogic.forget(enemy.logic, player)
			enemy.lastContact[player] = nil
		end
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		local targets = collectTargets()
		for _, enemy in enemies do
			updateEnemy(enemy, targets, dt, now)
		end
	end)
end

return EnemyService
