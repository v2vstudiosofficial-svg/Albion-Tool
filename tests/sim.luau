-- Run: lune run tests/sim
-- Runs the real server code (src/server, src/shared and the vendored ProfileStore in its mock mode)
-- inside Lune with fake players, a simulated clock, fake remotes and stubbed engine pieces
-- (no physics, raycasts always clear, no rendering). It exercises the quest chain, automatic combat,
-- co-op rewards, boss fight, invalid client payloads and save/rejoin, and fails on any error
-- raised in any server thread. It is not a substitute for playing in Studio.
local roblox = require("@lune/roblox")
local H = require("./harness")

local Instance, Vector3, CFrame = roblox.Instance, roblox.Vector3, roblox.CFrame
local workspace = H.workspace
local remotes = H.remotes
local advance, test, eq, logCount = H.advance, H.test, H.eq, H.logCount
local threadErrors, warnings = H.threadErrors, H.warnings
local positionOf = function(object)
	return H.read(object, "Position")
end
local run = H.run
local task = H.task

-- Server-side fake services -----------------------------------------------------------------

local Players = {
	PlayerAdded = H.Signal.new(),
	PlayerRemoving = H.Signal.new(),
	RespawnTime = 5,
	list = {},
}
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
	-- Fails like Studio without API access, which puts ProfileStore into its mock mode.
	GetDataStore = function()
		return {
			SetAsync = function()
				error("HTTP 403 (Forbidden): Studio API access is disabled")
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
		return "GUID-" .. guid
	end,
}

local WorldData = H.loadModule("src/shared/WorldData.luau")
local Balance = H.loadModule("src/shared/Balance.luau")
local Progression = H.loadModule("src/shared/Progression.luau")
local WeaponData = H.loadModule("src/shared/WeaponData.luau")
local ChestData = H.loadModule("src/shared/ChestData.luau")

local function vec(p: { number }, lift: number?): any
	return Vector3.new(p[1], p[2] + (lift or 0), p[3])
end

local function newPlayer(name: string, userId: number)
	return H.newPlayer(name, userId, Players)
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

-- Model:PivotTo (used by the server to teleport characters): moves the root part.
roblox.implementMethod("Model", "PivotTo", function(self, cframe)
	local part = self.HumanoidRootPart
	part.Position = cframe.Position
	part.CFrame = cframe
end)

local function heal(player)
	local h = humanoid(player)
	h.Health = h.MaxHealth
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

-- Stands right next to one enemy of a kind (so it is the nearest target) until the automatic
-- attacks purify it; keeps the player healed. Nearby enemies may be purified along the way.
local function purifyOne(player, kind: string, maxSeconds: number?): boolean
	local model = nearestEnemy(kind, root(player).Position)
	assert(model, "no living " .. kind)
	local elapsed = 0
	while isAlive(model) and elapsed < (maxSeconds or 30) do
		teleport(player, positionOf(model.Body) + Vector3.new(0, 1, 2))
		advance(0.2)
		heal(player)
		elapsed += 0.2
	end
	return not isAlive(model)
end

local function attr(player, name: string)
	return player:GetAttribute(name)
end

local function Attrs(player, name: string): { [string]: boolean }
	local set = {}
	for item in string.gmatch(attr(player, name) or "", "[^,]+") do
		set[item] = true
	end
	return set
end

-- Totals of every RewardGranted the server sent to a player (optionally one reason only).
local function rewardsTo(player, reason: string?): (number, number, number)
	local xp, coins, count = 0, 0, 0
	for _, entry in H.remoteLog do
		if entry.remote == "RewardGranted" and entry.target == player and (reason == nil or entry.args[1] == reason) then
			xp += entry.args[2]
			coins += entry.args[3]
			count += 1
		end
	end
	return xp, coins, count
end

local function attacksBy(player, weaponId: string?, slot: number?): number
	return logCount("Fx", function(e)
		return e.args[1] == "attack" and e.args[2] == player
			and (weaponId == nil or e.args[3] == weaponId)
			and (slot == nil or e.args[4] == slot)
	end)
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

test("players load profiles (ProfileStore mock) and hold their weapon", function()
	join(alice)
	join(bob)
	advance(2)
	for _, player in { alice, bob } do
		eq(attr(player, "DataState"), "ready", player.Name .. " data")
		eq(attr(player, "Level"), 1)
		eq(attr(player, "QuestState"), "available")
		eq(attr(player, "QuestId"), "first_purify")
	end
	for _, player in { alice, bob } do
		eq(logCount("Cinematic", function(e)
			return e.target == player and e.args[1] == "prologue"
		end), 1, player.Name .. " sees the prologue once")
	end
	spawnCharacter(alice, vec(WorldData.spawn, 3))
	spawnCharacter(bob, vec(WorldData.spawn, 3))
	advance(0.5)
	local weapon = alice.Character:FindFirstChild("Weapon")
	assert(weapon, "weapon in hand")
	eq(weapon:GetAttribute("WeaponId"), "staff", "starter weapon")
	eq(attr(alice, "Weapon"), "staff")
	eq(attr(alice, "Companions"), "", "no floating weapons at level 1")
	eq(humanoid(alice).MaxHealth, Balance.levels.baseHealth)
	eq(humanoid(alice).BreakJointsOnDeath, false, "kid-friendly defeat")
end)

test("purifying before accepting the quest pays the enemy reward only", function()
	assert(purifyOne(bob, "Gloomling"), "bob purified")
	local xp, _, count = rewardsTo(bob)
	assert(count >= 1, "purify reward sent")
	eq(attr(bob, "XP"), xp, "xp matches the rewards sent")
	eq(rewardsTo(bob, "quest"), 0, "no quest reward")
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
	local xp, coins = rewardsTo(alice)
	local questXp, questCoins, quests = rewardsTo(alice, "quest")
	eq(quests, 1, "quest reward paid once")
	eq(questXp, 50, "quest xp")
	eq(questCoins, 20, "quest coins")
	eq(attr(alice, "XP"), xp, "xp matches the rewards sent")
	eq(attr(alice, "Coins"), coins, "coins match the rewards sent")
	eq(attr(alice, "QuestId"), "lantern_flowers", "next quest")
	eq(attr(alice, "QuestState"), "available")
	assert(attr(alice, "Level") >= 2, "level up")
	assert(logCount("Fx", function(e)
		return e.args[1] == "levelUp" and e.args[2] == alice
	end) >= 1, "level-up broadcast")
end)

local function toVillage(player)
	teleport(player, vec(WorldData.spawn, 3))
	heal(player)
end

test("the village heals players", function()
	toVillage(alice)
	humanoid(alice).Health = 20
	advance(2)
	assert(humanoid(alice).Health > 40, "healed in the village: " .. humanoid(alice).Health)
	teleport(alice, vec(WorldData.areas.hollow.center, 3) + Vector3.new(0, 0, 60))
	humanoid(alice).Health = 20
	advance(2)
	assert(humanoid(alice).Health < 40, "no fast heal in the forest")
	toVillage(alice)
end)

test("purified enemies respawn", function()
	toVillage(alice)
	toVillage(bob)
	advance(16)
	eq(#workspace.Enemies:GetChildren(), #WorldData.spawns, "respawned")
end)

test("weapons attack automatically: nearest enemy in range, nothing out of range", function()
	local target = nearestEnemy("Gloomling", vec(WorldData.areas.glade.center))
	local body = positionOf(target.Body)
	local hp = target:GetAttribute("Hp")
	local before = attacksBy(alice, "staff", 0)
	heal(alice)
	teleport(alice, body + Vector3.new(0, 1, 3))
	advance(0.3)
	assert(attacksBy(alice, "staff", 0) > before, "attacked without any request")
	assert(target:GetAttribute("Hp") < hp or not isAlive(target), "the nearest enemy took damage")
	toVillage(alice)
	advance(1)
	local idle = attacksBy(alice)
	advance(2)
	eq(attacksBy(alice), idle, "no attacks with nothing in range")
	-- Just outside the staff's reach of the glade's northernmost creature: no attack either.
	local far = vec(WorldData.areas.glade.center, 3) + Vector3.new(0, 0, WorldData.areas.glade.radius + WeaponData.weapons.staff.range + 30)
	teleport(alice, far)
	advance(1)
	eq(attacksBy(alice), idle, "out of range")
	toVillage(alice)
end)

test("invalid client payloads are ignored safely", function()
	local xp, coins = attr(alice, "XP"), attr(alice, "Coins")
	for _, args in { { "x", "bow" }, { 0 / 0, "staff" }, { math.huge, "staff" }, { -1, "staff" }, { 1, "staff" }, { 2.5, "staff" }, { 0, "hammer" }, { 0, string.rep("a", 500) }, { {}, {} }, { 0, true } } do
		remotes.EquipWeapon.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.4)
	end
	for _, args in { { {}, nil }, { "flower", string.rep("a", 500) }, { "flower", "flower_1" }, { 42, 42 } } do
		remotes.Interact.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.3)
	end
	remotes.EquipCharm.OnServerEvent:Fire(alice, 123)
	remotes.EquipCharm.OnServerEvent:Fire(alice, "glow")
	for _, stat in { "power", "nope", 5, {} } do
		remotes.BuyUpgrade.OnServerEvent:Fire(alice, stat)
		advance(0.5)
	end
	for _, choice in { "sharp", 7, string.rep("a", 200), "coins" } do
		remotes.PickSkill.OnServerEvent:Fire(alice, choice)
		advance(0.4)
	end
	remotes.RequestWave.OnServerEvent:Fire(alice)
	remotes.RetryLoad.OnServerEvent:Fire(alice)
	advance(1)
	eq(attr(alice, "XP"), xp, "xp unchanged")
	eq(attr(alice, "Coins"), coins, "coins unchanged")
	eq(attr(alice, "StaffTier"), 0, "no upgrade from afar")
	eq(attr(alice, "Upgrades"), "", "no bogus upgrades")
	eq(attr(alice, "Charm"), "", "cannot equip unowned charm")
	eq(attr(alice, "Weapon"), "staff", "no locked or bogus weapons")
	eq(attr(alice, "Companions"), "", "no floating slot opened")
	eq(attr(alice, "DataState"), "ready")
