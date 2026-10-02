-- Lantern Valley's own loading screen. ReplicatedFirst runs before anything else, so this script
-- builds its own small UI (the client's UiKit is not there yet): a night-blue valley sky with
-- rising sparks, a glowing lantern, the title, rotating tips and a progress bar. It fades out once
-- the world has loaded and the player's save is ready, or after MAX_SECONDS; a Skip button shows
-- up when loading takes long.
local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local MIN_SECONDS = 2.5 -- long enough to read the title, short enough not to annoy
local MAX_SECONDS = 25
local SKIP_AFTER = 8
local TIP_SECONDS = 4
local TIPS = { "loading_tip_1", "loading_tip_2", "loading_tip_3", "loading_tip_4", "loading_tip_5", "loading_tip_6", "loading_tip_7", "loading_tip_8" }
local SPARKS = 28
local FONT = Enum.Font.FredokaOne
local GOLD = Color3.fromRGB(255, 215, 110)
local CREAM = Color3.fromRGB(255, 248, 230)
local MUTED = Color3.fromRGB(190, 180, 210)

local player = Players.LocalPlayer
pcall(function()
	ReplicatedFirst:RemoveDefaultLoadingScreen()
end)

local function create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in props do
		(instance :: any)[key] = value
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

local function round(parent: Instance, radius: number)
	create("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }): Tween
	local t = TweenService:Create(instance, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

-- Everything sits in one CanvasGroup so the whole screen can fade out in one tween.
local gui = create("ScreenGui", { Name = "LoadingScreen", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100 }, player:WaitForChild("PlayerGui"))
local root = create("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(12, 14, 40), BorderSizePixel = 0 }, gui)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(46, 36, 96), Color3.fromRGB(8, 10, 28)) }, root)

-- Gold sparks drifting up the screen, each at its own pace and sway.
local random = Random.new()
local sparks = {}
for index = 1, SPARKS do
	local size = random:NextInteger(3, 7)
	local spark = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = 0.2 + (index % 4) * 0.15,
		BorderSizePixel = 0,
	}, root)
	round(spark, size)
	table.insert(sparks, { frame = spark, x = random:NextNumber(), y = random:NextNumber(), speed = random:NextNumber(0.03, 0.09), sway = random:NextNumber(0, math.pi * 2) })
end

-- The middle block (lantern, title, tip, bar) keeps its proportions on any screen.
local middle = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(520, 420),
	BackgroundTransparency = 1,
}, root)
local middleScale = create("UIScale", {}, middle)

-- The lantern: soft halo rings, a dark cap and base, warm glass and a flickering flame.
local lantern = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(260, 110), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1 }, middle)
local halos = {}
for _, ring in { { 240, 0.9 }, { 170, 0.8 }, { 115, 0.65 } } do
	local halo = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(ring[1], ring[1]),
		BackgroundColor3 = GOLD,
		BackgroundTransparency = ring[2],
		BorderSizePixel = 0,
	}, lantern)
	round(halo, ring[1])
	table.insert(halos, { frame = halo, size = ring[1] })
end
local dark = Color3.fromRGB(40, 32, 60)
local hook = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, -56), Size = UDim2.fromOffset(18, 14), BackgroundTransparency = 1, BorderSizePixel = 0 }, lantern)
create("UIStroke", { Color = dark, Thickness = 4 }, hook)
round(hook, 9)
local cap = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(0, -40), Size = UDim2.fromOffset(62, 16), BackgroundColor3 = dark, BorderSizePixel = 0 }, lantern)
round(cap, 6)
local glass = create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(52, 72), BackgroundColor3 = Color3.fromRGB(255, 225, 140), BorderSizePixel = 0 }, lantern)
round(glass, 10)
create("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 245, 200), Color3.fromRGB(255, 190, 90)) }, glass)
create("UIStroke", { Color = dark, Thickness = 4 }, glass)
create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(4, 72), BackgroundColor3 = dark, BorderSizePixel = 0 }, glass)
local flame = create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(16, 26), BackgroundColor3 = Color3.fromRGB(255, 140, 40), BorderSizePixel = 0, ZIndex = 2 }, glass)
round(flame, 8)
local base = create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(0, 38), Size = UDim2.fromOffset(70, 14), BackgroundColor3 = dark, BorderSizePixel = 0 }, lantern)
round(base, 6)

