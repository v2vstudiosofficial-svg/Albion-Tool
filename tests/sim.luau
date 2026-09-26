-- Run: lune run tests/sim
-- Runs the real server code (src/server, src/shared and the vendored ProfileStore in its mock mode)
-- inside Lune with fake players, a simulated clock, fake remotes and stubbed engine pieces
-- (no physics, raycasts always clear, no rendering). It exercises the quest chain, combat,
-- co-op rewards, boss fight, invalid client payloads and save/rejoin, and fails on any error
-- raised in any server thread. It is not a substitute for playing in Studio.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame

-- Scheduler with a simulated clock -------------------------------------------------------------

local clock = 0
local queue: { { at: number, thread: thread, args: { any } } } = {}
local threadErrors: { string } = {}
local warnings: { string } = {}

local function resume(thread: thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		table.insert(threadErrors, debug.traceback(thread, tostring(err)))
	end
end

local task = {}
function task.spawn(target: any, ...)
	local thread = if type(target) == "thread" then target else coroutine.create(target)
	resume(thread, ...)
	return thread
end
function task.defer(target: any, ...)
	local thread = if type(target) == "thread" then target else coroutine.create(target)
	table.insert(queue, { at = clock, thread = thread, args = table.pack(...) })
	return thread
end
function task.delay(seconds: number?, target: any, ...)
	local thread = if type(target) == "thread" then target else coroutine.create(target)
	table.insert(queue, { at = clock + (seconds or 0), thread = thread, args = table.pack(...) })
	return thread
end
function task.wait(seconds: number?): number
	local start = clock
	table.insert(queue, { at = clock + (seconds or 1 / 60), thread = coroutine.running(), args = table.pack() })
	coroutine.yield()
	return clock - start
end

-- Minimal RBXScriptSignal.
local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local handler = { fn = fn, connected = true }
	table.insert(self.handlers, handler)
	return {
		Connected = true,
		Disconnect = function()
			handler.connected = false
		end,
	}
end
function Signal:Once(fn)
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		fn(...)
	end)
	return connection
end
function Signal:Fire(...)
	for _, handler in table.clone(self.handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
	local waiting = self.waiting
	self.waiting = {}
	for _, thread in waiting do
		resume(thread, ...)
	end
end
function Signal:Wait()
	table.insert(self.waiting, coroutine.running())
	return coroutine.yield()
end

local heartbeat = Signal.new()

local function advance(seconds: number, dt: number?)
	local step = dt or 1 / 30
	local target = clock + seconds
	while clock < target - 1e-9 do
		clock += step
		heartbeat:Fire(step)
		while true do
			local bestIndex = nil
			for index, item in queue do
				if item.at <= clock and (bestIndex == nil or item.at < queue[bestIndex].at) then
					bestIndex = index
				end
			end
			if not bestIndex then
				break
			end
			local item = table.remove(queue, bestIndex)
			resume(item.thread, table.unpack(item.args, 1, item.args.n))
		end
	end
end

-- Engine pieces Lune does not implement -------------------------------------------------------

-- Lune may hand out a different userdata for the same Instance, so key signals by full name.
local instanceSignals = {}
local function signalFor(instance, name: string)
	local key = instance:GetFullName()
	instanceSignals[key] = instanceSignals[key] or {}
	local signals = instanceSignals[key]
	signals[name] = signals[name] or Signal.new()
	return signals[name]
end
roblox.implementProperty("ProximityPrompt", "Triggered", function(self)
	return signalFor(self, "Triggered")
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(self, amount: number)
	self.Health = math.max(0, self.Health - amount)
end)
for _, className in { "Model", "Folder", "Part", "Workspace" } do
	roblox.implementMethod(className, "WaitForChild", function(self, name: string)
		return self:FindFirstChild(name)
	end)
end
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)
roblox.implementMethod("DataStoreOptions", "SetExperimentalFeatures", function() end)

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")

