-- Shared simulation harness for tests/sim (server) and tests/client (client).
-- Provides a simulated clock + task scheduler, signals, fake remotes, instance-path proxies for
-- requires, and a module loader that runs our real sources against Lune's Roblox Instances.
-- Engine features Lune lacks are stubbed here; see each test file for what that means for coverage.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}

-- Scheduler -------------------------------------------------------------------------------------

local clock = 0
local queue: { { at: number, thread: thread, args: { any } } } = {}
Harness.threadErrors = {} :: { string }
Harness.warnings = {} :: { string }

local function resume(thread: thread, ...)
	local ok, err = coroutine.resume(thread, ...)
	if not ok then
		table.insert(Harness.threadErrors, debug.traceback(thread, tostring(err)))
	end
end
Harness.resume = resume

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
Harness.task = task

function Harness.now(): number
	return clock
end

-- Signals ---------------------------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {}, waiting = {} }, Signal)
end
function Signal:Connect(fn)
	local handler = { fn = fn, connected = true }
	table.insert(self.handlers, handler)
	local connection = { Connected = true }
	function connection.Disconnect()
		handler.connected = false
		connection.Connected = false
	end
	return connection
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
Harness.Signal = Signal

Harness.heartbeat = Signal.new()
Harness.renderStepped = Signal.new()

function Harness.advance(seconds: number, dt: number?)
	local step = dt or 1 / 30
	local target = clock + seconds
	while clock < target - 1e-9 do
		clock += step
		Harness.renderStepped:Fire(step)
		Harness.heartbeat:Fire(step)
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

-- Engine pieces Lune does not implement ---------------------------------------------------------

-- Lune can hand out different userdata for one Instance, so identify instances by an attribute.
local nextSimId = 0
local function simId(instance): string
	local id = instance:GetAttribute("__simId")
	if id == nil then
		nextSimId += 1
		id = "sim" .. nextSimId
		instance:SetAttribute("__simId", id)
	end
	return id
end

local instanceSignals = {}
function Harness.signalFor(instance, name: string)
	local key = simId(instance) .. "\0" .. name
	instanceSignals[key] = instanceSignals[key] or Signal.new()
	return instanceSignals[key]
end

for _, eventName in {
	"Triggered",
	"Activated",
	"MouseButton1Down",
	"MouseButton1Up",
	"MouseLeave",
	"Destroying",
	"ChildAdded",
	"ChildRemoved",
} do
	roblox.implementProperty("Instance", eventName, function(self)
		return Harness.signalFor(self, eventName)
	end)
end
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, name: string)
	return Harness.signalFor(self, "attr:" .. name)
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, name: string)
	return Harness.signalFor(self, "prop:" .. name)
end)
roblox.implementMethod("Instance", "WaitForChild", function(self, name: string)
	return self:FindFirstChild(name)
end)
roblox.implementMethod("Humanoid", "TakeDamage", function(self, amount: number)
	self.Health = math.max(0, self.Health - amount)
end)
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)
roblox.implementMethod("Workspace", "GetServerTimeNow", function()
	return Harness.EPOCH + Harness.now()
end)
roblox.implementMethod("DataStoreOptions", "SetExperimentalFeatures", function() end)
roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
roblox.implementMethod("ParticleEmitter", "Emit", function() end)
roblox.implementMethod("StarterGui", "SetCoreGuiEnabled", function() end)
-- Tests may set Harness.guiAtPosition to simulate what sits under the pointer.
Harness.guiAtPosition = {}
roblox.implementMethod("PlayerGui", "GetGuiObjectsAtPosition", function()
	return Harness.guiAtPosition
end)
roblox.implementMethod("Camera", "ViewportPointToRay", function(self, x: number, y: number)
	return roblox.Ray.new(self.CFrame.Position, roblox.Vector3.new(0, 0, -1))
end)

-- Sets an attribute and fires its change signal, like the engine would.
function Harness.setAttribute(instance, name: string, value: any)
	instance:SetAttribute(name, value)
	Harness.signalFor(instance, "attr:" .. name):Fire()
end

function Harness.addChild(parent, child)
	child.Parent = parent
	Harness.signalFor(parent, "ChildAdded"):Fire(child)
end

function Harness.destroy(instance)
	Harness.signalFor(instance, "Destroying"):Fire()
	instance:Destroy()
end

Harness.game = roblox.Instance.new("DataModel")
Harness.workspace = Harness.game:GetService("Workspace")

-- Remotes ---------------------------------------------------------------------------------------

Harness.remoteLog = {} :: { { remote: string, direction: string, target: any, args: { any } } }