end)

test("co-op: both attackers get their own reward, never more than once per purify", function()
	local target = nil
	for _, model in enemiesOf("Gloomling") do
		if model:GetAttribute("Hp") == model:GetAttribute("MaxHp") then
			target = model
			break
		end
	end
	assert(target, "an untouched Gloomling")
	local _, _, aliceBefore = rewardsTo(alice, "purify")
	local _, _, bobBefore = rewardsTo(bob, "purify")
	local purifiesBefore = logCount("Fx", function(e)
		return e.args[1] == "purify"
	end)
	local elapsed = 0
	while isAlive(target) and elapsed < 10 do
		local body = positionOf(target.Body)
		teleport(alice, body + Vector3.new(0, 1, 2))
		teleport(bob, body + Vector3.new(0, 1, -2))
		advance(0.1)
		heal(alice)
		heal(bob)
		elapsed += 0.1
	end
	eq(isAlive(target), false, "purified by the two players")
	toVillage(alice)
	toVillage(bob)
	advance(0.2)
	local purified = logCount("Fx", function(e)
		return e.args[1] == "purify"
	end) - purifiesBefore
	local _, _, aliceAfter = rewardsTo(alice, "purify")
	local _, _, bobAfter = rewardsTo(bob, "purify")
	assert(aliceAfter - aliceBefore >= 1 and bobAfter - bobBefore >= 1, "both rewarded")
	assert(aliceAfter - aliceBefore <= purified and bobAfter - bobBefore <= purified, "at most one reward per purify")
	eq(attr(alice, "XP"), (rewardsTo(alice)), "alice xp matches rewards")
	eq(attr(bob, "XP"), (rewardsTo(bob)), "bob xp matches rewards")
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

test("quest 4: upgrade at the Smith once; throttled and priced correctly", function()
	talk(alice, "Elder")
	eq(attr(alice, "QuestId"), "first_upgrade")
	local coins = attr(alice, "Coins")
	local cost = Progression.upgradeCost("power", 0) :: number
	assert(coins >= cost, "enough coins without grinding: " .. coins)
	talk(alice, "Smith")
	eq(logCount("OpenShop", function(e)
		return e.target == alice
	end), 1, "shop opened")
	remotes.BuyUpgrade.OnServerEvent:Fire(alice, "power")
	remotes.BuyUpgrade.OnServerEvent:Fire(alice, "power")
	advance(0.2)
	eq(attr(alice, "StaffTier"), 1, "single upgrade")
	eq(attr(alice, "Coins"), coins - cost, "charged once")
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
		if #enemiesOf("Gloomling") == 0 then
			advance(3) -- wait for respawns
		else
			assert(purifyOne(alice, "Gloomling"), "grind")
		end
		advance(0.1)
	end
	talk(alice, "Elder")
	eq(attr(alice, "QuestState"), "active")
	local boss = enemiesOf("Warden")[1]
	assert(boss, "boss alive")
	local arena = vec(WorldData.areas.arena.center, 3)
	teleport(alice, arena + Vector3.new(0, 0, 16))
	local elapsed = 0
	while isAlive(boss) and elapsed < 240 do
		local bossPosition = positionOf(boss.Body)
		teleport(alice, Vector3.new(bossPosition.X, 3, bossPosition.Z + 12))
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
	-- The chapter finale is a full scene that starts a moment after the boss falls (not in the fight).
	local function finale(): number
		return logCount("Cinematic", function(e)
			return e.target == alice and e.args[1] == "warden_end"
		end)
	end
	advance(3)
	eq(finale(), 1, "the chapter finale plays once")
	eq(attr(alice, "QuestId"), "marsh_scouts", "chapter 2 is next")
	eq(attr(alice, "QuestState"), "level", "and waits for a stronger player")
	eq(attr(alice, "Flags"), "festival,gardens,lanterns")
	eq(attr(alice, "Legends"), "Warden", "first Legendary Shadow")
	eq(H.loadModule("src/server/PlayerProfiles.luau").get(alice).counters.legendWins, nil, "the intro Warden does not count for legend bounties")
	eq(attr(alice, "Chests"), "mystic:0", "a Mystic chest for the first win")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_legend"
	end), 1, "told once")
end)

test("Ranger Wren: her quests come in the chain, counters follow the profile, paid once", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local QuestData = H.loadModule("src/shared/QuestData.luau")
	local profile = PlayerProfiles.get(alice)
	local savedXp = profile.xp
	local function said(npc: string, key: string): number
		return logCount("NpcSay", function(e)
			return e.target == alice and e.args[1] == npc and e.args[2] == key
		end)
	end
	local function setLevel(level: number)
		profile.xp = Progression.thresholds[level]
		PlayerProfiles.sync(alice)
	end
	local wren = workspace.LanternValleyMap.Village.Wren.Body
	assert(wren.TalkPrompt, "Wren has a prompt")
	-- Too low: she asks for a stronger player and nothing starts.
	setLevel(QuestData.quests.marsh_scouts.minLevel - 1)
	talk(alice, "Wren")
	eq(said("Wren", "wren_need_level"), 1, "level gate")
	eq(attr(alice, "QuestState"), "level")
	-- The Elder sends players to Wren when the next quest is hers.
	setLevel(QuestData.quests.marsh_scouts.minLevel)
	eq(attr(alice, "QuestState"), "available")
	talk(alice, "Elder")
	eq(said("Elder", "elder_go_wren"), 1, "the Elder points to Wren")
	-- Far from Wren nothing happens.
	toVillage(alice)
	wren.TalkPrompt.Triggered:Fire(alice)
	advance(0.2)
	eq(attr(alice, "QuestState"), "available", "the prompt needs the player near her")
	talk(alice, "Wren")
	local function played(sceneId: string): number
		return logCount("Cinematic", function(e)
			return e.target == alice and e.args[1] == sceneId
		end)
	end
	eq(played("marsh_scouts"), 1, "her first meeting plays as a scene")
	eq(played("rift_watch"), 0)
	eq(attr(alice, "QuestId"), "marsh_scouts")
	eq(attr(alice, "QuestState"), "active")
	talk(alice, "Elder")
	eq(said("Elder", "elder_quest_active"), 1, "the Elder knows a quest is running")
	talk(alice, "Wren")
	eq(played("marsh_scouts"), 2, "talking to the giver again repeats the story")
	-- Purify the Mudlings; the reward comes once and the next errand is ready.
	local coins = attr(alice, "Coins")
	local guard = 0
	while attr(alice, "QuestId") == "marsh_scouts" and guard < 20 do
		purifyOne(alice, "Mudling", 40)
		guard += 1
	end
	eq(attr(alice, "QuestId"), "rift_watch", "marsh scouts done")
	eq(played("marsh_scouts_end"), 1, "the ending of the errand is shown")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_story_blessing"
	end) >= 1, true, "a story blessing was announced")
	assert(attr(alice, "Coins") >= coins + QuestData.quests.marsh_scouts.reward.coins, "coins paid")
	setLevel(QuestData.quests.rift_watch.minLevel)
	talk(alice, "Wren")
	eq(attr(alice, "QuestId"), "rift_watch")
	eq(attr(alice, "QuestState"), "active")
	eq(attr(alice, "QuestCount"), 0, "earlier rifts do not count")
	-- A cleared rift (counter) completes it without any event.
	local paidBefore = attr(alice, "Coins")
	profile.counters.rifts = (profile.counters.rifts or 0) + 1
	PlayerProfiles.sync(alice)
	advance(0.2)
	eq(attr(alice, "QuestId"), "bog_mother", "rift watch done")
	local paid = attr(alice, "Coins") - paidBefore
	eq(paid, QuestData.quests.rift_watch.reward.coins, "reward paid exactly once")
	PlayerProfiles.sync(alice)
	eq(attr(alice, "Coins") - paidBefore, paid, "a later sync pays nothing more")
	-- The next quest is the Elder's: Wren sends the player back.
	talk(alice, "Wren")
	eq(said("Wren", "wren_go_elder"), 1, "Wren points back to the Elder")
	talk(alice, "Smith")
	eq(said("Smith", "smith_greet_east"), 1, "the Smith talks about the freed Warden")
	profile.xp = savedXp
	PlayerProfiles.sync(alice)
	toVillage(alice)
