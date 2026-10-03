-- Run: lune run tests/client [desktop|touch]
-- Runs the real client code (src/client + src/shared) against Lune's Roblox Instances with a fake
-- LocalPlayer, instant tweens, fake input services and server events fired by hand. It checks that
-- every UI/effect/world path builds and reacts without runtime errors and sends the right requests.
-- Nothing is rendered: layout, readability and feel still need Studio and a real phone.
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local H = require("./harness")

local Instance, Vector3, Vector2, CFrame = roblox.Instance, roblox.Vector3, roblox.Vector2, roblox.CFrame
local Enum = roblox.Enum
local workspace = H.workspace
local remotes = H.remotes
local advance, test, eq, logCount = H.advance, H.test, H.eq, H.logCount

local mode = process.args[1] or "desktop"
local returning = mode == "returning"
local touchMode = mode == "touch" or mode == "touch-cas"
local withJumpButton = mode == "touch"

-- Client-side fake services -----------------------------------------------------------------

local Players = { list = {}, PlayerAdded = H.Signal.new(), PlayerRemoving = H.Signal.new() }
local hero = H.newPlayer("Hero", 1, Players)
local friend = H.newPlayer("Friend", 2, Players)
Players.LocalPlayer = hero
Players.list = { hero, friend }
function Players:GetPlayers()
	return table.clone(self.list)
end

local playerGui = Instance.new("PlayerGui")
function hero:WaitForChild(name: string)
	assert(name == "PlayerGui", "unexpected player child " .. name)
	return playerGui
end
hero.FindFirstChild = hero.WaitForChild

-- Roblox's touch controls: a jump button in the bottom-right corner of a 640x360 phone screen.
local JUMP_POSITION, JUMP_SIZE = Vector2.new(540, 250), Vector2.new(70, 70)
if withJumpButton then
	local touchGui = Instance.new("ScreenGui")
	touchGui.Name = "TouchGui"
	touchGui.IgnoreGuiInset = true
	touchGui.ResetOnSpawn = false -- as in Roblox: it outlives respawns
	local frame = Instance.new("Frame")
	frame.Name = "TouchControlFrame"
	frame.Parent = touchGui
	local jump = Instance.new("ImageButton")
	jump.Name = "JumpButton"
	jump.AbsolutePosition = JUMP_POSITION
	jump.AbsoluteSize = JUMP_SIZE
	jump.Parent = frame
	touchGui.Parent = playerGui
end