local title = create("TextLabel", {
	Position = UDim2.fromOffset(0, 200),
	Size = UDim2.new(1, 0, 0, 72),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 64,
	TextColor3 = GOLD,
	TextStrokeColor3 = Color3.fromRGB(90, 50, 20),
	TextStrokeTransparency = 0.2,
	Text = "",
}, middle)
local tip = create("TextLabel", {
	Position = UDim2.fromOffset(10, 280),
	Size = UDim2.new(1, -20, 0, 52),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 20,
	TextColor3 = MUTED,
	TextWrapped = true,
	Text = "",
}, middle)
local barBack = create("Frame", { Position = UDim2.fromOffset(80, 350), Size = UDim2.fromOffset(360, 12), BackgroundColor3 = Color3.fromRGB(30, 26, 60), BorderSizePixel = 0 }, middle)
round(barBack, 6)
local barFill = create("Frame", { Name = "Fill", Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0 }, barBack)
round(barFill, 6)
local status = create("TextLabel", {
	Position = UDim2.fromOffset(0, 368),
	Size = UDim2.new(1, 0, 0, 24),
	BackgroundTransparency = 1,
	Font = FONT,
	TextSize = 16,
	TextColor3 = CREAM,
	Text = "",
}, middle)
local skip = create("TextButton", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -24, 1, -24),
	Size = UDim2.fromOffset(120, 46),
	BackgroundColor3 = Color3.fromRGB(70, 62, 105),
	BorderSizePixel = 0,
	Font = FONT,
	TextSize = 20,
	TextColor3 = CREAM,
	Text = "",
	Visible = false,
	AutoButtonColor = true,
}, root)
round(skip, 12)

-- Texts come from Strings once ReplicatedStorage has arrived (a moment after the sky shows).
local Strings = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Strings"))
	end)
	if ok then
		Strings = module
		title.Text = module.get("loading_title")
		skip.Text = module.get("loading_skip")
	end
end)

local function loaded(): boolean
	local ok, value = pcall(function()
		return game:IsLoaded()
	end)
	return not ok or value == true
end

local function queueSize(): number
	local ok, value = pcall(function()
		return ContentProvider.RequestQueueSize
	end)
	return if ok and typeof(value) == "number" then value else 0
end

local started = os.clock()
local tipIndex = random:NextInteger(1, #TIPS)
local tipShownAt = -math.huge
local progress = 0
local closing = false
local connection: RBXScriptConnection? = nil

local function close()
	if closing then
		return
	end
	closing = true
	tween(barFill, 0.25, { Size = UDim2.fromScale(1, 1) })
	tween(root, 0.6, { GroupTransparency = 1 }).Completed:Connect(function()
		if connection then
			connection:Disconnect()
		end
		gui:Destroy()
	end)
end
skip.Activated:Connect(close)

connection = RunService.RenderStepped:Connect(function(dt)
	local now = os.clock()
	local elapsed = now - started
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 560)
	middleScale.Scale = math.clamp(math.min(viewport.X / 900, viewport.Y / 560), 0.55, 1.3)

	for _, spark in sparks do
		spark.y -= spark.speed * dt
		if spark.y < -0.05 then
			spark.y, spark.x = 1.05, random:NextNumber()
		end
		spark.frame.Position = UDim2.fromScale(spark.x + math.sin(elapsed * 1.3 + spark.sway) * 0.012, spark.y)
	end
	-- The halo breathes and the flame flickers.
	for index, halo in halos do
		local size = halo.size * (1 + 0.06 * math.sin(elapsed * 2 + index))
		halo.frame.Size = UDim2.fromOffset(size, size)
	end
	flame.Size = UDim2.fromOffset(16 + math.sin(elapsed * 17) * 2, 26 + math.sin(elapsed * 11) * 4)

	if Strings and now - tipShownAt >= TIP_SECONDS then
		tipShownAt = now
		tipIndex = tipIndex % #TIPS + 1
		tip.Text = Strings.get(TIPS[tipIndex])
		tip.TextTransparency = 1
		tween(tip, 0.4, { TextTransparency = 0 })
	end

	-- World first (60% of the bar), then the save (the rest).
	local worldPart = if loaded() then 1 else math.clamp(0.9 - queueSize() / 200, 0.2, 0.9)
	local state = player:GetAttribute("DataState")
	local ready = state == "ready" or state == "failed"
	local target = worldPart * 0.6 + (if ready then 0.4 else math.min(0.3, elapsed * 0.03))
	progress += (target - progress) * math.min(1, dt * 4)
	barFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	if Strings then
		status.Text = Strings.get(if not loaded() then "loading_world" elseif not ready then "loading_data" else "loading_done")
	end
	skip.Visible = elapsed >= SKIP_AFTER

	if (loaded() and ready and elapsed >= MIN_SECONDS) or elapsed >= MAX_SECONDS then
		close()
	end
end)
