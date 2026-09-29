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

local Players = { list = {}, PlayerRemoving = H.Signal.new() }
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
	InputChanged = H.Signal.new(),
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
local function addEnemy(kind: string, position: any)
	nextEnemyId += 1
	local stats = Balance.enemies[kind]
	local model = EnemyModels.build(kind, stats, CFrame.new(position))
	model:SetAttribute("EnemyId", nextEnemyId)
	model:SetAttribute("EnemyType", kind)
	model:SetAttribute("Boss", stats.isBoss == true)
	model:SetAttribute("Alive", true)
	model:SetAttribute("Hp", stats.maxHp)
	model:SetAttribute("MaxHp", stats.maxHp)
	H.addChild(enemiesFolder, model)
	return model
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
		if current:IsA("LayerCollector") and current:IsA("BillboardGui") and not current.Enabled then
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
	local billboards = playerGui.EnemyBillboards:GetChildren()
	eq(#billboards, 4, "a billboard per non-boss enemy")
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

test("server events render: rewards, notices, dialog, effects", function()
	remotes.RewardGranted.OnClientEvent:Fire("purify", 10, 5)
	remotes.RewardGranted.OnClientEvent:Fire("quest", 50, 20)
	remotes.Notice.OnClientEvent:Fire("notice_charm_gained", "charm_swift_name")
	remotes.NpcSay.OnClientEvent:Fire("Elder", "elder_need_level", 3)
	advance(0.2)
	assert(shownText(Strings.get("reward_quest", 50, 20)), "quest toast")
	assert(not shownText(Strings.get("reward_purify", 10)), "purify toasts wait to be summed")
	advance(1.2)
	assert(shownText(Strings.get("reward_purify", 10)), "one purify, one toast")
	-- A whole pack melts: one summed toast, not five.
	for _ = 1, 5 do
		remotes.RewardGranted.OnClientEvent:Fire("purify", 12, 0)
	end
	advance(1.3)
	assert(shownText(Strings.get("reward_purify_many", 5, 60)), "pack summed into one toast")
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
	setAttributes({ Weapon = "staff" })
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

test("light wave is locked until level 3", function()
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 0, "locked")
	setAttributes({ Level = 3, XP = 150 })
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 1, "sent when unlocked")
	actions.LvLightWave("LvLightWave", Enum.UserInputState.Begin, {})
	eq(sent("RequestWave"), 1, "local cooldown")
	assert(shownText(Strings.get("notice_wave_unlocked")), "unlock banner")
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

	setAttributes({ Flags = "festival,gardens,lanterns" })
	for _, flag in { "gardens", "lanterns", "festival" } do
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
	click(findButton(Strings.get("weapon_find")))
	eq(sent("EquipWeapon"), 0, "a weapon not found yet does nothing")
	click(findButton(Strings.get("weapon_locked", 25)))
	assert(shownText(Strings.get("bag_main_hint")), "closed slot does not open")
	setAttributes({ Level = 25, Companions = "spear", Weapons = "bow,spear,staff,sword" })
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
	local now = H.EPOCH + H.now()
	setAttributes({ ChestSpots = "chest_glade_1:" .. math.floor(now + 5) })
	eq(chestModels(), total - 1, "taken spot is empty")
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
	advance(0.2)
	assert(shownText(Strings.get("chest_reward_title", Strings.get(ChestData.chests.wood.nameKey))), "reward title")
	assert(shownText(Strings.get("chest_reward_coins", 33)), "coins line")
	assert(shownText(Strings.get("chest_reward_weapon", Strings.get("weapon_bow_name"), Strings.get("rarity_common"))), "weapon line")
	assert(shownText(Strings.get("chest_reward_slot", Strings.get("bag_main"), 3, 1)), "slot line")
	remotes.Fx.OnClientEvent:Fire("chestOpened", { chest = "wood", coins = 10, weapon = "bow", rarity = "common", duplicate = true, star = 2, slots = {} })
	advance(0.2)
	assert(shownText(Strings.get("chest_reward_star", Strings.get("weapon_bow_name"), 2, 5)), "star line for a repeat")
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
	setAttributes({ Upgrades = "", Crystals = capacity })
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
	advance(1)
	setAttributes({ Crystals = 0 })
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

test("shadow tower: floor banner and HUD label while inside", function()
	setAttributes({ TowerBest = 7, TowerFloor = 0 })
	assert(not shownText(Strings.get("tower_hud", 3, 7)), "no label outside the tower")
	setAttributes({ TowerFloor = 3 })
	assert(shownText(Strings.get("tower_hud", 3, 7)), "floor and best floor shown")
	remotes.Fx.OnClientEvent:Fire("towerFloor", 3, 8)
	advance(0.2)
	assert(shownText(Strings.get("tower_floor", 3)), "floor banner")
	assert(shownText(Strings.get("tower_floor_sub", 8)), "creature count under it")
	setAttributes({ TowerBest = 8 })
	assert(shownText(Strings.get("tower_hud", 3, 8)), "best floor follows")
	remotes.Fx.OnClientEvent:Fire("towerFloor", "x", nil)
	setAttributes({ TowerFloor = 0 })
	assert(not shownText(Strings.get("tower_hud", 3, 8)), "label hides after leaving")
	advance(3)
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

test("rebirth: the panel says what resets, confirms only at level 100, badge and costume tile", function()
	local Balance = H.loadModule("src/shared/Balance.luau")
	local Format = H.loadModule("src/shared/Format.luau")
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
	setAttributes({ Rebirths = 0 })
	assert(not shownText(Strings.get("rebirth_hud", 2)), "no badge before the first rebirth")
	-- The shop shows how the rebirth costumes are earned.
	click(findButton(Strings.get("menu_shop")))
	click(findButton(Strings.get("shop_tab_costumes")))
	assert(shownText(Strings.get("costume_from_rebirth", 1)) and shownText(Strings.get("costume_from_rebirth", 3)), "rebirth costumes explained")
	click(findButton(Strings.get("menu_shop")))
	setAttributes({ Level = 3 })
end)

test("settings toggle sound and the performance overlay", function()
	click(findButton(Strings.get("menu_settings")))
	local on, off = Strings.get("setting_on"), Strings.get("setting_off")
	click(findButton(Strings.get("settings_sound", on)))
	assert(shownText(Strings.get("settings_sound", off)), "sound off")
	click(findButton(Strings.get("settings_fps", off)))
	assert(shownText(Strings.get("settings_fps", on)), "fps on")
	advance(1.5)
	local perf = false
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("TextLabel") and string.find(descendant.Text, "FPS", 1, true) and isShown(descendant) then
			perf = true
		end
	end
	assert(perf, "perf overlay text")
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
	local wardenName = Strings.get(Balance.enemies.Warden.nameKey)
	assert(shownText(Strings.get("banner_boss", wardenName)), "boss banner")
	assert(shownText(Strings.get("enemy_label", 1, wardenName)), "boss bar name with level")
	boss:SetAttribute("Hp", 450)
	advance(0.6)
	remotes.Fx.OnClientEvent:Fire("purify", H.read(boss.Body, "Position"), "Warden", Vector3.new(0, 0, 1))
	advance(0.2)
	assert(shownText(Strings.get("banner_boss_down", wardenName)), "boss defeated banner")
end)

test("level up banner and respawn reassurance", function()
	setAttributes({ Level = 4, XP = 300 })
	assert(shownText(Strings.get("hud_level", 4) .. "!"), "level banner")
	hero.CharacterAdded:Fire(hero.Character)
	advance(1)
	assert(shownText(Strings.get("notice_respawn")), "respawn toast")
end)

test("enemy billboards follow enemies coming and going", function()
	local before = #playerGui.EnemyBillboards:GetChildren()
	H.destroy(enemies[1])
	advance(0.2)
	eq(#playerGui.EnemyBillboards:GetChildren(), before - 1, "billboard removed")
	addEnemy("Sporeling", vec(WorldData.spawns[4].position, 2))
	advance(0.3)
	eq(#playerGui.EnemyBillboards:GetChildren(), before, "billboard added")
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
		eq(casButtons.LvLightWave, nil, "no CAS touch button when the custom one exists")
		local buttons = {}
		for _, child in abilities:GetChildren() do
			if child:IsA("TextButton") then
				table.insert(buttons, child)
			end
		end
		eq(#buttons, 1, "one ability button (attacks are automatic)")
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
		buttons[1].MouseButton1Down:Fire()
		advance(0.1)
		assert(sent("RequestWave") > before, "pressing the touch button casts the wave")
	end)
elseif touchMode then
	test("touch without a jump button: falls back to decorated CAS buttons", function()
		for _, name in { "LvLightWave" } do
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
	eq(#H.threadErrors, 0, "thread errors")
	eq(#H.warnings, 0, "warnings")
end)

H.finish(`client tests ({mode})`)