local RaycastParams = {
	new = function()
		return { FilterType = nil, FilterDescendantsInstances = {} }
	end,
}

-- Fake remotes recording what the server sends.
local remoteLog: { { remote: string, target: any, args: { any } } } = {}
local function newRemote(name: string)
	local remote = { Name = name, OnServerEvent = Signal.new() }
	function remote:FireClient(player, ...)
		table.insert(remoteLog, { remote = name, target = player, args = table.pack(...) })
	end
	function remote:FireAllClients(...)
		table.insert(remoteLog, { remote = name, target = "all", args = table.pack(...) })
	end
	return remote
end
local remotes = {}
for _, name in {
	"RequestAttack",
	"RequestWave",
	"Interact",
	"UpgradeStaff",
	"EquipCharm",
	"RetryLoad",
	"RewardGranted",
	"Notice",
	"NpcSay",
	"OpenShop",
	"Fx",
} do
	remotes[name] = newRemote(name)
end

local proxyPaths = setmetatable({}, { __mode = "k" })
local function pathProxy(path: string)
	local name = string.match(path, "([^/]+)$")
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return name
			elseif key == "Parent" then
				return pathProxy(string.match(path, "^(.*)/[^/]+$"))
			end
			return pathProxy(path .. "/" .. key)
		end,
	})
	proxyPaths[proxy] = path
	return proxy
end

local Players = {
	PlayerAdded = Signal.new(),
	PlayerRemoving = Signal.new(),
	RespawnTime = 5,
	list = {},
}
function Players:GetPlayers()
	return table.clone(self.list)
end

local ReplicatedStorage = { Shared = pathProxy("RS/Shared"), Remotes = remotes }
local RunService = {
	Heartbeat = heartbeat,
	IsStudio = function()
		return true
	end,
}
local DataStoreService = {
	GetDataStore = function()
		return {
			SetAsync = function()
				error("HTTP 403 (Forbidden): Studio API access is disabled")
			end,
		}
	end,
}
local guid = 0
local services = {
	Players = Players,
	ReplicatedStorage = ReplicatedStorage,
	RunService = RunService,
	DataStoreService = DataStoreService,
	MessagingService = {},
	HttpService = {
		GenerateGUID = function()
			guid += 1
			return "GUID-" .. guid
		end,
	},
	Workspace = workspace,
}
local closeCallbacks = {}
local fakeGame = {
	JobId = "sim-job",
	PlaceId = 1,
	GetService = function(_, name: string)
		return services[name] or game:GetService(name)
	end,
	BindToClose = function(_, fn)
		table.insert(closeCallbacks, fn)
	end,
}

-- Module loader ---------------------------------------------------------------------------------

-- Lune stores Position and CFrame separately and cannot read Position of a part placed by CFrame,
-- so simple `a.b.Position` reads in our sources are routed through __pos for the simulation only.
local function rewritePositionReads(source: string): string
	return (string.gsub(source, "([%a_][%w_%.]*)%.Position(%s*)(=?)(=?)", function(object, space, first, second)
		if first == "=" and second ~= "=" then
			return nil
		end
		return "__pos(" .. object .. ")" .. space .. first .. second
	end))
end

local function positionOf(object: any)
	if typeof(object) == "Instance" then
		local ok, value = pcall(function()
			return object.Position
		end)
		if ok and value ~= nil then
			return value
		end
		return object.CFrame.Position
	end
	return object.Position
end

local simOs = setmetatable({
	clock = function()
		return clock
	end,
}, { __index = os })

local modules = {}
local loadModule

local function moduleFile(instancePath: string): string
	local shared = string.match(instancePath, "^RS/Shared/(.+)$")
	if shared then
		return "src/shared/" .. shared .. ".luau"
	end
	local server = string.match(instancePath, "^SSS/Server/(.+)$")
	if server then
		return "src/server/" .. server .. ".luau"
	end
	error("cannot require " .. instancePath)
end