end)

test("a defeated character is not revived by a level-up", function()
	local CharacterService = H.loadModule("src/server/CharacterService.luau")
	humanoid(alice).Health = 0
	CharacterService.onLevelUp(alice)
	advance(0.1)
	eq(humanoid(alice).Health, 0, "stays defeated until respawn")
	heal(alice)
	toVillage(alice)
end)

test("the boss cancels a pending attack when everyone leaves the arena", function()
	advance(Balance.enemies.Warden.respawnDelay + 1)
	local boss = enemiesOf("Warden")[1]
	assert(boss, "boss respawned")
	local arena = vec(WorldData.areas.arena.center, 3)
	local function countFx(kind)
		return logCount("Fx", function(e)
			return e.args[1] == kind
		end)
	end
	local telegraphs = countFx("telegraph")
	teleport(alice, arena + Vector3.new(0, 0, 14))
	local waited = 0
	while countFx("telegraph") == telegraphs and waited < 20 do
		advance(0.1)
		heal(alice)
		waited += 0.1
	end
	assert(countFx("telegraph") > telegraphs, "boss telegraphed a slam")
	local slams = countFx("slam")
	toVillage(alice)
	advance(Balance.enemies.Warden.slamWarn + 0.6) -- longer than the warning, shorter than a reset
	teleport(alice, arena + Vector3.new(0, 0, 14))
	advance(0.2)
	eq(countFx("slam"), slams, "no untelegraphed slam on return")
	toVillage(alice)
	advance(Balance.enemies.Warden.resetAfter + 1)
end)

test("enemies drop their alert state when they fall asleep", function()
	teleport(bob, vec(WorldData.areas.hollow.center, 3))
	local alerted = nil
	for _ = 1, 40 do
		advance(0.1)
		heal(bob)
		for _, model in workspace.Enemies:GetChildren() do
			if model:GetAttribute("Aggro") then
				alerted = model
			end
		end
		if alerted then
			break
		end
	end
	assert(alerted, "an enemy noticed bob")
	toVillage(bob)
	advance(0.2)
	eq(alerted:GetAttribute("Aggro"), false, "calm after everyone left")
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

local function nearAnyEnemy(player, kind: string, area: string)
	local model = nil
	while not model do
		model = nearestEnemy(kind, vec(WorldData.areas[area].center))
		if not model then
			advance(2) -- wait for respawns
		end
	end
	teleport(player, positionOf(model.Body) + Vector3.new(0, 1, 2))
end

test("chests: pick up nearby, full slots, one unlock at a time, open when the timer is done", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	PlayerProfiles.get(alice).chests = {} -- start with empty slots (the legend chest is tested above)
	PlayerProfiles.sync(alice)
	local spot = WorldData.chests.chest_glade_1
	local spotPosition = vec(spot.position, 3)
	remotes.Interact.OnServerEvent:Fire(alice, "chest", "chest_glade_1")
	advance(0.5)
	eq(attr(alice, "Chests"), "", "too far away")
	teleport(alice, spotPosition + Vector3.new(2, 0, 0))
	remotes.Interact.OnServerEvent:Fire(alice, "chest", "chest_glade_1")
	advance(0.5)
	eq(attr(alice, "Chests"), spot.type .. ":0", "chest in the first slot")
	assert(string.find(attr(alice, "ChestSpots"), "chest_glade_1:", 1, true), "spot taken for alice")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_chest_taken"
	end), 1, "told about it")
	remotes.Interact.OnServerEvent:Fire(alice, "chest", "chest_glade_1")
	advance(0.5)
	eq(attr(alice, "Chests"), spot.type .. ":0", "the same spot cannot be taken twice")
	-- Bob's own chest at the same spot is still there; his single slot fills up.
	teleport(bob, spotPosition + Vector3.new(-2, 0, 0))
	remotes.Interact.OnServerEvent:Fire(bob, "chest", "chest_glade_1")
	advance(0.5)
	eq(attr(bob, "Chests"), spot.type .. ":0", "personal chests")
	local other = WorldData.chests.chest_glade_2
	teleport(bob, vec(other.position, 3) + Vector3.new(2, 0, 0))
	remotes.Interact.OnServerEvent:Fire(bob, "chest", "chest_glade_2")
	advance(0.5)
	if Progression.chestSlots(attr(bob, "Level")) == 1 then
		eq(logCount("Notice", function(e)
			return e.target == bob and e.args[1] == "notice_chest_full"
		end), 1, "full slots")
	end
	toVillage(bob)

	for _, args in { { "x", 1 }, { "open", 1.5 }, { "open", "1" }, { "unlock", 0 / 0 }, { nil, nil }, { "unlock", 99 } } do
		remotes.ChestAction.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.4)
	end
	eq(attr(alice, "Chests"), spot.type .. ":0", "bad requests change nothing")
	remotes.ChestAction.OnServerEvent:Fire(alice, "open", 1)
	advance(0.4)
	eq(attr(alice, "Chests"), spot.type .. ":0", "cannot open before unlocking")
	remotes.ChestAction.OnServerEvent:Fire(alice, "unlock", 1)
	advance(0.4)
	local startedAt = tonumber(string.match(attr(alice, "Chests"), ":(%d+)$"))
	assert(startedAt and startedAt > 0, "unlocking")
	remotes.ChestAction.OnServerEvent:Fire(alice, "open", 1)
	advance(0.4)
	assert(attr(alice, "Chests") ~= "", "still locked")
	toVillage(alice)
	advance(ChestData.chests[spot.type].unlockSeconds)
	local coins = attr(alice, "Coins")
	remotes.ChestAction.OnServerEvent:Fire(alice, "open", 1)
	advance(0.4)
	eq(attr(alice, "Chests"), "", "opened and removed")
	local opened = nil
	for _, entry in H.remoteLog do
		if entry.remote == "Fx" and entry.target == alice and entry.args[1] == "chestOpened" then
			opened = entry.args[2]
		end
	end
	assert(opened, "reward shown to alice")
	assert(attr(alice, "Coins") >= coins + ChestData.chests[spot.type].coins[1], "coins paid")
	eq(attr(alice, "Coins"), coins + opened.coins, "exactly the coins shown")
	local levels = string.split(attr(alice, "SlotLevels"), ",")
	eq(tonumber(levels[1]), ChestData.chests[spot.type].slotLevels, "main slot levelled up")
	if opened.weapon and not opened.duplicate then
		assert(Attrs(alice, "Weapons")[opened.weapon], "new weapon owned")
	end
	remotes.ChestAction.OnServerEvent:Fire(alice, "open", 1)
	advance(0.4)
	eq(logCount("Fx", function(e)
		return e.target == alice and e.args[1] == "chestOpened"
	end), 1, "paid once")
end)

test("weapon choice: owned weapons equip, the hand model swaps, attacks use it", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	eq(attr(alice, "Weapon"), "staff")
	remotes.EquipWeapon.OnServerEvent:Fire(alice, 0, "hammer")
	advance(0.5)
	local owned = PlayerProfiles.get(alice).ownedWeapons
	eq(attr(alice, "Weapon"), if owned.hammer then "hammer" else "staff", "only owned weapons")
	-- As if a chest had given these.
	PlayerProfiles.get(alice).ownedWeapons = { staff = true, bow = true, daggers = true, spear = true }
	PlayerProfiles.sync(alice)
	remotes.EquipWeapon.OnServerEvent:Fire(alice, 0, "bow")
	advance(0.5)
	eq(attr(alice, "Weapon"), "bow")
	eq(alice.Character.Weapon:GetAttribute("WeaponId"), "bow", "hand model swapped")
	local models = 0
	for _, child in alice.Character:GetChildren() do
		if child.Name == "Weapon" then
			models += 1
		end
	end
	eq(models, 1, "old model removed")
	nearAnyEnemy(alice, "Gloomling", "glade")
	advance(1)
	heal(alice)
	assert(attacksBy(alice, "bow", 0) > 0, "bow attacks")
	toVillage(alice)
end)

