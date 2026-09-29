-- Run: lune run tests/playtime   (a balance tool, not part of tests/all)
-- A simple bot plays the whole quest chain on the real server code at walking speed:
-- it walks straight lines (no obstacles), fights what is in range, steps out of boss warning
-- circles, and respawns in the village when defeated. It prints time per quest, deaths, level
-- and coins. Real players take longer (reading, looking around, detours), so treat the totals
-- as a lower bound when tuning towards the plan's 45-60 minute target.
local roblox = require("@lune/roblox")
local H = require("./harness")

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local workspace = H.workspace
local remotes = H.remotes

local Players = { PlayerAdded = H.Signal.new(), PlayerRemoving = H.Signal.new(), RespawnTime = 5, list = {} }
function Players:GetPlayers()
	return table.clone(self.list)
end
function Players:GetPlayerByUserId(userId: number)
	for _, player in self.list do
		if player.UserId == userId then
			return player
		end
	end
	return nil
end
local guid = 0
H.services.Players = Players
H.services.RunService = {
	Heartbeat = H.heartbeat,
	IsStudio = function()
		return true
	end,
}
H.services.DataStoreService = {
	GetDataStore = function()
		return {
			SetAsync = function()
				error("HTTP 403 (Forbidden)")
			end,
		}
	end,
}
H.services.MessagingService = {}
-- ProcessReceipt is set by StoreService; tests call it directly with fake receipts.
H.services.MarketplaceService = {}
H.services.HttpService = {
	GenerateGUID = function()
		guid += 1
		return "G" .. guid
	end,
}

local WorldData = H.loadModule("src/shared/WorldData.luau")
local Balance = H.loadModule("src/shared/Balance.luau")
local Progression = H.loadModule("src/shared/Progression.luau")
local WeaponData = H.loadModule("src/shared/WeaponData.luau")
-- The bot keeps the starter staff; attacks are automatic, so it only walks and casts the wave.
local RANGE = WeaponData.weapons.staff.range
local QuestData = H.loadModule("src/shared/QuestData.luau")

local STEP = 1 / 15

local function vec(p: { number }, lift: number?): any
	return Vector3.new(p[1], p[2] + (lift or 0), p[3])
end
local function positionOf(object)
	return H.read(object, "Position")
end
local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

H.task.spawn(H.run, "src/server/init.server.luau")
H.advance(0.5)

local bot = H.newPlayer("Bot", 7, Players)
table.insert(Players.list, bot)
Players.PlayerAdded:Fire(bot)
H.advance(2)

local function spawnCharacter()
	local character = Instance.new("Model")
	character.Name = "Bot"
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = roblox.Enum.HumanoidRigType.R15
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = vec(WorldData.spawn, 3)
	root.Parent = character
	local hand = Instance.new("Part")
	hand.Name = "RightHand"
	hand.CFrame = CFrame.new(vec(WorldData.spawn, 2))
	hand.Parent = character
	character.Parent = workspace
	bot.Character = character
	bot.CharacterAdded:Fire(character)
	H.advance(0.2)
end
spawnCharacter()

local stats = { deaths = 0 }
local lastWave = -math.huge
local seenLog = #H.remoteLog
local dodgeUntil, dodgeTarget = 0, nil

local function root()
	return bot.Character.HumanoidRootPart
end
local function attr(name)
	return bot:GetAttribute(name)
end

local function aliveEnemies()
	local list = {}
	for _, model in workspace.Enemies:GetChildren() do
		local ok, alive = pcall(function()
			return model:GetAttribute("Alive") == true
		end)
		if ok and alive then
			table.insert(list, model)
		end
	end
	return list
end