local function scriptPathFor(file: string): string
	local shared = string.match(file, "^src/shared/(.+)%.luau$")
	if shared then
		return "RS/Shared/" .. shared
	end
	if file == "src/server/init.server.luau" then
		return "SSS/Server"
	end
	local server = string.match(file, "^src/server/(.+)%.luau$")
	return "SSS/Server/" .. server
end

-- fs.readFile yields when called from a coroutine in Lune, so read every source up front.
local sources: { [string]: string } = {}
local function preload(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			preload(path)
		elseif string.sub(name, -5) == ".luau" then
			sources[path] = fs.readFile(path)
		end
	end
end
preload("src")

local function run(file: string)
	local dir = string.match(file, "^(.*)/[^/]+$")
	local source = assert(sources[file], "unknown source " .. file)
	if not string.find(file, "Packages", 1, true) then
		source = rewritePositionReads(source)
	end
	local env = {
		game = fakeGame,
		workspace = workspace,
		script = pathProxy(scriptPathFor(file)),
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Enum = roblox.Enum,
		RaycastParams = RaycastParams,
		Random = {
			new = function(seed: number)
				local state = seed
				return {
					NextNumber = function(_, min: number, max: number)
						state = (state * 1103515245 + 12345) % 2147483648
						return min + (max - min) * state / 2147483648
					end,
				}
			end,
		},
		task = task,
		os = simOs,
		__pos = positionOf,
		warn = function(...)
			table.insert(warnings, table.concat({ ... }, " "))
		end,
		print = function() end,
		require = function(target)
			local path = proxyPaths[target]
			if path then
				return loadModule(moduleFile(path))
			end
			local resolved = dir
			for segment in string.gmatch(target, "[^/]+") do
				if segment == ".." then
					resolved = string.match(resolved, "^(.*)/[^/]+$")
				elseif segment ~= "." then
					resolved ..= "/" .. segment
				end
			end
			return loadModule(resolved .. ".luau")
		end,
	}
	return luau.load(source, { debugName = file, environment = env })()
end

function loadModule(file: string)
	if modules[file] == nil then
		modules[file] = run(file)
	end
	return modules[file]
end

-- Test helpers ----------------------------------------------------------------------------------

local passed, failed = 0, 0
local function test(name: string, fn: () -> ())
	local before = #threadErrors
	local ok, err = pcall(fn)
	if ok and #threadErrors > before then
		ok, err = false, "server thread error:\n" .. threadErrors[before + 1]
	end
	if ok then
		passed += 1
	else
		failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

local function eq(actual, expected, message: string?)
	if actual ~= expected then
		error(`{message or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

local WorldData = loadModule("src/shared/WorldData.luau")
local Balance = loadModule("src/shared/Balance.luau")

local function vec(p: { number }, lift: number?): any
	return Vector3.new(p[1], p[2] + (lift or 0), p[3])
end

local function newPlayer(name: string, userId: number)
	local attributes = {}
	local player = {
		Name = name,
		UserId = userId,
		Parent = Players,
		Character = nil,
		CharacterAdded = Signal.new(),
		attributes = attributes,
	}
	function player:SetAttribute(key: string, value: any)
		attributes[key] = value
	end
	function player:GetAttribute(key: string)
		return attributes[key]
	end
	function player:Kick(message: string)
		self.kicked = message
	end
	return player
end

local function join(player)
	table.insert(Players.list, player)
	Players.PlayerAdded:Fire(player)
end

local function leave(player)
	local index = table.find(Players.list, player)
	if index then
		table.remove(Players.list, index)
	end
	player.Parent = nil
	Players.PlayerRemoving:Fire(player)
end

local function spawnCharacter(player, position: any)
	local character = Instance.new("Model")
	character.Name = player.Name
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = roblox.Enum.HumanoidRigType.R15
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.Parent = character
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.CFrame = CFrame.new(position + Vector3.new(1.5, -1, 0))
	hand.Parent = character
	character.Parent = workspace
	player.Character = character
	player.CharacterAdded:Fire(character)
	return character
end

local function root(player)
	return player.Character.HumanoidRootPart
end

local function humanoid(player)
	return player.Character.Humanoid
end

local function teleport(player, position: any)
	root(player).Position = position
end

local function heal(player)
	local h = humanoid(player)
	h.Health = h.MaxHealth
end

local function logCount(remote: string, predicate: ((any) -> boolean)?): number
	local count = 0
	for _, entry in remoteLog do
		if entry.remote == remote and (predicate == nil or predicate(entry)) then
			count += 1
		end
	end
	return count
end

-- Destroyed Instances raise on access in Lune (unlike Roblox), so check liveness defensively.
local function isAlive(model): boolean
	local ok, alive = pcall(function()
		return model.Parent ~= nil and model:GetAttribute("Alive") == true
	end)
	return ok and alive
end

local function enemiesOf(kind: string): { any }
	local list = {}
	for _, model in workspace.Enemies:GetChildren() do
		if model:GetAttribute("EnemyType") == kind and model:GetAttribute("Alive") then
			table.insert(list, model)
		end
	end
	return list
end

local function nearestEnemy(kind: string, from: any)
	local best, bestDistance = nil, math.huge
	for _, model in enemiesOf(kind) do
		local distance = (positionOf(model.Body) - from).Magnitude
		if distance < bestDistance then
			best, bestDistance = model, distance
		end
	end
	return best
end

local function talk(player, npc: string)
	local body = workspace.LanternValleyMap.Village[npc].Body
	teleport(player, positionOf(body) + Vector3.new(0, 1.5, 4))
	body.TalkPrompt.Triggered:Fire(player)
	advance(0.1)
end

-- Fights one enemy of a kind next to it until it is purified; keeps the player healed.
local function purifyOne(player, kind: string, maxSeconds: number?): boolean
	local model = nearestEnemy(kind, root(player).Position)
	assert(model, "no living " .. kind)
	local id = model:GetAttribute("EnemyId")
	local elapsed = 0
	while isAlive(model) and elapsed < (maxSeconds or 30) do
		teleport(player, positionOf(model.Body) + Vector3.new(0, 1, 9))
		remotes.RequestAttack.OnServerEvent:Fire(player, id)
		advance(0.6)
		heal(player)
		elapsed += 0.6
	end
	return not isAlive(model)
end

local function attr(player, name: string)
	return player:GetAttribute(name)
end

-- Scenario --------------------------------------------------------------------------------------

test("server boots", function()
	local boot = task.spawn(run, "src/server/init.server.luau")
	advance(0.5)
	if coroutine.status(boot) ~= "dead" then
		error("boot thread still " .. coroutine.status(boot) .. ":\n" .. debug.traceback(boot))
	end
	if #threadErrors > 0 then
		error(threadErrors[1])
	end
	assert(workspace:FindFirstChild("LanternValleyMap"), "map built")
	eq(#workspace.Enemies:GetChildren(), #WorldData.spawns, "all enemies spawned")
end)

local alice = newPlayer("Alice", 101)
local bob = newPlayer("Bob", 102)

test("players load profiles (ProfileStore mock) and get staffs", function()
	join(alice)
	join(bob)
	advance(2)
	for _, player in { alice, bob } do
		eq(attr(player, "DataState"), "ready", player.Name .. " data")
		eq(attr(player, "Level"), 1)
		eq(attr(player, "QuestState"), "available")
		eq(attr(player, "QuestId"), "first_purify")
	end
	spawnCharacter(alice, vec(WorldData.spawn, 3))
	spawnCharacter(bob, vec(WorldData.spawn, 3))
	advance(0.5)
	assert(alice.Character:FindFirstChild("LightStaff"), "staff attached")
	eq(humanoid(alice).MaxHealth, 100)
	eq(humanoid(alice).BreakJointsOnDeath, false, "kid-friendly defeat")
end)

test("purifying before accepting the quest pays the enemy reward only", function()
	assert(purifyOne(bob, "Gloomling"), "bob purified")
	eq(attr(bob, "XP"), Balance.enemies.Gloomling.reward.xp)
	eq(attr(bob, "QuestState"), "available", "quest not started")
end)

test("first quest: accept at the Elder, purify three, reward once", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestState"), "active")
	eq(attr(alice, "QuestGoal"), 3)
	for index = 1, 3 do
		assert(purifyOne(alice, "Gloomling"), "purify " .. index)
	end
	advance(0.2)
	local enemyReward = Balance.enemies.Gloomling.reward
	eq(attr(alice, "XP"), enemyReward.xp * 3 + 50, "xp")
	eq(attr(alice, "Coins"), enemyReward.coins * 3 + 20, "coins")
	eq(attr(alice, "QuestId"), "lantern_flowers", "next quest")
	eq(attr(alice, "QuestState"), "available")
	eq(attr(alice, "Level"), 2, "level up")
	eq(logCount("Fx", function(e)
		return e.args[1] == "levelUp" and e.args[2] == alice
	end), 1, "level-up broadcast")
end)

local function toVillage(player)
	teleport(player, vec(WorldData.spawn, 3))
	heal(player)
end

test("purified enemies respawn", function()
	toVillage(alice)
	toVillage(bob)
	advance(16)
	eq(#workspace.Enemies:GetChildren(), #WorldData.spawns, "respawned")
end)

test("invalid client payloads are ignored safely", function()
	local xp, coins = attr(alice, "XP"), attr(alice, "Coins")
	for _, payload in { "x", 0 / 0, math.huge, -1, 1e308, 2.5, {}, true } do
		remotes.RequestAttack.OnServerEvent:Fire(alice, payload)
		advance(0.6)
	end
	for _, args in { { {}, nil }, { "flower", string.rep("a", 500) }, { "flower", "flower_1" }, { 42, 42 } } do
		remotes.Interact.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.3)
	end
	remotes.EquipCharm.OnServerEvent:Fire(alice, 123)
	remotes.EquipCharm.OnServerEvent:Fire(alice, "glow")
	remotes.UpgradeStaff.OnServerEvent:Fire(alice)
	remotes.RequestWave.OnServerEvent:Fire(alice)
	remotes.RetryLoad.OnServerEvent:Fire(alice)
	advance(1)
	eq(attr(alice, "XP"), xp, "xp unchanged")
	eq(attr(alice, "Coins"), coins, "coins unchanged")
	eq(attr(alice, "StaffTier"), 0, "no upgrade from afar")
	eq(attr(alice, "Charm"), "", "cannot equip unowned charm")
	eq(attr(alice, "DataState"), "ready")
end)

test("attacks from beyond staff range are rejected", function()
	local target = nearestEnemy("Gloomling", vec(WorldData.areas.glade.center))
	local body = positionOf(target.Body)
	local hp = target:GetAttribute("Hp")
	heal(alice)
	teleport(alice, body + Vector3.new(0, 1, Balance.staff.range + 20))
	remotes.RequestAttack.OnServerEvent:Fire(alice, target:GetAttribute("EnemyId"))
	advance(0.6)
	eq(target:GetAttribute("Hp"), hp, "no damage from afar")
	toVillage(alice)
	advance(0.6)
end)

test("co-op: both hitters get their own reward, exactly once", function()
	local target = nearestEnemy("Gloomling", vec(WorldData.areas.glade.center))
	local id = target:GetAttribute("EnemyId")
	local body = positionOf(target.Body)
	local aliceXp, bobXp = attr(alice, "XP"), attr(bob, "XP")
	heal(alice)
	heal(bob)
	teleport(alice, body + Vector3.new(0, 1, 8))
	teleport(bob, body + Vector3.new(0, 1, -8))
	remotes.RequestAttack.OnServerEvent:Fire(alice, id)
	advance(0.6)
	remotes.RequestAttack.OnServerEvent:Fire(bob, id)
	advance(0.6)
	heal(alice)
	heal(bob)
	eq(isAlive(target), false, "purified by two hits")
	local reward = Balance.enemies.Gloomling.reward.xp
	eq(attr(alice, "XP"), aliceXp + reward, "alice")
	eq(attr(bob, "XP"), bobXp + reward, "bob")
end)

test("quest 2: personal flowers, duplicates and far requests ignored, charm + flag", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestId"), "lantern_flowers")
	eq(attr(alice, "QuestState"), "active")
	remotes.Interact.OnServerEvent:Fire(alice, "flower", "flower_1")
	advance(0.3)
	eq(attr(alice, "QuestCount"), 0, "too far")
	for id, position in WorldData.flowers do
		teleport(alice, vec(position, 3) + Vector3.new(2, 0, 0))
		remotes.Interact.OnServerEvent:Fire(alice, "flower", id)
		advance(0.3)
		remotes.Interact.OnServerEvent:Fire(alice, "flower", id)
		advance(0.3)
		heal(alice)
	end
	eq(attr(alice, "QuestId"), "forest_explore", "completed")
	eq(attr(alice, "Charms"), "swift")
	eq(attr(alice, "Charm"), "swift", "auto-equipped")
	eq(attr(alice, "Flags"), "gardens")
	advance(0.1)
	eq(humanoid(alice).WalkSpeed, Balance.player.walkSpeed * Balance.charms.swift.walkSpeedMultiplier, "swift speed")
end)

test("quest 3: exploration by visiting landmarks", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestId"), "forest_explore")
	for _, landmark in WorldData.landmarks do
		teleport(alice, vec(landmark.position, 3) + Vector3.new(4, 0, 0))
		advance(1)
		heal(alice)
	end
	eq(attr(alice, "QuestId"), "first_upgrade", "completed")
end)

test("quest 4: upgrade at Usta Demir once; throttled and priced correctly", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestId"), "first_upgrade")
	local coins = attr(alice, "Coins")
	assert(coins >= Balance.staff.tiers[2].cost, "enough coins without grinding: " .. coins)
	talk(alice, "Demir")
	eq(logCount("OpenShop", function(e)
		return e.target == alice
	end), 1, "shop opened")
	remotes.UpgradeStaff.OnServerEvent:Fire(alice)
	remotes.UpgradeStaff.OnServerEvent:Fire(alice)
	advance(0.2)
	eq(attr(alice, "StaffTier"), 1, "single upgrade")
	eq(attr(alice, "Coins"), coins - Balance.staff.tiers[2].cost, "charged once")
	eq(attr(alice, "QuestId"), "ruin_vines", "quest completed")
	eq(attr(alice, "Charms"), "guard,swift")
	eq(attr(alice, "Flags"), "gardens,lanterns")
	assert(attr(alice, "Level") >= 3, "wave unlocked by now")
end)

test("quest 5: light wave clears the vines; wave cooldown enforced", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestState"), "active")
	teleport(alice, vec(WorldData.areas.gate.center, 3))
	remotes.RequestWave.OnServerEvent:Fire(alice)
	advance(0.1)
	eq(attr(alice, "QuestId"), "warden", "vines cleared")
	eq(attr(alice, "Charms"), "glow,guard,swift")
	local waves = logCount("Fx", function(e)
		return e.args[1] == "wave"
	end)
	remotes.RequestWave.OnServerEvent:Fire(alice)
	advance(0.1)
	eq(logCount("Fx", function(e)
		return e.args[1] == "wave"
	end), waves, "cooldown blocks a second wave")
end)

test("charms can be switched and unequipped", function()
	remotes.EquipCharm.OnServerEvent:Fire(alice, "guard")
	advance(0.5)
	eq(attr(alice, "Charm"), "guard")
	remotes.EquipCharm.OnServerEvent:Fire(alice, "")
	advance(0.5)
	eq(attr(alice, "Charm"), "")
	remotes.EquipCharm.OnServerEvent:Fire(alice, "glow")
	advance(0.5)
	eq(attr(alice, "Charm"), "glow")
end)

test("quest 6: boss fight with telegraphed attacks, rewards, festival", function()
	local state = attr(alice, "QuestState")
	assert(state == "level" or state == "available", "boss quest waiting: " .. tostring(state))
	while attr(alice, "Level") < 5 do
		assert(purifyOne(alice, "Gloomling"), "grind")
		advance(0.1)
	end
	talk(alice, "Elder")
	eq(attr(alice, "QuestState"), "active")
	local boss = enemiesOf("Warden")[1]
	assert(boss, "boss alive")
	local id = boss:GetAttribute("EnemyId")
	local arena = vec(WorldData.areas.arena.center, 3)
	teleport(alice, arena + Vector3.new(0, 0, 16))
	local elapsed = 0
	while isAlive(boss) and elapsed < 240 do
		local bossPosition = positionOf(boss.Body)
		teleport(alice, Vector3.new(bossPosition.X, 3, bossPosition.Z + 12))
		remotes.RequestAttack.OnServerEvent:Fire(alice, id)
		remotes.RequestWave.OnServerEvent:Fire(alice)
		advance(0.6)
		heal(alice)
		elapsed += 0.6
	end
	assert(not isAlive(boss), "boss purified")
	advance(0.3)
	for _, kind in { "telegraph", "slam", "projectile", "windup" } do
		assert(logCount("Fx", function(e)
			return e.args[1] == kind
		end) > 0, "boss used " .. kind)
	end
	eq(attr(alice, "QuestState"), "done")
	eq(attr(alice, "Flags"), "festival,gardens,lanterns")
end)

test("other enemy behaviors run (shooter, charger) and hurt players", function()
	teleport(bob, vec(WorldData.areas.grove.center, 3))
	local hurt = false
	for _ = 1, 150 do
		advance(0.1)
		if humanoid(bob).Health < humanoid(bob).MaxHealth then
			hurt = true
		end
		heal(bob)
	end
	teleport(bob, vec(WorldData.areas.hollow.center, 3))
	for _ = 1, 150 do
		advance(0.1)
		heal(bob)
	end
	assert(hurt, "sporelings hit bob")
	assert(logCount("Fx", function(e)
		return e.args[1] == "projectile" and e.args[7] == "spore"
	end) > 0, "spores fired")
end)

test("leaving and rejoining restores the saved profile", function()
	local snapshot = {}
	for _, key in { "XP", "Coins", "StaffTier", "Charms", "Charm", "Flags", "QuestState" } do
		snapshot[key] = attr(alice, key)
	end
	leave(alice)
	advance(2)
	local again = newPlayer("Alice", 101)
	join(again)
	advance(3)
	eq(attr(again, "DataState"), "ready", "reloaded")
	for key, value in snapshot do
		eq(attr(again, key), value, key)
	end
	alice = again
end)

test("rapid reconnect waits for the old session and keeps data", function()
	local xp = attr(alice, "XP")
	leave(alice)
	local again = newPlayer("Alice", 101)
	join(again)
	advance(20)
	eq(attr(again, "DataState"), "ready", "reloaded after session release")
	eq(attr(again, "XP"), xp, "xp kept")
end)

test("a player leaving during load does not break anything", function()
	local carol = newPlayer("Carol", 103)
	join(carol)
	leave(carol)
	advance(3)
	eq(attr(carol, "DataState") ~= "ready", true, "no session for a player who left")
end)

test("no warnings from ProfileStore and no server thread errors", function()
	for _, message in warnings do
		print("warn: " .. message)
	end
	eq(#threadErrors, 0, "thread errors")
end)

print(`sim tests: {passed} passed, {failed} failed`)
if failed > 0 then
	error("sim tests failed")
end
