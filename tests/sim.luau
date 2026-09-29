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
		eq(logCount("NpcSay", function(e)
			return e.target == player and e.args[2] == "elder_welcome"
		end), 1, player.Name .. " welcomed once")
	end
	spawnCharacter(alice, vec(WorldData.spawn, 3))
	spawnCharacter(bob, vec(WorldData.spawn, 3))
	advance(0.5)
	local weapon = alice.Character:FindFirstChild("Weapon")
	assert(weapon, "weapon in hand")
	eq(weapon:GetAttribute("WeaponId"), "staff", "starter weapon")
	eq(attr(alice, "Weapon"), "staff")
	eq(attr(alice, "Companions"), "", "no floating weapons at level 1")
	eq(humanoid(alice).MaxHealth, 100)
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
	remotes.UpgradeStaff.OnServerEvent:Fire(alice)
	remotes.RequestWave.OnServerEvent:Fire(alice)
	remotes.RetryLoad.OnServerEvent:Fire(alice)
	advance(1)
	eq(attr(alice, "XP"), xp, "xp unchanged")
	eq(attr(alice, "Coins"), coins, "coins unchanged")
	eq(attr(alice, "StaffTier"), 0, "no upgrade from afar")
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
	assert(coins >= Balance.staff.tiers[2].cost, "enough coins without grinding: " .. coins)
	talk(alice, "Smith")
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
	eq(attr(alice, "QuestState"), "done")
	eq(attr(alice, "Flags"), "festival,gardens,lanterns")
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

test("weapon choice: unlocked weapons equip, the hand model swaps, attacks use it", function()
	eq(attr(alice, "Weapon"), "staff")
	assert(attr(alice, "Level") >= WeaponData.weapons.bow.unlockLevel, "bow unlocked by now")
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
	eq(attr(alice, "Companions"), "spear", "auto pick: strongest unlocked weapon not in use")
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
end)

test("leaving and rejoining restores the saved profile", function()
	local snapshot = {}
	for _, key in { "XP", "Coins", "StaffTier", "Charms", "Charm", "Flags", "QuestState", "Weapon", "Companions" } do
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
	eq(#threadErrors, 0, "thread errors")
end)

H.finish("sim tests")