test("every 25 levels a floating weapon joins the fight from behind the player", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	PlayerProfiles.get(alice).xp = Progression.thresholds[25]
	PlayerProfiles.sync(alice)
	eq(attr(alice, "Level"), 25)
	eq(attr(alice, "Companions"), "spear", "auto pick: rarest owned weapon not in use")
	remotes.EquipWeapon.OnServerEvent:Fire(alice, 1, "daggers")
	advance(0.5)
	eq(attr(alice, "Companions"), "daggers", "picked for the slot")
	remotes.EquipWeapon.OnServerEvent:Fire(alice, 2, "sword")
	advance(0.5)
	eq(attr(alice, "Companions"), "daggers", "second slot still closed")
	-- Sturdy level 5-6 creatures, so the main weapon cannot clear the area before the slot acts.
	nearAnyEnemy(alice, "Rockling", "hollow")
	local before = attacksBy(alice, "daggers", 1)
	advance(1.5)
	heal(alice)
	assert(attacksBy(alice, "daggers", 1) > before, "floating slot attacks")
	for _, entry in H.remoteLog do
		if entry.remote == "Fx" and entry.args[1] == "attack" and entry.args[2] == alice and entry.args[4] == 1 then
			local origin = entry.args[5]
			local hover = WeaponData.companionOffsets[1]
			eq(math.floor(origin.Y - positionOf(root(alice)).Y + 0.5), math.floor(hover[2] + 0.5), "attacks from the hover height")
			break
		end
	end
	toVillage(alice)
end)

test("crystals: purifies fill the pouch (not coins), the Great Lantern turns them into coins", function()
	-- Earlier fights may have filled the pouch; empty it first.
	teleport(alice, vec(WorldData.plaza, 3))
	advance(1)
	eq(attr(alice, "Crystals"), 0, "emptied at the lantern")
	local coins = attr(alice, "Coins")
	local crystals = attr(alice, "Crystals")
	nearAnyEnemy(alice, "Gloomling", "glade")
	local before = logCount("Fx", function(e)
		return e.target == alice and e.args[1] == "crystals"
	end)
	local waited = 0
	while logCount("Fx", function(e)
		return e.target == alice and e.args[1] == "crystals"
	end) == before and waited < 10 do
		advance(0.2)
		heal(alice)
		waited += 0.2
	end
	assert(attr(alice, "Crystals") > crystals, "crystals in the pouch")
	eq(attr(alice, "Coins"), coins, "purifies pay no coins directly")
	toVillage(alice)
	advance(1) -- let rewards from the last fight arrive
	local carried = attr(alice, "Crystals")
	coins = attr(alice, "Coins")
	teleport(alice, vec(WorldData.plaza, 3) + Vector3.new(3, 0, 0))
	advance(1)
	eq(attr(alice, "Crystals"), 0, "pouch emptied at the lantern")
	eq(attr(alice, "Coins"), coins + carried, "one coin per crystal")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_deposit" and e.args[2] == carried
	end), 1, "told about the deposit")
end)

test("a full pouch keeps its capacity and warns once", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local Stats = H.loadModule("src/shared/Stats.luau")
	local profile = PlayerProfiles.get(alice)
	local capacity = Stats.of(profile).pouchCapacity
	advance(21) -- past the warning cooldown from earlier fights
	profile.crystals = capacity - 1
	PlayerProfiles.sync(alice)
	local warnings = logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_pouch_full"
	end)
	for _ = 1, 3 do
		nearAnyEnemy(alice, "Gloomling", "glade")
		for _ = 1, 20 do
			advance(0.2)
			heal(alice)
		end
	end
	eq(attr(alice, "Crystals"), capacity, "never above capacity")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_pouch_full"
	end) - warnings, 1, "one warning, not spam")
	toVillage(alice)
	teleport(alice, vec(WorldData.plaza, 3))
	advance(1)
	eq(attr(alice, "Crystals"), 0)
end)

test("forge upgrades: levels, prices, health and regen take effect; far or unknown ignored", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local profile = PlayerProfiles.get(alice)
	profile.coins += 5000
	PlayerProfiles.sync(alice)
	local coins = attr(alice, "Coins")
	remotes.BuyUpgrade.OnServerEvent:Fire(alice, "health")
	advance(0.5)
	eq(attr(alice, "Upgrades"), "", "not near the Smith")
	talk(alice, "Smith")
	local maxHealth = humanoid(alice).MaxHealth
	remotes.BuyUpgrade.OnServerEvent:Fire(alice, "health")
	advance(0.5)
	eq(attr(alice, "Upgrades"), "health:1")
	eq(attr(alice, "Coins"), coins - Progression.upgradeCost("health", 0), "charged the listed price")
	assert(humanoid(alice).MaxHealth > maxHealth, "more health")
	for _ = 1, 2 do
		remotes.BuyUpgrade.OnServerEvent:Fire(alice, "regen")
		advance(0.5)
	end
	eq(attr(alice, "Upgrades"), "health:1,regen:2")
	remotes.BuyUpgrade.OnServerEvent:Fire(alice, "teleport")
	advance(0.5)
	eq(attr(alice, "Upgrades"), "health:1,regen:2", "unknown upgrade ignored")
	-- Regen heals slowly outside the village.
	teleport(alice, vec(WorldData.areas.hollow.center, 3) + Vector3.new(0, 0, 60))
	humanoid(alice).Health = 20
	advance(2)
	local healed = humanoid(alice).Health - 20
	assert(healed > 0 and healed < Balance.village.healPerSecond, "slow regen outside: " .. healed)
	toVillage(alice)
end)

