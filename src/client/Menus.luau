-- Weapons, chests, bag (charms), weapon-power shop, settings, performance overlay and the save-loading overlay.
-- Only one modal is open at a time so the screen never fills up with windows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Progression = require(Shared:WaitForChild("Progression"))
local Strings = require(Shared:WaitForChild("Strings"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local ChestData = require(Shared:WaitForChild("ChestData"))
local Format = require(Shared:WaitForChild("Format"))
local AchievementData = require(Shared:WaitForChild("AchievementData"))
local Audio = require(script.Parent.Audio)
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipCharm = Remotes:WaitForChild("EquipCharm") :: RemoteEvent
local upgradeStaff = Remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local equipWeapon = Remotes:WaitForChild("EquipWeapon") :: RemoteEvent
local chestAction = Remotes:WaitForChild("ChestAction") :: RemoteEvent
local claimAchievement = Remotes:WaitForChild("ClaimAchievement") :: RemoteEvent
local retryLoad = Remotes:WaitForChild("RetryLoad") :: RemoteEvent
local player = Players.LocalPlayer
local colors = UiKit.colors

local Menus = {}

function Menus.start()
	local gui = UiKit.create("ScreenGui", { Name = "Menus", ResetOnSpawn = false, DisplayOrder = 5 }, player:WaitForChild("PlayerGui"))

	local openModal: Frame? = nil
	local function closeModal()
		if openModal then
			openModal.Visible = false
			openModal = nil
		end
	end
	local function showModal(modal: Frame)
		if openModal == modal then
			closeModal()
			return
		end
		closeModal()
		openModal = modal
		modal.Visible = true
		UiKit.pop(modal)
		Audio.play("ui")
	end

	local center = UiKit.region(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(460, 400))

	local function modal(titleKey: string, height: number): (Frame, Frame)
		local frame = UiKit.panel({
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(440, height),
			Visible = false,
			Corner = 18,
		}, center)
		UiKit.label({ Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 34), Text = Strings.get(titleKey), TextSize = 28, TextColor3 = colors.accent }, frame)
		UiKit.button({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 10),
			Size = UDim2.fromOffset(44, 44),
			Text = "X",
			BackgroundColor3 = colors.panelLight,
			TextColor3 = colors.text,
			Corner = 22,
		}, frame, closeModal)
		local body = UiKit.create("Frame", {
			Position = UDim2.fromOffset(16, 56),
			Size = UDim2.new(1, -32, 1, -68),
			BackgroundTransparency = 1,
		}, frame)
		return frame, body
	end

	-- Top-right buttons ---------------------------------------------------------------------
	-- A two-column grid keeps the buttons clear of the quest panel in the top center.
	local topRight = UiKit.region(gui, Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), Vector2.new(208, 160))
	UiKit.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(100, 48),
		CellPadding = UDim2.fromOffset(8, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, topRight)

	-- Bag -----------------------------------------------------------------------------------
	local bag, bagBody = modal("bag_title", 380)
	local staffLine = UiKit.label({ Size = UDim2.new(1, 0, 0, 28), TextSize = 20 }, bagBody)
	local charmList = UiKit.create("Frame", {
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 1, -36),
		BackgroundTransparency = 1,
	}, bagBody)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 8) }, charmList)
	local charmRows = {}
	for order, charmId in Balance.charmOrder do
		local charm = Balance.charms[charmId]
		local row = UiKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 80),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, charmList)
		UiKit.corner(row, 12)
		local gem = UiKit.create("Frame", {
			Position = UDim2.fromOffset(12, 18),
			Size = UDim2.fromOffset(44, 44),
			BackgroundColor3 = UiKit.rgb(charm.color),
			BorderSizePixel = 0,
			Rotation = 45,
		}, row)
		UiKit.corner(gem, 10)
		local name = UiKit.label({
			Position = UDim2.fromOffset(72, 8),
			Size = UDim2.new(1, -190, 0, 28),
			Text = Strings.get(charm.nameKey),
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local desc = UiKit.label({
			Position = UDim2.fromOffset(72, 36),
			Size = UDim2.new(1, -190, 0, 36),
			Text = Strings.get(charm.descKey),
			TextSize = 16,
			TextWrapped = true,
			TextColor3 = colors.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, row)
		local button = UiKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -12, 0.5, 0),
			Size = UDim2.fromOffset(104, 52),
			Text = "",
		}, row, function()
			local owned = Attrs.set("Charms")
			if not owned[charmId] then
				return
			end
			local equipped = Attrs.get("Charm", "") == charmId
			equipCharm:FireServer(if equipped then "" else charmId)
			Audio.play("ui")
		end)
		charmRows[charmId] = { row = row, gem = gem, name = name, desc = desc, button = button }
	end

	local function refreshBag()
		local tier = Attrs.get("StaffTier", 0)
		staffLine.Text = Strings.get("bag_staff", tier, Progression.staffDamage(tier, Attrs.get("Level", 1)))
		local owned = Attrs.set("Charms")
		local equipped = Attrs.get("Charm", "")
		for charmId, view in charmRows do
			local has = owned[charmId] == true
			view.gem.BackgroundTransparency = if has then 0 else 0.7
			view.name.TextTransparency = if has then 0 else 0.5
			if not has then
				view.button.Text = Strings.get("bag_locked")
				view.button.TextSize = 14
				view.button.BackgroundColor3 = colors.panel
				view.button.TextColor3 = colors.muted
			elseif equipped == charmId then
				view.button.Text = Strings.get("bag_unequip")
				view.button.TextSize = 22
				view.button.BackgroundColor3 = colors.good
				view.button.TextColor3 = colors.panel
			else
				view.button.Text = Strings.get("bag_equip")
				view.button.TextSize = 22
				view.button.BackgroundColor3 = colors.accent
				view.button.TextColor3 = colors.panel
			end
		end
	end

	-- Weapons -------------------------------------------------------------------------------
	-- Slot 0 is the main weapon; slots 1..4 float behind the player once unlocked (every 25 levels).
	local weapons, weaponsBody = modal("menu_weapons", 430)
	local editingSlot = 0
	local slotRow = UiKit.create("Frame", { Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, weaponsBody)
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, slotRow)
	local weaponHint = UiKit.label({
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = colors.muted,
	}, weaponsBody)
	local grid = UiKit.create("Frame", {
		Position = UDim2.fromOffset(0, 78),
		Size = UDim2.new(1, 0, 0, 172),
		BackgroundTransparency = 1,
	}, weaponsBody)
	UiKit.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(96, 80),
		CellPadding = UDim2.fromOffset(6, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, grid)
	local weaponInfo = UiKit.label({
		Position = UDim2.fromOffset(0, 256),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 16,
		TextWrapped = true,
	}, weaponsBody)
	local refreshWeapons: () -> ()

	local slotButtons: { [number]: TextButton } = {}
	for slot = 0, WeaponData.maxCompanions do
		slotButtons[slot] = UiKit.button({ Size = UDim2.fromOffset(74, 44), TextSize = 16, LayoutOrder = slot }, slotRow, function()
			if slot <= Progression.companionSlots(Attrs.get("Level", 1)) then
				editingSlot = slot
				Audio.play("ui")
				refreshWeapons()
			end
		end)
	end
	local tiles: { [string]: { button: TextButton, stripe: Frame } } = {}
	for order, weaponId in WeaponData.order do
		local weapon = WeaponData.weapons[weaponId]
		local button = UiKit.button({
			LayoutOrder = order,
			Text = Strings.get(weapon.nameKey),
			TextSize = 14,
			TextWrapped = true,
			BackgroundColor3 = colors.panelLight,
			TextColor3 = colors.text,
		}, grid, function()
			if Attrs.set("Weapons")[weaponId] then
				equipWeapon:FireServer(editingSlot, weaponId)
				Audio.play("ui")
			end
		end)
		-- The stripe shows the weapon's rarity.
		local stripe = UiKit.create("Frame", {
			Position = UDim2.new(0, 8, 1, -10),
			Size = UDim2.new(1, -16, 0, 5),
			BackgroundColor3 = UiKit.rgb(WeaponData.rarities[weapon.rarity].color),
			BorderSizePixel = 0,
		}, button)
		UiKit.corner(stripe, 3)
		tiles[weaponId] = { button = button, stripe = stripe }
	end
	local autoButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -4),
		Size = UDim2.fromOffset(180, 48),
		Text = Strings.get("bag_auto"),
		BackgroundColor3 = colors.panelLight,
		TextColor3 = colors.text,
	}, weaponsBody, function()
		if editingSlot > 0 then
			equipWeapon:FireServer(editingSlot, "")
			Audio.play("ui")
		end
	end)

	refreshWeapons = function()
		local level = Attrs.get("Level", 1)
		local slots = Progression.companionSlots(level)
		if editingSlot > slots then
			editingSlot = 0
		end
		local companions = Attrs.list("Companions")
		local owned = Attrs.set("Weapons")
		local slotLevels = Attrs.list("SlotLevels")
		local current = if editingSlot == 0 then Attrs.get("Weapon", "staff") else companions[editingSlot]
		for slot, button in slotButtons do
			local open = slot <= slots
			local name = if slot == 0 then Strings.get("bag_main") else Strings.get("bag_slot", slot)
			local slotLevel = tonumber(slotLevels[slot + 1]) or 0
			button.Text = if not open
				then Strings.get("weapon_locked", slot * WeaponData.companionEvery)
				elseif slotLevel > 0 then Strings.get("slot_level", name, slotLevel)
				else name
			button.BackgroundColor3 = if slot == editingSlot then colors.accent elseif open then colors.panelLight else colors.panel
			button.TextColor3 = if slot == editingSlot then colors.panel elseif open then colors.text else colors.muted
		end
		weaponHint.Text = Strings.get(if editingSlot == 0 then "bag_main_hint" else "bag_slot_hint")
		for weaponId, tile in tiles do
			local unlocked = owned[weaponId] == true
			tile.button.Text = if unlocked then Strings.get(WeaponData.weapons[weaponId].nameKey) else Strings.get("weapon_find")
			tile.button.BackgroundColor3 = if weaponId == current then colors.good elseif unlocked then colors.panelLight else colors.panel
			tile.button.TextColor3 = if weaponId == current then colors.panel elseif unlocked then colors.text else colors.muted
			tile.stripe.BackgroundTransparency = if unlocked then 0 else 0.7
		end
		local weapon = current and WeaponData.weapons[current]
		weaponInfo.Text = if weapon
			then Strings.get(
				"weapon_info",
				Strings.get(WeaponData.rarities[weapon.rarity].nameKey),
				Strings.get(weapon.descKey),
				Progression.weaponDamage(current, Attrs.get("StaffTier", 0), level, editingSlot > 0, tonumber(slotLevels[editingSlot + 1]))
			)
			else ""
		autoButton.Visible = editingSlot > 0
	end

	-- Chests --------------------------------------------------------------------------------
	-- Chest slots open with levels; one chest unlocks at a time (server time), then it opens.
	local chestsModal, chestsBody = modal("chests_title", 330)
	UiKit.label({
		Size = UDim2.new(1, 0, 0, 40),
		Text = Strings.get("chest_hint"),
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = colors.muted,
	}, chestsBody)
	local chestRow = UiKit.create("Frame", {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 200),
		BackgroundTransparency = 1,
	}, chestsBody)
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chestRow)

	type ChestState = { type: string, startedAt: number }
	local function chestStates(): { ChestState }
		local list = {}
		for _, entry in Attrs.list("Chests") do
			local chestType, startedAt = string.match(entry, "^([^:]+):(%d+)$")
			if chestType and ChestData.chests[chestType] then
				table.insert(list, { type = chestType, startedAt = tonumber(startedAt) :: number })
			end
		end
		return list
	end
	-- Seconds left (nil = not started, 0 = ready to open).
	local function remaining(chest: ChestState, now: number): number?
		if chest.startedAt == 0 then
			return nil
		end
		return math.max(0, math.ceil(chest.startedAt + ChestData.chests[chest.type].unlockSeconds - now))
	end
	local function anyUnlocking(list: { ChestState }, now: number): boolean
		for _, chest in list do
			local left = remaining(chest, now)
			if left and left > 0 then
				return true
			end
		end
		return false
	end
	local function clock(seconds: number): string
		return Strings.get("chest_time", seconds // 60, seconds % 60)
	end

	local chestCards = {}
	for index = 1, #ChestData.slotUnlockLevels do
		local card = UiKit.create("Frame", {
			LayoutOrder = index,
			Size = UDim2.fromOffset(76, 200),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, chestRow)
		UiKit.corner(card, 12)
		local lid = UiKit.create("Frame", {
			Position = UDim2.fromOffset(10, 12),
			Size = UDim2.fromOffset(56, 40),
			BorderSizePixel = 0,
		}, card)
		UiKit.corner(lid, 8)
		local name = UiKit.label({ Position = UDim2.fromOffset(2, 58), Size = UDim2.new(1, -4, 0, 36), TextSize = 13, TextWrapped = true }, card)
		local timer = UiKit.label({ Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 26), TextSize = 18, TextColor3 = colors.xp }, card)
		local button = UiKit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -8),
			Size = UDim2.fromOffset(68, 44),
			TextSize = 15,
		}, card, function()
			local list = chestStates()
			local chest = list[index]
			if not chest then
				return
			end
			local now = workspace:GetServerTimeNow()
			local left = remaining(chest, now)
			if left == nil and not anyUnlocking(list, now) then
				chestAction:FireServer("unlock", index)
				Audio.play("ui")
			elseif left == 0 then
				chestAction:FireServer("open", index)
				Audio.play("ui")
			end
		end)
		chestCards[index] = { card = card, lid = lid, name = name, timer = timer, button = button }
	end

	local function refreshChests()
		local list = chestStates()
		local now = workspace:GetServerTimeNow()
		local slots = Progression.chestSlots(Attrs.get("Level", 1))
		local busy = anyUnlocking(list, now)
		for index, view in chestCards do
			local chest = list[index]
			view.button.Visible = false
			view.timer.Text = ""
			if index > slots then
				view.card.BackgroundColor3 = colors.panel
				view.lid.BackgroundTransparency = 1
				view.name.Text = Strings.get("weapon_locked", ChestData.slotUnlockLevels[index])
				view.name.TextColor3 = colors.muted
			elseif not chest then
				view.card.BackgroundColor3 = colors.panelLight
				view.lid.BackgroundTransparency = 1
				view.name.Text = Strings.get("chest_empty")
				view.name.TextColor3 = colors.muted
			else
				local data = ChestData.chests[chest.type]
				local left = remaining(chest, now)
				view.card.BackgroundColor3 = colors.panelLight
				view.lid.BackgroundTransparency = 0
				view.lid.BackgroundColor3 = UiKit.rgb(data.color)
				view.name.Text = Strings.get(data.nameKey)
				view.name.TextColor3 = colors.text
				view.button.Visible = left == nil or left == 0
				if left == nil then
					view.timer.Text = clock(data.unlockSeconds)
					view.button.Text = Strings.get(if busy then "chest_wait" else "chest_unlock")
					view.button.BackgroundColor3 = if busy then colors.panel else colors.accent
					view.button.TextColor3 = if busy then colors.muted else colors.panel
				elseif left > 0 then
					view.timer.Text = clock(left)
				else
					view.button.Text = Strings.get("chest_open")
					view.button.BackgroundColor3 = colors.good
					view.button.TextColor3 = colors.panel
				end
			end
		end
	end

	-- What the last opened chest gave.
	local rewardModal, rewardBody = modal("chests_title", 300)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center }, rewardBody)
	local function showReward(reward: { [string]: any })
		for _, child in rewardBody:GetChildren() do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local function line(text: string, color: Color3?, size: number?)
			UiKit.label({ Size = UDim2.new(1, 0, 0, (size or 20) + 10), Text = text, TextSize = size or 20, TextWrapped = true, TextColor3 = color or colors.text }, rewardBody)
		end
		local data = ChestData.chests[reward.chest]
		line(Strings.get("chest_reward_title", Strings.get(if data then data.nameKey else "chests_title")), colors.accent, 24)
		line(Strings.get("chest_reward_coins", Format.short(reward.coins or 0)), colors.coin)
		local weapon = WeaponData.weapons[reward.weapon or ""]
		if weapon then
			local rarity = WeaponData.rarities[weapon.rarity]
			if reward.duplicate then
				line(Strings.get("chest_reward_duplicate", Strings.get(weapon.nameKey)), colors.muted)
			else
				line(Strings.get("chest_reward_weapon", Strings.get(weapon.nameKey), Strings.get(rarity.nameKey)), UiKit.rgb(rarity.color), 22)
			end
		end
		for _, entry in reward.slots or {} do
			local slot, gained, newLevel = entry[1], entry[2], entry[3]
			local slotName = if slot == 0 then Strings.get("bag_main") else Strings.get("bag_slot", slot)
			line(Strings.get("chest_reward_slot", slotName, newLevel, gained), colors.xp)
		end
		if openModal ~= rewardModal then
			showModal(rewardModal)
		end
		Audio.play("levelUp")
	end
	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, reward)
		if kind == "chestOpened" and typeof(reward) == "table" then
			showReward(reward)
		end
	end)

	-- Legendary Shadows --------------------------------------------------------------------
	-- Purified legends show in color; the others stay dark silhouettes.
	local legends, legendsBody = modal("legends_title", 330)
	UiKit.label({ Size = UDim2.new(1, 0, 0, 26), Text = Strings.get("legends_hint"), TextSize = 17, TextColor3 = colors.muted }, legendsBody)
	local legendRow = UiKit.create("Frame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 210),
		BackgroundTransparency = 1,
	}, legendsBody)
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, legendRow)
	local legendLevels = {}
	for _, spawn in WorldData.spawns do
		if spawn.level and Balance.enemies[spawn.kind].isBoss then
			legendLevels[spawn.kind] = spawn.level
		end
	end
	local legendCards = {}
	for order, kind in Balance.legends do
		local stats = Balance.enemies[kind]
		local card = UiKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.fromOffset(94, 200),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, legendRow)
		UiKit.corner(card, 12)
		local face = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 12),
			Size = UDim2.fromOffset(64, 64),
			BorderSizePixel = 0,
		}, card)
		UiKit.corner(face, 32)
		local name = UiKit.label({ Position = UDim2.fromOffset(4, 84), Size = UDim2.new(1, -8, 0, 40), TextSize = 15, TextWrapped = true }, card)
		UiKit.label({
			Position = UDim2.fromOffset(0, 126),
			Size = UDim2.new(1, 0, 0, 22),
			Text = Strings.get("legend_level", legendLevels[kind] or 1),
			TextSize = 15,
			TextColor3 = colors.xp,
		}, card)
		local done = UiKit.label({ Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 26), TextSize = 16, TextColor3 = colors.good }, card)
		legendCards[kind] = { face = face, name = name, done = done, stats = stats }
	end
	local function refreshLegends()
		local purified = Attrs.set("Legends")
		for kind, view in legendCards do
			local known = purified[kind] == true
			view.face.BackgroundColor3 = if known then UiKit.rgb(view.stats.color) else Color3.fromRGB(25, 20, 35)
			view.name.Text = if known then Strings.get(view.stats.nameKey) else Strings.get("legend_unknown")
			view.done.Text = if known then Strings.get("legend_done") else ""
		end
	end

	-- Adventure Log ------------------------------------------------------------------------
	-- One row per achievement: next tier's goal and progress, and a Claim button when reached.
	local log, logBody = modal("log_title", 430)
	local logList = UiKit.create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, logBody)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, logList)
	local logRows = {}
	for order, id in AchievementData.order do
		local def = AchievementData.achievements[id]
		local row = UiKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, -10, 0, 64),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, logList)
		UiKit.corner(row, 12)
		local name = UiKit.label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -130, 0, 24),
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		UiKit.label({
			Position = UDim2.fromOffset(12, 26),
			Size = UDim2.new(1, -130, 0, 16),
			Text = Strings.get(def.descKey),
			TextSize = 13,
			TextColor3 = colors.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local barBack = UiKit.create("Frame", {
			Position = UDim2.fromOffset(12, 46),
			Size = UDim2.new(1, -130, 0, 10),
			BackgroundColor3 = Color3.fromRGB(30, 26, 48),
			BorderSizePixel = 0,
		}, row)
		UiKit.corner(barBack, 5)
		local barFill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.xp, BorderSizePixel = 0 }, barBack)
		UiKit.corner(barFill, 5)
		local progress = UiKit.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -118, 0, 4),
			Size = UDim2.fromOffset(110, 20),
			TextSize = 14,
			TextColor3 = colors.muted,
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
		local button = UiKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(100, 44),
			TextSize = 18,
		}, row, function()
			claimAchievement:FireServer(id)
			Audio.play("ui")
		end)
		logRows[id] = { name = name, barFill = barFill, progress = progress, button = button }
	end
	-- "id:claimedTiers:progress" from the server.
	local function logEntries(): { [string]: { claimed: number, progress: number } }
		local entries = {}
		for _, item in Attrs.list("Achievements") do
			local id, claimed, value = string.match(item, "^([^:]+):(%d+):(%d+)$")
			if id then
				entries[id] = { claimed = tonumber(claimed) :: number, progress = tonumber(value) :: number }
			end
		end
		return entries
	end
	local function logReadyCount(): number
		local ready = 0
		for id, entry in logEntries() do
			local def = AchievementData.achievements[id]
			local tier = def and def.tiers[entry.claimed + 1]
			if tier and entry.progress >= tier.goal then
				ready += 1
			end
		end
		return ready
	end
	local function refreshLog()
		local entries = logEntries()
		for id, view in logRows do
			local def = AchievementData.achievements[id]
			local entry = entries[id] or { claimed = 0, progress = 0 }
			local tier = def.tiers[entry.claimed + 1]
			view.name.Text = Strings.get(def.nameKey) .. "  " .. Strings.get("log_tier", math.min(entry.claimed + 1, #def.tiers), #def.tiers)
			if not tier then
				view.progress.Text = ""
				view.barFill.Size = UDim2.fromScale(1, 1)
				view.button.Text = Strings.get("log_done")
				view.button.BackgroundColor3 = colors.panel
				view.button.TextColor3 = colors.muted
			else
				view.progress.Text = Strings.get("log_progress", Format.short(math.min(entry.progress, tier.goal)), Format.short(tier.goal))
				view.barFill.Size = UDim2.fromScale(math.clamp(entry.progress / tier.goal, 0, 1), 1)
				local ready = entry.progress >= tier.goal
				view.button.Text = if ready then Strings.get("log_claim") else Strings.get("hud_coins", Format.short(tier.coins))
				view.button.BackgroundColor3 = if ready then colors.good else colors.panel
				view.button.TextColor3 = if ready then colors.panel else colors.coin
			end
		end
	end

	-- Forge (the Smith's shop) ------------------------------------------------------------
	-- One row per upgrade: level, what it does and the price of the next level.
	local shop, shopBody = modal("shop_title", 420)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, shopBody)
	local upgradeRows = {}
	local function upgradeLevel(stat: string): number
		if stat == "power" then
			return Attrs.get("StaffTier", 0)
		end
		return Attrs.pairs("Upgrades")[stat] or 0
	end
	for order, stat in Balance.upgradeOrder do
		local upgrade = Balance.upgrades[stat]
		local row = UiKit.create("Frame", {
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 62),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, shopBody)
		UiKit.corner(row, 12)
		local name = UiKit.label({
			Position = UDim2.fromOffset(12, 4),
			Size = UDim2.new(1, -140, 0, 26),
			TextSize = 19,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		UiKit.label({
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -140, 0, 24),
			Text = Strings.get(upgrade.descKey),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = colors.muted,
			TextXAlignment = Enum.TextXAlignment.Left,
		}, row)
		local button = UiKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(112, 46),
			TextSize = 20,
		}, row, function()
			upgradeStaff:FireServer(stat)
		end)
		upgradeRows[stat] = { name = name, button = button }
	end

	local function refreshShop()
		local coins = Attrs.get("Coins", 0)
		for stat, view in upgradeRows do
			local upgrade = Balance.upgrades[stat]
			local level = upgradeLevel(stat)
			view.name.Text = Strings.get(upgrade.nameKey) .. "  " .. Strings.get("upgrade_level", level, upgrade.maxLevel)
			local cost = Progression.upgradeCost(stat, level)
			if not cost then
				view.button.Text = Strings.get("upgrade_max")
				view.button.BackgroundColor3 = colors.panel
				view.button.TextColor3 = colors.muted
			else
				local affordable = coins >= cost
				view.button.Text = Strings.get("hud_coins", Format.short(cost))
				view.button.BackgroundColor3 = if affordable then colors.accent else colors.panel
				view.button.TextColor3 = if affordable then colors.panel else colors.muted
			end
		end
	end

	-- Settings + performance overlay ---------------------------------------------------------
	local settings, settingsBody = modal("settings_title", 230)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 12), HorizontalAlignment = Enum.HorizontalAlignment.Center }, settingsBody)
	local perfVisible = false
	local perfRegion = UiKit.region(gui, Vector2.new(0, 0), UDim2.fromOffset(12, 12), Vector2.new(240, 110))
	local perfLabel = UiKit.label({
		Position = UDim2.fromOffset(0, 86),
		Size = UDim2.fromOffset(230, 22),
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.3,
		Visible = false,
	}, perfRegion)
	local frames, windowStart = 0, os.clock()
	local soundButton, perfButton
	local function refreshSettings()
		local on, off = Strings.get("setting_on"), Strings.get("setting_off")
		soundButton.Text = Strings.get("settings_sound", if Audio.isEnabled() then on else off)
		perfButton.Text = Strings.get("settings_fps", if perfVisible then on else off)
	end
	soundButton = UiKit.button({ Size = UDim2.fromOffset(340, 56) }, settingsBody, function()
		Audio.setEnabled(not Audio.isEnabled())
		refreshSettings()
	end)
	perfButton = UiKit.button({ Size = UDim2.fromOffset(340, 56) }, settingsBody, function()
		perfVisible = not perfVisible
		frames, windowStart = 0, os.clock()
		perfLabel.Visible = perfVisible
		refreshSettings()
	end)
	refreshSettings()

	RunService.RenderStepped:Connect(function()
		if not perfVisible then
			return
		end
		frames += 1
		local now = os.clock()
		if now - windowStart >= 1 then
			local ping = math.floor(player:GetNetworkPing() * 1000 + 0.5)
			perfLabel.Text = Strings.get("perf_line", math.floor(frames / (now - windowStart) + 0.5), ping)
			frames, windowStart = 0, now
		end
	end)

	UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_weapons"), LayoutOrder = 0 }, topRight, function()
		refreshWeapons()
		showModal(weapons)
	end)
	local chestsButton = UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_chests"), LayoutOrder = 1, BackgroundColor3 = colors.coin }, topRight, function()
		refreshChests()
		showModal(chestsModal)
	end)
	-- A "!" badge when a chest can be opened, or chests wait and none is unlocking.
	local chestBadge = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = colors.good,
		BackgroundTransparency = 0,
		Text = "!",
		TextSize = 18,
		TextColor3 = colors.panel,
		Visible = false,
	}, chestsButton)
	UiKit.corner(chestBadge, 12)
	UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_legends"), LayoutOrder = 2, BackgroundColor3 = colors.boss }, topRight, function()
		refreshLegends()
		showModal(legends)
	end)
	local logButton = UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_log"), LayoutOrder = 5, BackgroundColor3 = colors.good }, topRight, function()
		refreshLog()
		showModal(log)
	end)
	local logBadge = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = colors.accent,
		BackgroundTransparency = 0,
		Text = "!",
		TextSize = 18,
		TextColor3 = colors.panel,
		Visible = false,
	}, logButton)
	UiKit.corner(logBadge, 12)
	local function refreshLogBadge()
		logBadge.Visible = logReadyCount() > 0
		if openModal == log then
			refreshLog()
		end
	end
	player:GetAttributeChangedSignal("Achievements"):Connect(refreshLogBadge)
	refreshLogBadge()
	UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_bag"), LayoutOrder = 3 }, topRight, function()
		refreshBag()
		showModal(bag)
	end)
	UiKit.button({
		Size = UDim2.fromOffset(100, 48),
		Text = Strings.get("menu_settings"),
		LayoutOrder = 4,
		BackgroundColor3 = colors.panelLight,
		TextColor3 = colors.text,
	}, topRight, function()
		showModal(settings)
	end)

	Remotes:WaitForChild("OpenShop").OnClientEvent:Connect(function()
		refreshShop()
		if openModal ~= shop then
			showModal(shop)
		end
	end)
	local function refreshBadge()
		local list = chestStates()
		local now = workspace:GetServerTimeNow()
		local ready = false
		for _, chest in list do
			if remaining(chest, now) == 0 then
				ready = true
			end
		end
		chestBadge.Visible = ready or (#list > 0 and not anyUnlocking(list, now))
	end
	task.spawn(function()
		while true do
			task.wait(0.5)
			refreshBadge()
			if openModal == chestsModal then
				refreshChests()
			end
		end
	end)
	for _, name in { "StaffTier", "Upgrades", "Coins", "Level", "Charm", "Charms", "Weapon", "Companions", "Weapons", "SlotLevels", "Chests", "Legends" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			refreshBadge()
			if openModal == legends then
				refreshLegends()
			elseif openModal == chestsModal then
				refreshChests()
			elseif openModal == weapons then
				refreshWeapons()
			elseif openModal == bag then
				refreshBag()
			elseif openModal == shop then
				refreshShop()
			end
		end)
	end

	-- Close the shop when walking away from the Smith.
	local smith = WorldData.vector(WorldData.npcs.Smith.position)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if openModal == shop then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root or (root.Position - smith).Magnitude > Balance.shopDistance + 4 then
					closeModal()
				end
			end
		end
	end)

	-- Save loading / failure overlay --------------------------------------------------------
	local loadingLabel = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 16),
		Size = UDim2.fromOffset(320, 36),
		Text = Strings.get("data_loading"),
		TextStrokeTransparency = 0.2,
		Visible = false,
	}, gui)
	local failed = UiKit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 250),
		Visible = false,
		Corner = 18,
	}, center)
	failed.ZIndex = 10
	UiKit.label({ Position = UDim2.fromOffset(20, 16), Size = UDim2.new(1, -40, 0, 36), Text = Strings.get("data_failed_title"), TextSize = 28, TextColor3 = colors.accent }, failed)
	UiKit.label({
		Position = UDim2.fromOffset(20, 60),
		Size = UDim2.new(1, -40, 0, 80),
		Text = Strings.get("data_failed_body"),
		TextWrapped = true,
	}, failed)
	local retryButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -18),
		Size = UDim2.fromOffset(220, 60),
		Text = Strings.get("data_retry"),
		TextSize = 26,
	}, failed, function()
		retryLoad:FireServer()
	end)
	local function refreshData()
		local state = Attrs.get("DataState", "loading")
		loadingLabel.Visible = state == "loading"
		failed.Visible = state == "failed"
		retryButton.Visible = state == "failed"
		topRight.Visible = state == "ready"
	end
	player:GetAttributeChangedSignal("DataState"):Connect(refreshData)
	refreshData()
end

return Menus