local remoteNames = {
	"EquipWeapon",
	"ChestAction",
	"PickSkill",
	"ClaimAchievement",
	"RequestWave",
	"Interact",
	"BuyUpgrade",
	"EquipCharm",
	"RetryLoad",
	"RewardGranted",
	"Notice",
	"NpcSay",
	"OpenShop",
	"Fx",
}
local remotes = {}
for _, name in remoteNames do
	local remote = { Name = name, OnServerEvent = Signal.new(), OnClientEvent = Signal.new() }
	function remote:FireClient(player, ...)
		table.insert(Harness.remoteLog, { remote = name, direction = "toClient", target = player, args = table.pack(...) })
	end
	function remote:FireAllClients(...)
		table.insert(Harness.remoteLog, { remote = name, direction = "toClient", target = "all", args = table.pack(...) })
	end
	function remote:FireServer(...)
		table.insert(Harness.remoteLog, { remote = name, direction = "toServer", target = "server", args = table.pack(...) })
	end
	remotes[name] = remote
end
function remotes:WaitForChild(name: string)
	return self[name]
end
remotes.FindFirstChild = remotes.WaitForChild
Harness.remotes = remotes

function Harness.logCount(remote: string, predicate: ((any) -> boolean)?): number
	local count = 0
	for _, entry in Harness.remoteLog do
		if entry.remote == remote and (predicate == nil or predicate(entry)) then
			count += 1
		end
	end
	return count
end

-- Instance-path proxies used for `require(...)` of our ModuleScripts ------------------------------

local proxyPaths = setmetatable({}, { __mode = "k" })
local function pathProxy(path: string)
	local name = string.match(path, "([^/]+)$")
	local proxy = setmetatable({}, {
		__index = function(_, key)
			if key == "Name" then
				return name
			elseif key == "Parent" then
				return pathProxy(string.match(path, "^(.*)/[^/]+$"))
			elseif key == "WaitForChild" or key == "FindFirstChild" then
				return function(_, child: string)
					return pathProxy(path .. "/" .. child)
				end
			end
			return pathProxy(path .. "/" .. key)
		end,
	})
	proxyPaths[proxy] = path
	return proxy
end
Harness.pathProxy = pathProxy

local ReplicatedStorage = { Shared = pathProxy("RS/Shared"), Remotes = remotes }
function ReplicatedStorage:WaitForChild(name: string)
	return self[name]
end
ReplicatedStorage.FindFirstChild = ReplicatedStorage.WaitForChild
Harness.ReplicatedStorage = ReplicatedStorage

-- Services a test may replace or extend before loading code.
Harness.services = {
	ReplicatedStorage = ReplicatedStorage,
	Workspace = Harness.workspace,
}

Harness.fakeGame = {
	JobId = "sim-job",
	PlaceId = 1,
	GetService = function(_, name: string)
		return Harness.services[name] or Harness.game:GetService(name)
	end,
	BindToClose = function() end,
}

-- Loader ----------------------------------------------------------------------------------------