local camera = Instance.new("Camera")
camera.ViewportSize = if touchMode then Vector2.new(640, 360) else Vector2.new(1280, 720)
camera.CFrame = CFrame.new(0, 20, 60)
camera.Parent = workspace
workspace.CurrentCamera = camera
-- Where a test wants world points to land on the screen (nil: off screen).
local fakeScreenPoint: Vector3? = nil
-- The same for viewport points (the waypoint's edge arrow); nil: the projection fails, as before.
local fakeViewportPoint: Vector3? = nil
roblox.implementMethod("Camera", "WorldToViewportPoint", function(self)
	local point = fakeViewportPoint
	if not point then
		error("no projection in this test")
	end
	local size = self.ViewportSize
	return point, point.Z > 0 and point.X >= 0 and point.Y >= 0 and point.X <= size.X and point.Y <= size.Y
end)
roblox.implementMethod("Camera", "WorldToScreenPoint", function()
	return fakeScreenPoint or Vector3.new(-1000, -1000, -1), fakeScreenPoint ~= nil
end)

roblox.implementMethod("Model", "GetPivot", function(self)
	return self.PrimaryPart.CFrame
end)
roblox.implementMethod("Model", "PivotTo", function(self, cframe)
	self.PrimaryPart.CFrame = cframe
end)

local TweenService = {}
function TweenService:Create(instance, info, goal)
	local tween = { Completed = H.Signal.new() }
	function tween:Play()
		for key, value in goal do
			instance[key] = value
		end
		H.task.delay(info[1] or 0, function()
			tween.Completed:Fire(Enum.PlaybackState.Completed)
		end)
	end
	function tween:Cancel() end
	return tween
end

local actions = {}
local casButtons = {}
local ContextActionService = {}
function ContextActionService:BindAction(name: string, handler, createTouchButton: boolean)
	actions[name] = handler
	if casButtons[name] and not createTouchButton then
		-- Rebinding without a touch button removes the old one, as in Roblox.
		casButtons[name]:Destroy()
		casButtons[name] = nil
	end
	if createTouchButton and touchMode and not casButtons[name] then
		local holder = playerGui:FindFirstChild("ContextActionGui") or Instance.new("ScreenGui")
		holder.Name = "ContextActionGui"
		holder.ResetOnSpawn = false -- as in Roblox: it outlives respawns
		holder.Parent = playerGui
		local button = Instance.new("ImageButton")
		button.Name = name
		button.Parent = holder
		casButtons[name] = button
	end
end
function ContextActionService:SetTitle() end
function ContextActionService:GetButton(name: string)
	return casButtons[name]
end

H.services.Players = Players
H.services.TweenService = TweenService
H.services.ContextActionService = ContextActionService
-- Robux prices by product id (only ids a test sets up) and the purchase prompts that were shown.
local productPrices = { [7001] = 49, [7002] = 99, [7003] = 299 }
local prompts = {}
H.services.MarketplaceService = {
	GetProductInfo = function(_, productId: number)
		return { PriceInRobux = productPrices[productId] }
	end,
	PromptProductPurchase = function(_, _player, productId: number)
		table.insert(prompts, productId)
	end,
}
H.services.UserInputService = {
	TouchEnabled = touchMode,
	KeyboardEnabled = not touchMode,
	GetMouseLocation = function()
		return Vector2.new(500, 280)
	end,
	GetFocusedTextBox = function()
		return nil
	end,
	-- Tests switch it to a gamepad and fire LastInputTypeChanged.
	lastInputType = if touchMode then Enum.UserInputType.Touch else Enum.UserInputType.Keyboard,
	GetLastInputType = function(self)
		return self.lastInputType
	end,
	LastInputTypeChanged = H.Signal.new(),
	InputChanged = H.Signal.new(),
	InputBegan = H.Signal.new(),
	InputEnded = H.Signal.new(),
	TouchPinch = H.Signal.new(),
}
H.services.RunService = {
	Heartbeat = H.heartbeat,
	RenderStepped = H.renderStepped,
	BindToRenderStep = function(_, _name, _priority, fn)
		H.renderStepped:Connect(fn)
	end,
	IsStudio = function()
		return true
	end,
}
H.services.Debris = {
	AddItem = function(_, instance, seconds: number)
		H.task.delay(seconds, function()
			pcall(function()
				instance:Destroy()
			end)
		end)
	end,
}

-- World setup (what the server would have replicated) -----------------------------------------

local Strings = H.loadModule("src/shared/Strings.luau")
local WorldData = H.loadModule("src/shared/WorldData.luau")
local Balance = H.loadModule("src/shared/Balance.luau")
local MapBuilder = H.loadModule("src/server/MapBuilder.luau")
local EnemyModels = H.loadModule("src/server/EnemyModels.luau")
MapBuilder.build()

local enemiesFolder = Instance.new("Folder")
enemiesFolder.Name = "Enemies"
enemiesFolder.Parent = workspace

local nextEnemyId = 0
local function addEnemy(kind: string, position: any, attributes: { [string]: any }?)
	nextEnemyId += 1
	local stats = Balance.enemies[kind]
	local model = EnemyModels.build(kind, stats, CFrame.new(position))
	model:SetAttribute("EnemyId", nextEnemyId)
	model:SetAttribute("EnemyType", kind)
	model:SetAttribute("Boss", stats.isBoss == true)
	model:SetAttribute("Alive", true)
	model:SetAttribute("Hp", stats.maxHp)
	model:SetAttribute("MaxHp", stats.maxHp)
	for key, value in attributes or {} do
		model:SetAttribute(key, value)
	end
	H.addChild(enemiesFolder, model)
	return model
end

-- The name, level and health label over each creature (it lives on the creature's body).
local function enemyLabels(): { BillboardGui }
	local found = {}
	for _, gui in enemiesFolder:GetDescendants() do
		if gui:IsA("BillboardGui") and gui.Name == "LvLabel" then
			table.insert(found, gui)
		end
	end
	return found
end

local function makeCharacter(name: string, position: any)
	local character = Instance.new("Model")
	character.Name = name
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Position = position
	root.CFrame = CFrame.new(position)
	root.Parent = character
	local upperArm = Instance.new("Part")
	upperArm.Name = "RightUpperArm"
	upperArm.Parent = character
	local shoulder = Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.Parent = upperArm
	character.Parent = workspace
	return character
end

local function vec(p: { number }, lift: number?): any
	return Vector3.new(p[1], p[2] + (lift or 0), p[3])
end

hero.Character = makeCharacter("Hero", vec(WorldData.spawn, 3))
friend.Character = makeCharacter("Friend", vec(WorldData.spawn, 3) + Vector3.new(4, 0, 0))

local function teleport(position: any)
	local root = hero.Character.HumanoidRootPart
	root.Position = position
	root.CFrame = CFrame.new(position)
end

-- GUI query helpers -------------------------------------------------------------------------------

local function isShown(object): boolean
	local current = object
	while current and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("LayerCollector") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return current == playerGui
end

local function findText(text: string, root: any?): any
	for _, descendant in (root or playerGui):GetDescendants() do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == text then
			return descendant
		end
	end
	return nil
end

local function findButton(text: string): any
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextButton") and descendant.Text == text then
			return descendant
		end
	end
	return nil
end

local function shownText(text: string): boolean
	for _, descendant in playerGui:GetDescendants() do
		if (descendant:IsA("TextLabel") or descendant:IsA("TextButton")) and descendant.Text == text and isShown(descendant) then
			return true
		end
	end
	return false
end

local function click(button)
	assert(button, "button not found")
	button.Activated:Fire()
	advance(0.1)
end

local function sent(remote: string, predicate: ((any) -> boolean)?): number
	return logCount(remote, function(entry)
		return entry.direction == "toServer" and (predicate == nil or predicate(entry.args))
	end)
end

local function setAttributes(values: { [string]: any })
	for key, value in values do
		hero:SetAttribute(key, value)
	end
	advance(0.2)
end

-- Scenario ---------------------------------------------------------------------------------------

if returning then
	-- A returning level-5 player whose saved profile arrives right after joining.
	test("returning player: saved progress is not replayed as new unlocks", function()
		hero:SetAttribute("DataState", "loading")
		H.task.spawn(H.run, "src/client/init.client.luau")
		advance(1)
		setAttributes({
			Level = 5,
			XP = 500,
			Coins = 30,
			StaffTier = 1,
			Charm = "swift",
			Charms = "guard,swift",
			Flags = "gardens,lanterns",
			QuestId = "ruin_vines",
			QuestState = "available",
			SkillOffer = "swift,sharp,wave",
			PendingPicks = 1,
			DataState = "ready",
		})
		advance(0.3)
		assert(not shownText(Strings.get("skills_title")), "a saved offer does not pop up by itself")
		assert(shownText(Strings.get("skill_button", 1)), "but the pick button is there")
		for _, flag in { "gardens", "lanterns" } do
			assert(workspace.ClientWorld:FindFirstChild("Restoration_" .. flag), "restoration " .. flag)
		end
		assert(not shownText(Strings.get("hint_wave_pc")), "no 'wave unlocked' hint for saved levels")
		assert(not shownText(Strings.get("notice_wave_unlocked")), "no unlock banner for saved levels")
		eq(#workspace.ClientFx:GetChildren(), 0, "no celebration bursts for saved restorations")
		for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
	end)
	H.finish("client tests (returning)")
	return
end

local enemies = {}
local wardenIndex = 0
for index, spawn in WorldData.spawns do
	if spawn.kind == "Warden" then
		wardenIndex = index
	end
end
test("client boots with every module", function()
	for index, spawn in WorldData.spawns do
		if index <= 4 or spawn.kind == "Warden" then
			enemies[index] = addEnemy(spawn.kind, vec(spawn.position, Balance.enemies[spawn.kind].hoverHeight))
		end
	end
	hero:SetAttribute("DataState", "loading")
	H.task.spawn(H.run, "src/client/init.client.luau")
	advance(1)
	if #H.threadErrors > 0 then error(H.threadErrors[1]) end
	for _, name in { "Hud", "Controls", "Menus" } do
		assert(playerGui:FindFirstChild(name), name .. " gui")
	end
	assert(workspace:FindFirstChild("ClientFx"), "fx folder")
	assert(workspace:FindFirstChild("ClientWorld"), "world folder")
	assert(shownText(Strings.get("data_loading")), "loading label shown")
	eq(#enemyLabels(), 4, "a billboard per non-boss enemy")
end)

test("data ready: HUD, quest panel, Elder marker, waypoint", function()
	setAttributes({
		Level = 1,
		XP = 0,
		Coins = 0,
		StaffTier = 0,
		Charm = "",
		Charms = "",
		Flags = "",
		QuestId = "first_purify",
		QuestState = "available",
		DataState = "ready",
	})
	advance(0.5)
	assert(not shownText(Strings.get("data_loading")), "loading hidden")
	assert(shownText(Strings.get("quest_talk_to", Strings.get("npc_elder_name"))), "quest hint")
	assert(shownText(Strings.get("hud_level", 1)), "level badge")
	local elderMarker = false
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee == workspace.LanternValleyMap.Village.Elder.Body then
			elderMarker = true
		end
	end
	assert(elderMarker, "Elder ! marker enabled")
	assert(findText("20m") or findText("15m") or findText("14m") or findText("13m"), "waypoint distance shown")
end)

test("quests from Ranger Wren: hint, marker and waypoint follow the giver", function()
	local function markerOn(npcName: string): boolean
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Enabled and child.Adornee == workspace.LanternValleyMap.Village[npcName].Body then
				return true
			end
		end
		return false
	end
	setAttributes({ QuestId = "marsh_scouts", QuestState = "available", Level = 10 })
	advance(0.5)
	assert(shownText(Strings.get("quest_talk_to", Strings.get("npc_wren_name"))), "hint names Ranger Wren")
	assert(markerOn("Wren"), "! over Wren")
	assert(not markerOn("Elder"), "no ! over the Elder")
	local wren = WorldData.vector(WorldData.npcs.Wren.position)
	local found = false
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee and child.Adornee.Name == "WaypointAnchor" then
			found = (H.read(child.Adornee, "Position") - wren).Magnitude < 1
		end
	end
	assert(found, "the waypoint guides to Wren")
	-- An active counter quest shows its progress like any other.
	setAttributes({ QuestId = "rift_watch", QuestState = "active", QuestCount = 0, QuestGoal = 1 })
	advance(0.3)
	assert(shownText(Strings.get("quest_rift_watch_objective", 0, 1)), "counter quest objective")
	assert(not markerOn("Wren"), "no ! while the quest runs")
	setAttributes({ QuestId = "first_purify", QuestState = "available", Level = 1 })
	advance(0.5)
	assert(markerOn("Elder"), "the Elder's ! is back")
end)

test("Kael the Keeper: hidden until the Shadow King falls, then the ! and the waypoint lead to him", function()
	local kael = workspace.LanternValleyMap.Village.Kael
	local function markerOn(npcName: string): boolean
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Enabled and child.Adornee == workspace.LanternValleyMap.Village[npcName].Body then
				return true
			end
		end
		return false
	end
	local function visible(): boolean
		return H.read(kael.Body, "LocalTransparencyModifier") == 0 and kael.Body.TalkPrompt.Enabled
	end
	setAttributes({ QuestId = "shadow_king", QuestState = "active", QuestCount = 0, QuestGoal = 1, Level = 60 })
	advance(0.5)
	assert(not visible(), "Kael is not in the village yet")
	assert(not kael.Body.CanCollide, "and not solid before that")
	assert(not markerOn("Kael"), "no ! over a hidden Kael")
	setAttributes({ QuestId = "keepers_promise", QuestState = "available", Level = 95 })
	advance(0.5)
	assert(visible(), "Kael appears after the Shadow King")
	assert(kael.Body.CanCollide, "and is solid again")
	assert(markerOn("Kael"), "! over Kael")
	assert(not markerOn("Elder") and not markerOn("Wren"), "no ! over the others")
	assert(shownText(Strings.get("quest_talk_to", Strings.get("npc_kael_name"))), "hint names Kael")
	setAttributes({ QuestId = "first_purify", QuestState = "available", Level = 1 })
	advance(0.5)
end)

test("signposts: a ! over the Bounty Board with a bounty to claim and over the Tower gate for newcomers", function()
	local Balance = H.loadModule("src/shared/Balance.luau")
	local function markerOn(name: string): boolean
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Enabled and child.Adornee == workspace.LanternValleyMap.Village[name].Body then
				return true
			end
		end
		return false
	end
	setAttributes({ Level = 3, Bounties = "purify:40:12,chest:2:0,rift:1:0", TowerBest = 0, TowerFloor = 0 })
	advance(0.3)
	assert(not markerOn("BountyBoard"), "nothing to claim yet")
	assert(not markerOn("TowerGate"), "the tower is not open at this level")
	setAttributes({ Bounties = "purify:40:40,chest:2:0,rift:1:0" })
	assert(markerOn("BountyBoard"), "a finished bounty waits at the board")
	setAttributes({ Bounties = "purify:40:0,chest:2:0,rift:1:0" })
	assert(not markerOn("BountyBoard"), "claimed")
	setAttributes({ Level = Balance.tower.minLevel })
	assert(markerOn("TowerGate"), "the gate calls a player who can enter")
	setAttributes({ TowerFloor = 2 })
	assert(not markerOn("TowerGate"), "not while inside")
	setAttributes({ TowerFloor = 0, TowerBest = 1 })
	assert(not markerOn("TowerGate"), "not after the first climb")
	setAttributes({ Level = 1, TowerBest = 0, Bounties = "" })
end)

test("server events render: rewards, notices, dialog, effects", function()
	advance(2.5) -- let an earlier banner finish (banners hide toasts while they show)
	remotes.RewardGranted.OnClientEvent:Fire("purify", 10, 5)
	remotes.RewardGranted.OnClientEvent:Fire("quest", 50, 20)
	remotes.Notice.OnClientEvent:Fire("notice_charm_gained", "charm_swift_name")
	remotes.NpcSay.OnClientEvent:Fire("Elder", "elder_need_level", 3)
	advance(0.2)
	assert(shownText(Strings.get("reward_quest", 50, 20)), "quest toast")
	-- Purify XP pops beside the XP bar (not a toast over the fight), summed while it shows.
	local gain = playerGui.Hud:FindFirstChild("XpGain", true)
	assert(isShown(gain) and gain.Text == Strings.get("hud_xp_gain", "10"), "purify XP beside the XP bar")
	for _ = 1, 5 do
		remotes.RewardGranted.OnClientEvent:Fire("purify", 12, 0)
	end
	advance(0.2)
	eq(gain.Text, Strings.get("hud_xp_gain", "70"), "a pack sums up")
	for _, toast in playerGui.Hud:GetDescendants() do
		if toast.Name == "Toast" then
			assert(not string.find(toast:FindFirstChildOfClass("TextLabel").Text, "70", 1, true), "no toast for it")
		end
	end
	advance(2.5)
	assert(not isShown(gain), "then it fades")
	assert(shownText(Strings.get("notice_charm_gained", Strings.get("charm_swift_name"))), "translated notice")
	assert(shownText(Strings.get("elder_need_level", 3)), "dialog line")

	local gloom = enemies[1]
	local at = H.read(gloom.Body, "Position")
	local fx = remotes.Fx.OnClientEvent
	fx:Fire("bolt", friend, at + Vector3.new(0, 0, 10), at, 1)
	fx:Fire("hit", gloom, at, 27)
	fx:Fire("wave", friend, at, 14, 2)
	fx:Fire("projectile", 1, at, Vector3.new(0, 0, 30), 2, 1.3, "spore")
	fx:Fire("projectile", 2, at, Vector3.new(30, 0, 0), 4, 1.6, "shadow")
	fx:Fire("projectileEnd", 1, at)
	fx:Fire("telegraph", at, 7, 1.4)
	fx:Fire("slam", at, 7)
	fx:Fire("windup", gloom, 0.9)
	fx:Fire("bossPhase", enemies[wardenIndex])
	fx:Fire("levelUp", friend, 2)
	fx:Fire("upgrade", friend, 1)
	fx:Fire("purify", at, "Gloomling", Vector3.new(0, 0, 1))
	fx:Fire("purify", at, "Warden", Vector3.new(0, 0, 1))
	fx:Fire("questComplete", "first_purify")
	fx:Fire("collected", "flower_1", vec(WorldData.flowers.flower_1))
	fx:Fire("discovered", "old_oak", vec(WorldData.landmarks.old_oak.position))
	fx:Fire("vineCleared", "vine_1")
	fx:Fire("unknownKind", 1, 2, 3)
	advance(0.3)
	assert(#workspace.ClientFx:GetChildren() > 0, "effects spawned")
	assert(shownText(Strings.get("banner_quest_complete")), "quest banner")
	assert(isShown(playerGui.Hud:FindFirstChild("QuestTick", true)), "a green tick on the quest panel")
	advance(6)
	eq(#workspace.ClientFx:GetChildren(), 0, "effects cleaned up")
end)

test("automatic attacks from the server render for every weapon style", function()
	local WeaponData = H.loadModule("src/shared/WeaponData.luau")
	local root = hero.Character.HumanoidRootPart
	local origin = H.read(root, "Position") + Vector3.new(0, 1.5, 0)
	for _, weaponId in WeaponData.order do
		for _, slot in { 0, 1 } do
			advance(1) -- let earlier effects finish so the count only sees this attack
			local before = #workspace.ClientFx:GetChildren()
			remotes.Fx.OnClientEvent:Fire("attack", hero, weaponId, slot, origin, origin + Vector3.new(4, 0, -8), 0)
			advance(0.05)
			assert(#workspace.ClientFx:GetChildren() > before, `{weaponId} slot {slot} drew an effect`)
		end
	end
	remotes.Fx.OnClientEvent:Fire("attack", hero, "not-a-weapon", 0, origin, origin, 0)
	advance(1)
	for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
	eq(sent("EquipWeapon"), 0, "attacks never ask anything from the client")
end)

test("camera follows from above and the range ring matches the main weapon", function()
	local WeaponData = H.loadModule("src/shared/WeaponData.luau")
	local root = hero.Character.HumanoidRootPart
	advance(0.5)
	eq(camera.CameraType, Enum.CameraType.Scriptable, "scripted camera")
	local eye = camera.CFrame.Position
	local rootPosition = H.read(root, "Position")
	assert(eye.Y > rootPosition.Y + 20, "camera sits high above the player")
	assert(eye.Z > rootPosition.Z, "and behind")
	local ring = workspace.ClientRing.RangeRing
	eq(ring.Visible, true, "ring shown")
	eq(ring.Radius, WeaponData.weapons.staff.range, "staff range")
	setAttributes({ Weapon = "sword" })
	advance(0.1)
	eq(ring.Radius, WeaponData.weapons.sword.range, "ring follows the equipped weapon")
	advance(1)
	setAttributes({ Weapon = "staff" })
	assert(workspace.ClientFx:FindFirstChild("WeaponGlint"), "a newly equipped weapon flashes in the hand")
	advance(1)
end)

test("floating weapons hover behind their player", function()
	setAttributes({ Companions = "sword,bow" })
	advance(0.1)
	local models = workspace.Companions:GetChildren()
	eq(#models, 2, "one model per slot")
	local root = H.read(hero.Character.HumanoidRootPart, "Position")
	for _, model in models do
		local position = model.PrimaryPart.CFrame.Position
		assert((position - root).Magnitude < 8, "near the player")
		assert(position.Y > root.Y, "hovering")
	end
	setAttributes({ Companions = "" })
	advance(0.1)
	eq(#workspace.Companions:GetChildren(), 0, "removed when the slots are empty")
end)

test("a cancelled boss attack clears its warning circles", function()
	local at = vec(WorldData.areas.arena.center)
	remotes.Fx.OnClientEvent:Fire("telegraph", at, 7, 1.4)
	remotes.Fx.OnClientEvent:Fire("telegraph", at + Vector3.new(8, 0, 0), 7, 1.4)
	advance(0.1)
	local before = #workspace.ClientFx:GetChildren()
	assert(before >= 4, "telegraph discs drawn")
	remotes.Fx.OnClientEvent:Fire("attackCancel", enemies[wardenIndex])
	advance(0.1)
	eq(#workspace.ClientFx:GetChildren(), before - 4, "warnings removed")
	advance(2)
end)

test("creature decorations animate near the camera and stop with Low effects", function()
	local model = addEnemy("Hexcap", Vector3.new(0, 3, 30))
	advance(0.2)
	local rune = model:FindFirstChild("Rune1")
	local weld = rune and rune:FindFirstChildOfClass("Weld")
	assert(weld, "Hexcap runes are animated")
	local before = weld.C0
	advance(0.4)
	assert(weld.C0 ~= before, "the runes circle")
	setAttributes({ Pref_quality = "custom", Pref_effects = "low", Pref_shadows = true, Pref_bloom = true, Pref_atmosphere = true, Pref_detail = "high" })
	local still = weld.C0
	advance(0.4)
	eq(weld.C0, still, "nothing moves with Low effects")
	setAttributes({ Pref_quality = "auto" })
	model:Destroy()
	advance(0.1)
end)

test("music follows the place and one track fades out before the next fades in", function()
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local SoundService = H.game:GetService("SoundService")
	local home = H.read(hero.Character.HumanoidRootPart, "Position")
	local function audible(): { string }
		local names = {}
		for _, sound in SoundService:GetChildren() do
			if sound:IsA("Sound") and sound.Name:sub(1, 6) == "Music_" and sound.Playing and sound.Volume > 0 then
				table.insert(names, sound.Name)
			end
		end
		return names
	end
	teleport(vec(WorldData.spawn, 3))
	advance(3)
	local village = SoundService:FindFirstChild("Music_village")
	assert(village and village.Looped and village.SoundId == Sounds.music.tracks.village, "village music loops")
	assert(math.abs(village.Volume - Sounds.music.volume) < 0.01, "village music at full volume")
	teleport(vec(WorldData.areas.arena.center, 3))
	advance(0.5)
	eq(audible()[1], "Music_village", "a short visit does not change the music")
	for _ = 1, 40 do
		advance(0.1)
		assert(#audible() <= 1, "never two tracks at once")
	end
	eq(audible()[1], "Music_boss", "boss music in the arena")
	eq(village.Playing, false, "the village track stopped")
	setAttributes({ Pref_sound = false })
	eq(#audible(), 0, "sound off: music stops")
	setAttributes({ Pref_sound = true })
	eq(audible()[1], "Music_boss", "sound on: music plays again")
	teleport(home)
	advance(5)
	eq(audible()[1], "Music_village", "back home")
end)

test("creature attacks: dust and sounds for chargers, shooters, blinkers and slams", function()
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local here = H.read(hero.Character.HumanoidRootPart, "Position")
	local function sounds(key: string): number
		local count = 0
		for _, descendant in workspace.ClientFx:GetDescendants() do
			if descendant:IsA("Sound") and descendant.SoundId == Sounds[key].id and math.abs(descendant.PlaybackSpeed - (Sounds[key].pitch or 1)) < 0.01 then
				count += 1
			end
		end
		return count
	end
	local function dustCount(): number
		local count = 0
		for _, child in workspace.ClientFx:GetChildren() do
			if child:IsA("Part") and child.Shape == Enum.PartType.Ball and child.Color == roblox.Color3.fromRGB(190, 170, 140) then
				count += 1
			end
		end
		return count
	end
	-- A charger paws the ground, then kicks up a dust trail and lands.
	local rock = addEnemy("Rockling", here + Vector3.new(8, 0, 0))
	remotes.Fx.OnClientEvent:Fire("windup", rock, 0.5)
	advance(0.2)
	eq(sounds("creatureCharge"), 1, "charge sound at the creature")
	assert(dustCount() > 0, "pawing dust")
	advance(0.5)
	eq(sounds("creatureDash"), 1, "dash sound")
	advance(0.9)
	eq(sounds("creatureLand"), 1, "landing sound")
	-- A shooter pops when the shot leaves.
	local spore = addEnemy("Sporeling", here + Vector3.new(-8, 0, 0))
	remotes.Fx.OnClientEvent:Fire("windup", spore, 0.3)
	advance(0.4)
	eq(sounds("creatureShoot"), 1, "shot pop")
	-- Boss slams thump where they land.
	remotes.Fx.OnClientEvent:Fire("slam", here + Vector3.new(0, 0, 6), 6)
	advance(0.05)
	eq(sounds("slam"), 1, "slam thump")
	local thump = workspace.ClientFx:FindFirstChild("Sfx_slam", true)
	assert(thump.PlaybackRegionsEnabled and math.abs(thump.PlaybackRegion.Max - Sounds.slam.length) < 0.01, "long file cut short")
	-- Far away nothing plays; with sound off nothing plays either.
	local far = addEnemy("Rockling", here + Vector3.new(400, 0, 0))
	advance(0.5)
	local charges = sounds("creatureCharge")
	remotes.Fx.OnClientEvent:Fire("windup", far, 0.3)
	advance(0.1)
	eq(sounds("creatureCharge"), charges, "no sound for creatures far away")
	setAttributes({ Pref_sound = false })
	remotes.Fx.OnClientEvent:Fire("windup", rock, 0.3)
	advance(0.1)
	eq(sounds("creatureCharge"), charges, "sound off: silent")
	setAttributes({ Pref_sound = true })
	for _, model in { rock, spore, far } do
		model:Destroy()
	end
	advance(1)
end)

test("the top level: its own banner and confetti", function()
	local Progression = H.loadModule("src/shared/Progression.luau")
	local level = hero:GetAttribute("Level")
	setAttributes({ Level = Progression.MAX_LEVEL - 1 })
	advance(4)
	setAttributes({ Level = Progression.MAX_LEVEL })
	assert(shownText(Strings.get("banner_max_level", Progression.MAX_LEVEL)), "max level banner")
	assert(shownText(Strings.get("banner_max_level_sub")), "it says the lantern can rebirth you")
	assert(playerGui.Hud:FindFirstChild("Confetti", true), "confetti")
	advance(4)
	eq(playerGui.Hud:FindFirstChild("Confetti", true), nil, "gone after a few seconds")
	setAttributes({ Level = level })
	advance(4)
end)

test("light wave is locked until level 3", function()
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 0, "locked")
	setAttributes({ Level = 3, XP = 150 })
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 1, "sent when unlocked")
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 1, "local cooldown")
	assert(shownText(Strings.get("notice_wave_unlocked")), "unlock banner")
	-- Other unlocks are named on the level-up banner too.
	setAttributes({ Level = Balance.tower.minLevel - 1 })
	setAttributes({ Level = Balance.tower.minLevel })
	assert(shownText(Strings.get("notice_heal_unlocked")), "the ability is the banner's news")
	local announced = false
	for _ = 1, 16 do
		advance(0.5)
		announced = announced or shownText(Strings.get("hud_unlocked", Strings.get("unlock_tower")))
	end
	assert(announced, "the tower opening follows as a toast")
	setAttributes({ Level = 3 })
end)

test("Star Fall and Lantern Glow: locked by level, need a target / missing health, local cooldown", function()
	local function casts(id: string): number
		return sent("RequestAbility", function(args)
			return args[1] == id
		end)
	end
	local character = hero.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	setAttributes({ Level = 5 })
	actions.LvStarFall("LvStarFall", Enum.UserInputState.Begin, {})
	actions.LvLanternGlow("LvLanternGlow", Enum.UserInputState.Begin, {})
	eq(casts("star") + casts("heal"), 0, "both locked below their levels")
	setAttributes({ Level = 10 })
	humanoid.Health = humanoid.MaxHealth
	actions.LvLanternGlow("LvLanternGlow", Enum.UserInputState.Begin, {})
	eq(casts("heal"), 0, "no glow at full health")
	humanoid.Health = humanoid.MaxHealth * 0.5
	actions.LvLanternGlow("LvLanternGlow", Enum.UserInputState.Begin, {})
	eq(casts("heal"), 1, "glow when hurt")
	actions.LvLanternGlow("LvLanternGlow", Enum.UserInputState.Begin, {})
	eq(casts("heal"), 1, "glow cooldown")
	humanoid.Health = humanoid.MaxHealth
	-- Star Fall needs a living creature in reach.
	local saved = H.read(rootPart, "Position")
	rootPart.Position = Vector3.new(0, 3, 5000)
	rootPart.CFrame = CFrame.new(rootPart.Position)
	actions.LvStarFall("LvStarFall", Enum.UserInputState.Begin, {})
	eq(casts("star"), 0, "no creature in reach: nothing cast")
	rootPart.Position = saved
	rootPart.CFrame = CFrame.new(saved)
	local target = nil
	for _, model in workspace.Enemies:GetChildren() do
		if model:GetAttribute("Alive") and model:FindFirstChild("Body") then
			target = model
			break
		end
	end
	assert(target, "a living creature for the test")
	rootPart.Position = H.read(target.Body, "Position") + Vector3.new(0, 0, 6)
	rootPart.CFrame = CFrame.new(rootPart.Position)
	actions.LvStarFall("LvStarFall", Enum.UserInputState.Begin, {})
	eq(casts("star"), 1, "star cast at a creature in reach")
	actions.LvStarFall("LvStarFall", Enum.UserInputState.Begin, {})
	eq(casts("star"), 1, "star cooldown")
	rootPart.Position = saved
	rootPart.CFrame = CFrame.new(saved)
	-- The server's effects play for every player without errors.
	remotes.Fx.OnClientEvent:Fire("ability", hero, "star", H.read(target.Body, "Position"), 0)
	remotes.Fx.OnClientEvent:Fire("ability", friend, "heal", saved, 40)
	local healShown = false
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("TextLabel") and descendant.Text == "+40" then
			healShown = true
		end
	end
	assert(healShown, "heal amount shown")
	advance(1)
	setAttributes({ Level = 3 })
end)

test("quest 2 flowers are personal, collectable and disappear when found", function()
	setAttributes({ QuestId = "lantern_flowers", QuestState = "active", QuestCount = 0, QuestGoal = 5, QuestFound = "" })
	local count = 0
	for _, child in workspace.ClientWorld:GetChildren() do
		if string.match(child.Name, "^Flower_") then
			count += 1
		end
	end
	eq(count, 5, "five flowers")
	local prompt = workspace.ClientWorld.Flower_flower_2:FindFirstChildWhichIsA("ProximityPrompt", true)
	prompt.Triggered:Fire()
	advance(0.1)
	eq(sent("Interact", function(args)
		return args[1] == "flower" and args[2] == "flower_2"
	end), 1, "interact sent")
	setAttributes({ QuestFound = "flower_2", QuestCount = 1 })
	eq(workspace.ClientWorld:FindFirstChild("Flower_flower_2"), nil, "collected flower removed")
	assert(shownText(Strings.get("quest_lantern_flowers_objective", 1, 5)), "objective text")
end)

test("exploration beacons, vine barrier and restoration follow progress", function()
	setAttributes({ QuestId = "forest_explore", QuestState = "active", QuestFound = "", QuestCount = 0, QuestGoal = 3 })
	local beacons, vines, barrier = 0, 0, false
	for _, child in workspace.ClientWorld:GetChildren() do
		if child.Name == "Beacon" then
			beacons += 1
		elseif child.Name == "Vine" then
			vines += 1
		elseif child:IsA("BasePart") and child.CanCollide then
			barrier = true
		end
	end
	eq(beacons, 3, "beacons")
	eq(vines, 3, "vines before the ruins quest")
	assert(barrier, "gate barrier")
	eq(workspace.ClientWorld:FindFirstChild("Flower_flower_1"), nil, "flowers gone after quest 2")

	setAttributes({ QuestId = "warden", QuestState = "available", QuestFound = "" })
	for _, child in workspace.ClientWorld:GetChildren() do
		assert(child.Name ~= "Vine" and child.Name ~= "Beacon", "cleared " .. child.Name)
		assert(not (child:IsA("BasePart") and child.CanCollide), "barrier removed")
	end

	setAttributes({ Flags = "festival,gardens,lanterns,reunion" })
	for _, flag in { "gardens", "lanterns", "festival", "reunion" } do
		assert(workspace.ClientWorld:FindFirstChild("Restoration_" .. flag), "restoration " .. flag)
	end
	teleport(vec(WorldData.spawn, 3))
	local wing = nil
	for _, child in workspace.ClientWorld.Restoration_gardens:GetChildren() do
		if child:IsA("BasePart") and child.Material == Enum.Material.Neon and child.Size.X < 1 then
			wing = child
		end
	end
	assert(wing, "butterflies with the gardens")
	local before = wing.CFrame
	advance(0.3)
	assert(wing.CFrame ~= before, "butterflies flutter near the village")
end)

test("upgrade nudge and Smith marker appear when coins suffice", function()
	local Progression = H.loadModule("src/shared/Progression.luau")
	setAttributes({ Coins = Progression.upgradeCost("power", 0) })
	assert(shownText(Strings.get("notice_can_upgrade")), "nudge toast")
	local smithMarker = false
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee == workspace.LanternValleyMap.Village.Smith.Body then
			smithMarker = true
		end
	end
	assert(smithMarker, "Smith ! marker")
end)

test("weapons menu: main weapon, floating slots, locked ones do nothing", function()
	local WeaponData = H.loadModule("src/shared/WeaponData.luau")
	setAttributes({ Level = 3, Weapon = "staff", Companions = "", Weapons = "staff", SlotLevels = "2,0,0,0,0" })
	click(findButton(Strings.get("menu_weapons")))
	assert(shownText(Strings.get("bag_main_hint")), "weapons menu open")
	assert(findButton(Strings.get("slot_level", Strings.get("bag_main"), 2)), "main slot shows its level")
	local bow = WeaponData.weapons.bow
	click(findButton(Strings.get("weapon_find_named", Strings.get(bow.nameKey))))
	eq(sent("EquipWeapon"), 0, "a weapon not found yet is not equipped")
	assert(shownText(Strings.get("weapon_locked_info", Strings.get(WeaponData.rarities[bow.rarity].nameKey), Strings.get(bow.descKey))), "but it says what it is")
	click(findButton(Strings.get("weapon_locked", 25)))
	assert(shownText(Strings.get("bag_main_hint")), "closed slot does not open")
	setAttributes({ Level = 25, Companions = "spear", Weapons = "bow,spear,staff,sword" })
	local Progression = H.loadModule("src/shared/Progression.luau")
	local swordGap = Progression.weaponDamage("sword", 0, 25, false, 2, nil) - Progression.weaponDamage("staff", 0, 25, false, 2, nil)
	if swordGap > 0 then
		assert(shownText(Strings.get("weapon_better", swordGap)), "a stronger owned weapon shows how much stronger")
	end
	click(findButton(Strings.get(WeaponData.weapons.bow.nameKey)))
	eq(sent("EquipWeapon", function(args)
		return args[1] == 0 and args[2] == "bow"
	end), 1, "main weapon chosen")
	click(findButton(Strings.get("bag_slot", 1)))
	assert(shownText(Strings.get("bag_slot_hint")), "editing the floating slot")
	click(findButton(Strings.get(WeaponData.weapons.sword.nameKey)))
	eq(sent("EquipWeapon", function(args)
		return args[1] == 1 and args[2] == "sword"
	end), 1, "floating slot chosen")
	click(findButton(Strings.get("bag_auto")))
	eq(sent("EquipWeapon", function(args)
		return args[1] == 1 and args[2] == ""
	end), 1, "back to auto")
	setAttributes({ Stars = "bow:2" })
	assert(shownText(Strings.get(WeaponData.weapons.bow.nameKey) .. "\n" .. Strings.get("weapon_stars", 2, WeaponData.maxStars)), "stars on the weapon tile")
	click(findButton(Strings.get("menu_weapons")))
	setAttributes({ Level = 3, Companions = "", Stars = "" })
end)

test("chests in the world: shown when ready, hidden while their spot is empty", function()
	local ChestData = H.loadModule("src/shared/ChestData.luau")
	local function chestModels(): number
		local count = 0
		for _, child in workspace.ClientWorld:GetChildren() do
			if string.sub(child.Name, 1, 6) == "Chest_" then
				count += 1
			end
		end
		return count
	end
	setAttributes({ ChestSpots = "" })
	advance(1.1)
	local total = 0
	for _ in WorldData.chests do
		total += 1
	end
	eq(chestModels(), total, "every spot has a chest")
	-- The mini map marks the chests waiting nearby.
	local function chestMarks(): number
		local count = 0
		for _, descendant in playerGui.Minimap:GetDescendants() do
			if descendant.Name == "Chest" and isShown(descendant) then
				count += 1
			end
		end
		return count
	end
	teleport(vec(WorldData.chests.chest_glade_1.position, 3) + Vector3.new(0, 0, 8))
	advance(0.3)
	local marked = chestMarks()
	assert(marked >= 1, "chests on the mini map")
	local now = H.EPOCH + H.now()
	setAttributes({ ChestSpots = "chest_glade_1:" .. math.floor(now + 5) })
	eq(chestModels(), total - 1, "taken spot is empty")
	eq(chestMarks(), marked - 1, "a taken chest leaves the mini map")
	teleport(vec(WorldData.spawn, 3))
	advance(6)
	eq(chestModels(), total, "chest came back when its time passed")
	local prompt = workspace.ClientWorld.Chest_chest_glade_1:FindFirstChildWhichIsA("ProximityPrompt", true)
	assert(prompt, "chest prompt")
	eq(prompt.ObjectText, Strings.get(ChestData.chests.wood.nameKey))
	prompt.Triggered:Fire()
	eq(sent("Interact", function(args)
		return args[1] == "chest" and args[2] == "chest_glade_1"
	end), 1, "asks the server")
end)

test("chests menu: slots by level, one unlock at a time, timers, open and reward panel", function()
	local ChestData = H.loadModule("src/shared/ChestData.luau")
	setAttributes({ Level = 3, Chests = "wood:0,silver:0" })
	click(findButton(Strings.get("menu_chests")))
	assert(shownText(Strings.get("chest_hint")), "chests menu open")
	assert(shownText(Strings.get("weapon_locked", ChestData.slotUnlockLevels[3])), "third slot closed at level 3")
	assert(shownText(Strings.get(ChestData.chests.silver.nameKey)), "silver chest listed")
	click(findButton(Strings.get("chest_unlock")))
	eq(sent("ChestAction", function(args)
		return args[1] == "unlock" and (args[2] == 1 or args[2] == 2)
	end), 1, "unlock a chest")
	local now = math.floor(H.EPOCH + H.now())
	setAttributes({ Chests = "wood:" .. now .. ",silver:0" })
	advance(0.6)
	assert(shownText(Strings.get("chest_time", 1, 59)) or shownText(Strings.get("chest_time", 2, 0)), "countdown shown")
	assert(findButton(Strings.get("chest_wait")), "the other chest has to wait")
	click(findButton(Strings.get("chest_wait")))
	eq(sent("ChestAction"), 1, "waiting chest sends nothing")
	advance(ChestData.chests.wood.unlockSeconds)
	assert(findButton(Strings.get("chest_open")):FindFirstChild("Pulse"), "a chest ready to open glows")
	click(findButton(Strings.get("chest_open")))
	eq(sent("ChestAction", function(args)
		return args[1] == "open" and args[2] == 1
	end), 1, "open when ready")
	remotes.Fx.OnClientEvent:Fire("chestOpened", {
		chest = "wood",
		coins = 33,
		weapon = "bow",
		rarity = "common",
		duplicate = false,
		slots = { { 0, 1, 3 } },
	})
	advance(0.3)
	assert(playerGui.ChestReveal.Enabled, "the opening moment starts")
	assert(not shownText(Strings.get("chest_reward_coins", 33)), "rewards wait for the lid to open")
	advance(4)
	assert(shownText(Strings.get("chest_reward_title", Strings.get(ChestData.chests.wood.nameKey))), "reward title")
	assert(shownText(Strings.get("chest_reward_coins", 33)), "coins line")
	assert(shownText(Strings.get("chest_reward_weapon", Strings.get("weapon_bow_name"), Strings.get("rarity_common"))), "weapon line")
	assert(shownText(Strings.get("chest_reward_slot", Strings.get("bag_main"), 3, 1)), "slot line")
	assert(shownText(Strings.get("chest_continue")), "Continue at the end")
	local function motes(): number
		local count = 0
		for _, descendant in playerGui.ChestReveal:GetDescendants() do
			if descendant.Name == "Mote" then
				count += 1
			end
		end
		return count
	end
	eq(motes(), 0, "a wooden chest has no motes")
	remotes.Fx.OnClientEvent:Fire("chestOpened", { chest = "mystic", coins = 500, slots = {} })
	advance(3)
	assert(motes() > 5, "light rises from a mystic chest: " .. motes())
	remotes.Fx.OnClientEvent:Fire("chestOpened", { chest = "wood", coins = 10, weapon = "bow", rarity = "common", duplicate = true, star = 2, slots = {} })
	advance(0.2)
	assert(not shownText(Strings.get("chest_reward_coins", 33)), "a new chest starts over")
	advance(4)
	assert(shownText(Strings.get("chest_reward_star", Strings.get("weapon_bow_name"), 2, 5)), "star line for a repeat")
	click(findButton(Strings.get("chest_continue")))
	assert(not playerGui.ChestReveal.Enabled, "Continue closes it")
	advance(3)
	eq(motes(), 0, "the motes are gone once it is closed")
	click(findButton("X"))
	setAttributes({ Level = 3, Chests = "" })
end)

test("crystal pouch on the HUD; a full pouch guides back to the Great Lantern", function()
	local Stats = H.loadModule("src/shared/Stats.luau")
	local function capacityWith(upgrades)
		return Stats.of({ xp = hero:GetAttribute("XP") or 0, staffUpgrade = 0, upgrades = upgrades }).pouchCapacity
	end
	local capacity = capacityWith({})
	setAttributes({ Crystals = 12, Upgrades = "" })
	assert(shownText(Strings.get("hud_crystals", 12, capacity)), "pouch count")
	setAttributes({ Upgrades = "pouch:1" })
	assert(capacityWith({ pouch = 1 }) > capacity, "upgrade adds room")
	assert(shownText(Strings.get("hud_crystals", 12, capacityWith({ pouch = 1 }))), "capacity follows the upgrade")
	local icon = playerGui:FindFirstChild("CrystalIcon", true)
	local fill = playerGui:FindFirstChild("PouchFill", true)
	assert(math.abs(fill.Size.X.Scale - 12 / capacityWith({ pouch = 1 })) < 1e-6, "the bar shows how full the pouch is")
	eq(icon:FindFirstChild("Pulse"), nil, "a pouch with room is calm")
	setAttributes({ Upgrades = "", Crystals = capacity })
	eq(fill.Size.X.Scale, 1, "full bar")
	assert(icon:FindFirstChild("Pulse"), "a full pouch beats")
	advance(0.5)
	local anchorPart = nil
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee and child.Adornee.Name == "WaypointAnchor" then
			anchorPart = child.Adornee
		end
	end
	assert(anchorPart, "waypoint shown")
	local at = H.read(anchorPart, "Position")
	local plaza = vec(WorldData.plaza)
	assert(Vector3.new(at.X - plaza.X, 0, at.Z - plaza.Z).Magnitude < 1, "full pouch guides to the lantern")
	remotes.Fx.OnClientEvent:Fire("crystals", plaza + Vector3.new(0, 0, -20), 5)
	remotes.Fx.OnClientEvent:Fire("deposit", plaza, 60)
	-- The crystals arc from the hero into the lamp, then the coins earned pop up over it.
	advance(0.15)
	local shards = 0
	for _, part in workspace.ClientFx:GetChildren() do
		if part.Name == "DepositShard" then
			shards += 1
		end
	end
	assert(shards > 0, "crystals fly to the lantern")
	advance(1.1)
	local popped = false
	for _, label in workspace.ClientFx:GetDescendants() do
		if label:IsA("TextLabel") and label.Text == Strings.get("deposit_popup", "60") then
			popped = true
		end
	end
	assert(popped, "the coins earned pop up")
	advance(1)
	setAttributes({ Crystals = 0 })
	eq(icon:FindFirstChild("Pulse"), nil, "emptied: calm again")
end)

test("skill cards: open on a new offer, pick sends the card, later hides, button reopens", function()
	local SkillData = H.loadModule("src/shared/SkillData.luau")
	-- The server's first sync sends the (empty) saved offer; a later offer is new.
	setAttributes({ Skills = "swift:1", SkillOffer = "", PendingPicks = 0 })
	setAttributes({ SkillOffer = "swift,sharp,wave", PendingPicks = 2 })
	assert(shownText(Strings.get("skills_title")), "cards open on a new offer")
	assert(shownText(Strings.get(SkillData.skills.swift.nameKey)), "card name")
	assert(shownText(Strings.get("skill_rank", 2, SkillData.skills.swift.maxRank)), "next rank shown")
	click(findButton(Strings.get("skill_later")))
	assert(not shownText(Strings.get("skills_title")), "later hides the cards")
	click(findButton(Strings.get("skill_button", 2)))
	assert(shownText(Strings.get("skills_title")), "button reopens them")
	local cards = playerGui.SkillCards
	local picked = nil
	for _, object in cards:GetDescendants() do
		if object:IsA("TextLabel") and object.Text == Strings.get(SkillData.skills.sharp.nameKey) then
			picked = object.Parent
		end
	end
	assert(picked, "sharp card")
	click(picked)
	eq(sent("PickSkill", function(args)
		return args[1] == "sharp"
	end), 1, "pick sent")
	setAttributes({ Skills = "sharp:1,swift:1", SkillOffer = "coins", PendingPicks = 1 })
	assert(shownText(Strings.get("skill_coins_name")), "coin card")
	setAttributes({ SkillOffer = "", PendingPicks = 0 })
	assert(not shownText(Strings.get("skills_title")), "closed when nothing is left")
end)

test("legends: silhouettes until purified; the waypoint picks a zone for the player's level", function()
	setAttributes({ Legends = "Warden" })
	click(findButton(Strings.get("menu_legends")))
	assert(shownText(Strings.get("legends_hint")), "legends open")
	assert(shownText(Strings.get(Balance.enemies.Warden.nameKey)), "purified legend named")
	assert(shownText(Strings.get("legend_done")), "purified mark")
	assert(not shownText(Strings.get(Balance.enemies.ShadowKing.nameKey)), "unknown legends stay hidden")
	assert(shownText(Strings.get("legend_unknown")), "silhouette")
	setAttributes({ Legends = "BogMother,Warden" })
	assert(shownText(Strings.get(Balance.enemies.BogMother.nameKey)), "updates live")
	click(findButton(Strings.get("menu_legends")))

	-- A level-30 player who is waiting for the next legend quest is guided to the Frost Peaks.
	setAttributes({ Level = 30, QuestId = "frost_titan", QuestState = "level", Crystals = 0 })
	advance(0.5)
	local anchorPart = nil
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee and child.Adornee.Name == "WaypointAnchor" then
			anchorPart = child.Adornee
		end
	end
	assert(anchorPart, "waypoint shown")
	local at = H.read(anchorPart, "Position")
	local peaks = vec(WorldData.areas.peaks.center)
	assert(Vector3.new(at.X - peaks.X, 0, at.Z - peaks.Z).Magnitude < 1, "guided to the Frost Peaks")
	setAttributes({ Level = 3, QuestId = "first_purify", QuestState = "available" })
end)

test("shadow rift: portal while open, wave banner nearby, cleaned up on close", function()
	local root = hero.Character.HumanoidRootPart
	local center = H.read(root, "Position") + Vector3.new(10, -3, 0)
	advance(2)
	local before = #workspace.ClientFx:GetChildren()
	remotes.Fx.OnClientEvent:Fire("riftOpened", "glade", center)
	advance(0.1)
	assert(#workspace.ClientFx:GetChildren() >= before + 4, "portal rings and core")
	remotes.Fx.OnClientEvent:Fire("riftWave", "glade", center, 2, 3)
	advance(0.1)
	assert(shownText(Strings.get("banner_rift_wave", 2, 3)), "wave banner")
	remotes.Fx.OnClientEvent:Fire("riftClosed", "glade", center, true)
	advance(2)
	eq(#workspace.ClientFx:GetChildren(), 0, "portal removed")
	for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
end)

test("adventure log: rows with progress, claim when ready, badge", function()
	local AchievementData = H.loadModule("src/shared/AchievementData.luau")
	setAttributes({ Achievements = "friends:0:12,elites:0:1,rifts:0:0,treasure:0:0,crystals:0:0,legends:0:0,arsenal:0:1,rising:0:3,forge:0:0" })
	click(findButton(Strings.get("menu_log")))
	assert(shownText(Strings.get(AchievementData.achievements.friends.nameKey) .. "  " .. Strings.get("log_tier", 1, 5)), "row with tier")
	assert(shownText(Strings.get("log_progress", 12, 50)), "progress")
	click(findButton(Strings.get("log_claim")))
	eq(sent("ClaimAchievement", function(args)
		return args[1] == "elites"
	end), 1, "claim the ready one")
	setAttributes({ Achievements = "friends:0:12,elites:1:1,rifts:0:0,treasure:0:0,crystals:0:0,legends:0:0,arsenal:0:1,rising:0:3,forge:0:0" })
	assert(not findButton(Strings.get("log_claim")), "nothing left to claim")
	click(findButton(Strings.get("menu_log")))
end)

test("bounty board: opens from the server, shows progress, claims a finished bounty, closes when walking away", function()
	local BountyData = H.loadModule("src/shared/BountyData.luau")
	local Progression = H.loadModule("src/shared/Progression.luau")
	local Format = H.loadModule("src/shared/Format.luau")
	setAttributes({ Bounties = "purify:40:12,chest:2:2,rift:1:0" })
	remotes.OpenBoard.OnClientEvent:Fire()
	advance(0.2)
	assert(shownText(Strings.get("board_hint")), "board open")
	assert(shownText(Strings.get("bounty_purify", 40)), "purify bounty")
	assert(shownText(Strings.get("bounty_progress", 12, 40)), "progress shown")
	local level = hero:GetAttribute("Level")
	assert(shownText(Strings.get("bounty_reward", Format.short(Progression.incomeCoins(level, BountyData.kinds.chest.minutes)))), "reward in coins")
	click(findButton(Strings.get("bounty_progress", 12, 40)))
	eq(sent("ClaimBounty"), 0, "an unfinished bounty sends nothing")
	click(findButton(Strings.get("bounty_claim")))
	eq(sent("ClaimBounty", function(args)
		return args[1] == 2
	end), 1, "claim the finished one")
	setAttributes({ Bounties = "purify:40:12,elite:3:0,rift:1:0" })
	assert(shownText(Strings.get("bounty_elite", 3)), "board refreshed with the new bounty")
	assert(not findButton(Strings.get("bounty_claim")), "nothing left to claim")
	teleport(Vector3.new(0, 3, -150))
	advance(1)
	assert(not shownText(Strings.get("board_hint")), "board closes when walking away")
	setAttributes({ Bounties = "" })
end)

test("emotes: the panel sends the chosen emote, bubbles show over heads and fade", function()
	local EmoteData = H.loadModule("src/shared/EmoteData.luau")
	assert(not shownText(Strings.get("emote_wave")), "panel starts closed")
	click(findButton(Strings.get("emote_button")))
	assert(shownText(Strings.get("emote_wave")), "panel open")
	click(findButton(Strings.get("emote_dance")))
	eq(sent("PlayEmote", function(args)
		return args[1] == "dance"
	end), 1, "chosen emote sent")
	assert(not shownText(Strings.get("emote_wave")), "panel closes after choosing")
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = hero.Character
	local owner = hero
	local function bubbles(): number
		local count = 0
		for _, child in head:GetChildren() do
			if child.Name == "EmoteBubble" then
				count += 1
			end
		end
		return count
	end
	remotes.Fx.OnClientEvent:Fire("emote", owner, "cheer")
	advance(0.1)
	eq(bubbles(), 1, "bubble over the head")
	remotes.Fx.OnClientEvent:Fire("emote", owner, "laugh")
	advance(0.1)
	eq(bubbles(), 1, "a new emote replaces the old bubble")
	remotes.Fx.OnClientEvent:Fire("emote", owner, "nope")
	remotes.Fx.OnClientEvent:Fire("emote", "notaplayer", "wave")
	advance(EmoteData.duration + 0.5)
	eq(bubbles(), 0, "bubble fades")
	head:Destroy()
end)

test("story scenes: typewriter caption, tap to continue, Skip, soft captions, queue", function()
	local StoryData = H.loadModule("src/shared/StoryData.luau")
	local function gui(): any
		return playerGui:FindFirstChild("Cinematic")
	end
	local function tapCaption()
		for _, descendant in gui():GetDescendants() do
			if descendant:IsA("TextButton") and descendant.Text == "" then
				click(descendant)
				return
			end
		end
		error("caption button missing")
	end
	local function barsVisible(): boolean
		return gui().BarTop.Visible and gui().BarBottom.Visible
	end
	assert(not shownText(Strings.get("cinematic_skip")), "no Skip button between scenes")
	-- A full scene: letterbox, speaker name, the caption types itself, taps go on.
	local scene = StoryData.scenes.first_purify
	-- The speaker babbles in little pops at their own pitch while the caption types.
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local pops = {}
	H.localSound = function(sound)
		if sound.SoundId == Sounds.voice.id then
			table.insert(pops, sound.PlaybackSpeed)
		end
	end
	remotes.Cinematic.OnClientEvent:Fire("first_purify")
	advance(0.25)
	assert(shownText(Strings.get("npc_elder_name")), "speaker name shown")
	assert(shownText(Strings.get("cinematic_skip")), "Skip in the corner")
	assert(barsVisible(), "letterbox bars")
	local abilityBar = playerGui.Controls:FindFirstChild("AbilityBar")
	if abilityBar then
		eq(abilityBar.Visible, false, "the ability bar hides during a full scene (it would sit under Skip)")
	end
	for _, name in { "Hud", "Menus", "Minimap" } do
		eq(playerGui[name].Enabled, false, name .. " hidden during a full scene")
	end
	assert(not shownText("!"), "no quest marker over heads in a scene")
	local first = Strings.get(scene.lines[1].key)
	assert(not shownText(first), "the caption is still being typed")
	advance(0.6)
	assert(not shownText(first) or #first < 40, "typing takes time")
	advance(6)
	assert(shownText(first), "the whole line appears")
	H.localSound = nil
	local voice = StoryData.speakers[scene.lines[1].speaker].voice
	assert(#pops >= 3, "voice pops while typing: " .. #pops)
	for _, pitch in pops do
		assert(math.abs(pitch - voice) <= voice * 0.1, "at the speaker's pitch: " .. pitch)
	end
	assert(shownText(Strings.get("cinematic_continue")), "tap hint")
	tapCaption()
	advance(0.1)
	assert(not shownText(first) and playerGui.Cinematic ~= nil, "next line started")
	tapCaption() -- finishes typing the second line
	advance(0.1)
	assert(shownText(Strings.get(scene.lines[2].key)), "a tap finishes the line")
	tapCaption()
	advance(0.3)
	assert(shownText(Strings.get("story_hero_name")), "the hero speaks the last line")
	advance(6)
	assert(shownText(Strings.get("cinematic_end")), "last line asks to finish")
	tapCaption()
	advance(1)
	assert(not shownText(Strings.get("cinematic_skip")), "scene over: Skip gone")
	assert(not barsVisible(), "bars away")
	if abilityBar then
		eq(abilityBar.Visible, true, "the ability bar comes back after the scene")
	end
	for _, name in { "Hud", "Menus", "Minimap" } do
		eq(playerGui[name].Enabled, true, name .. " back after the scene")
	end
	-- Skip ends a scene at once.
	remotes.Cinematic.OnClientEvent:Fire("shadow_king")
	advance(0.5)
	assert(shownText(Strings.get("cinematic_skip")))
	click(findButton(Strings.get("cinematic_skip")))
	advance(1)
	assert(not shownText(Strings.get("cinematic_skip")), "skipped")
	assert(not barsVisible(), "bars away after skipping")
	-- Soft scenes: a caption only, no bars, and it fades by itself.
	remotes.Cinematic.OnClientEvent:Fire("first_purify_end")
	advance(0.3)
	assert(not barsVisible(), "no bars in a soft scene")
	assert(shownText(Strings.get("npc_elder_name") .. "  " .. Strings.get("icon_heart")), "soft scene caption (a closing scene: the giver's name has a heart)")
	advance(12)
	assert(not shownText(Strings.get("cinematic_skip")), "a soft scene ends on its own")
	-- Scenes that arrive while one is playing wait their turn; unknown scenes are ignored.
	remotes.Cinematic.OnClientEvent:Fire("first_purify_end")
	remotes.Cinematic.OnClientEvent:Fire("lantern_flowers_end")
	remotes.Cinematic.OnClientEvent:Fire("no_such_scene")
	remotes.Cinematic.OnClientEvent:Fire(5)
	advance(0.3)
	assert(shownText(Strings.get("cinematic_skip")), "the first queued scene is playing")
	advance(20)
	assert(not shownText(Strings.get("cinematic_skip")), "queue finished")
	for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
end)

test("hit squash: a creature is marked squashing for a moment, then springs back to its size", function()
	local victim = enemies[1]
	local body = victim.Body
	local size = body.Size
	-- (The test clock's tweens finish instantly, so the squash is seen through its marker.)
	eq(body:GetAttribute("LvSquash"), nil)
	remotes.Fx.OnClientEvent:Fire("hit", victim, H.read(body, "Position"), 12, false)
	advance(0.02)
	eq(body:GetAttribute("LvSquash"), true, "squashing")
	-- A second hit during the squash does not stack it.
	remotes.Fx.OnClientEvent:Fire("hit", victim, H.read(body, "Position"), 12, false)
	advance(0.5)
	eq(body:GetAttribute("LvSquash"), nil, "spring finished")
	assert((body.Size - size).Magnitude < 0.001, "back to its size")
end)

test("sounds heard often wobble in pitch, so repeats do not sound mechanical", function()
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local victim = enemies[1]
	local pitches = {}
	H.localSound = function(sound)
		if sound.SoundId == Sounds.hit.id then
			pitches[sound.PlaybackSpeed] = true
		end
	end
	for _ = 1, 6 do
		remotes.Fx.OnClientEvent:Fire("hit", victim, H.read(victim.Body, "Position"), 12, false)
		advance(0.3)
	end
	H.localSound = nil
	local distinct = 0
	for pitch in pitches do
		distinct += 1
		assert(math.abs(pitch - 1) <= Sounds.hit.vary + 1e-6, "within the wobble: " .. pitch)
	end
	assert(distinct >= 3, "different pitches: " .. distinct)
end)

test("story scenes: the talking NPC nods and the camera shot follows the speaker", function()
	local village = workspace.LanternValleyMap.Village
	local head = village.Elder.Head
	local body = village.Elder.Body
	local function headHeight(): number
		return H.read(head, "Position").Y - H.read(body, "Position").Y
	end
	-- The hero stands behind the Elder's usual facing: she turns to them, and the camera must film
	-- her face from that side (it used to stay on her usual side and show the back of her head).
	local elder = WorldData.vector(WorldData.npcs.Elder.position)
	local usual = (WorldData.vector(WorldData.npcs.Elder.lookAt) - elder) * Vector3.new(1, 0, 1)
	teleport(elder - usual.Unit * 6 + Vector3.new(0, 3, 0))
	advance(0.5)
	local resting = headHeight()
	remotes.Cinematic.OnClientEvent:Fire("first_purify")
	local highest = resting
	for _ = 1, 30 do
		advance(0.05)
		highest = math.max(highest, headHeight())
	end
	assert(highest > resting + 0.05, "the Elder's head bobs while she talks")
	local camera = workspace.CurrentCamera
	local eye = H.read(camera, "CFrame").Position
	assert((eye - elder).Magnitude < 25, "the camera moved in on the Elder: " .. (eye - elder).Magnitude)
	assert((eye - elder):Dot(-usual) > 0, "filmed from the side she faces (the hero's)")
	click(findButton(Strings.get("cinematic_skip")))
	advance(1)
	local after = headHeight()
	assert(math.abs(after - resting) < 0.2, "the head settles when the scene ends")
end)

test("story journal: finished scenes can be replayed, the current one is marked, later ones hidden", function()
	local QuestData = H.loadModule("src/shared/QuestData.luau")
	setAttributes({ QuestsDone = "first_purify,lantern_flowers", QuestId = "forest_explore", QuestState = "active" })
	click(findButton(Strings.get("menu_bag")))
	click(findButton(Strings.get("bag_tab_story")))
	assert(shownText(Strings.get("story_prologue_title")), "the prologue is always there")
	assert(shownText(Strings.get(QuestData.quests.first_purify.titleKey)), "a finished quest")
	assert(shownText(Strings.get(QuestData.quests.forest_explore.titleKey)), "the current quest")
	assert(shownText(Strings.get("story_now")), "marked as current")
	assert(not shownText(Strings.get(QuestData.quests.shadow_king.titleKey)), "later chapters stay secret")
	assert(shownText(Strings.get("story_locked")), "hidden titles")
	local replays = 0
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextButton") and descendant.Text == Strings.get("story_replay") and isShown(descendant) then
			replays += 1
		end
	end
	eq(replays, 3, "prologue plus two finished quests")
	-- The current quest's button does nothing.
	click(findButton(Strings.get("story_now")))
	assert(not shownText(Strings.get("cinematic_skip")), "no scene from the current quest's marker")
	-- Replay the first finished quest: the bag closes and its scene plays.
	click(findText(Strings.get(QuestData.quests.first_purify.titleKey)).Parent:FindFirstChildOfClass("TextButton"))
	advance(0.5)
	assert(not shownText(Strings.get("story_prologue_title")), "the bag closed")
	assert(shownText(Strings.get("cinematic_skip")), "the scene plays")
	assert(shownText(Strings.get("npc_elder_name")), "with its speaker")
	click(findButton(Strings.get("cinematic_skip")))
	advance(1.5)
	-- Its ending is queued behind it and plays too, then everything finishes.
	click(findButton(Strings.get("cinematic_skip")))
	advance(1.5)
	assert(not shownText(Strings.get("cinematic_skip")), "all done")
	-- Leave the bag on its first tab for whoever opens it next.
	click(findButton(Strings.get("menu_bag")))
	click(findButton(Strings.get("bag_tab_charms")))
	click(findButton(Strings.get("menu_bag")))
	setAttributes({ QuestsDone = "", QuestId = "first_purify", QuestState = "available" })
end)

-- Settings window -------------------------------------------------------------------------------

local function settingsRow(titleKey: string): any
	local title = findText(Strings.get(titleKey))
	assert(title, "settings row " .. titleKey)
	return title.Parent
end

local function rowButton(row: any, text: string): any
	for _, descendant in row:GetDescendants() do
		if descendant:IsA("TextButton") and descendant.Text == text then
			return descendant
		end
	end
	error("no button " .. text)
end

local function lastChanges(): any
	local last = nil
	for _, entry in H.remoteLog do
		if entry.remote == "SetSetting" and entry.direction == "toServer" then
			last = entry.args[1]
		end
	end
	return last
end

test("settings window: pages, presets, single options make it Custom, reset, notes", function()
	local SettingsData = H.loadModule("src/shared/SettingsData.luau")
	local device = if touchMode then "medium" else "high"
	click(findButton(Strings.get("menu_settings")))
	assert(shownText(Strings.get("settings_reset")), "window open")
	assert(shownText(Strings.get("settings_auto_note", Strings.get(({ medium = "opt_medium", high = "opt_high" })[device]))), "Auto says what it picked")
	local recommended = findButton(Strings.get(({ medium = "opt_medium", high = "opt_high" })[device])):FindFirstChild("Recommended")
	assert(recommended and isShown(recommended), "a star on the preset this device should use")
	for _, key in { "set_detail", "set_shadows", "set_effects", "set_bloom", "set_atmosphere", "set_fov" } do
		assert(shownText(Strings.get(key)), "graphics row " .. key)
	end
	assert(not shownText(Strings.get("set_master")), "audio rows are on another page")
	-- A preset chip asks for that preset.
	click(findButton(Strings.get("opt_low")))
	eq(lastChanges().quality, "low", "Low preset requested")
	setAttributes({ Pref_quality = "low" })
	assert(not shownText(Strings.get("settings_custom_note")), "a preset is not Custom")
	-- One option: everything on screen is kept and the preset becomes Custom.
	click(rowButton(settingsRow("set_shadows"), ""))
	local changes = lastChanges()
	eq(changes.quality, "custom", "a single option makes the preset Custom")
	eq(changes.shadows, true, "the switch flipped (Low had shadows off)")
	eq(changes.bloom, false, "the other options stay as the preset had them")
	eq(changes.effects, SettingsData.presets.low.effects)
	eq(changes.detail, "low")
	setAttributes({ Pref_quality = "custom", Pref_shadows = true, Pref_effects = "low", Pref_bloom = false, Pref_atmosphere = false, Pref_detail = "low" })
	assert(shownText(Strings.get("settings_custom_note")), "Custom is explained")
	click(rowButton(settingsRow("set_effects"), Strings.get("opt_high")))
	eq(lastChanges().effects, "high", "effects choice")
	eq(lastChanges().quality, "custom")
	-- Sliders: the + button steps, dragging sets a value when the finger lets go.
	click(rowButton(settingsRow("set_fov"), "+"))
	eq(lastChanges().fov, SettingsData.settings.fov.default + SettingsData.settings.fov.step, "one step")
	local track = nil
	for _, descendant in playerGui:GetDescendants() do
		if descendant.Name == "Track" and isShown(descendant) then
			track = descendant
		end
	end
	assert(track, "the slider track")
	local drag = { UserInputType = Enum.UserInputType.MouseButton1, Position = Vector3.new(500, 0, 0) }
	track.InputBegan:Fire(drag)
	H.services.UserInputService.InputEnded:Fire(drag)
	advance(0.1)
	assert(lastChanges().fov ~= nil and lastChanges().fov >= 40 and lastChanges().fov <= 70, "a dragged value is clamped to the range")
	-- Pages and reset.
	click(findButton(Strings.get("settings_cat_audio")))
	assert(shownText(Strings.get("set_master")) and shownText(Strings.get("set_sfx")) and shownText(Strings.get("set_sound")), "audio page")
	assert(not shownText(Strings.get("set_shadows")), "graphics rows hidden")
	click(rowButton(settingsRow("set_master"), "-"))
	eq(lastChanges().master, 90, "volume steps by ten")
	-- Music has its own volume; every row and page has an icon; "Saved" once the server keeps it.
	assert(shownText(Strings.get("icon_cat_audio")) and shownText(Strings.get("icon_set_music")), "page and row icons")
	advance(2)
	-- A saved effects volume plays a sample at the new level.
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local samples = 0
	H.localSound = function(sound)
		if sound.SoundId == Sounds.pickup.id then
			samples += 1
		end
	end
	click(rowButton(settingsRow("set_sfx"), "-"))
	setAttributes({ Pref_sfx = 90 })
	eq(samples, 1, "a sample at the new effects volume")
	H.localSound = nil
	setAttributes({ Pref_sfx = 100 })
	advance(2)
	click(rowButton(settingsRow("set_music"), "-"))
	eq(lastChanges().music, 90, "music volume")
	assert(not shownText(Strings.get("settings_saved")), "not saved until the server keeps it")
	setAttributes({ Pref_music = 90 })
	assert(shownText(Strings.get("settings_saved")), "the server kept it: Saved")
	advance(2)
	assert(not shownText(Strings.get("settings_saved")), "Saved goes away")
	setAttributes({ Pref_music = 100 })
	assert(not shownText(Strings.get("settings_saved")), "a change from elsewhere is not a save from this window")
	click(rowButton(settingsRow("set_sound"), ""))
	eq(lastChanges().sound, false, "the sound switch")
	click(findButton(Strings.get("settings_reset")))
	eq(lastChanges().reset, "audio", "reset asks for this page only")
	click(findButton(Strings.get("settings_cat_gameplay")))
	for _, key in { "set_shake", "set_cinematics", "set_damage_numbers", "set_range_ring" } do
		assert(shownText(Strings.get(key)), "gameplay row " .. key)
	end
	click(rowButton(settingsRow("set_shake"), ""))
	eq(lastChanges().shake, false)
	assert(lastChanges().quality == nil, "gameplay options never touch the graphics preset")
	click(findButton(Strings.get("settings_cat_interface")))
	click(rowButton(settingsRow("set_ui_scale"), Strings.get("opt_large")))
	eq(lastChanges().uiScale, "large")
	click(findButton(Strings.get("settings_cat_graphics")))
	click(findButton(Strings.get("menu_settings")))
	assert(not shownText(Strings.get("settings_reset")), "window closed")
	setAttributes({ Pref_quality = "auto", Pref_shadows = true, Pref_effects = "high", Pref_bloom = true, Pref_atmosphere = true, Pref_detail = "high" })
end)

test("quality presets switch off the effects the place already ships (default.project.json)", function()
	local Lighting = H.game:GetService("Lighting")
	-- The real place has its own Atmosphere/Bloom/ColorCorrection/SunRays; start from that.
	for _, name in { "LvBloom", "LvAtmosphere", "LvGrading", "LvRays" } do
		local copy = Lighting:FindFirstChild(name)
		if copy then
			copy:Destroy()
		end
	end
	local builtIn = {}
	for name, className in { Bloom = "BloomEffect", Atmosphere = "Atmosphere", ColorCorrection = "ColorCorrectionEffect", SunRays = "SunRaysEffect" } do
		local instance = Instance.new(className)
		instance.Name = name
		instance.Parent = Lighting
		builtIn[name] = instance
	end
	setAttributes({ Pref_quality = "ultra" })
	eq(builtIn.Bloom.Enabled, true, "Ultra: the built-in glow is on")
	eq(builtIn.SunRays.Enabled, true, "Ultra: the built-in sun rays are on")
	setAttributes({ Pref_quality = "low" })
	eq(builtIn.Bloom.Enabled, false, "Low turns the built-in glow off")
	eq(builtIn.ColorCorrection.Enabled, false, "Low turns the built-in colour grading off")
	eq(builtIn.SunRays.Enabled, false, "Low turns the built-in sun rays off")
	assert(builtIn.Atmosphere.Parent == nil, "Low removes the built-in haze")
	assert(not Lighting:FindFirstChild("LvBloom") and not Lighting:FindFirstChild("LvAtmosphere"), "no second copy of an effect is made")
	setAttributes({ Pref_quality = "high" })
	eq(builtIn.Bloom.Enabled, true, "High: the glow is back")
	assert(Lighting:FindFirstChildOfClass("Atmosphere"), "High: haze is back")
	builtIn.Bloom:Destroy()
	builtIn.ColorCorrection:Destroy()
	builtIn.SunRays:Destroy()
	setAttributes({ Pref_quality = "auto" })
end)

test("settings apply: look, effects, damage numbers, creature bars, camera scenes, interface size", function()
	local Lighting = H.game:GetService("Lighting")
	setAttributes({ Pref_quality = "low" })
	eq(Lighting.GlobalShadows, false, "Low: no shadows")
	assert(not Lighting:FindFirstChild("LvAtmosphere"), "Low: no haze")
	local bloom = Lighting:FindFirstChild("LvBloom")
	assert(bloom and bloom.Enabled == false, "Low: no glow")
	setAttributes({ Pref_quality = "ultra" })
	eq(Lighting.GlobalShadows, true, "Ultra: shadows")
	assert(Lighting:FindFirstChild("LvAtmosphere"), "Ultra: haze")
	eq(Lighting.LvBloom.Enabled, true, "Ultra: glow")
	eq(Lighting.LvRays.Enabled, true, "Ultra: sun rays")
	setAttributes({ Pref_quality = "high" })
	eq(Lighting.LvRays.Enabled, false, "High has no sun rays")
	setAttributes({ Pref_quality = "custom", Pref_shadows = false, Pref_bloom = true, Pref_atmosphere = false, Pref_detail = "medium", Pref_effects = "medium" })
	eq(Lighting.GlobalShadows, false, "Custom follows the single options")
	eq(Lighting.LvBloom.Enabled, true)
	assert(not Lighting:FindFirstChild("LvAtmosphere"), "Custom: haze off")
	-- Creature names and health bars.
	local function barsEnabled(): boolean
		for _, gui in enemyLabels() do
			if gui.Enabled then
				return true
			end
		end
		return false
	end
	local near = addEnemy("Rockling", H.read(hero.Character.HumanoidRootPart, "Position") + Vector3.new(10, 0, 0))
	setAttributes({ Pref_enemyBars = true })
	advance(0.3)
	assert(barsEnabled(), "bars shown")
	setAttributes({ Pref_enemyBars = false })
	for _, gui in enemyLabels() do
		eq(gui.Enabled, false, "bars hidden")
	end
	setAttributes({ Pref_enemyBars = true })
	near:Destroy()
	-- Damage numbers.
	local function damageText(text: string): boolean
		for _, descendant in workspace:GetDescendants() do
			if descendant:IsA("TextLabel") and descendant.Text == text then
				return true
			end
		end
		return false
	end
	local victim = enemies[1]
	setAttributes({ Pref_damageNumbers = false })
	remotes.Fx.OnClientEvent:Fire("hit", victim, H.read(victim.Body, "Position"), 31337, false)
	advance(0.1)
	assert(not damageText("31.3K") and not damageText("31337"), "no damage number when they are off")
	setAttributes({ Pref_damageNumbers = true })
	remotes.Fx.OnClientEvent:Fire("hit", victim, H.read(victim.Body, "Position"), 31337, false)
	advance(0.1)
	assert(damageText("31.3K"), "damage number shown when on")
	advance(1.5)
	-- Camera scenes: off = captions only.
	setAttributes({ Pref_cinematics = false })
	remotes.Cinematic.OnClientEvent:Fire("first_purify")
	advance(0.5)
	assert(shownText(Strings.get("npc_elder_name")), "captions still play")
	assert(not (playerGui.Cinematic.BarTop.Visible or playerGui.Cinematic.BarBottom.Visible), "no letterbox")
	click(findButton(Strings.get("cinematic_skip")))
	advance(1)
	setAttributes({ Pref_cinematics = true })
	-- Interface size: every region follows.
	local function regionScale(): number
		for _, child in playerGui.Hud:GetChildren() do
			local scale = child:FindFirstChildOfClass("UIScale")
			if child:IsA("Frame") and scale then
				return scale.Scale
			end
		end
		error("no region")
	end
	setAttributes({ Pref_uiScale = "normal" })
	local normal = regionScale()
	setAttributes({ Pref_uiScale = "large" })
	assert(regionScale() > normal, "large makes the interface bigger")
	setAttributes({ Pref_uiScale = "small" })
	assert(regionScale() < normal, "small makes it smaller")
	setAttributes({ Pref_uiScale = "normal" })
	-- The performance display is saved too.
	setAttributes({ Pref_perf = true })
	advance(1.5)
	local perf = false
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextLabel") and string.find(descendant.Text, "FPS", 1, true) and isShown(descendant) then
			perf = true
		end
	end
	assert(perf, "the performance overlay follows the saved setting")
	setAttributes({ Pref_perf = false, Pref_quality = "auto" })
	for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
end)

test("attack animation: the arm swings by stepping the joint (TweenService cannot tween C0) and returns", function()
	local shoulder = friend.Character.RightUpperArm.RightShoulder
	local original = H.read(shoulder, "C0")
	teleport(vec(WorldData.spawn, 3)) -- effects of far-away players are skipped
	remotes.Fx.OnClientEvent:Fire("attack", friend, "staff", 0, vec(WorldData.spawn, 3) + Vector3.new(0, 0, 10), vec(WorldData.spawn, 3), 1)
	advance(0.06)
	assert(H.read(shoulder, "C0") ~= original, "the arm is raised while swinging")
	assert(shoulder:GetAttribute("LvSwing"), "one swing at a time")
	advance(0.6)
	assert(H.read(shoulder, "C0") == original, "the arm returns to where it was")
	assert(not shoulder:GetAttribute("LvSwing"), "ready for the next swing")
	-- A joint removed mid-swing ends the swing quietly.
	remotes.Fx.OnClientEvent:Fire("attack", friend, "staff", 0, vec(WorldData.spawn, 3) + Vector3.new(0, 0, 10), vec(WorldData.spawn, 3), 1)
	advance(0.03)
	shoulder:Destroy()
	advance(0.5)
	eq(#H.threadErrors, 0, "no thread errors")
end)

test("mini map: near and world views, other players, guide goal, follows the setting", function()
	local MapLogic = H.loadModule("src/shared/MapLogic.luau")
	local map = playerGui.Minimap:FindFirstChild("Map", true)
	local function frames(name: string): { any }
		local list = {}
		for _, child in map:GetChildren() do
			if child.Name == name and child:IsA("Frame") and child.Visible then
				table.insert(list, child)
			end
		end
		return list
	end
	setAttributes({ QuestId = "first_purify", QuestState = "available", Level = 1 })
	teleport(vec(WorldData.spawn, 3))
	advance(0.5)
	assert(isShown(map), "the map shows once the save is ready")
	eq(#frames("OtherPlayer"), 1, "the other player is a dot")
	local you = map.You
	assert(math.abs(H.read(you, "Position").X.Offset - 66) < 1 and math.abs(H.read(you, "Position").Y.Offset - 66) < 1, "near view centers on the player")
	-- The guide goal (Elder Nora) is north of the spawn: a gold dot above the arrow.
	local goal = frames("Goal")[1]
	assert(goal, "the guide goal is on the map")
	assert(H.read(goal, "Position").Y.Offset < H.read(you, "Position").Y.Offset, "north is up")
	-- Nearby creature zones name their levels; in the whole-valley view the discs are too small to.
	teleport(vec(WorldData.areas.glade.center, 3) + Vector3.new(0, 0, 30))
	advance(0.5)
	local glade = Strings.get("map_zone_levels", WorldData.areas.glade.levels[1], WorldData.areas.glade.levels[2])
	assert(shownText(glade), "the glade's levels on the mini map")
	teleport(vec(WorldData.spawn, 3))
	advance(0.5)
	-- Walking east moves the map, not the arrow.
	teleport(vec(WorldData.spawn, 3) + Vector3.new(30, 0, 0))
	advance(0.5)
	assert(math.abs(H.read(you, "Position").X.Offset - 66) < 1, "the arrow stays centered in the near view")
	assert(H.read(frames("Goal")[1], "Position").X.Offset < 66, "the goal moved west of the arrow")
	-- Tap: the whole valley, with the arrow where the player really is.
	click(map)
	advance(0.5)
	local view = MapLogic.view("world", 30, 43, 132)
	local x, y = MapLogic.toMap(view, 132, H.read(hero.Character.HumanoidRootPart, "Position").X, H.read(hero.Character.HumanoidRootPart, "Position").Z)
	assert(math.abs(H.read(you, "Position").X.Offset - x) < 1 and math.abs(H.read(you, "Position").Y.Offset - y) < 1, "world view places the arrow on the valley map")
	assert(not shownText(glade), "no level labels on the tiny discs of the whole valley")
	click(map)
	advance(0.5)
	assert(math.abs(H.read(you, "Position").X.Offset - 66) < 1, "tapping again returns to the near view")
	-- Turned off in Settings, and hidden while a scene plays or the save is loading.
	setAttributes({ Pref_minimap = false })
	assert(not isShown(map), "the setting hides it")
	setAttributes({ Pref_minimap = true })
	assert(isShown(map), "and shows it again")
	setAttributes({ DataState = "loading" })
	assert(not isShown(map), "hidden while loading")
	setAttributes({ DataState = "ready" })
	teleport(vec(WorldData.spawn, 3))
end)

test("player tags: title, name and level over other players' heads, follows the setting", function()
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = friend.Character
	local ownHead = Instance.new("Part")
	ownHead.Name = "Head"
	ownHead.Parent = hero.Character
	friend:SetAttribute("Level", 42)
	friend:SetAttribute("Rebirths", 2)
	friend:SetAttribute("Title", "reborn")
	advance(1)
	local tag = head:FindFirstChild("PlayerTag")
	assert(tag, "a tag hangs on the other player's head")
	eq(tag.NameLine.Text, friend.DisplayName or friend.Name)
	eq(tag.LevelLine.Text, Strings.get("hud_level", 42) .. "  " .. Strings.get("rebirth_hud", 2))
	local PlayerBoard = H.loadModule("src/client/PlayerBoard.luau")
	local expected = PlayerBoard.badgeColor(42):Lerp(roblox.Color3.new(1, 1, 1), 0.35)
	assert(math.abs(tag.LevelLine.TextColor3.R - expected.R) < 0.01 and math.abs(tag.LevelLine.TextColor3.B - expected.B) < 0.01, "level in its badge colour")
	eq(tag.TitleLine.Text, Strings.get("title_reborn"))
	assert(tag.TitleLine.Visible, "the title is shown")
	eq(friend.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.None, "the default name tag is hidden")
	assert(not ownHead:FindFirstChild("PlayerTag"), "no tag on yourself")
	friend:SetAttribute("Title", nil)
	friend:SetAttribute("Rebirths", nil)
	advance(1)
	assert(not tag.TitleLine.Visible, "no title, no line")
	eq(tag.LevelLine.Text, Strings.get("hud_level", 42), "no rebirths, no suffix")
	setAttributes({ Pref_playerTags = false })
	advance(1)
	assert(not head:FindFirstChild("PlayerTag"), "the setting removes the tag")
	eq(friend.Character.Humanoid.DisplayDistanceType, Enum.HumanoidDisplayDistanceType.Viewer, "the default name tag is back")
	setAttributes({ Pref_playerTags = true })
	advance(1)
	assert(head:FindFirstChild("PlayerTag"), "and the setting brings it back")
	head:Destroy()
	ownHead:Destroy()
	friend:SetAttribute("Level", nil)
end)

test("daily gift: the button shows only while a gift waits and asks the server", function()
	local function button()
		local found = playerGui:FindFirstChild("DailyGiftButton", true)
		assert(found, "the gift button exists")
		return found
	end
	setAttributes({ DailyReady = false })
	advance(0.6)
	assert(not isShown(button()), "no gift, no button")
	local countdown = playerGui:FindFirstChild("NextGift", true)
	local left = 24 * 3600 - workspace:GetServerTimeNow() % (24 * 3600)
	assert(countdown and isShown(countdown), "a countdown to the next gift instead")
	assert(string.find(countdown.Text, tostring(math.floor(left / 3600)) .. "h", 1, true), "hours until the next UTC day: " .. countdown.Text)
	setAttributes({ DailyReady = true })
	advance(0.6)
	assert(isShown(button()), "the button appears when a gift waits")
	assert(not isShown(countdown), "no countdown while a gift waits")
	assert(shownText(Strings.get("notice_daily_ready")), "and a toast tells about it")
	local coins = hero:GetAttribute("Coins") or 0
	click(button())
	eq(sent("ClaimDailyGift"), 1, "clicking asks the server")
	hero:SetAttribute("Coins", coins + 600)
	remotes.Notice.OnClientEvent:Fire("notice_daily_gift", "600")
	advance(5)
	assert(shownText(Strings.get("chest_reward_title", Strings.get("daily_gift_title"))), "the gift opens like a chest")
	assert(shownText(Strings.get("chest_reward_coins", "600")), "with the coins it gave")
	click(findButton(Strings.get("chest_continue")))
	hero:SetAttribute("Coins", coins)
	setAttributes({ DailyReady = false })
	advance(0.6)
	assert(not isShown(button()), "gone once it is taken")
	setAttributes({ DailyReady = true, DataState = "loading" })
	advance(0.6)
	assert(not isShown(button()), "hidden while the save loads")
	setAttributes({ DailyReady = false, DataState = "ready" })
end)

test("players board: everyone on the server, highest level first, opened by button or Tab", function()
	local heroLevel = hero:GetAttribute("Level")
	hero:SetAttribute("Level", 5)
	friend:SetAttribute("Level", 20)
	friend:SetAttribute("Rebirths", 1)
	friend:SetAttribute("TowerBest", 7)
	friend:SetAttribute("Title", "reborn")
	assert(not shownText(Strings.get("players_title")), "closed at first")
	click(findButton(Strings.get("players_button")))
	advance(0.2)
	assert(shownText(Strings.get("players_title")), "opened by the button")
	assert(shownText(Strings.get("title_reborn")), "the chosen title is shown under the name")
	assert(not shownText(Strings.get("title_keeper")), "no title for players who chose none")
	local summary = Strings.get("rebirth_hud", 1) .. "   " .. Strings.get("players_tower", 7)
	assert(shownText(summary), "rebirths and tower record: " .. summary)
	local friendRow = findText(friend.DisplayName or friend.Name)
	local heroRow = findText(hero.DisplayName or hero.Name)
	assert(friendRow and heroRow, "both names listed")
	assert(friendRow.Parent.LayoutOrder < heroRow.Parent.LayoutOrder, "the higher level is listed first")
	-- Level badges (a gold ring after a rebirth) and medals for the top three.
	eq(friendRow.Parent.LevelBadge.Text, "20")
	eq(heroRow.Parent.LevelBadge.Text, "5", "the local player's level")
	assert(friendRow.Parent.LevelBadge:FindFirstChildOfClass("UIStroke") and not heroRow.Parent.LevelBadge:FindFirstChildOfClass("UIStroke"), "rebirth ring")
	eq(friendRow.Parent.Rank.Text, Strings.get("players_rank_1"))
	eq(heroRow.Parent.Rank.Text, Strings.get("players_rank_2"))
	-- Levels change live; a player who leaves disappears.
	hero:SetAttribute("Level", 30)
	advance(1.5)
	assert(findText(hero.DisplayName or hero.Name).Parent.LayoutOrder < findText(friend.DisplayName or friend.Name).Parent.LayoutOrder, "the order follows the levels")
	table.remove(Players.list, table.find(Players.list, friend))
	Players.PlayerRemoving:Fire(friend)
	advance(0.5)
	assert(not findText(friend.DisplayName or friend.Name), "a player who left is gone")
	table.insert(Players.list, friend)
	-- The X closes it; so do the button and Tab.
	click(rowButton(findText(Strings.get("players_title")).Parent, "X"))
	assert(not shownText(Strings.get("players_title")), "closed by X")
	click(findButton(Strings.get("players_button")))
	click(findButton(Strings.get("players_button")))
	assert(not shownText(Strings.get("players_title")), "closed")
	H.services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Tab }, false)
	advance(0.2)
	assert(shownText(Strings.get("players_title")), "opened by Tab")
	H.services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.Tab }, false)
	advance(0.2)
	assert(not shownText(Strings.get("players_title")), "closed by Tab")
	hero:SetAttribute("Level", heroLevel)
	friend:SetAttribute("Level", nil)
	friend:SetAttribute("Title", nil)
	friend:SetAttribute("Rebirths", nil)
	friend:SetAttribute("TowerBest", nil)
end)

test("loading screen: title, tips and a bar until the save is ready, then it fades away", function()
	local previous = hero:GetAttribute("DataState")
	hero:SetAttribute("DataState", "loading")
	H.task.spawn(H.run, "src/first/LoadingScreen.client.luau")
	advance(1)
	local screen = playerGui:FindFirstChild("LoadingScreen")
	assert(screen and screen.Enabled, "the loading screen is up")
	assert(shownText(Strings.get("loading_title")), "title")
	assert(shownText(Strings.get("loading_data")), "waiting for the save")
	local tipShown = false
	for index = 1, 8 do
		tipShown = tipShown or shownText(Strings.get("loading_tip_" .. index))
	end
	assert(tipShown, "a tip is shown")
	local fill = screen:FindFirstChild("Fill", true)
	assert(fill.Size.X.Scale > 0.3 and fill.Size.X.Scale < 0.95, "the bar moves but is not full yet")
	assert(not shownText(Strings.get("loading_skip")), "no Skip at first")
	local stars = 0
	for _, descendant in screen:GetDescendants() do
		if descendant.Name == "Star" then
			stars += 1
		end
	end
	assert(stars >= 30, "a starry sky: " .. stars)
	local shooting = false
	for _ = 1, 32 do
		advance(0.25)
		shooting = shooting or screen:FindFirstChild("ShootingStar", true) ~= nil
	end
	assert(shooting, "now and then a shooting star")
	assert(shownText(Strings.get("loading_skip")), "Skip appears when it takes long")
	assert(playerGui:FindFirstChild("LoadingScreen"), "still waiting for the save")
	remotes.Cinematic.OnClientEvent:Fire("first_purify")
	advance(0.3)
	assert(not shownText(Strings.get("npc_elder_name")), "a story scene waits for the loading screen")
	hero:SetAttribute("DataState", "ready")
	advance(1.5)
	assert(not playerGui:FindFirstChild("LoadingScreen"), "gone once the save is ready")
	advance(0.3)
	assert(shownText(Strings.get("npc_elder_name")), "then the scene plays")
	click(findButton(Strings.get("cinematic_skip")))
	advance(1)
	hero:SetAttribute("DataState", previous)
	advance(0.2)
end)

test("player card: health bar, red screen edges on a hit and at low health, toasts merge and cap", function()
	local humanoid = hero.Character:FindFirstChildOfClass("Humanoid")
	local Format = H.loadModule("src/shared/Format.luau")
	humanoid.MaxHealth, humanoid.Health = 200, 200
	advance(0.2)
	assert(shownText(Strings.get("hud_hp", Format.short(200), Format.short(200))), "full health shown")
	local edges = playerGui.HealthEdges
	local function edgeStrength(): number
		return 1 - edges:GetChildren()[1].BackgroundTransparency
	end
	eq(edgeStrength(), 0, "no red edges at full health")
	humanoid.Health = 194
	advance(0.05)
	assert(shownText(Strings.get("hud_hp", Format.short(194), Format.short(200))), "the bar follows a hit")
	eq(edgeStrength(), 0, "chip damage does not flash the screen")
	humanoid.Health = 150
	advance(0.05)
	assert(edgeStrength() > 0.3, "a real hit flashes the edges")
	advance(1)
	eq(edgeStrength(), 0, "the flash fades")
	humanoid.Health = 40
	advance(0.5)
	assert(edgeStrength() > 0.1, "low health keeps the edges red")
	advance(1.5)
	local heartbeat = H.game:GetService("SoundService"):FindFirstChild("Ambient_heartbeat")
	assert(heartbeat and heartbeat.Playing and heartbeat.Volume > 0, "a heartbeat at low health")
	humanoid.Health = 200
	advance(2)
	eq(edgeStrength(), 0, "healed: edges clear")
	assert(not heartbeat.Playing, "healed: the heartbeat fades away")
	-- Each hit points at where it came from, around the hero in the middle of the screen.
	local root = hero.Character.HumanoidRootPart
	local look = H.read(workspace.CurrentCamera, "CFrame").LookVector
	local right = Vector3.new(-look.Z, 0, look.X).Unit
	remotes.Fx.OnClientEvent:Fire("hurt", root.Position + right * 10)
	advance(0.05)
	local arrow = edges:FindFirstChild("HurtArrow")
	assert(arrow and isShown(arrow), "a chevron points at the hit")
	local flash = hero.Character:FindFirstChild("HurtFlash")
	assert(flash and flash:IsA("Highlight") and flash.FillColor.G < 0.5, "the hero flashes red")
	assert(math.abs(arrow.Rotation - 90) < 1, "to the right of the view: " .. arrow.Rotation)
	assert(arrow.Position.X.Offset > 0 and math.abs(arrow.Position.Y.Offset) < 1, "on the hero's right")
	remotes.Fx.OnClientEvent:Fire("hurt", root.Position - right * 10)
	advance(0.05)
	local behind = 0
	for _, child in edges:GetChildren() do
		if child.Name == "HurtArrow" and math.abs(child.Rotation - 270) < 1 then
			behind += 1
		end
	end
	eq(behind, 1, "a hit from the left points left")
	local flashes = 0
	for _, child in hero.Character:GetChildren() do
		if child.Name == "HurtFlash" then
			flashes += 1
		end
	end
	eq(flashes, 1, "one flash reused for every hit")
	remotes.Fx.OnClientEvent:Fire("hurt", "x")
	advance(1.2)
	eq(edges:FindFirstChild("HurtArrow"), nil, "chevrons fade away")
	setAttributes({ Pref_flashes = false })
	humanoid.Health = 150
	advance(0.05)
	eq(edgeStrength(), 0, "flashes off: a hit does not flash")
	humanoid.Health = 40
	local first = (advance(0.13) or 0) and edgeStrength()
	advance(0.21)
	eq(edgeStrength(), first, "flashes off: low health is steady, not pulsing")
	assert(first > 0, "but still shown")
	humanoid.Health = 200
	setAttributes({ Pref_flashes = true })
	advance(1)
	-- Toasts: the same news twice is one pill with a counter, and only a few show at once.
	local notice = remotes.Notice
	notice.OnClientEvent:Fire("notice_respawn")
	notice.OnClientEvent:Fire("notice_respawn")
	advance(0.1)
	assert(shownText(Strings.get("notice_respawn") .. "  x2"), "repeated toast counts up")
	for _ = 1, 6 do
		notice.OnClientEvent:Fire("data_loading")
		notice.OnClientEvent:Fire("players_title")
		notice.OnClientEvent:Fire("menu_bag")
		notice.OnClientEvent:Fire("menu_pass")
		notice.OnClientEvent:Fire("menu_log")
	end
	advance(0.1)
	local pills = 0
	for _, descendant in playerGui.Hud:GetDescendants() do
		if descendant.Name == "Toast" and descendant.Parent and isShown(descendant) then
			pills += 1
		end
	end
	assert(pills <= 4, "at most four toasts at once, got " .. pills)
	advance(4)
end)

test("quest panel: a counting quest fills a bar that turns green when done", function()
	local saved = {}
	for _, key in { "QuestId", "QuestState", "QuestCount", "QuestGoal" } do
		saved[key] = hero:GetAttribute(key)
	end
	setAttributes({ QuestId = "first_purify", QuestState = "active", QuestCount = 2, QuestGoal = 5 })
	local bar = playerGui.Hud:FindFirstChild("QuestBar", true)
	assert(isShown(bar), "bar for a counting quest")
	local fill = bar:FindFirstChild("Fill")
	assert(math.abs(fill.Size.X.Scale - 0.4) < 0.01, "2 of 5")
	setAttributes({ QuestCount = 5 })
	assert(fill.Size.X.Scale > 0.99 and fill.BackgroundColor3.G > 0.8, "full and green")
	setAttributes({ QuestState = "available" })
	assert(not isShown(bar), "no bar when the quest is not running")
	-- A quest that does not move for a few minutes nudges with a gentle beat; progress calms it.
	local panel = bar.Parent
	setAttributes({ QuestState = "active", QuestCount = 1 })
	H.advance(170, 0.5)
	eq(panel:FindFirstChild("Pulse"), nil, "not yet")
	H.advance(20, 0.5)
	assert(panel:FindFirstChild("Pulse"), "a stuck quest beats")
	setAttributes({ QuestCount = 2 })
	eq(panel:FindFirstChild("Pulse"), nil, "progress calms it")
	setAttributes(saved)
end)

test("day and night: the sky follows the server clock; the setting keeps it afternoon", function()
	local DayCycle = H.loadModule("src/shared/DayCycle.luau")
	local Lighting = H.game:GetService("Lighting")
	advance(0.5)
	local expected = DayCycle.clock(H.EPOCH + H.now())
	assert(math.abs(Lighting.ClockTime - expected) < 0.2, "clock " .. Lighting.ClockTime .. " vs " .. expected)
	local fireflies = workspace:FindFirstChild("LvNightFireflies")
	assert(fireflies and fireflies:FindFirstChild("Fireflies"), "night fireflies follow the player")
	local rate = fireflies.Fireflies.Rate
	eq(rate > 0, DayCycle.night(expected) > 0, "fireflies only after dark")
	setAttributes({ Pref_dayNight = false })
	advance(0.5)
	eq(Lighting.ClockTime, 15.5, "off: always afternoon")
	eq(fireflies.Fireflies.Rate, 0, "no fireflies in the afternoon")
	setAttributes({ Pref_dayNight = true })
	advance(0.5)
end)

test("ambience: particles match the place (pollen, leaves, snow...), marsh showers, all off on Low effects", function()
	local holder = workspace:FindFirstChild("LvAmbience")
	assert(holder and holder:FindFirstChild("Ambience"), "ambience emitter exists")
	local emitter = holder.Ambience
	teleport(vec(WorldData.spawn, 3))
	advance(0.6)
	assert(emitter.Rate > 0, "village pollen")
	-- Birdsong in the village by day (the afternoon with Day & night off), crickets after dark.
	setAttributes({ Pref_dayNight = false })
	advance(2)
	local SoundService = H.game:GetService("SoundService")
	local birds = SoundService:FindFirstChild("Ambient_birds")
	assert(birds and birds.Playing and birds.Volume > 0, "birds by day")
	local crickets = SoundService:FindFirstChild("Ambient_crickets")
	assert(not (crickets and crickets.Playing), "no crickets by day")
	setAttributes({ Pref_dayNight = true })
	local villageColor = emitter.Color.Keypoints[1].Value
	teleport(vec(WorldData.areas.peaks.center, 3))
	advance(2)
	assert(emitter.Rate > 0 and emitter.Color.Keypoints[1].Value ~= villageColor, "snow on the peaks looks different")
	assert(not birds.Playing, "no birds on the peaks")
	-- Rain in the marsh now and then, the same for everyone (server time).
	local DayCycle = H.loadModule("src/shared/DayCycle.luau")
	local rain = workspace.LvRain.Rain
	eq(rain.Rate, 0, "no rain on the peaks")
	teleport(vec(WorldData.areas.marsh.center, 3))
	local into = workspace:GetServerTimeNow() % DayCycle.RAIN_EVERY
	H.advance((DayCycle.RAIN_EVERY - into + DayCycle.RAIN_LENGTH / 2) % DayCycle.RAIN_EVERY + 0.1, 0.5)
	advance(0.6)
	assert(rain.Rate > 0 and workspace.LvSplashes.Splashes.Rate > 0, "a marsh shower, with splashes")
	local rainSound = H.game:GetService("SoundService"):FindFirstChild("Ambient_rain")
	advance(2)
	assert(rainSound and rainSound.Playing and rainSound.Volume > 0, "and the sound of rain")
	local minimap = playerGui.Minimap
	assert(isShown(minimap:FindFirstChild("WeatherRain", true)), "a rain cloud over the marsh on the mini map")
	assert(not isShown(minimap:FindFirstChild("WeatherSnow", true)), "no blizzard meanwhile")
	H.advance(DayCycle.RAIN_LENGTH / 2 + 5, 0.5)
	advance(2)
	eq(rain.Rate, 0, "the shower passes")
	assert(not rainSound.Playing and rainSound.Volume == 0, "the rain sound fades out")
	H.advance(DayCycle.RAIN_EVERY - DayCycle.RAIN_LENGTH, 0.5)
	advance(0.6)
	assert(rain.Rate > 0, "and comes back")
	-- Between the showers a blizzard sweeps the peaks: more snow, wind, a colder and thicker haze.
	local Lighting = H.game:GetService("Lighting")
	local Graphics = H.loadModule("src/client/Graphics.luau")
	teleport(vec(WorldData.areas.peaks.center, 3))
	advance(0.6)
	local calmSnow = emitter.Rate
	into = (workspace:GetServerTimeNow() + DayCycle.RAIN_EVERY / 2) % DayCycle.RAIN_EVERY
	H.advance((DayCycle.RAIN_EVERY - into + DayCycle.RAIN_LENGTH / 2) % DayCycle.RAIN_EVERY + 0.1, 0.5)
	advance(6)
	assert(emitter.Rate > calmSnow * 2, "a blizzard: " .. emitter.Rate .. " vs " .. calmSnow)
	local wind = H.game:GetService("SoundService"):FindFirstChild("Ambient_wind")
	assert(wind and wind.Playing and wind.Volume > 0, "the wind howls")
	assert(isShown(minimap:FindFirstChild("WeatherSnow", true)), "a snow cloud over the peaks on the mini map")
	local haze = Lighting:FindFirstChildOfClass("Atmosphere")
	assert(haze and haze.Density > Graphics.HAZE.density + 0.1, "the haze thickens")
	teleport(vec(WorldData.spawn, 3))
	advance(6)
	assert(math.abs(haze.Density - Graphics.HAZE.density) < 1e-3, "back to the usual haze off the peaks")
	assert(not wind.Playing, "no wind in the village")
	teleport(vec(WorldData.areas.peaks.center, 3))
	local warned = false
	for _ = 1, 6 do
		advance(0.5)
		warned = warned or shownText(Strings.get("place_blizzard"))
	end
	assert(warned, "walking into the storm, the place title warns of it")
	teleport(vec(WorldData.spawn, 3))
	advance(6)
	setAttributes({ Pref_quality = "custom", Pref_effects = "low" })
	advance(0.6)
	eq(emitter.Rate, 0, "nothing with Low effects")
	eq(rain.Rate, 0, "no rain with Low effects")
	setAttributes({ Pref_quality = "auto", Pref_effects = "high" })
	teleport(vec(WorldData.spawn, 3))
	advance(0.6)
end)

test("idle camera: left alone it slowly circles the hero, any input brings it straight back", function()
	local UIS = H.services.UserInputService
	local function nudge()
		UIS.InputBegan:Fire({ KeyCode = Enum.KeyCode.Unknown, UserInputType = Enum.UserInputType.Keyboard }, false)
	end
	local function heading(): number
		local look = H.read(workspace.CurrentCamera, "CFrame").LookVector
		return math.deg(math.atan2(look.X, -look.Z))
	end
	nudge()
	advance(1)
	local usual = heading()
	local function turned(): number
		return math.abs((heading() - usual + 180) % 360 - 180)
	end
	advance(20)
	assert(turned() < 1, "not yet after 20 s")
	-- A hit while standing still counts as playing.
	local humanoid = hero.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid.Health
	humanoid.Health = health - 1
	advance(10)
	assert(turned() < 1, "not while fighting")
	humanoid.Health = health
	advance(30)
	assert(turned() > 5, "circling after a while: " .. turned())
	nudge()
	advance(1)
	assert(turned() < 1, "back to the usual view on any input: " .. turned())
end)

test("a quest's closing scene opens on its giver cheering with floating hearts", function()
	local head = workspace.LanternValleyMap.Village.Wren.Head
	local function hearts(): number
		local count = 0
		for _, child in head:GetChildren() do
			if child.Name == "Heart" then
				count += 1
			end
		end
		return count
	end
	remotes.Cinematic.OnClientEvent:Fire("marsh_scouts_end")
	advance(1)
	assert(hearts() >= 2, "hearts over Ranger Wren, who gave the quest: " .. hearts())
	assert(shownText(Strings.get("npc_wren_name") .. "  " .. Strings.get("icon_heart")), "and a heart by her name in the caption")
	eq(workspace.LanternValleyMap.Village.Elder.Head:FindFirstChild("Heart"), nil, "not over the Elder")
	advance(3)
	eq(hearts(), 0, "the hearts float away")
	click(findButton(Strings.get("cinematic_skip")))
	advance(1)
end)

test("glow pond: rings spread on the water and frogs croak nearby, nothing far away", function()
	local pond = vec(WorldData.landmarks.glow_pond.position)
	local function ripples(): number
		local count = 0
		for _, child in workspace:GetChildren() do
			if child.Name == "LvRipple" then
				count += 1
			end
		end
		return count
	end
	teleport(pond + Vector3.new(0, 3, 14))
	-- Rings are random (most updates) and short-lived, so look throughout rather than at one moment.
	local seen = false
	for _ = 1, 12 do
		advance(0.25)
		seen = seen or ripples() > 0
	end
	assert(seen, "rings on the water")
	local frogs = H.game:GetService("SoundService"):FindFirstChild("Ambient_frogs")
	assert(frogs and frogs.Playing and frogs.Volume > 0, "frogs croak by the pond")
	teleport(vec(WorldData.spawn, 3))
	advance(4)
	eq(ripples(), 0, "rings stop when nobody is near")
	assert(not frogs.Playing, "the frogs fall quiet")
end)

test("marsh lightning: while it pours the sky flickers and thunder follows; no flicker with flashes off", function()
	local DayCycle = H.loadModule("src/shared/DayCycle.luau")
	local Sounds = H.loadModule("src/shared/Sounds.luau")
	local flash = workspace.CurrentCamera:FindFirstChild("LvLightning")
	assert(flash, "the flash effect")
	local thunder = 0
	H.localSound = function(sound)
		if sound.SoundId == Sounds.thunder.id then
			thunder += 1
		end
	end
	teleport(vec(WorldData.areas.marsh.center, 3))
	local into = workspace:GetServerTimeNow() % DayCycle.RAIN_EVERY
	H.advance((DayCycle.RAIN_EVERY - into + DayCycle.RAIN_FADE + 2) % DayCycle.RAIN_EVERY, 0.5)
	local brightest = 0
	for _ = 1, 25 / 0.05 do
		advance(0.05)
		brightest = math.max(brightest, flash.Brightness)
	end
	assert(brightest > 0.2, "the sky flickers")
	assert(thunder >= 1, "thunder follows")
	setAttributes({ Pref_flashes = false })
	brightest, thunder = 0, 0
	for _ = 1, 25 / 0.05 do
		advance(0.05)
		brightest = math.max(brightest, flash.Brightness)
	end
	eq(brightest, 0, "flashes off: no flicker")
	assert(thunder >= 1, "but the thunder is still heard")
	setAttributes({ Pref_flashes = true })
	H.localSound = nil
	teleport(vec(WorldData.spawn, 3))
	advance(1)
end)

test("see-through: map parts between the camera and the player fade, then come back", function()
	local map = workspace:FindFirstChild("LanternValleyMap")
	local madeMap = false
	if not map then
		map = Instance.new("Folder")
		map.Name = "LanternValleyMap"
		map.Parent = workspace
		madeMap = true
	end
	local canopy = Instance.new("Part")
	canopy.Name = "Canopy"
	canopy.Parent = map
	local blockAt = Vector3.new(0, 20, 0)
	local blocking = true
	H.raycast = function(_, origin)
		if blocking and (origin - blockAt).Magnitude > 0.5 then
			return { Instance = canopy, Position = blockAt }
		end
		return nil
	end
	advance(0.5)
	assert(canopy.LocalTransparencyModifier > 0.6, "the blocking canopy fades")
	blocking = false
	advance(0.5)
	eq(canopy.LocalTransparencyModifier, 0, "and comes back when it no longer blocks")
	H.raycast = nil
	canopy:Destroy()
	if madeMap then
		map:Destroy()
	end
end)

test("the player card names what the next level milestone opens", function()
	local heroLevel = hero:GetAttribute("Level")
	setAttributes({ Level = 4 })
	assert(shownText(Strings.get("hud_next_unlock", Balance.abilities.star.unlockLevel, Strings.get("ability_star"))), "Star Fall next")
	setAttributes({ Level = 26 })
	assert(shownText(Strings.get("hud_next_unlock", 50, Strings.get("unlock_weapon_slot", 2))), "second floating weapon next")
	setAttributes({ Level = 100 })
	assert(not isShown(playerGui.Hud:FindFirstChild("NextUnlock", true)), "nothing left at the top")
	setAttributes({ Level = heroLevel })
end)

test("prompts: drawn in the game's look with the key, action and target", function()
	local Prompts = H.loadModule("src/client/Prompts.luau")
	local part = Instance.new("Part")
	part.Parent = workspace
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Talk"
	prompt.ObjectText = "Test Friend"
	prompt.Parent = part
	Prompts.show(prompt, Enum.ProximityPromptInputType.Keyboard)
	assert(shownText("Talk") and shownText("Test Friend"), "action and target")
	assert(shownText("E"), "the key to press")
	Prompts.hide(prompt)
	assert(not shownText("Test Friend"), "gone when Roblox hides it")
	-- The pill goes under the thing while the hero stands beyond it (higher on screen), so it
	-- never covers the hero; with the hero in front it floats over the thing.
	local eye = H.read(workspace.CurrentCamera, "CFrame").Position
	local heroAt = H.read(hero.Character.HumanoidRootPart, "Position")
	local towardCamera = ((eye - heroAt) * Vector3.new(1, 0, 1)).Unit
	part.Position = heroAt + towardCamera * 6
	Prompts.show(prompt, Enum.ProximityPromptInputType.Keyboard)
	assert(playerGui.LvPrompt.StudsOffset.Y < 0, "the hero beyond it: the pill goes under it")
	Prompts.hide(prompt)
	part.Position = heroAt - towardCamera * 6
	Prompts.show(prompt, Enum.ProximityPromptInputType.Keyboard)
	assert(playerGui.LvPrompt.StudsOffset.Y > 0, "the hero in front of it: over it")
	Prompts.hide(prompt)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Parent = part
	Prompts.show(prompt, Enum.ProximityPromptInputType.Keyboard)
	eq(tag.Enabled, false, "the name tag steps aside while the prompt names it")
	Prompts.hide(prompt)
	eq(tag.Enabled, true, "and comes back")
	Prompts.show(prompt, Enum.ProximityPromptInputType.Touch)
	assert(not shownText("E"), "a hand instead of a key on touch screens")
	Prompts.hide(prompt)
	part:Destroy()
end)

test("a new Light Pass tier makes the Pass button glow for a moment", function()
	local target = findButton(Strings.get(if touchMode then "menu_hub" else "menu_pass"))
	remotes.Notice.OnClientEvent:Fire("notice_pass_tier", 3)
	advance(0.2)
	assert(target:FindFirstChild("Pulse"), "glowing")
	advance(3.2)
	assert(not target:FindFirstChild("Pulse"), "then calm again")
end)

test("defeat: the screen says what happened, counts down and gives a tip, then clears", function()
	local humanoid = hero.Character:FindFirstChildOfClass("Humanoid")
	local health = humanoid.Health
	humanoid.Health = 0
	advance(0.3)
	assert(shownText(Strings.get("defeat_title")), "defeat title")
	assert(shownText(Strings.get("defeat_countdown", Balance.player.respawnTime)), "countdown")
	advance(1.1)
	assert(shownText(Strings.get("defeat_countdown", Balance.player.respawnTime - 1)), "counting down")
	humanoid.Health = health
	advance(0.2)
	assert(not shownText(Strings.get("defeat_title")), "gone once alive again")
	-- The last hit names who won; one far above the player picks the "grow first" tip.
	local level = hero:GetAttribute("Level") or 1
	remotes.Fx.OnClientEvent:Fire("hurt", H.read(hero.Character.HumanoidRootPart, "Position") + Vector3.new(5, 0, 0), "Frostling", level + 20)
	humanoid.Health = 0
	advance(0.3)
	assert(shownText(Strings.get("defeat_by", level + 20, Strings.get(Balance.enemies.Frostling.nameKey))), "defeated by a Frostling")
	assert(shownText(Strings.get("defeat_tip_level")), "much stronger: grow a little first")
	humanoid.Health = health
	advance(7)
	humanoid.Health = 0
	advance(0.3)
	assert(not shownText(Strings.get("defeat_by", level + 20, Strings.get(Balance.enemies.Frostling.nameKey))), "an old hit is not named")
	humanoid.Health = health
	advance(0.2)
	-- Lantern Glow is only suggested once it is unlocked.
	local function healTipShown(heroLevel: number): boolean
		setAttributes({ Level = heroLevel })
		local seen = false
		for _ = 1, 4 do
			humanoid.Health = 0
			advance(0.3)
			seen = seen or shownText(Strings.get("defeat_tip_heal"))
			humanoid.Health = health
			advance(0.2)
		end
		return seen
	end
	eq(healTipShown(1), false, "no healing tip before Lantern Glow")
	eq(healTipShown(Balance.abilities.heal.unlockLevel), true, "then it comes up")
	setAttributes({ Level = level })
end)

test("mini map: north mark, the place you are in, a title when you enter a new place, open rifts", function()
	teleport(vec(WorldData.spawn, 3))
	advance(0.5)
	assert(shownText(Strings.get("map_north")), "N on the map")
	assert(shownText(Strings.get("place_village")), "the village named under the map")
	teleport(vec(WorldData.areas.peaks.center, 3))
	advance(0.3)
	local function bannerSays(text: string): boolean
		for _, label in playerGui.Hud:GetDescendants() do
			if label:IsA("TextLabel") and label.Text == text and isShown(label) then
				return true
			end
		end
		return false
	end
	assert(bannerSays(Strings.get("place_peaks")), "entering the peaks shows their name in the banner")
	advance(3.5)
	assert(not bannerSays(Strings.get("place_peaks")), "then it goes")
	local center = vec(WorldData.areas.marsh.center, 0)
	remotes.Fx.OnClientEvent:Fire("riftOpened", "marsh", center)
	advance(0.3)
	local riftShown = false
	for _, child in playerGui.Minimap:GetDescendants() do
		if child.Name == "Rift" and isShown(child) then
			riftShown = true
		end
	end
	assert(riftShown, "the open rift is on the map")
	remotes.Fx.OnClientEvent:Fire("riftClosed", "marsh", center, true)
	teleport(vec(WorldData.spawn, 3))
	advance(3.5)
end)

test("purify streak: counts chained purifications, celebrates milestones, leaves when the chain breaks", function()
	local CombatFeel = H.loadModule("src/shared/CombatFeel.luau")
	advance(CombatFeel.WINDOW + 1)
	local reward = remotes.RewardGranted.OnClientEvent
	reward:Fire("purify", 5, 0)
	reward:Fire("purify", 5, 0)
	advance(0.1)
	assert(not shownText(Strings.get("hud_streak_label")), "two in a row is not a streak yet")
	reward:Fire("purify", 5, 0)
	advance(0.1)
	assert(shownText(Strings.get("hud_streak", 3)), "x3 shows")
	assert(shownText(Strings.get("hud_streak_label")))
	reward:Fire("quest", 10, 10)
	advance(0.1)
	assert(shownText(Strings.get("hud_streak", 3)), "quest rewards are not purifications")
	for _ = 1, 7 do
		reward:Fire("purify", 5, 0)
		advance(0.5)
	end
	assert(shownText(Strings.get("hud_streak", 10)), "x10")
	assert(shownText(Strings.get("notice_streak", 10)), "milestone toast")
	advance(CombatFeel.WINDOW + 0.5)
	assert(not shownText(Strings.get("hud_streak_label")), "the counter leaves when the chain breaks")
	advance(3)
end)

test("creature labels: near the player, tinted by the level gap, health in numbers, a trail of the last hit", function()
	local CombatFeel = H.loadModule("src/shared/CombatFeel.luau")
	local heroLevel = hero:GetAttribute("Level")
	teleport(vec(WorldData.spawn, 3))
	setAttributes({ Level = 10 })
	local enemy = addEnemy("Rockling", vec(WorldData.spawn, 3) + Vector3.new(20, 0, 0))
	enemy:SetAttribute("Level", 20)
	H.setAttribute(enemy, "MaxHp", 100)
	H.setAttribute(enemy, "Hp", 100)
	advance(0.5)
	local gui
	for _, candidate in workspace.ClientFx:GetDescendants() do
		if candidate:IsA("BillboardGui") and candidate.Adornee == enemy:FindFirstChild("Body") then
			gui = candidate
		end
	end
	if not gui then
		for _, folder in { playerGui, workspace } do
			for _, candidate in folder:GetDescendants() do
				if candidate:IsA("BillboardGui") and candidate.Adornee == enemy:FindFirstChild("Body") then
					gui = candidate
				end
			end
		end
	end
	assert(gui, "creature label exists")
	local name = gui:FindFirstChild("NameLabel")
	setAttributes({ Level = 11 })
	setAttributes({ Level = 10 })
	eq(CombatFeel.threat(10, 20), "deadly")
	assert(name.TextColor3.G < 0.5, "ten levels above the player: red")
	setAttributes({ Level = 19 })
	eq(CombatFeel.threat(19, 20), "even")
	assert(name.TextColor3.G > 0.9, "a fair fight: plain cream")
	setAttributes({ Level = 26 })
	assert(name.TextColor3.R < 0.7, "far below the player: grey")
	-- Shown near the hero (the camera sits far behind, so this is measured from the hero).
	assert(gui.Enabled, "a calm creature close by shows its label")
	eq(gui:FindFirstChild("HpText", true).Text, Strings.get("enemy_hp", "100", "100"), "its health in numbers")
	teleport(vec(WorldData.spawn, 3) + Vector3.new(-40, 0, 0))
	advance(0.3)
	eq(gui.Enabled, false, "a calm creature far away keeps quiet")
	assert(not enemy.Body:FindFirstChild("EliteSparkles"), "plain creatures do not sparkle")
	local elite = addEnemy("Rockling", vec(WorldData.spawn, 3) + Vector3.new(26, 0, 0), { Elite = true })
	advance(0.2)
	assert(elite.Body:FindFirstChild("EliteSparkles"), "elites sparkle gold")
	elite:Destroy()
	H.setAttribute(enemy, "Hp", 40)
	advance(0.3)
	assert(gui.Enabled, "a hurt one shows from further away")
	eq(gui:FindFirstChild("HpText", true).Text, Strings.get("enemy_hp", "40", "100"), "how much health is left")
	teleport(vec(WorldData.spawn, 3))
	local fill, trail = gui:FindFirstChild("Fill", true), gui:FindFirstChild("Trail", true)
	assert(fill.Size.X.Scale < 0.45 and trail.Size.X.Scale > 0.9, "the trail lingers after a hit")
	advance(1)
	assert(trail.Size.X.Scale < 0.45, "then drains")
	-- In a fight only the hero's target (and elites) keep the full label; others show a slim bar.
	eq(name.Visible, false, "a hurt creature that is not the target: no name")
	eq(gui:FindFirstChild("HpText", true).Visible, false, "and no numbers, just a slim bar")
	assert(gui.Enabled and fill.Visible, "the bar itself stays")
	remotes.Fx.OnClientEvent:Fire("attack", hero, "staff", 0, H.read(hero.Character.HumanoidRootPart, "Position"), H.read(enemy.Body, "Position"), 0)
	advance(0.3)
	assert(name.Visible and gui:FindFirstChild("HpText", true).Visible, "the hero's target keeps name and numbers")
	enemy:Destroy()
	setAttributes({ Level = heroLevel })
end)

test("the waypoint's edge arrow points the right way: ahead off screen at the top, behind at the bottom", function()
	setAttributes({ QuestState = "available" })
	advance(0.6)
	local edge = playerGui.WaypointEdge.EdgeArrow
	local height = workspace.CurrentCamera.ViewportSize.Y
	local function arrowAt(point: Vector3): number?
		fakeViewportPoint = point
		advance(0.05)
		return if edge.Visible then edge.Position.Y.Offset else nil
	end
	local ahead = arrowAt(Vector3.new(workspace.CurrentCamera.ViewportSize.X / 2, -400, 30))
	assert(ahead and ahead < height / 2, "a goal far ahead: the arrow is at the top")
	local panelScale = playerGui.Hud:FindFirstChild("QuestPanel", true).Parent:FindFirstChildOfClass("UIScale").Scale
	assert(ahead >= (12 + 72) * panelScale, "below the quest panel, not over it")
	local behind = arrowAt(Vector3.new(workspace.CurrentCamera.ViewportSize.X / 2, -400, -30))
	assert(behind and behind > height / 2, "a goal behind: the arrow is at the bottom")
	eq(arrowAt(Vector3.new(300, 200, 30)), nil, "on screen: no arrow")
	fakeViewportPoint = nil
	advance(0.05)
end)

test("the Great Lantern's Rebirth prompt shows only to players who can rebirth", function()
	local Progression = H.loadModule("src/shared/Progression.luau")
	local prompt = workspace.LanternValleyMap.Village.LanternPost.RebirthPrompt
	local heroLevel = hero:GetAttribute("Level")
	setAttributes({ Level = 1 })
	eq(prompt.Enabled, false, "a new player walks past it")
	setAttributes({ Level = Progression.MAX_LEVEL })
	eq(prompt.Enabled, true, "at the top level it offers a rebirth")
	setAttributes({ Level = heroLevel })
end)

test("the quest panel turns see-through while a creature label is behind it", function()
	local panel = playerGui.Hud:FindFirstChild("QuestPanel", true)
	assert(isShown(panel), "quest panel up")
	panel.AbsolutePosition, panel.AbsoluteSize = Vector2.new(470, 12), Vector2.new(340, 72)
	local spot = vec(WorldData.spawn, 3)
	teleport(spot)
	local enemy = addEnemy("Rockling", spot + Vector3.new(0, 0, -12))
	advance(0.5)
	fakeScreenPoint = Vector3.new(640, 300, 20)
	advance(0.3)
	assert(panel.BackgroundTransparency < 0.2, "solid while the label is clear of it")
	fakeScreenPoint = Vector3.new(700, 60, 20)
	advance(0.3)
	assert(panel.BackgroundTransparency > 0.5, "see-through with a label behind it")
	fakeScreenPoint = Vector3.new(640, 300, 20)
	advance(0.4)
	assert(panel.BackgroundTransparency > 0.5, "holds a moment")
	advance(1)
	assert(panel.BackgroundTransparency < 0.2, "then solid again")
	fakeScreenPoint = Vector3.new(700, 60, 20)
	setAttributes({ Pref_enemyBars = false })
	advance(0.5)
	assert(panel.BackgroundTransparency < 0.2, "hidden labels do not count")
	setAttributes({ Pref_enemyBars = true })
	fakeScreenPoint = nil
	enemy:Destroy()
	advance(1.5)
end)

test("the creature the hero's weapon is hitting wears an outline and a ground ring that fade when attacks stop", function()
	local spot = vec(WorldData.spawn, 3)
	teleport(spot)
	local first = addEnemy("Rockling", spot + Vector3.new(12, 0, 0))
	local second = addEnemy("Rockling", spot + Vector3.new(-12, 0, 0))
	advance(0.2)
	remotes.Fx.OnClientEvent:Fire("attack", hero, "staff", 0, spot, H.read(first.Body, "Position"), 0)
	local mark = first:FindFirstChild("TargetMark")
	assert(mark and mark.OutlineTransparency < 0.5, "the chosen creature is outlined")
	local ring = workspace.ClientFx:FindFirstChild("TargetRing")
	assert(ring, "a ring on the ground under it")
	local function under(model): boolean
		advance(0.05)
		local offset = H.read(ring, "CFrame").Position - H.read(model.Body, "Position")
		return Vector3.new(offset.X, 0, offset.Z).Magnitude < 0.5 and offset.Y < 0
	end
	assert(under(first), "right under the creature")
	remotes.Fx.OnClientEvent:Fire("attack", hero, "staff", 1, spot, H.read(second.Body, "Position"), 0)
	remotes.Fx.OnClientEvent:Fire("attack", friend, "staff", 0, spot, H.read(second.Body, "Position"), 0)
	eq(mark.Parent, first, "floating weapons and other players do not move it")
	remotes.Fx.OnClientEvent:Fire("attack", hero, "staff", 0, spot, H.read(second.Body, "Position"), 0)
	eq(mark.Parent, second, "the outline moves to the next target")
	assert(under(second), "the ring moves along")
	advance(2)
	eq(mark.OutlineTransparency, 1, "it fades once the attacks stop")
	assert(not workspace.ClientFx:FindFirstChild("TargetRing"), "the ring goes too")
	second:Destroy()
	remotes.Fx.OnClientEvent:Fire("attack", hero, "staff", 0, spot, H.read(first.Body, "Position"), 0)
	local fresh = first:FindFirstChild("TargetMark")
	assert(fresh and fresh.OutlineTransparency < 0.5, "a purified target's outline is replaced")
	first:Destroy()
	advance(2)
end)

if not touchMode then
	test("toasts hang under the quest panel on tall screens and lie over it on short ones", function()
		remotes.Notice.OnClientEvent:Fire("notice_streak", 10)
		advance(0.1)
		local holder
		for _, toast in playerGui.Hud:GetDescendants() do
			if toast.Name == "Toast" then
				holder = toast.Parent
			end
		end
		local camera = workspace.CurrentCamera
		local function resize(size: Vector2)
			camera.ViewportSize = size
			H.signalFor(camera, "prop:ViewportSize"):Fire()
		end
		eq(holder.Position.Y.Offset, 0, "a 720-tall window: over the quest panel, clear of the hero")
		resize(Vector2.new(1920, 1080))
		assert(holder.Position.Y.Offset > 72, "a tall screen: under the quest panel")
		resize(Vector2.new(1280, 720))
		eq(holder.Position.Y.Offset, 0, "and back")
		advance(4)
	end)

	test("a ready ability that would help beats: Lantern Glow when hurt, Light Wave in a crowd", function()
		local bar = playerGui.Controls:FindFirstChild("AbilityBar")
		local function beating(id: string): boolean
			return bar:FindFirstChild(id):FindFirstChild("Pulse", true) ~= nil
		end
		local heroLevel = hero:GetAttribute("Level")
		setAttributes({ Level = Balance.abilities.heal.unlockLevel })
		local spot = vec(WorldData.spawn, 3)
		teleport(spot)
		advance(31) -- any earlier cast has cooled down
		local humanoid = hero.Character:FindFirstChildOfClass("Humanoid")
		local health = humanoid.Health
		eq(beating("heal"), false, "calm at full health")
		humanoid.Health = humanoid.MaxHealth * 0.3
		advance(0.5)
		assert(beating("heal"), "hurt: Lantern Glow beats")
		humanoid.Health = health
		advance(0.5)
		eq(beating("heal"), false, "healed: calm again")
		eq(beating("wave"), false, "no crowd: Light Wave calm")
		local crowd = {}
		for index = 1, 3 do
			table.insert(crowd, addEnemy("Gloomling", spot + Vector3.new(index * 2, 0, 3)))
		end
		advance(0.5)
		assert(beating("wave"), "a crowd: Light Wave beats")
		for _, creature in crowd do
			creature:Destroy()
		end
		advance(0.5)
		eq(beating("wave"), false, "crowd gone: calm")
		setAttributes({ Level = heroLevel })
	end)

	test("player card: hovering a part says what it is", function()
		local icon = playerGui:FindFirstChild("CrystalIcon", true)
		icon.MouseEnter:Fire()
		advance(0.1)
		assert(shownText(Strings.get("tip_crystals")), "crystals explained")
		icon.MouseLeave:Fire()
		advance(0.1)
		assert(not shownText(Strings.get("tip_crystals")), "gone when the mouse leaves")
	end)

	test("ability tooltips on hover say what it does and when it is ready", function()
		local bar = playerGui.Controls:FindFirstChild("AbilityBar")
		local star = bar:FindFirstChild("star")
		local heroLevel = hero:GetAttribute("Level")
		setAttributes({ Level = 1 })
		star.MouseEnter:Fire()
		advance(0.1)
		assert(shownText(Strings.get("ability_star_desc")), "description")
		assert(shownText(Strings.get("ability_unlocks", Balance.abilities.star.unlockLevel)), "locked: says when it unlocks")
		star.MouseLeave:Fire()
		advance(0.1)
		assert(not shownText(Strings.get("ability_star_desc")), "hidden again")
		setAttributes({ Level = 20 })
		star.MouseEnter:Fire()
		advance(0.1)
		assert(shownText(Strings.get("ability_cooldown", Balance.abilities.star.cooldown)), "unlocked: recharge time")
		star.MouseLeave:Fire()
		setAttributes({ Level = heroLevel })
	end)
end

if touchMode then
	test("touch: the mini map sits left of the Menu button, the daily gift under it, all in the top corner", function()
		-- Both regions hang from the same top-right corner at the same scale, so their contents can be
		-- compared as rectangles measured from that corner (x to the left is negative).
		local function rect(item): { number }
			local width = item.Parent.Size.X.Offset
			local left = (item.Position.X.Scale - 1) * width + item.Position.X.Offset - item.AnchorPoint.X * item.Size.X.Offset
			local top = item.Position.Y.Offset - item.AnchorPoint.Y * item.Size.Y.Offset
			return { left, top, left + item.Size.X.Offset, top + item.Size.Y.Offset }
		end
		local function apart(a, b): boolean
			return a[3] <= b[1] or b[3] <= a[1] or a[4] <= b[2] or b[4] <= a[2]
		end
		local menu = { -100, 0, 0, 48 } -- the grid's right-aligned first cell
		local map = rect(playerGui.Minimap:FindFirstChild("Map", true))
		local region = playerGui.Minimap:FindFirstChild("Map", true).Parent
		eq(region.Position.Y.Offset, 12, "the map's region starts in the top row")
		for _, name in { "DailyGiftButton", "NextGift" } do
			local gift = rect(region:FindFirstChild(name))
			assert(apart(gift, menu) and apart(gift, map), `{name} clear of the Menu button and the map`)
			assert(gift[4] <= map[4] + 22, `{name} no lower than the map`)
		end
		assert(apart(map, menu), "the map clear of the Menu button")
	end)

	test("touch: toasts and the purify streak keep clear of the hero and the controls", function()
		advance(4) -- earlier toasts and banners leave
		for index = 1, 5 do
			remotes.Notice.OnClientEvent:Fire("notice_streak", index * 10)
		end
		advance(0.1)
		local shown = 0
		local holder
		for _, toast in playerGui.Hud:GetDescendants() do
			if toast.Name == "Toast" and isShown(toast) then
				shown += 1
				holder = toast.Parent
			end
		end
		eq(shown, 3, "three toasts at most on a phone")
		eq(holder.Position.Y.Offset, 0, "they start at the top, over the quest panel")
		local streak = playerGui.Hud:FindFirstChild("StreakCount", true).Parent
		assert(streak.Position.X.Scale <= 0.35 and streak.Position.Y.Scale == 0.5 and streak.AnchorPoint == Vector2.new(0.5, 0.5), "the streak sits left of the hero")
		advance(5)
	end)

	test("touch: one Menu button opens big tiles; a tile opens its window; badges show on Menu", function()
		local hub = findButton(Strings.get("menu_hub"))
		assert(hub and isShown(hub), "Menu button in the corner")
		local bag = findButton(Strings.get("menu_bag"))
		assert(not isShown(bag), "menu tiles wait inside the Menu window")
		click(hub)
		advance(0.3)
		assert(isShown(bag), "tiles shown")
		click(bag)
		advance(0.3)
		assert(not isShown(bag), "the Menu window closes when a tile is tapped")
		assert(isShown(playerGui.Menus.Backdrop), "and the chosen window is open")
		click(playerGui.Menus.Backdrop)
		advance(0.3)
		local heroChests = hero:GetAttribute("Chests")
		setAttributes({ Chests = "wood:0" })
		advance(0.6)
		local anyBadge = false
		for _, child in hub:GetChildren() do
			if child:IsA("TextLabel") and child.Text == "!" and isShown(child) then
				anyBadge = true
			end
		end
		assert(anyBadge, "a chest waiting shows ! on the Menu button")
		setAttributes({ Chests = heroChests or "" })
	end)
end

test("menu windows: hotkeys, key caps, a dim backdrop that closes them, blur except in Settings", function()
	local backdrop = playerGui.Menus.Backdrop
	-- Window titles are labels (the menu buttons with the same words are buttons).
	local function windowOpen(key: string): boolean
		for _, descendant in playerGui.Menus:GetDescendants() do
			if descendant:IsA("TextLabel") and descendant.Text == Strings.get(key) and isShown(descendant) then
				return true
			end
		end
		return false
	end
	local blur = workspace.CurrentCamera:FindFirstChild("LvMenuBlur")
	assert(blur, "blur effect exists")
	local bagButton = findButton(Strings.get("menu_bag"))
	eq(bagButton:FindFirstChild("KeyCap") ~= nil, not touchMode, "key cap only on a keyboard")
	eq(findButton(Strings.get("menu_settings")):FindFirstChild("KeyCap"), nil, "Settings has no hotkey")
	-- With a gamepad in hand: no keyboard letters on the menus, the ability badges name pad buttons.
	if not touchMode then
		local UIS = H.services.UserInputService
		local function hints(): { string }
			local found = {}
			for _, descendant in playerGui:GetDescendants() do
				if descendant.Name == "KeyHint" and isShown(descendant) then
					table.insert(found, descendant.Text)
				end
			end
			table.sort(found)
			return found
		end
		eq(table.concat(hints(), ","), "F,Q,R", "keyboard hints on the ability bar")
		UIS.lastInputType = Enum.UserInputType.Gamepad1
		UIS.LastInputTypeChanged:Fire(Enum.UserInputType.Gamepad1)
		eq(bagButton.KeyCap.Visible, false, "no keyboard letters with a gamepad")
		eq(table.concat(hints(), ","), "LB,RB,RT", "pad buttons on the ability bar")
		UIS.lastInputType = Enum.UserInputType.Keyboard
		UIS.LastInputTypeChanged:Fire(Enum.UserInputType.Keyboard)
		eq(bagButton.KeyCap.Visible, true, "letters again on the keyboard")
		eq(table.concat(hints(), ","), "F,Q,R")
	end
	H.services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.B }, false)
	advance(0.4)
	assert(windowOpen("bag_title"), "B opens the bag")
	assert(isShown(backdrop) and backdrop.BackgroundTransparency < 0.7, "the screen dims")
	assert(blur.Size > 5, "the world blurs")
	H.services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.B }, true)
	advance(0.1)
	assert(windowOpen("bag_title"), "a key the game already used does nothing")
	H.services.UserInputService.InputBegan:Fire({ KeyCode = Enum.KeyCode.G }, false)
	advance(0.4)
	assert(windowOpen("menu_weapons") and not windowOpen("bag_title"), "G switches to weapons")
	click(backdrop)
	advance(0.4)
	assert(not windowOpen("menu_weapons"), "a click on the dim backdrop closes the window")
	assert(not isShown(backdrop) and blur.Size < 0.5, "backdrop and blur gone")
	click(findButton(Strings.get("menu_settings")))
	advance(0.4)
	assert(isShown(backdrop) and blur.Size < 0.5, "Settings dims but keeps the world sharp")
	click(findButton(Strings.get("menu_settings")))
	advance(0.4)
end)

test("bag: equip an owned charm, locked ones do nothing", function()
	setAttributes({ Charms = "swift", Charm = "" })
	click(findButton(Strings.get("menu_bag")))
	assert(shownText(Strings.get("charm_swift_desc")), "bag open")
	click(findButton(Strings.get("bag_equip")))
	eq(sent("EquipCharm", function(args)
		return args[1] == "swift"
	end), 1, "equip sent")
	local before = sent("EquipCharm")
	click(findButton(Strings.get("bag_locked")))
	eq(sent("EquipCharm"), before, "locked charm ignored")
	setAttributes({ Charm = "swift" })
	assert(shownText(Strings.get("bag_unequip")), "shows unequip")
	click(findButton(Strings.get("menu_bag")))
	assert(not shownText(Strings.get("charm_swift_desc")), "bag closed")
end)

test("shop: packs say Soon without ids, show prices, prompt only when buyable; costumes", function()
	local StoreData = H.loadModule("src/shared/StoreData.luau")
	local Progression = H.loadModule("src/shared/Progression.luau")
	local Format = H.loadModule("src/shared/Format.luau")
	setAttributes({ Coins = 3000, Costumes = "", Worn = "", OneTime = "", BoostUntil = 0 })
	click(findButton(Strings.get("menu_shop")))
	assert(shownText(Strings.get("shop_note")), "shop open")
	local coins = Format.short(Progression.incomeCoins(hero:GetAttribute("Level"), StoreData.products.coins_small.coinMinutes))
	assert(shownText(Strings.get("store_gives_coins", coins)), "pack shows the coins it gives at this level")
	click(findButton(Strings.get("shop_soon")))
	eq(#prompts, 0, "no product ids yet: nothing to buy")
	click(findButton(Strings.get("menu_shop")))

	StoreData.products.coins_small.productId = 7001
	StoreData.products.starter.productId = 7002
	click(findButton(Strings.get("menu_shop")))
	click(findButton(Strings.get("shop_price_robux", 49)))
	eq(prompts[1], 7001, "Roblox purchase prompt for the pack")
	setAttributes({ OneTime = "starter" })
	assert(not findButton(Strings.get("shop_price_robux", 99)), "starter pack already bought")
	click(findButton(Strings.get("shop_owned")))
	eq(#prompts, 1, "an owned pack does not prompt")

	click(findButton(Strings.get("shop_tab_costumes")))
	assert(shownText(Strings.get("costume_from_pass", 30)), "pass costumes point to the pass")
	click(findButton(Strings.get("hud_coins", Format.short(2000))))
	eq(sent("BuyCosmetic", function(args)
		return args[1] == "lantern_hat"
	end), 1, "buy with coins")
	setAttributes({ Costumes = "lantern_hat" })
	click(findButton(Strings.get("costume_wear")))
	eq(sent("EquipCosmetic", function(args)
		return args[1] == "lantern_hat" and args[2] == "hat"
	end), 1, "wear")
	setAttributes({ Worn = "hat:lantern_hat" })
	click(findButton(Strings.get("costume_remove")))
	eq(sent("EquipCosmetic", function(args)
		return args[1] == "" and args[2] == "hat"
	end), 1, "remove")
	click(findButton(Strings.get("menu_shop")))
	assert(not shownText(Strings.get("shop_note")), "shop closed")
	StoreData.products.coins_small.productId = 0
	StoreData.products.starter.productId = 0
end)

test("light pass: tiers, claim all, costume cell, premium button, badge", function()
	local StoreData = H.loadModule("src/shared/StoreData.luau")
	local PassData = H.loadModule("src/shared/PassData.luau")
	local passButton = findButton(Strings.get("menu_pass"))
	setAttributes({ PassSeason = 1, PassXp = 0, PassFree = "", PassPremiumClaimed = "", PassPremium = false })
	eq(findText("!", passButton).Visible, false, "no badge with nothing to claim")
	setAttributes({ PassXp = 5 * PassData.xpPerTier + 10 })
	eq(findText("!", passButton).Visible, true, "badge when a tier is ready")
	click(passButton)
	assert(shownText(Strings.get("pass_tier", 5, PassData.tiers)), "tier shown")
	click(findButton(Strings.get("pass_claim_all")))
	eq(sent("ClaimPass", function(args)
		return args[1] == "all"
	end), 1, "claim all")
	click(findButton(Strings.get("costume_leaf_crown")))
	eq(sent("ClaimPass", function(args)
		return args[1] == 5 and args[2] == "free"
	end), 1, "claim one cell")
	local before = #prompts
	click(findButton(Strings.get("pass_get_premium") .. "  " .. Strings.get("shop_soon")))
	eq(#prompts, before, "premium not on sale yet")
	click(passButton)
	StoreData.products.pass_premium.productId = 7003
	click(passButton)
	click(findButton(Strings.get("pass_get_premium") .. "  " .. Strings.get("shop_price_robux", 299)))
	eq(prompts[#prompts], 7003, "premium prompt")
	local free = {}
	for tier = 1, 5 do
		table.insert(free, tostring(tier))
	end
	setAttributes({ PassPremium = true, PassFree = table.concat(free, ","), PassPremiumClaimed = table.concat(free, ",") })
	assert(shownText(Strings.get("pass_premium_on")), "premium active")
	eq(findText("!", passButton).Visible, false, "badge gone once everything is claimed")
	click(passButton)
	StoreData.products.pass_premium.productId = 0
end)

test("double XP time left shows on the HUD while the boost runs", function()
	local label = findText(Strings.get("hud_boost", 1, 30))
	assert(label == nil or not isShown(label), "no boost label yet")
	hero:SetAttribute("BoostUntil", workspace:GetServerTimeNow() + 90.4)
	advance(0.6)
	assert(shownText(Strings.get("hud_boost", 1, 29)) or shownText(Strings.get("hud_boost", 1, 30)), "boost time left")
	hero:SetAttribute("BoostUntil", 0)
	advance(0.6)
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextLabel") and string.find(descendant.Text, "2x XP", 1, true) then
			assert(not isShown(descendant), "hidden when the boost ends")
		end
	end
end)

test("shadow tower: floor banner; a card with floor, best, boss distance, shadows left and new records", function()
	local function card(): any
		return findText(Strings.get("icon_tower")).Parent
	end
	local questPanel = playerGui:FindFirstChild("QuestTick", true).Parent
	setAttributes({ TowerBest = 7, TowerFloor = 0 })
	assert(not isShown(card()), "no card outside the tower")
	assert(isShown(questPanel), "the quest panel outside")
	setAttributes({ TowerFloor = 3 })
	assert(isShown(card()) and not isShown(questPanel), "inside, the card takes the quest panel's place")
	assert(shownText(Strings.get("tower_floor", 3)), "the floor")
	local sub = Strings.get("tower_card_best", 7) .. "   ·   " .. Strings.get("tower_card_boss_in", Balance.tower.bossEvery - 3)
	assert(shownText(sub), "best floor and how far the boss is: " .. sub)
	assert(not isShown(card().Left), "no count before the shadows arrive")
	-- Shadows count down; a cleared floor shows a tick.
	setAttributes({ TowerLeft = 6 })
	eq(card().Left.Count.Text, "6")
	assert(shownText(Strings.get("tower_card_left")), "shadows left")
	setAttributes({ TowerLeft = 0 })
	eq(card().Left.Count.Text, "✓")
	assert(shownText(Strings.get("tower_card_clear")), "floor clear")
	-- The floor before a boss warns.
	setAttributes({ TowerFloor = Balance.tower.bossEvery - 1 })
	assert(shownText(Strings.get("tower_card_best", 7) .. "   ·   " .. Strings.get("tower_card_boss_next")), "boss next floor")
	setAttributes({ TowerFloor = 3 })
	remotes.Fx.OnClientEvent:Fire("towerFloor", 3, 8)
	advance(0.2)
	assert(shownText(Strings.get("tower_floor", 3)), "floor banner")
	assert(workspace.ClientFx:FindFirstChild("FloorLight"), "a column of light rises in the arena")
	assert(shownText(Strings.get("tower_floor_sub", 8)), "creature count under it")
	remotes.Fx.OnClientEvent:Fire("towerFloor", 10, 2, "enemy_bogmother_name")
	advance(0.2)
	assert(shownText(Strings.get("tower_floor", 10)), "boss floor banner")
	assert(shownText(Strings.get("tower_floor_boss", Strings.get("enemy_bogmother_name"))), "the banner names the Legendary Shadow")
	-- A new best floor glows gold for a moment, then the best number follows.
	setAttributes({ TowerBest = 8 })
	assert(shownText(Strings.get("tower_card_record")), "new best celebrated")
	advance(4)
	assert(not shownText(Strings.get("tower_card_record")), "the celebration ends")
	assert(shownText(Strings.get("tower_card_best", 8) .. "   ·   " .. Strings.get("tower_card_boss_in", Balance.tower.bossEvery - 3)), "best floor follows")
	remotes.Fx.OnClientEvent:Fire("towerFloor", "x", nil)
	setAttributes({ TowerFloor = 0, TowerLeft = nil })
	assert(not isShown(card()) and isShown(questPanel), "card hides after leaving, the quest is back")
	setAttributes({ TowerBest = 9 })
	assert(not shownText(Strings.get("tower_card_record")), "no celebration outside the tower")
	advance(3)
end)

test("villagers chat: a bubble pops over one the hero walks past, not up close or far away", function()
	local root = hero.Character.HumanoidRootPart
	local home = root.Position
	local elder = WorldData.vector(WorldData.npcs.Elder.position)
	local elderBody = workspace.LanternValleyMap.Village.Elder.Body
	local function bubble(): any
		return elderBody:FindFirstChild("LvChatter")
	end
	local elderLines = { Strings.get("chatter_elder_1"), Strings.get("chatter_elder_2"), Strings.get("chatter_elder_3") }
	-- The first line within `seconds`, or nil.
	local function nextLine(seconds: number): string?
		for _ = 1, seconds * 2 do
			advance(0.5)
			local gui = bubble()
			if gui then
				return gui.Bubble:FindFirstChildOfClass("TextLabel").Text
			end
		end
		return nil
	end
	teleport(elder + Vector3.new(0, 0, 5))
	advance(6) -- a line from before the test fades first
	eq(nextLine(20), nil, "up close the talk prompt is up instead")
	teleport(elder + Vector3.new(0, 0, 18))
	local line = nextLine(20)
	assert(line and table.find(elderLines, line), "the Elder says one of her lines as the hero passes")
	-- She nods along while the bubble shows.
	local head = workspace.LanternValleyMap.Village.Elder.Head
	local function headHeight(): number
		return H.read(head, "Position").Y - H.read(elderBody, "Position").Y
	end
	local low, high = math.huge, -math.huge
	for _ = 1, 20 do
		advance(0.05)
		low, high = math.min(low, headHeight()), math.max(high, headHeight())
	end
	assert(high - low > 0.05, "her head nods while she talks: " .. (high - low))
	advance(5)
	eq(bubble(), nil, "the bubble goes away")
	teleport(elder + Vector3.new(0, 0, 60))
	eq(nextLine(20), nil, "far away nobody talks")
	teleport(home)
	advance(0.5)
end)

test("new in the Bag: a pet earned while playing is marked NEW until its tab has been seen", function()
	local PetData = H.loadModule("src/shared/PetData.luau")
	setAttributes({ PetProgress = "" })
	local bagButton = findButton(Strings.get("menu_bag"))
	local badge = bagButton:FindFirstChild("NewBadge")
	-- Leave the Bag on its charms page.
	click(bagButton)
	click(findButton(Strings.get("bag_tab_charms")))
	click(bagButton)
	assert(badge and not badge.Visible, "nothing new yet")
	setAttributes({ PetProgress = "glowmoth:" .. PetData.pets.glowmoth.unlock.goal })
	assert(badge.Visible, "a pet earned just now: ! on the Bag")
	click(bagButton)
	advance(0.3)
	local petsTab = findButton(Strings.get("bag_tab_pets"))
	assert(isShown(petsTab.NewDot), "the Pets tab has a dot")
	assert(badge.Visible, "still new: the pets page was not looked at yet")
	click(petsTab)
	assert(shownText(Strings.get("bag_new")), "NEW on the pet")
	assert(not badge.Visible and not isShown(petsTab.NewDot), "seen: the ! and the dot go")
	click(findButton(Strings.get("bag_tab_charms")))
	click(petsTab)
	assert(not shownText(Strings.get("bag_new")), "NEW only the first time")
	click(findButton(Strings.get("bag_tab_charms")))
	click(bagButton)
	setAttributes({ PetProgress = "" })
end)

test("pets: bag tab shows progress, equips earned pets only; the pet follows its owner", function()
	local PetData = H.loadModule("src/shared/PetData.luau")
	local Balance = H.loadModule("src/shared/Balance.luau")
	setAttributes({ Pet = "", PetProgress = "glowmoth:10,sproutling:120,pebble:0,ember_fox:10,frost_pup:0,shade_cat:0" })
	click(findButton(Strings.get("menu_bag")))
	assert(not shownText(Strings.get(PetData.pets.glowmoth.nameKey)), "the bag opens on charms")
	click(findButton(Strings.get("bag_tab_pets")))
	assert(shownText(Strings.get(PetData.pets.glowmoth.nameKey)), "pet list")
	assert(shownText(Strings.get("pet_unlock_purifies", 500) .. "  (" .. Strings.get("pet_progress", 120, 500) .. ")"), "progress towards the next pet")
	assert(shownText(Strings.get("pet_unlock_legend", Strings.get(Balance.enemies.FrostTitan.nameKey)) .. "  (" .. Strings.get("pet_progress", 0, 1) .. ")"), "legend unlock text")
	click(findButton(Strings.get("bag_locked_pet")))
	eq(sent("EquipPet"), 0, "an unearned pet sends nothing")
	local equipButtons = 0
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextButton") and descendant.Text == Strings.get("bag_equip") and isShown(descendant) then
			equipButtons += 1
		end
	end
	eq(equipButtons, 2, "two pets are earned")
	click(findText(Strings.get(PetData.pets.glowmoth.nameKey)).Parent:FindFirstChildOfClass("TextButton"))
	eq(sent("EquipPet", function(args)
		return args[1] == "glowmoth"
	end), 1, "equip the first earned pet")
	setAttributes({ Pet = "glowmoth" })
	assert(shownText(Strings.get("pet_send_home")), "shows send home")
	click(findButton(Strings.get("pet_send_home")))
	eq(sent("EquipPet", function(args)
		return args[1] == ""
	end), 1, "send home")
	-- The pet is drawn behind its owner and follows.
	local function pets(): { any }
		return workspace.Pets:GetChildren()
	end
	setAttributes({ Pet = "" })
	advance(0.3)
	eq(#pets(), 0, "no pet without a choice")
	setAttributes({ Pet = "ember_fox" })
	advance(0.3)
	eq(#pets(), 1, "the chosen pet appears")
	local root = H.read(hero.Character.HumanoidRootPart, "Position")
	local position = pets()[1].PrimaryPart.CFrame.Position
	assert((position - root).Magnitude < 9, "near its owner")
	teleport(root + Vector3.new(80, 0, 0))
	advance(0.3)
	local moved = pets()[1].PrimaryPart.CFrame.Position
	assert((moved - H.read(hero.Character.HumanoidRootPart, "Position")).Magnitude < 9, "snaps along when the owner is teleported far away")
	setAttributes({ Pet = "glowmoth" })
	advance(0.3)
	eq(#pets(), 1, "switching pets replaces the model")
	eq(pets()[1]:GetAttribute("PetId"), "glowmoth")
	setAttributes({ Pet = "nope" })
	advance(0.3)
	eq(#pets(), 0, "unknown pets are not drawn")
	setAttributes({ Pet = "", PetProgress = "" })
	click(findButton(Strings.get("menu_bag")))
end)

test("creature codex: the Adventure Log tab shows counts, hides unmet creatures and the next milestone", function()
	local BestiaryData = H.loadModule("src/shared/BestiaryData.luau")
	local Balance = H.loadModule("src/shared/Balance.luau")
	local Format = H.loadModule("src/shared/Format.luau")
	local Progression = H.loadModule("src/shared/Progression.luau")
	setAttributes({ Level = 20, Bestiary = "Gloomling:12,Warden:1,Mudling:1000", Achievements = "" })
	click(findButton(Strings.get("menu_log")))
	assert(not shownText(Strings.get("codex_count", 12)), "the log opens on the goals")
	click(findButton(Strings.get("log_tab_creatures")))
	assert(shownText(Strings.get(Balance.enemies.Gloomling.nameKey)), "a met creature is named")
	assert(shownText(Strings.get("codex_count", 12)), "its count")
	local coins = Format.short(Progression.incomeCoins(20, BestiaryData.tiers.regular[2].minutes))
	assert(shownText(Strings.get("codex_next", Format.short(BestiaryData.tiers.regular[2].goal), coins)), "the next milestone and its reward")
	assert(shownText(Strings.get("codex_done")), "a creature with every milestone says so")
	assert(shownText(Strings.get("codex_unknown_desc")), "unmet creatures are hidden")
	assert(not shownText(Strings.get(Balance.enemies.ShadowKing.nameKey)), "and not named")
	setAttributes({ Bestiary = "Gloomling:50,Warden:1,Mudling:1000" })
	assert(shownText(Strings.get("codex_count", 50)), "the tab follows the count while open")
	assert(not shownText(Strings.get("notice_codex_new", Strings.get(Balance.enemies.Gloomling.nameKey)) .. "  x2"), "more of a known kind is not news again")
	setAttributes({ Bestiary = "Gloomling:50,Warden:1,Mudling:1000,Frostling:1" })
	local news = false
	for _ = 1, 16 do -- (the level-up banner from the start of this test holds toasts back for a moment)
		advance(0.25)
		news = news or shownText(Strings.get("notice_codex_new", Strings.get(Balance.enemies.Frostling.nameKey)))
	end
	assert(news, "a first Frostling joins the Codex")
	click(findButton(Strings.get("log_tab_goals")))
	assert(not shownText(Strings.get("codex_count", 50)), "back to the goals")
	setAttributes({ Bestiary = "" })
	click(findButton(Strings.get("menu_log")))
end)

test("titles: bag tab shows progress, chooses earned titles only", function()
	local TitleData = H.loadModule("src/shared/TitleData.luau")
	local QuestData = H.loadModule("src/shared/QuestData.luau")
	local Format = H.loadModule("src/shared/Format.luau")
	local progress = {}
	for _, id in TitleData.order do
		table.insert(progress, id .. ":" .. (if id == "keeper" or id == "glow_walker" then TitleData.titles[id].unlock.goal else 0))
	end
	progress[3] = "shadow_friend:120"
	setAttributes({ Title = "", TitleProgress = table.concat(progress, ",") })
	click(findButton(Strings.get("menu_bag")))
	click(findButton(Strings.get("bag_tab_titles")))
	assert(shownText(Strings.get("title_keeper")), "title list")
	assert(shownText(Strings.get("title_unlock_purifies", 1000) .. "  (" .. Strings.get("pet_progress", 120, Format.short(1000)) .. ")"), "progress towards the next title")
	assert(shownText(Strings.get("title_unlock_quest", Strings.get(QuestData.quests.shadow_king.titleKey))), "quest unlock text")
	click(findButton(Strings.get("bag_locked_pet")))
	eq(sent("EquipTitle"), 0, "an unearned title sends nothing")
	local equipButtons = 0
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextButton") and descendant.Text == Strings.get("bag_equip") and isShown(descendant) then
			equipButtons += 1
		end
	end
	eq(equipButtons, 2, "two titles are earned")
	click(findText(Strings.get("title_glow_walker")).Parent:FindFirstChildOfClass("TextButton"))
	eq(sent("EquipTitle", function(args)
		return args[1] == "glow_walker"
	end), 1, "choose an earned title")
	setAttributes({ Title = "glow_walker" })
	assert(shownText(Strings.get("title_hide")), "shows hide")
	click(findButton(Strings.get("title_hide")))
	eq(sent("EquipTitle", function(args)
		return args[1] == ""
	end), 1, "hide the title")
	setAttributes({ Title = "", TitleProgress = "" })
	click(findButton(Strings.get("menu_bag")))
end)

test("rebirth: the panel says what resets, confirms only at level 100, badge and costume tile", function()
	local Balance = H.loadModule("src/shared/Balance.luau")
	local Format = H.loadModule("src/shared/Format.luau")
	teleport(vec(WorldData.plaza, 3)) -- the panel closes when the player walks away from the lantern
	setAttributes({ Level = 100, Rebirths = 0 })
	remotes.OpenRebirth.OnClientEvent:Fire()
	advance(0.2)
	assert(shownText(Strings.get("rebirth_intro")), "panel open")
	assert(shownText(Strings.get("rebirth_resets", Format.short(Balance.rebirth.startCoins))), "what resets")
	assert(shownText(Strings.get("rebirth_keeps")), "what stays")
	assert(shownText(Strings.get("rebirth_gain", 1, 10)), "what the next rebirth gives")
	click(findButton(Strings.get("rebirth_later")))
	eq(sent("ConfirmRebirth"), 0, "Not now sends nothing")
	assert(not shownText(Strings.get("rebirth_intro")), "panel closed")
	-- A stale panel opened below level 100 cannot confirm.
	setAttributes({ Level = 50 })
	remotes.OpenRebirth.OnClientEvent:Fire()
	advance(0.2)
	click(findButton(Strings.get("rebirth_confirm")))
	eq(sent("ConfirmRebirth"), 0, "below level 100 nothing is sent")
	click(findButton(Strings.get("rebirth_later")))
	setAttributes({ Level = 100, Rebirths = 2 })
	remotes.OpenRebirth.OnClientEvent:Fire()
	advance(0.2)
	assert(shownText(Strings.get("rebirth_gain", 3, 30)), "the bonus grows with each rebirth")
	click(findButton(Strings.get("rebirth_confirm")))
	eq(sent("ConfirmRebirth"), 1, "confirmed at level 100")
	assert(not shownText(Strings.get("rebirth_intro")), "panel closes after confirming")
	assert(shownText(Strings.get("rebirth_hud", 2)), "rebirth count under the level badge")
	-- The server's word that it happened: a banner and confetti.
	local function confettiCount(): number
		local count = 0
		for _, descendant in playerGui.Hud:GetDescendants() do
			if descendant.Name == "Confetti" then
				count += 1
			end
		end
		return count
	end
	remotes.Notice.OnClientEvent:Fire("notice_rebirth_done", 3)
	advance(0.2)
	assert(shownText(Strings.get("banner_reborn")) and shownText(Strings.get("banner_reborn_sub", 3)), "rebirth banner")
	assert(confettiCount() > 20, "confetti")
	advance(4)
	eq(confettiCount(), 0, "the confetti is gone")
	setAttributes({ Rebirths = 0 })
	assert(not shownText(Strings.get("rebirth_hud", 2)), "no badge before the first rebirth")
	-- The shop shows how the rebirth costumes are earned.
	click(findButton(Strings.get("menu_shop")))
	click(findButton(Strings.get("shop_tab_costumes")))
	assert(shownText(Strings.get("costume_from_rebirth", 1)) and shownText(Strings.get("costume_from_rebirth", 3)), "rebirth costumes explained")
	assert(shownText(Strings.get("costume_from_tower", 20)) and shownText(Strings.get("costume_from_tower", 40)), "tower costumes explained")
	assert(shownText(Strings.get("costume_from_legend", Strings.get(Balance.enemies.ShadowKing.nameKey))), "Kael's Crown explained")
	click(findButton(Strings.get("menu_shop")))
	setAttributes({ Level = 3 })
end)

test("forge opens from the server with every upgrade, buys, and closes when walking away", function()
	local Progression = H.loadModule("src/shared/Progression.luau")
	setAttributes({ Coins = 10000, StaffTier = 3, Upgrades = "pouch:2" })
	teleport(vec(WorldData.npcs.Smith.position, 1.5) + Vector3.new(0, 0, 4))
	remotes.OpenShop.OnClientEvent:Fire()
	advance(0.2)
	assert(shownText(Strings.get("shop_title")), "shop open")
	for _, stat in Balance.upgradeOrder do
		local upgrade = Balance.upgrades[stat]
		local level = if stat == "power" then 3 elseif stat == "pouch" then 2 else 0
		assert(shownText(Strings.get(upgrade.nameKey) .. "  " .. Strings.get("upgrade_level", level, upgrade.maxLevel)), stat .. " row")
	end
	click(findButton(Strings.get("hud_coins", Progression.upgradeCost("pouch", 2))))
	eq(sent("BuyUpgrade", function(args)
		return args[1] == "pouch"
	end), 1, "pouch upgrade requested")
	teleport(vec(WorldData.spawn, 3))
	advance(1.2)
	assert(not shownText(Strings.get("shop_title")), "shop closed after walking away")
end)

test("boss bar and intro banner near an engaged boss", function()
	local boss = enemies[wardenIndex]
	H.setAttribute(boss, "Engaged", true)
	teleport(vec(WorldData.areas.arena.center, 3) + Vector3.new(0, 0, 10))
	advance(0.6)
	local camera = workspace.CurrentCamera
	assert(camera.FieldOfView < 48, "the camera glides over to introduce the boss")
	local questPanel = playerGui.Hud:FindFirstChild("QuestBar", true).Parent
	assert(not isShown(questPanel), "the quest panel steps aside for the boss bar")
	assert((H.read(camera, "CFrame").Position - H.read(boss.Body, "Position")).Magnitude < 45, "close to the boss")
	local wardenName = Strings.get(Balance.enemies.Warden.nameKey)
	assert(shownText(Strings.get("banner_boss", wardenName)), "boss banner")
	local rays = playerGui.Hud:FindFirstChild("Rays", true)
	assert(not isShown(rays), "a boss arriving is a danger banner: no celebration rays")
	assert(shownText(Strings.get("enemy_label", 1, wardenName)), "boss bar name with level")
	local maxHp = boss:GetAttribute("MaxHp")
	boss:SetAttribute("Hp", maxHp * 0.5)
	advance(0.6)
	assert(shownText(Strings.get("hud_percent", 50)), "boss health in percent")
	remotes.Fx.OnClientEvent:Fire("bossPhase", boss)
	advance(0.4)
	assert(shownText(Strings.get("banner_boss_enraged", wardenName)), "the second phase is announced")
	remotes.Fx.OnClientEvent:Fire("purify", H.read(boss.Body, "Position"), "Warden", Vector3.new(0, 0, 1))
	advance(0.2)
	assert(shownText(Strings.get("banner_boss_down", wardenName)), "boss defeated banner")
	assert(isShown(rays), "a defeated boss is celebrated with rays")
	local stillness = camera:FindFirstChild("LvBossDown")
	assert(stillness and stillness.Saturation < -0.5, "the colour drains for a moment as the boss falls")
	advance(2)
	eq(stillness.Saturation, 0, "and floods back")
	assert(camera.FieldOfView > 48, "the intro is over and the follow camera is back")
	H.setAttribute(boss, "Engaged", false)
	advance(0.6)
	assert(isShown(questPanel), "the quest panel returns after the fight")
end)

test("level up banner and respawn reassurance", function()
	setAttributes({ Level = 4, XP = 300 })
	assert(shownText(Strings.get("hud_level", 4) .. "!"), "level banner")
	hero.CharacterAdded:Fire(hero.Character)
	advance(1)
	assert(not shownText(Strings.get("notice_respawn")), "toasts wait while the banner shows")
	advance(3)
	assert(shownText(Strings.get("notice_respawn")), "then the respawn toast is still there to read")
end)

test("enemy billboards follow enemies coming and going", function()
	local before = #enemyLabels()
	H.destroy(enemies[1])
	advance(0.2)
	eq(#enemyLabels(), before - 1, "billboard removed")
	addEnemy("Sporeling", vec(WorldData.spawns[4].position, 2))
	advance(0.3)
	eq(#enemyLabels(), before, "billboard added")
end)

test("a respawn keeps creature labels, NPC markers and the waypoint", function()
	local kept: { BillboardGui }, names: { string } = {}, {}
	local labels, waypoint, markers = 0, false, 0
	for _, folder in { playerGui, workspace } do
		for _, gui in folder:GetDescendants() do
			if gui:IsA("BillboardGui") then
				table.insert(kept, gui)
				table.insert(names, gui:GetFullName())
				local adornee = gui.Adornee
				if gui.Name == "LvLabel" then
					labels += 1
				elseif adornee and adornee.Name == "WaypointAnchor" then
					waypoint = true
				elseif adornee and adornee.Parent and adornee.Parent.Parent and adornee.Parent.Parent.Name == "Village" then
					markers += 1
				end
			end
		end
	end
	assert(labels > 0 and waypoint and markers > 0, `labels {labels}, waypoint {waypoint}, markers {markers}`)
	-- What Roblox does to PlayerGui when a character respawns.
	for _, child in playerGui:GetChildren() do
		if not (child:IsA("LayerCollector") and child.ResetOnSpawn == false) then
			child:Destroy()
		end
	end
	hero.CharacterAdded:Fire(hero.Character)
	advance(0.5)
	for index, gui in kept do
		local readable, parent = pcall(function()
			return gui.Parent
		end)
		assert(readable and parent ~= nil, `{names[index]} survives the respawn`)
	end
end)

test("after the story the panel and waypoint show the next personal goal", function()
	teleport(vec(WorldData.spawn, 3))
	setAttributes({ QuestId = nil, QuestState = "done", XP = 1000, Coins = 0, StaffTier = 1, DataState = "ready" })
	advance(0.5)
	local Progression = H.loadModule("src/shared/Progression.luau")
	local level = Progression.levelForXp(1000)
	assert(shownText(Strings.get("goal_level", Progression.nextMilestone(level), level)), "level goal shown")
	local function waypointAt(): any
		for _, child in playerGui:GetChildren() do
			if child:IsA("BillboardGui") and child.Enabled and child.Adornee and child.Adornee.Name == "WaypointAnchor" then
				return H.read(child.Adornee, "Position")
			end
		end
		return nil
	end
	local function near(point, p)
		return point ~= nil and (point - vec(p)).Magnitude < 1
	end
	local zones = WorldData.areas
	local at = waypointAt()
	assert(near(at, zones.glade.center) or near(at, zones.grove.center) or near(at, zones.hollow.center), "level goal guides to a creature zone")

	local nextCost = Progression.upgradeCost("power", 1)
	setAttributes({ Coins = nextCost })
	advance(0.5)
	assert(shownText(Strings.get("goal_staff_ready", 2)), "affordable power goal shown")
	assert(near(waypointAt(), WorldData.npcs.Smith.position), "affordable upgrade guides to Smith")

	setAttributes({ XP = Progression.thresholds[Progression.MAX_LEVEL], Coins = 0 })
	advance(0.5)
	assert(shownText(Strings.get("goal_staff_coins", 2, nextCost)), "coins still needed")
	local farm = waypointAt()
	assert(near(farm, zones.glade.center) or near(farm, zones.grove.center) or near(farm, zones.hollow.center), "coin goal guides to creatures")
	-- Inside the Shadow Tower there is no arrow (the valley is out of reach).
	setAttributes({ TowerFloor = 2 })
	advance(0.5)
	eq(waypointAt(), nil, "no waypoint inside the tower")
	setAttributes({ TowerFloor = 0 })
	advance(0.5)
	assert(waypointAt() ~= nil, "waypoint returns after leaving")
end)

test("level-gated quest points to a creature zone and explains why", function()
	teleport(vec(WorldData.spawn, 3))
	setAttributes({ QuestId = "ruin_vines", QuestState = "level", QuestNeedLevel = 3, DataState = "ready" })
	advance(0.5)
	assert(shownText(Strings.get("quest_need_level", 3)), "level hint text")
	local waypointShown = false
	for _, child in playerGui:GetChildren() do
		if child:IsA("BillboardGui") and child.Enabled and child.Adornee and child.Adornee.Name == "WaypointAnchor" then
			waypointShown = true
		end
	end
	assert(waypointShown, "waypoint guides to a zone")
end)

test("save failure shows the protective retry screen", function()
	setAttributes({ DataState = "failed" })
	assert(shownText(Strings.get("data_failed_title")), "failure panel")
	click(findButton(Strings.get("data_retry")))
	eq(sent("RetryLoad"), 1, "retry requested")
end)

if withJumpButton then
	test("touch: big ability buttons sit beside the jump button without overlapping", function()
		local abilities = playerGui:FindFirstChild("TouchAbilities")
		assert(abilities, "touch ability gui")
		for _, name in { "LvLightWave", "LvStarFall", "LvLanternGlow" } do
			eq(casButtons[name], nil, "no CAS touch button when the custom one exists: " .. name)
		end
		local buttons = {}
		for _, child in abilities:GetChildren() do
			if child:IsA("TextButton") then
				table.insert(buttons, child)
			end
		end
		eq(#buttons, 3, "three ability buttons: wave, star, glow (attacks are automatic)")
		local function rect(position, size)
			return { position.X, position.Y, position.X + size.X, position.Y + size.Y }
		end
		local function overlaps(a, b)
			return a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]
		end
		local jumpRect = rect(JUMP_POSITION, JUMP_SIZE)
		local rects = {}
		for _, button in buttons do
			local size = Vector2.new(button.Size.X.Offset, button.Size.Y.Offset)
			local r = rect(Vector2.new(button.Position.X.Offset, button.Position.Y.Offset), size)
			assert(size.X >= JUMP_SIZE.X * 0.9, "button at least about jump-button size")
			assert(not overlaps(r, jumpRect), "overlaps the jump button")
			assert(r[1] >= 0 and r[2] >= 0 and r[3] <= 640 and r[4] <= 360, "inside the screen")
			assert(button:FindFirstChildWhichIsA("Frame"), "decorated face")
			for _, other in rects do
				assert(not overlaps(r, other), "ability buttons do not overlap each other")
			end
			table.insert(rects, r)
		end

		-- Roblox rebuilds the jump button when the screen size changes; the layout must follow.
		local frame = playerGui.TouchGui.TouchControlFrame
		local newJump = Instance.new("ImageButton")
		newJump.Name = "JumpButton"
		newJump.AbsolutePosition = Vector2.new(400, 200)
		newJump.AbsoluteSize = Vector2.new(90, 90)
		frame.JumpButton:Destroy()
		H.addChild(frame, newJump)
		advance(0.1)
		local newJumpRect = rect(Vector2.new(400, 200), Vector2.new(90, 90))
		for _, button in buttons do
			local r = rect(Vector2.new(button.Position.X.Offset, button.Position.Y.Offset), Vector2.new(button.Size.X.Offset, button.Size.Y.Offset))
			assert(not overlaps(r, newJumpRect), "follows the rebuilt jump button")
			assert(button.Size.X.Offset >= 90 * 0.9, "resized with the new jump button")
		end

		setAttributes({ Level = 5 })
		advance(12)
		local before = sent("RequestWave")
		abilities.wave.MouseButton1Down:Fire()
		advance(0.1)
		assert(sent("RequestWave") > before, "pressing the touch button casts the wave")
	end)
elseif touchMode then
	test("touch without a jump button: falls back to decorated CAS buttons", function()
		for _, name in { "LvLightWave", "LvStarFall", "LvLanternGlow" } do
			local button = casButtons[name]
			assert(button, name .. " touch button")
			eq(button.ImageTransparency, 1, "default art hidden")
			assert(button:FindFirstChildWhichIsA("Frame"), "decorated face")
		end
	end)
end

test("no client thread errors or warnings", function()
	for _, message in H.warnings do
		print("warn: " .. message)
	end
	for _, message in H.threadErrors do print("THREADERR " .. message) end
	eq(#H.threadErrors, 0, "thread errors")
	eq(#H.warnings, 0, "warnings")
end)

H.finish(`client tests ({mode})`)