local function nearestEnemy(from, maxDistance: number?, kind: string?)
	local best, bestDistance = nil, maxDistance or math.huge
	for _, model in aliveEnemies() do
		if not kind or model:GetAttribute("EnemyType") == kind then
			local distance = (positionOf(model.Body) - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = model, distance
			end
		end
	end
	return best, bestDistance
end

-- One bot tick: respawn if defeated, react to warnings, attack what is in reach.
local function tick()
	local humanoid = bot.Character.Humanoid
	if humanoid.Health <= 0 then
		stats.deaths += 1
		H.advance(Balance.player.respawnTime)
		humanoid.Health = humanoid.MaxHealth
		root().Position = vec(WorldData.spawn, 3)
	end
	for index = seenLog + 1, #H.remoteLog do
		local entry = H.remoteLog[index]
		if entry.remote == "Fx" and entry.args[1] == "telegraph" then
			local point, radius = entry.args[2], entry.args[3]
			local offset = flat(root().Position - point)
			if offset.Magnitude <= radius + 2 then
				local away = if offset.Magnitude > 0.1 then offset.Unit else Vector3.new(1, 0, 0)
				dodgeTarget = point + away * (radius + 5) + Vector3.new(0, 3, 0)
				dodgeUntil = H.now() + entry.args[4]
			end
		end
	end
	seenLog = #H.remoteLog

	local now = H.now()
	local position = root().Position
	local level = Progression.levelForXp(attr("XP") or 0)
	local charm = attr("Charm")
	local wave = Progression.waveStats(attr("StaffTier") or 0, level, if charm ~= "" then charm else nil)
	if Progression.waveUnlocked(level) and now - lastWave >= wave.cooldown and nearestEnemy(position, wave.radius) then
		lastWave = now
		remotes.RequestWave.OnServerEvent:Fire(bot)
	end
	H.advance(STEP)
end

local function speed(): number
	local charm = attr("Charm")
	return Progression.walkSpeed(if charm ~= "" then charm else nil)
end

-- Walks toward a point; stops to fight enemies that are in reach.
local function walkTo(goal, arrive: number)
	local guard = 0
	while guard < 20000 do
		guard += 1
		local position = root().Position
		local destination = goal
		if H.now() < dodgeUntil and dodgeTarget then
			destination = dodgeTarget
		elseif nearestEnemy(position, RANGE * 0.8) then
			destination = nil -- stand and fight
		end
		if destination == goal and flat(goal - position).Magnitude <= arrive then
			return
		end
		if destination then
			local offset = flat(destination - position)
			if offset.Magnitude > 0.1 then
				root().Position = position + offset.Unit * math.min(speed() * STEP, offset.Magnitude)
			end
		end
		tick()
	end
	error("walk did not finish")
end

-- Fights near a zone until a condition holds.
local function grind(areaName: string, done: () -> boolean, kind: string?)
	local area = WorldData.areas[areaName]
	local guard = 0
	while not done() do
		guard += 1
		assert(guard < 40000, "grind stuck in " .. areaName)
		local target = nearestEnemy(vec(area.center), area.radius + 20, kind)
		if target then
			local body = positionOf(target.Body)
			if flat(body - root().Position).Magnitude > RANGE * 0.7 then
				walkTo(body + Vector3.new(0, 1, 0), RANGE * 0.7)
			else
				tick()
			end
		else
			walkTo(vec(area.center, 3), 4)
			tick()
		end
	end
end

local function talk(npc: string)
	local spec = WorldData.npcs[npc]
	walkTo(vec(spec.position, 1.5), 6)
	workspace.LanternValleyMap.Village[npc].Body.TalkPrompt.Triggered:Fire(bot)
	H.advance(0.5)
end

local function questId()
	return attr("QuestId")
end

local timeline = {}
local function mark(label: string, started: number)
	print(string.format("  ... %s bitti (%.1f sim dk)", label, H.now() / 60))
	table.insert(timeline, {
		label = label,
		seconds = H.now() - started,
		level = Progression.levelForXp(attr("XP") or 0),
		coins = attr("Coins") or 0,
		deaths = stats.deaths,
	})
end

local startAll = H.now()

local function startQuest(expected: string)
	local waitStart = H.now()
	talk("Elder")
	while attr("QuestState") == "level" do
		local need = QuestData.quests[expected].minLevel
		grind("grove", function()
			return Progression.levelForXp(attr("XP") or 0) >= need
		end)
		talk("Elder")
	end
	assert(questId() == expected and attr("QuestState") == "active", "could not start " .. expected)
	return waitStart
end

-- 1: purify three Gloomlings
local t = startQuest("first_purify")
grind("glade", function()
	return questId() ~= "first_purify"
end, "Gloomling")
mark("1 İlk Arındırma", t)

-- 2: flowers
t = startQuest("lantern_flowers")
while questId() == "lantern_flowers" do
	local found = {}
	for id in string.gmatch(attr("QuestFound") or "", "[^,]+") do
		found[id] = true
	end
	local best, bestDistance = nil, math.huge
	for id, point in WorldData.flowers do
		local distance = (vec(point) - root().Position).Magnitude
		if not found[id] and distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	walkTo(vec(WorldData.flowers[best], 3), 4)
	remotes.Interact.OnServerEvent:Fire(bot, "flower", best)
	H.advance(0.5)
end
mark("2 Fener Çiçekleri", t)

-- 3: landmarks
t = startQuest("forest_explore")
while questId() == "forest_explore" do
	local found = {}
	for id in string.gmatch(attr("QuestFound") or "", "[^,]+") do
		found[id] = true
	end
	local best, bestDistance = nil, math.huge
	for id, landmark in WorldData.landmarks do
		local distance = (vec(landmark.position) - root().Position).Magnitude
		if not found[id] and distance < bestDistance then
			best, bestDistance = id, distance
		end
	end
	walkTo(vec(WorldData.landmarks[best].position, 3), 6)
	H.advance(1)
end
mark("3 Orman Keşfi", t)

-- 4: upgrade
t = startQuest("first_upgrade")
local cost = Progression.upgradeCost("power", 0)
-- Creatures pay crystals, so the bot empties its pouch at the Great Lantern on the way.
walkTo(vec(WorldData.plaza, 3), 4)
H.advance(1)
if (attr("Coins") or 0) < cost then
	grind("glade", function()
		return (attr("Coins") or 0) + (attr("Crystals") or 0) >= cost
	end)
	walkTo(vec(WorldData.plaza, 3), 4)
	H.advance(1)
end
talk("Smith")
remotes.BuyUpgrade.OnServerEvent:Fire(bot, "power")
H.advance(0.5)
assert(questId() ~= "first_upgrade", "upgrade quest done")
mark("4 Asanı Güçlendir", t)

-- 5: vines
t = startQuest("ruin_vines")
walkTo(vec(WorldData.areas.gate.center, 3), 3)
while questId() == "ruin_vines" do
	-- A player aims the wave at the vines themselves, enemies or not.
	remotes.RequestWave.OnServerEvent:Fire(bot)
	lastWave = H.now()
	H.advance(0.5)
	tick()
end
mark("5 Harabelere Hazırlık", t)

-- 6: boss
t = startQuest("warden")
walkTo(vec(WorldData.areas.arena.center, 3) + Vector3.new(0, 0, 14), 3)
local guard = 0
while questId() == "warden" do
	guard += 1
	assert(guard < 40000, "boss fight stuck")
	local boss = nearestEnemy(root().Position, math.huge, "Warden")
	if boss then
		local body = positionOf(boss.Body)
		if flat(body - root().Position).Magnitude > RANGE * 0.8 or (H.now() < dodgeUntil) then
			walkTo(body + Vector3.new(0, 1, 0), RANGE * 0.8)
		else
			tick()
		end
	else
		tick()
	end
end
mark("6 Gölge Bekçisi", t)
talk("Elder")

print("")
print("Görev                      süre     sv  sikke  yenilgi")
for _, row in timeline do
	print(string.format("%-26s %5.1f dk  %2d  %5d  %4d", row.label, row.seconds / 60, row.level, row.coins, row.deaths))
end
print(string.format("Toplam (bot, alt sınır):   %5.1f dk", (H.now() - startAll) / 60))
local powerTen = 0
for level = 1, 9 do
	powerTen += Progression.upgradeCost("power", level)
end
print(string.format("Seviye 25'e (ilk yüzen silah) kalan XP: %d, güç 10 için kalan sikke: %d, kesede kristal: %d, bekleyen kart: %d",
	math.max(0, Progression.thresholds[25] - (attr("XP") or 0)),
	math.max(0, powerTen - (attr("Coins") or 0)),
	attr("Crystals") or 0,
	attr("PendingPicks") or 0))
assert(#H.threadErrors == 0, "server thread errors:\n" .. (H.threadErrors[1] or ""))