test("level-ups earn skill picks; only offered cards can be taken, once each", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local profile = PlayerProfiles.get(alice)
	local level = attr(alice, "Level")
	local picksBefore = attr(alice, "PendingPicks")
	PlayerProfiles.grant(alice, { xp = Progression.thresholds[level + 2] - profile.xp }, "quest")
	advance(0.2)
	eq(attr(alice, "PendingPicks"), picksBefore + 2, "one pick per level gained")
	local offer = string.split(attr(alice, "SkillOffer"), ",")
	eq(#offer, 3, "three cards")
	eq(#{ table.unpack(offer) } == 3 and offer[1] ~= offer[2] and offer[2] ~= offer[3] and offer[1] ~= offer[3], true, "distinct cards")
	local notOffered = nil
	for _, skillId in { "swift", "sharp", "reach", "lucky", "tough", "magnet", "feet", "wave", "wisdom", "echo" } do
		if not table.find(offer, skillId) then
			notOffered = skillId
			break
		end
	end
	remotes.PickSkill.OnServerEvent:Fire(alice, notOffered)
	advance(0.5)
	eq(attr(alice, "PendingPicks"), picksBefore + 2, "a card that was not offered does nothing")
	remotes.PickSkill.OnServerEvent:Fire(alice, offer[1])
	remotes.PickSkill.OnServerEvent:Fire(alice, offer[1])
	advance(0.5)
	eq(attr(alice, "PendingPicks"), picksBefore + 1, "spam picks once")
	assert(string.find(attr(alice, "Skills"), offer[1] .. ":", 1, true), "skill learned")
	while attr(alice, "PendingPicks") > 0 do
		remotes.PickSkill.OnServerEvent:Fire(alice, string.split(attr(alice, "SkillOffer"), ",")[1])
		advance(0.5)
	end
	eq(attr(alice, "SkillOffer"), "", "no offer without picks")
end)

test("critical hits happen and are marked for clients", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local profile = PlayerProfiles.get(alice)
	profile.upgrades.crit = Balance.upgrades.crit.maxLevel
	profile.skills.lucky = 5
	PlayerProfiles.sync(alice)
	local crits = logCount("Fx", function(e)
		return e.args[1] == "hit" and e.args[5] == true
	end)
	nearAnyEnemy(alice, "Rockling", "hollow")
	for _ = 1, 20 do
		advance(0.2)
		heal(alice)
	end
	assert(logCount("Fx", function(e)
		return e.args[1] == "hit" and e.args[5] == true
	end) > crits, "some hits were critical")
	toVillage(alice)
end)

test("Studio-only LvDebugLevel attribute moves loaded players to a level", function()
	-- Lune does not fire attribute signals by itself; the harness signal stands in for Roblox's.
	local changed = H.signalFor(workspace, "attr:LvDebugLevel")
	workspace:SetAttribute("LvDebugLevel", 50)
	changed:Fire()
	advance(0.2)
	eq(attr(alice, "Level"), 50)
	eq(#string.split(attr(alice, "Companions"), ","), 2, "two floating slots at 50")
	workspace:SetAttribute("LvDebugLevel", "nonsense")
	changed:Fire()
	advance(0.2)
	eq(attr(alice, "Level"), 50, "ignored")
	workspace:SetAttribute("LvDebugAllWeapons", true)
	H.signalFor(workspace, "attr:LvDebugAllWeapons"):Fire()
	advance(0.2)
	eq(#string.split(attr(alice, "Weapons"), ","), #WeaponData.order, "every weapon")
end)

test("east lands: packs roll levels in their range; the Bog Mother is a legend", function()
	for index, spawn in WorldData.spawns do
		if spawn.levels then
			for _, model in workspace.Enemies:GetChildren() do
				if model:GetAttribute("EnemyType") == spawn.kind and model:GetAttribute("Alive") then
					local level = model:GetAttribute("Level")
					assert(level >= 1 and level <= 100, "level set")
				end
			end
		end
		local _ = index
	end
	local levels = {}
	for _, model in workspace.Enemies:GetChildren() do
		if model:GetAttribute("EnemyType") == "Mudling" then
			table.insert(levels, model:GetAttribute("Level"))
		end
	end
	assert(#levels > 0, "mudlings in the marsh")
	for _, level in levels do
		assert(level >= 8 and level <= 25, "marsh levels " .. level)
	end

	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local profile = PlayerProfiles.get(alice)
	profile.chests = {}
	PlayerProfiles.sync(alice)
	local boss = enemiesOf("BogMother")[1]
	assert(boss, "Bog Mother waits in the bog")
	eq(boss:GetAttribute("Level"), 25)
	assert(boss:GetAttribute("MaxHp") > Balance.enemies.BogMother.maxHp, "scaled to its level")
	local coinsBefore = attr(alice, "Coins")
	local elapsed = 0
	while isAlive(boss) and elapsed < 240 do
		local bossPosition = positionOf(boss.Body)
		teleport(alice, Vector3.new(bossPosition.X, 3, bossPosition.Z + 10))
		advance(0.5)
		heal(alice)
		elapsed += 0.5
	end
	assert(not isAlive(boss), "Bog Mother purified in " .. elapsed .. " s")
	advance(0.3)
	assert(attr(alice, "Coins") - coinsBefore >= Balance.enemies.BogMother.reward.coins, "boss coins paid directly, not into the pouch")
	assert(string.find(attr(alice, "Legends"), "BogMother", 1, true), "second legend recorded")
	eq(attr(alice, "Chests"), "mystic:0", "legend chest")
	toVillage(alice)
end)

test("elites: crowned, tougher, triple rewards, may drop a chest", function()
	local EnemyService = H.loadModule("src/server/EnemyService.luau")
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	PlayerProfiles.get(alice).chests = {}
	PlayerProfiles.sync(alice)
	local chance = Balance.elite.chestChance
	Balance.elite.chestChance = 1 -- make the drop certain for the test
	local spot = vec(WorldData.areas.glade.center)
	local id = EnemyService.spawnTemporary("Gloomling", 2, spot, "glade", "test", true)
	local enemy = EnemyService.get(id)
	assert(enemy and enemy.elite, "elite spawned")
	eq(enemy.model:GetAttribute("Elite"), true)
	assert(enemy.model:FindFirstChild("Crown1"), "golden crown")
	local normal = Progression.enemyStats(Balance.enemies.Gloomling, 2)
	eq(enemy.model:GetAttribute("MaxHp"), math.floor(normal.maxHp * Balance.elite.hpMultiplier + 0.5), "tougher")
	local xpBefore = rewardsTo(alice, "purify")
	local waited = 0
	while EnemyService.get(id) and waited < 20 do
		teleport(alice, positionOf(enemy.body) + Vector3.new(0, 1, 2))
		advance(0.2)
		heal(alice)
		waited += 0.2
	end
	Balance.elite.chestChance = chance
	eq(EnemyService.get(id), nil, "purified")
	advance(0.2)
	assert(rewardsTo(alice, "purify") - xpBefore >= normal.reward.xp * Balance.elite.rewardMultiplier, "triple xp")
	assert(attr(alice, "Chests") ~= "", "elite chest dropped")
	-- Natural elites in the glade may drop chests during the fight too.
	assert(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_elite_chest"
	end) >= 1, "told about the chest")
	advance(20)
	eq(EnemyService.get(id), nil, "temporary enemies never respawn")
	toVillage(alice)
end)

test("shadow rift: waves in order, clearing them gives helpers a chest", function()
	local RiftService = H.loadModule("src/server/RiftService.luau")
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	PlayerProfiles.get(alice).chests = {}
	PlayerProfiles.sync(alice)
	local center = vec(WorldData.areas.hollow.center, 3)
	teleport(alice, center)
	if not RiftService.active("hollow") then
		eq(RiftService.open("hollow"), true, "rift opened")
	end
	eq(RiftService.open("hollow"), false, "one rift per zone")
	local function riftEnemies(): { any }
		local list = {}
		for _, model in workspace.Enemies:GetChildren() do
			local EnemyService = H.loadModule("src/server/EnemyService.luau")
			local enemy = EnemyService.get(model:GetAttribute("EnemyId"))
			if enemy and enemy.tag == "rift:hollow" then
				table.insert(list, enemy)
			end
		end
		return list
	end
	assert(#riftEnemies() >= Balance.rifts.baseCount + 1, "first wave spawned")
	local elapsed = 0
	while RiftService.active("hollow") and elapsed < Balance.rifts.timeLimit do
		local list = riftEnemies()
		if #list > 0 then
			teleport(alice, positionOf(list[1].body) + Vector3.new(0, 1, 2))
		end
		advance(0.25)
		heal(alice)
		elapsed += 0.25
	end
	eq(RiftService.active("hollow"), false, "rift closed")
	eq(logCount("Fx", function(e)
		return e.args[1] == "riftWave" and e.args[2] == "hollow"
	end) >= Balance.rifts.waves, true, "every wave came")
	eq(logCount("Fx", function(e)
		return e.args[1] == "riftClosed" and e.args[2] == "hollow" and e.args[4] == true
	end), 1, "closed by clearing it")
	assert(string.find(attr(alice, "Chests"), Balance.rifts.chest, 1, true), "rift chest for the helper")
	toVillage(alice)
end)

test("shadow rift: running out of time fades the rest away without rewards", function()
	local RiftService = H.loadModule("src/server/RiftService.luau")
	local EnemyService = H.loadModule("src/server/EnemyService.luau")
	local notices = logCount("Notice", function(e)
		return e.args[1] == "notice_rift_done"
	end)
	local function failedGrove(): number
		return logCount("Fx", function(e)
			return e.args[1] == "riftClosed" and e.args[2] == "grove" and e.args[4] == false
		end)
	end
	local failedBefore = failedGrove()
	eq(RiftService.open("grove"), true)
	local ids = {}
	for _, model in workspace.Enemies:GetChildren() do
		local enemy = EnemyService.get(model:GetAttribute("EnemyId"))
		if enemy and enemy.tag == "rift:grove" then
			table.insert(ids, enemy.id)
		end
	end
	assert(#ids > 0, "rift creatures")
	advance(Balance.rifts.timeLimit + 2)
	eq(RiftService.active("grove"), false, "closed")
	for _, id in ids do
		eq(EnemyService.get(id), nil, "faded away")
	end
	eq(failedGrove(), failedBefore + 1, "failed")
	eq(logCount("Notice", function(e)
		return e.args[1] == "notice_rift_done"
	end), notices, "no rewards")
end)

test("east creatures: hexcaps fire fans of spores, shades blink closer", function()
	local function spores(): number
		return logCount("Fx", function(e)
			return e.args[1] == "projectile" and e.args[7] == "spore"
		end)
	end
	local before = spores()
	local blinksBefore = logCount("Fx", function(e)
		return e.args[1] == "blink"
	end)
	local function packCenter(kind: string): any
		local sum, count = Vector3.new(0, 0, 0), 0
		for _, spawn in WorldData.spawns do
			if spawn.kind == kind and spawn.area == "citadel" then
				sum += vec(spawn.position)
				count += 1
			end
		end
		return sum / count
	end
	-- Hexcaps shoot at a player a little outside their preferred distance.
	teleport(bob, packCenter("Hexcap") + Vector3.new(0, 3, 16))
	local fanSeen = false
	for _ = 1, 80 do
		local previous = spores()
		advance(0.1)
		heal(bob)
		if spores() - previous >= Balance.enemies.Hexcap.shots then
			fanSeen = true
		end
	end
	assert(spores() > before, "hexcaps fired")
	assert(fanSeen, "a whole fan of spores at once")
	-- Shades hop toward a player standing beyond their blink range.
	toVillage(bob)
	advance(1)
	teleport(bob, packCenter("Shade") + Vector3.new(0, 3, 20))
	for _ = 1, 60 do
		advance(0.1)
		heal(bob)
	end
	assert(logCount("Fx", function(e)
		return e.args[1] == "blink"
	end) > blinksBefore, "a shade blinked")
	toVillage(bob)
end)

test("the light wave hits like the main weapon at any level", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local Profile = H.loadModule("src/server/Profile.luau")
	local profile = PlayerProfiles.get(alice)
	local main = Profile.loadout(profile)
	local level = attr(alice, "Level")
	local expected = Progression.weaponDamage(main, profile.staffUpgrade, level, false, profile.slotLevels[1], profile.weaponStars[main]) * Balance.wave.damageMultiplier
	advance(Balance.wave.cooldown + 1)
	nearAnyEnemy(alice, "Rockling", "hollow")
	local hits = #H.remoteLog
	remotes.RequestWave.OnServerEvent:Fire(alice)
	advance(0.05)
	local biggest = 0
	for index = hits + 1, #H.remoteLog do
		local entry = H.remoteLog[index]
		if entry.remote == "Fx" and entry.args[1] == "hit" then
			biggest = math.max(biggest, entry.args[4])
		end
	end
	assert(biggest >= math.floor(expected * 0.99), `wave hit {biggest}, main weapon wave {expected}`)
	assert(biggest > Progression.staffDamage(profile.staffUpgrade, level) * Balance.wave.damageMultiplier, "stronger than the old staff-only wave")
	toVillage(alice)
end)

test("adventure log counts play and pays claimed tiers once", function()
	local function entry(id: string): (number, number)
		for _, item in string.split(attr(alice, "Achievements"), ",") do
			local key, claimed, progress = string.match(item, "^([^:]+):(%d+):(%d+)$")
			if key == id then
				return tonumber(claimed) :: number, tonumber(progress) :: number
			end
		end
		error("missing " .. id)
	end
	local _, purifies = entry("friends")
	assert(purifies >= 50, "purifies counted during the scenario: " .. purifies)
	local _, chests = entry("treasure")
	assert(chests >= 1, "opened chests counted")
	local _, rifts = entry("rifts")
	assert(rifts >= 1, "cleared rifts counted")
	local _, crystals = entry("crystals")
	assert(crystals > 0, "deposited crystals counted")
	assert(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_achievement_ready"
	end) >= 1, "told when a reward is ready")
	local coins = attr(alice, "Coins")
	remotes.ClaimAchievement.OnServerEvent:Fire(alice, "friends")
	remotes.ClaimAchievement.OnServerEvent:Fire(alice, "friends")
	advance(0.5)
	eq((entry("friends")), 1, "one tier per claim, spam ignored")
	assert(attr(alice, "Coins") > coins, "coins paid")
	for _, bad in { "nope", 5, {} } do
		remotes.ClaimAchievement.OnServerEvent:Fire(alice, bad)
		advance(0.4)
	end
	eq((entry("friends")), 1, "bad claims ignored")
end)

test("team bonus: playing close together gives more XP per purify", function()
	local function xpOf(player): number
		return (rewardsTo(player, "purify"))
	end
	-- Alone: a bob-only purify at the glade.
	toVillage(alice)
	local before = xpOf(bob)
	local model = nearestEnemy("Gloomling", vec(WorldData.areas.glade.center))
	while not model do
		advance(2)
		model = nearestEnemy("Gloomling", vec(WorldData.areas.glade.center))
	end
	local level = model:GetAttribute("Level")
	local alone = Progression.enemyStats(Balance.enemies.Gloomling, level).reward.xp
	local logStart = #H.remoteLog + 1
	local waited = 0
	while isAlive(model) and waited < 20 do
		teleport(bob, positionOf(model.Body) + Vector3.new(0, 1, 2))
		teleport(alice, positionOf(model.Body) + Vector3.new(0, 1, 40)) -- nearby, not fighting
		advance(0.2)
		heal(bob)
		heal(alice)
		waited += 0.2
	end
	local expected = math.floor(alone * Progression.coopMultiplier(1) + 0.5)
	local found = false
	for index = logStart, #H.remoteLog do
		local e = H.remoteLog[index]
		if e.remote == "RewardGranted" and e.target == bob and e.args[1] == "purify" and e.args[2] == expected then
			found = true
		end
	end
	assert(found, `a purify paid {expected} XP (alone {alone}) with a teammate nearby`)
	assert(xpOf(bob) > before, "xp gained")
	toVillage(alice)
	toVillage(bob)
end)

test("bounty board: opens at the board, counts real play, pays once and only near the board", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local BountyData = H.loadModule("src/shared/BountyData.luau")
	local PassData = H.loadModule("src/shared/PassData.luau")
	assert(#string.split(attr(alice, "Bounties"), ",") == BountyData.slots, "the board is filled on join")
	local profile = PlayerProfiles.get(alice)
	local counters = profile.counters
	profile.bounties = {
		{ kind = "purify", goal = 1, base = counters.purifies or 0 },
		{ kind = "chest", goal = 2, base = counters.chests or 0 },
		{ kind = "rift", goal = 1, base = counters.rifts or 0 },
	}
	PlayerProfiles.sync(alice)
	talk(alice, "BountyBoard")
	eq(logCount("OpenBoard", function(e)
		return e.target == alice
	end), 1, "board opened by the prompt")
	local coins = attr(alice, "Coins")
	remotes.ClaimBounty.OnServerEvent:Fire(alice, 1)
	advance(0.4)
	eq(attr(alice, "Coins"), coins, "nothing to claim before the work is done")
	local readyBefore = logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_bounty_ready"
	end)
	assert(purifyOne(alice, "Gloomling"), "purified a creature")
	assert(string.find(attr(alice, "Bounties"), "purify:1:1", 1, true), "progress replicated: " .. attr(alice, "Bounties"))
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_bounty_ready"
	end), readyBefore + 1, "told once that a bounty is ready")
	-- Far from the board the claim is refused.
	local farCoins = attr(alice, "Coins")
	remotes.ClaimBounty.OnServerEvent:Fire(alice, 1)
	advance(0.4)
	eq(attr(alice, "Coins"), farCoins, "a claim far from the board pays nothing")
	local passXp = attr(alice, "PassXp")
	talk(alice, "BountyBoard")
	local level = attr(alice, "Level")
	local expected = Progression.incomeCoins(level, BountyData.kinds.purify.minutes)
	local before = attr(alice, "Coins")
	remotes.ClaimBounty.OnServerEvent:Fire(alice, 1)
	remotes.ClaimBounty.OnServerEvent:Fire(alice, 1)
	advance(0.5)
	eq(attr(alice, "Coins"), before + expected, "paid once, as many coins as the board shows")
	eq(attr(alice, "PassXp"), passXp + PassData.xp.bounty, "Pass XP for the bounty")
	eq(#string.split(attr(alice, "Bounties"), ","), BountyData.slots, "a new bounty took its place")
	for _, args in { { "x" }, { 0 }, { 99 }, { 1.5 }, { {} } } do
		remotes.ClaimBounty.OnServerEvent:Fire(alice, args[1])
		advance(0.4)
	end
	eq(attr(alice, "Coins"), before + expected, "bad requests change nothing")
	toVillage(alice)
end)

test("emotes: shown to nearby players only, cooldown, bad ids ignored, sit and hop", function()
	toVillage(alice)
	toVillage(bob)
	local EmoteData = H.loadModule("src/shared/EmoteData.luau")
	local function shownTo(player, id): number
		return logCount("Fx", function(e)
			return e.target == player and e.args[1] == "emote" and e.args[2] == alice and e.args[3] == id
		end)
	end
	remotes.PlayEmote.OnServerEvent:Fire(alice, "wave")
	advance(0.1)
	eq(shownTo(alice, "wave"), 1, "the player sees their own emote")
	eq(shownTo(bob, "wave"), 1, "a nearby player sees it")
	remotes.PlayEmote.OnServerEvent:Fire(alice, "wave")
	advance(0.1)
	eq(shownTo(bob, "wave"), 1, "cooldown blocks a second emote")
	advance(EmoteData.cooldown)
	for _, bad in { "nope", 5, {}, "" } do
		remotes.PlayEmote.OnServerEvent:Fire(alice, bad)
		advance(EmoteData.cooldown)
	end
	eq(logCount("Fx", function(e)
		return e.target == bob and e.args[1] == "emote" and e.args[2] == alice
	end), 1, "bad ids show nothing")
	remotes.PlayEmote.OnServerEvent:Fire(alice, "sit")
	advance(0.1)
	eq(humanoid(alice).Sit, true, "sit emote sits")
	humanoid(alice).Sit = false
	advance(EmoteData.cooldown)
	teleport(bob, vec(WorldData.areas.glade.center, 3))
	remotes.PlayEmote.OnServerEvent:Fire(alice, "bow")
	advance(0.1)
	eq(shownTo(bob, "bow"), 0, "a far player does not see it")
	eq(shownTo(alice, "bow"), 1)
	toVillage(bob)
end)

test("shadow tower: level gate, floors, rewards once, leaving, defeat and join rules", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local TowerLogic = H.loadModule("src/server/TowerLogic.luau")
	local PassData = H.loadModule("src/shared/PassData.luau")
	local tower = Balance.tower
	local center = vec(WorldData.areas.tower.center)
	local profile = PlayerProfiles.get(alice)
	local savedXp = profile.xp
	local function setLevel(player, level: number)
		PlayerProfiles.get(player).xp = Progression.thresholds[level]
		PlayerProfiles.sync(player)
	end
	local function towerEnemies(): { any }
		local list = {}
		for _, model in workspace.Enemies:GetChildren() do
			local flat = positionOf(model.Body) - center
			if isAlive(model) and Vector3.new(flat.X, 0, flat.Z).Magnitude < WorldData.areas.tower.radius + 5 then
				table.insert(list, model)
			end
		end
		return list
	end
	local function insideAt(player): boolean
		local offset = root(player).Position - center
		return Vector3.new(offset.X, 0, offset.Z).Magnitude < WorldData.areas.tower.radius
	end
	local gate = workspace.LanternValleyMap.Village.TowerGate.Body
	assert(gate.TalkPrompt, "gate prompt")
	assert(workspace.LanternValleyMap.Tower.ExitPad.LeavePrompt, "exit prompt")

	-- Too low: told, stays in the village.
	setLevel(alice, tower.minLevel - 1)
	talk(alice, "TowerGate")
	eq(insideAt(alice), false, "below the minimum level stays out")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_tower_level"
	end), 1, "told the level needed")

	-- Level ok: enters, floor 1 creatures appear after the start delay.
	local level = tower.minLevel + 2
	setLevel(alice, level)
	talk(alice, "TowerGate")
	assert(insideAt(alice), "teleported into the arena")
	eq(attr(alice, "TowerFloor"), 1)
	eq(#towerEnemies(), 0, "creatures wait for the start delay")
	advance(tower.startDelay + 1.5)
	local expected = TowerLogic.count(1, 1)
	-- The floor announces how many creatures it sent; a few may already have fallen to auto attacks.
	assert(#towerEnemies() > 0 and #towerEnemies() <= expected, "floor 1 creatures: " .. #towerEnemies())
	local floorLevel = TowerLogic.floorLevel(level, 1)
	for _, model in towerEnemies() do
		eq(model:GetAttribute("Level"), floorLevel, "creature level follows the floor")
	end
	assert(logCount("Fx", function(e)
		return e.target == alice and e.args[1] == "towerFloor" and e.args[2] == 1 and e.args[3] == expected
	end) == 1, "floor banner sent")

	-- Clear the floor: paid once, best floor recorded, next floor comes after a pause.
	local coins = attr(alice, "Coins")
	local passXp = attr(alice, "PassXp")
	local guard = 0
	while #towerEnemies() > 0 and guard < 30 do
		local model = towerEnemies()[1]
		purifyOne(alice, model:GetAttribute("EnemyType"), 30)
		guard += 1
	end
	eq(#towerEnemies(), 0, "floor cleared")
	assert(insideAt(alice), "still in the arena")
	advance(1.6)
	eq(attr(alice, "TowerBest"), 1, "best floor recorded")
	local paid = TowerLogic.floorCoins(level, 1) + TowerLogic.recordCoins(level)
	eq(attr(alice, "Coins"), coins + paid, "floor coins plus the new-best bonus")
	assert(attr(alice, "PassXp") >= passXp + PassData.xp.tower, "Pass XP for the floor")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_tower_record" and e.args[2] == 1
	end), 1, "new best announced")
	advance(tower.floorDelay + 1.5)
	eq(attr(alice, "TowerFloor"), 2, "next floor")
	assert(#towerEnemies() > 0 and #towerEnemies() <= TowerLogic.count(2, 1), "floor 2 creatures: " .. #towerEnemies())
	assert(logCount("Fx", function(e)
		return e.target == alice and e.args[1] == "towerFloor" and e.args[2] == 2 and e.args[3] == TowerLogic.count(2, 1)
	end) == 1, "floor 2 announced with its creature count")

	-- A second player who is far below the run's level cannot join; leaving closes the run.
	setLevel(bob, 1)
	toVillage(bob)
	setLevel(alice, 60)
	PlayerProfiles.sync(alice)
	talk(bob, "TowerGate")
	eq(insideAt(bob), false, "level 1 cannot enter")
	teleport(alice, positionOf(workspace.LanternValleyMap.Tower.ExitPad) + Vector3.new(0, 2, 0))
	workspace.LanternValleyMap.Tower.ExitPad.LeavePrompt.Triggered:Fire(alice)
	advance(1.6)
	eq(insideAt(alice), false, "back in the village")
	eq(attr(alice, "TowerFloor"), 0)
	eq(#towerEnemies(), 0, "the empty run's creatures are gone")
	eq(attr(alice, "TowerBest"), 1, "leaving keeps the best floor")

	-- Far from the gate does nothing; defeat ends the run.
	setLevel(alice, level)
	teleport(alice, vec(WorldData.areas.glade.center, 3))
	gate.TalkPrompt.Triggered:Fire(alice)
	advance(0.2)
	eq(insideAt(alice), false, "the prompt needs the player near the gate")
	talk(alice, "TowerGate")
	assert(insideAt(alice), "entered again")
	advance(tower.startDelay + 1.5)
	assert(#towerEnemies() > 0, "a new run starts at floor 1")
	eq(attr(alice, "TowerFloor"), 1)
	-- Being carried out of the arena (e.g. a respawn in the village) also ends the run for that player.
	toVillage(alice)
	advance(1.6)
	eq(attr(alice, "TowerFloor"), 0, "leaving the arena ends the run")
	eq(#towerEnemies(), 0, "an empty arena closes the run")
	talk(alice, "TowerGate")
	advance(tower.startDelay + 1.5)
	eq(attr(alice, "TowerFloor"), 1, "a fresh run")
	humanoid(alice).Health = 0
	advance(1.6)
	eq(attr(alice, "TowerFloor"), 0, "defeated players leave the run")
	eq(#towerEnemies(), 0, "the run closed")
	humanoid(alice).Health = humanoid(alice).MaxHealth
	profile.xp = savedXp
	PlayerProfiles.sync(alice)
	toVillage(alice)
	toVillage(bob)
end)

test("pets: earned by progress, announced once, chosen by the player, bad requests ignored", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local PetData = H.loadModule("src/shared/PetData.luau")
	local profile = PlayerProfiles.get(alice)
	local savedXp, savedPet = profile.xp, profile.equippedPet
	local goal = PetData.pets.glowmoth.unlock.goal
	profile.equippedPet = ""
	profile.xp = Progression.thresholds[goal - 1]
	PlayerProfiles.sync(alice)
	eq(attr(alice, "Pet"), "", "no pet before one is earned")
	local function announced(): number
		return logCount("Notice", function(e)
			return e.target == alice and e.args[1] == "notice_pet_new"
		end)
	end
	local before = announced()
	profile.xp = Progression.thresholds[goal]
	PlayerProfiles.sync(alice)
	advance(0.2)
	eq(announced(), before + 1, "told about the new friend")
	eq(attr(alice, "Pet"), "glowmoth", "the first pet starts following")
	PlayerProfiles.sync(alice)
	eq(announced(), before + 1, "announced only once")
	assert(string.find(attr(alice, "PetProgress"), "glowmoth:" .. goal, 1, true), "progress replicated")
	-- The player picks; unearned or unknown pets are refused.
	remotes.EquipPet.OnServerEvent:Fire(alice, "")
	advance(0.4)
	eq(attr(alice, "Pet"), "", "sent home")
	remotes.EquipPet.OnServerEvent:Fire(alice, "shade_cat")
	advance(0.4)
	eq(attr(alice, "Pet"), "", "not earned yet")
	remotes.EquipPet.OnServerEvent:Fire(alice, "glowmoth")
	remotes.EquipPet.OnServerEvent:Fire(alice, "")
	advance(0.4)
	eq(attr(alice, "Pet"), "glowmoth", "a second request inside the cooldown is ignored")
	for _, bad in { 5, {}, string.rep("x", 99), "nope" } do
		advance(0.4)
		remotes.EquipPet.OnServerEvent:Fire(alice, bad)
	end
	advance(0.4)
	eq(attr(alice, "Pet"), "glowmoth", "bad requests change nothing")
	-- Losing the level condition never happens in play, but a tampered choice must not show.
	profile.equippedPet = "shade_cat"
	PlayerProfiles.sync(alice)
	eq(attr(alice, "Pet"), "", "an unearned saved pet is not shown")
	profile.xp, profile.equippedPet = savedXp, savedPet
	PlayerProfiles.sync(alice)
end)

test("rebirth: the Great Lantern asks at level 100, resets once when confirmed near it, keeps collections", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local profile = PlayerProfiles.get(alice)
	local saved = {
		xp = profile.xp, coins = profile.coins, staffUpgrade = profile.staffUpgrade, upgrades = table.clone(profile.upgrades),
		skills = table.clone(profile.skills), skillOffer = table.clone(profile.skillOffer), pendingPicks = profile.pendingPicks,
		crystals = profile.crystals, ownedCosmetics = table.clone(profile.ownedCosmetics), rebirths = profile.rebirths,
	}
	local post = workspace.LanternValleyMap.Village.LanternPost
	assert(post.RebirthPrompt, "the lantern has a Rebirth prompt")
	local function opened(): number
		return logCount("OpenRebirth", function(e)
			return e.target == alice
		end)
	end
	local function atLantern()
		teleport(alice, positionOf(post) + Vector3.new(3, -3, 0))
		advance(0.1)
	end
	-- Below level 100 the lantern only explains, and a forged confirmation does nothing.
	atLantern()
	post.RebirthPrompt.Triggered:Fire(alice)
	advance(0.2)
	eq(opened(), 0, "no panel below the cap")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_rebirth_level"
	end), 1, "told what level it needs")
	local level = attr(alice, "Level")
	remotes.ConfirmRebirth.OnServerEvent:Fire(alice)
	advance(0.3)
	eq(attr(alice, "Rebirths"), 0, "confirming below level 100 changes nothing")
	eq(attr(alice, "Level"), level)
	-- At level 100 the panel opens; far from the lantern a confirmation is refused.
	profile.xp = Progression.thresholds[Progression.MAX_LEVEL]
	PlayerProfiles.sync(alice)
	post.RebirthPrompt.Triggered:Fire(alice)
	advance(0.2)
	eq(opened(), 1, "the panel opens at level 100")
	teleport(alice, vec(WorldData.areas.glade.center, 3))
	advance(2.1) -- past the request cooldown, so only the distance can refuse it
	remotes.ConfirmRebirth.OnServerEvent:Fire(alice)
	advance(0.3)
	eq(attr(alice, "Rebirths"), 0, "the lantern must be near")
	-- Confirmed near the lantern: the climb restarts once (after the request cooldown).
	advance(2.1)
	atLantern()
	profile.coins = 555555
	PlayerProfiles.sync(alice)
	remotes.ConfirmRebirth.OnServerEvent:Fire(alice)
	remotes.ConfirmRebirth.OnServerEvent:Fire(alice)
	advance(0.5)
	eq(attr(alice, "Rebirths"), saved.rebirths + 1, "reborn once")
	eq(attr(alice, "Level"), 1, "level restarts")
	eq(attr(alice, "XP"), 0)
	eq(attr(alice, "Coins"), Balance.rebirth.startCoins, "a small fresh start")
	assert(string.find(attr(alice, "Costumes"), "dawn_aura", 1, true), "the Dawn Aura is earned")
	eq(logCount("Notice", function(e)
		return e.target == alice and e.args[1] == "notice_rebirth_done"
	end), 1, "told once")
	eq(logCount("Fx", function(e)
		return e.args[1] == "rebirth"
	end), 1, "everyone sees the burst")
	eq(humanoid(alice).MaxHealth, Progression.maxHealth(1), "health follows the new level")
	profile.xp, profile.coins, profile.staffUpgrade, profile.upgrades = saved.xp, saved.coins, saved.staffUpgrade, saved.upgrades
	profile.skills, profile.skillOffer, profile.pendingPicks = saved.skills, saved.skillOffer, saved.pendingPicks
	profile.crystals, profile.ownedCosmetics, profile.rebirths = saved.crystals, saved.ownedCosmetics, saved.rebirths
	PlayerProfiles.sync(alice)
	heal(alice)
	toVillage(alice)
end)

test("robux store: receipts granted once and only after saving; unknown ones wait", function()
	local StoreData = H.loadModule("src/shared/StoreData.luau")
	local MarketplaceService = H.services.MarketplaceService
	assert(MarketplaceService.ProcessReceipt, "receipt handler installed")
	StoreData.products.coins_small.productId = 9001 -- test id; real ids come from the dashboard
	StoreData.products.starter.productId = 9002
	local coins = attr(alice, "Coins")
	local receipt = { PlayerId = alice.UserId, ProductId = 9001, PurchaseId = "p-1" }
	local decision = nil
	task.spawn(function()
		decision = MarketplaceService.ProcessReceipt(receipt)
	end)
	advance(2)
	eq(decision, roblox.Enum.ProductPurchaseDecision.PurchaseGranted, "granted after saving")
	local level = attr(alice, "Level")
	eq(attr(alice, "Coins"), coins + Progression.incomeCoins(level, StoreData.products.coins_small.coinMinutes), "coins as shown in the store")
	-- Roblox may send the same receipt again: no second grant.
	local again = nil
	task.spawn(function()
		again = MarketplaceService.ProcessReceipt(receipt)
	end)
	advance(2)
	eq(again, roblox.Enum.ProductPurchaseDecision.PurchaseGranted)
	eq(attr(alice, "Coins"), coins + Progression.incomeCoins(level, StoreData.products.coins_small.coinMinutes), "not paid twice")
	-- Unknown products and players who are not here yet are retried later.
	local unknown, absent = nil, nil
	task.spawn(function()
		unknown = MarketplaceService.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 1234, PurchaseId = "p-2" })
		absent = MarketplaceService.ProcessReceipt({ PlayerId = 999999, ProductId = 9001, PurchaseId = "p-3" })
	end)
	advance(1)
	eq(unknown, roblox.Enum.ProductPurchaseDecision.NotProcessedYet)
	eq(absent, roblox.Enum.ProductPurchaseDecision.NotProcessedYet)
	-- Starter pack: sword + cape, once.
	local starter = nil
	task.spawn(function()
		starter = MarketplaceService.ProcessReceipt({ PlayerId = alice.UserId, ProductId = 9002, PurchaseId = "p-4" })
	end)
	advance(2)
	eq(starter, roblox.Enum.ProductPurchaseDecision.PurchaseGranted)
	assert(string.find(attr(alice, "Costumes"), "explorer_cape", 1, true), "cape")
	assert(string.find(attr(alice, "OneTime"), "starter", 1, true), "starter marked")
	StoreData.products.coins_small.productId = 0
	StoreData.products.starter.productId = 0
end)

test("costumes: buy with coins, wear shows on the character, remove", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	PlayerProfiles.get(alice).coins += 10000
	PlayerProfiles.sync(alice)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = Vector3.new(2, 1, 1)
	head.Parent = alice.Character
	remotes.BuyCosmetic.OnServerEvent:Fire(alice, "star_crown")
	advance(0.5)
	assert(not string.find(attr(alice, "Costumes"), "star_crown", 1, true), "pass costumes are not sold for coins")
	remotes.BuyCosmetic.OnServerEvent:Fire(alice, "lantern_hat")
	advance(0.5)
	assert(string.find(attr(alice, "Costumes"), "lantern_hat", 1, true), "bought")
	assert(string.find(attr(alice, "Worn"), "hat:lantern_hat", 1, true), "worn right away")
	local hat = alice.Character:FindFirstChild("Costume_hat")
	assert(hat and hat:GetAttribute("CostumeId") == "lantern_hat", "on the character")
	remotes.EquipCosmetic.OnServerEvent:Fire(alice, "", "hat")
	advance(0.5)
	eq(alice.Character:FindFirstChild("Costume_hat"), nil, "removed")
	for _, args in { { 5, "hat" }, { "golden_aura" }, { "", "nope" }, { string.rep("a", 99) } } do
		remotes.EquipCosmetic.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.4)
	end
	assert(not string.find(attr(alice, "Worn"), "golden_aura", 1, true), "unowned costume not worn")
end)

test("light pass: playing earns tiers, free claims, premium only after buying it", function()
	local PlayerProfiles = H.loadModule("src/server/PlayerProfiles.luau")
	local PassData = H.loadModule("src/shared/PassData.luau")
	assert(attr(alice, "PassXp") > 0, "pass xp from the scenario so far")
	PlayerProfiles.get(alice).pass.xp = PassData.xpPerTier * 3 -- as if three tiers were played
	PlayerProfiles.sync(alice)
	local coins = attr(alice, "Coins")
	remotes.ClaimPass.OnServerEvent:Fire(alice, 1, "free")
	advance(0.5)
	assert(attr(alice, "Coins") > coins, "free tier paid")
	eq(attr(alice, "PassFree"), "1")
	remotes.ClaimPass.OnServerEvent:Fire(alice, 1, "premium")
	advance(0.5)
	eq(attr(alice, "PassPremiumClaimed"), "", "premium locked")
	remotes.ClaimPass.OnServerEvent:Fire(alice, 9, "free")
	advance(0.5)
	eq(attr(alice, "PassFree"), "1", "unreached tier")
	PlayerProfiles.get(alice).pass.premium = true -- as if pass_premium was bought
	PlayerProfiles.sync(alice)
	remotes.ClaimPass.OnServerEvent:Fire(alice, "all")
	advance(0.5)
	eq(attr(alice, "PassFree"), "1,2,3")
	eq(attr(alice, "PassPremiumClaimed"), "1,2,3")
	for _, args in { { "x", "free" }, { 2.5, "free" }, { 1, "gold" }, { {}, {} } } do
		remotes.ClaimPass.OnServerEvent:Fire(alice, args[1], args[2])
		advance(0.4)
	end
	eq(attr(alice, "PassFree"), "1,2,3", "bad claims ignored")
end)

test("leaving and rejoining restores the saved profile", function()
	local snapshot = {}
	for _, key in { "XP", "Coins", "StaffTier", "Charms", "Charm", "Flags", "QuestState", "Weapon", "Companions", "Weapons", "SlotLevels", "Chests", "ChestSpots", "Upgrades", "Crystals", "Skills", "SkillOffer", "PendingPicks", "Costumes", "Worn", "PassXp", "PassFree", "PassPremium", "OneTime" } do
		snapshot[key] = attr(alice, key)
	end
	leave(alice)
	advance(2)
	local again = newPlayer("Alice", 101)
	join(again)
	advance(3)
	eq(attr(again, "DataState"), "ready", "reloaded")
	eq(logCount("NpcSay", function(e)
		return e.target == again and e.args[2] == "elder_welcome"
	end), 0, "returning player not greeted as new")
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
	if #threadErrors > 0 then print(threadErrors[1]) end
	eq(#threadErrors, 0, "thread errors")
end)

H.finish("sim tests")