local sources: { [string]: string } = {}
local function preload(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			preload(path)
		elseif string.sub(name, -5) == ".luau" then
			sources[path] = fs.readFile(path) -- fs.readFile yields inside coroutines, so read up front
		end
	end
end
preload("src")

-- Lune cannot read computed properties (Position of a part placed by CFrame, AbsolutePosition,
-- ViewportSize...). Reads of those in our sources are routed through __read for the simulation.
local COMPUTED = { "Position", "AbsolutePosition", "AbsoluteSize", "ViewportSize" }
local function rewriteComputedReads(source: string): string
	for _, property in COMPUTED do
		source = string.gsub(source, "([%a_][%w_%.]*)%." .. property .. "(%s*)(=?)(=?)", function(object, space, first, second)
			if first == "=" and second ~= "=" then
				return nil
			end
			return `__read({object}, "{property}")` .. space .. first .. second
		end)
		-- A parenthesised expression like `(x :: BasePart).Position`, but not a call result `f(...).Position`.
		source = string.gsub(source, "([^%w_%]%)])(%b())%." .. property .. "(%s*)(=?)(=?)", function(before, object, space, first, second)
			if first == "=" and second ~= "=" then
				return nil
			end
			return before .. `__read({object}, "{property}")` .. space .. first .. second
		end)
	end
	return source
end

Harness.defaults = {
	ViewportSize = roblox.Vector2.new(1000, 560),
	AbsoluteSize = roblox.Vector2.new(1000, 560),
	AbsolutePosition = roblox.Vector2.new(0, 0),
}

function Harness.read(object: any, property: string): any
	if typeof(object) == "Instance" then
		local ok, value = pcall(function()
			return object[property]
		end)
		if ok and value ~= nil then
			return value
		end
		if property == "Position" then
			return object.CFrame.Position
		end
		return Harness.defaults[property]
	end
	return object[property]
end

-- Simulated wall clock: os.time() and GetServerTimeNow() advance with the simulated clock.
Harness.EPOCH = 1700000000
local simOs = setmetatable({
	clock = function()
		return clock
	end,
	time = function()
		return Harness.EPOCH + math.floor(clock)
	end,
}, { __index = os })

local modules = {}
local loadModule

-- Maps an instance path (from script/ReplicatedStorage proxies) to a source file.
local function moduleFile(instancePath: string): string
	local shared = string.match(instancePath, "^RS/Shared/(.+)$")
	if shared then
		return "src/shared/" .. shared .. ".luau"
	end
	local server = string.match(instancePath, "^SSS/Server/(.+)$")
	if server then
		return "src/server/" .. server .. ".luau"
	end
	local client = string.match(instancePath, "^SPS/Client/(.+)$")
	if client then
		return "src/client/" .. client .. ".luau"
	end
	error("cannot require " .. instancePath)
end

local function scriptPathFor(file: string): string
	if file == "src/server/init.server.luau" then
		return "SSS/Server"
	elseif file == "src/client/init.client.luau" then
		return "SPS/Client"
	end
	local shared = string.match(file, "^src/shared/(.+)%.luau$")
	if shared then
		return "RS/Shared/" .. shared
	end
	local server = string.match(file, "^src/server/(.+)%.luau$")
	if server then
		return "SSS/Server/" .. server
	end
	return "SPS/Client/" .. string.match(file, "^src/client/(.+)%.luau$")
end

local Random = {
	-- Like Roblox: the seed is optional and NextNumber() without bounds returns [0, 1).
	new = function(seed: number?)
		local state = seed or 1
		return {
			NextNumber = function(_, min: number?, max: number?)
				state = (state * 1103515245 + 12345) % 2147483648
				local low, high = min or 0, max or 1
				return low + (high - low) * state / 2147483648
			end,
			NextInteger = function(_, min: number, max: number)
				state = (state * 1103515245 + 12345) % 2147483648
				return min + math.floor((max - min + 1) * state / 2147483648)
			end,
		}
	end,
}

function Harness.run(file: string)
	local dir = string.match(file, "^(.*)/[^/]+$")
	local source = assert(sources[file], "unknown source " .. file)
	if not string.find(file, "Packages", 1, true) then
		source = rewriteComputedReads(source)
	end
	local env = {
		game = Harness.fakeGame,
		workspace = Harness.workspace,
		script = pathProxy(scriptPathFor(file)),
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Ray = roblox.Ray,
		TweenInfo = { new = function(...)
			return table.pack(...)
		end },
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		Enum = roblox.Enum,
		RaycastParams = { new = function()
			return { FilterType = nil, FilterDescendantsInstances = {} }
		end },
		Random = Random,
		task = task,
		os = simOs,
		__read = Harness.read,
		warn = function(...)
			table.insert(Harness.warnings, table.concat({ ... }, " "))
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
		modules[file] = Harness.run(file)
	end
	return modules[file]
end
Harness.loadModule = loadModule

-- Test helpers ----------------------------------------------------------------------------------

Harness.passed, Harness.failed = 0, 0

function Harness.test(name: string, fn: () -> ())
	local before = #Harness.threadErrors
	local ok, err = pcall(fn)
	if ok and #Harness.threadErrors > before then
		ok, err = false, "thread error:\n" .. Harness.threadErrors[before + 1]
	end
	if ok then
		Harness.passed += 1
	else
		Harness.failed += 1
		print("FAIL " .. name .. ": " .. tostring(err))
	end
end

function Harness.eq(actual, expected, message: string?)
	if actual ~= expected then
		error(`{message or "value"}: expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

function Harness.finish(label: string)
	print(`{label}: {Harness.passed} passed, {Harness.failed} failed`)
	if Harness.failed > 0 then
		error(label .. " failed")
	end
end

-- Fake player with attributes and attribute-changed signals.
function Harness.newPlayer(name: string, userId: number, playersService: any)
	local attributes = {}
	local signals = {}
	local player = {
		Name = name,
		UserId = userId,
		Parent = playersService,
		Character = nil,
		CharacterAdded = Signal.new(),
		attributes = attributes,
	}
	function player:SetAttribute(key: string, value: any)
		local changed = attributes[key] ~= value
		attributes[key] = value
		if changed and signals[key] then
			signals[key]:Fire()
		end
	end
	function player:GetAttribute(key: string)
		return attributes[key]
	end
	function player:GetAttributeChangedSignal(key: string)
		signals[key] = signals[key] or Signal.new()
		return signals[key]
	end
	function player:Kick(message: string)
		self.kicked = message
	end
	function player:GetNetworkPing()
		return 0.05
	end
	return player
end

return Harness
