-- Weapons, chests, bag (charms), weapon-power shop, settings, performance overlay and the save-loading overlay.
-- Only one modal is open at a time so the screen never fills up with windows.
local MarketplaceService = game:GetService("MarketplaceService")
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
local StoreData = require(Shared:WaitForChild("StoreData"))
local CosmeticData = require(Shared:WaitForChild("CosmeticData"))
local PassData = require(Shared:WaitForChild("PassData"))
local BountyData = require(Shared:WaitForChild("BountyData"))
local PetData = require(Shared:WaitForChild("PetData"))
local Audio = require(script.Parent.Audio)
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local equipCharm = Remotes:WaitForChild("EquipCharm") :: RemoteEvent
local upgradeStaff = Remotes:WaitForChild("BuyUpgrade") :: RemoteEvent
local equipWeapon = Remotes:WaitForChild("EquipWeapon") :: RemoteEvent
local chestAction = Remotes:WaitForChild("ChestAction") :: RemoteEvent
local claimAchievement = Remotes:WaitForChild("ClaimAchievement") :: RemoteEvent
local buyCosmetic = Remotes:WaitForChild("BuyCosmetic") :: RemoteEvent
local equipCosmetic = Remotes:WaitForChild("EquipCosmetic") :: RemoteEvent
local claimPass = Remotes:WaitForChild("ClaimPass") :: RemoteEvent
local claimBounty = Remotes:WaitForChild("ClaimBounty") :: RemoteEvent
local equipPet = Remotes:WaitForChild("EquipPet") :: RemoteEvent
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
	local topRight = UiKit.region(gui, Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), Vector2.new(208, 216))
	UiKit.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(100, 48),
		CellPadding = UDim2.fromOffset(8, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, topRight)

	-- Bag -----------------------------------------------------------------------------------
	local bag, bagBody = modal("bag_title", 440)
	local bagTab = "charms"
	local refreshBag: () -> ()
	local bagTabRow = UiKit.create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, bagBody)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, bagTabRow)
	local bagTabButtons = {}
	for order, tab in { "charms", "pets" } do
		bagTabButtons[tab] = UiKit.button({ Size = UDim2.fromOffset(130, 40), TextSize = 18, LayoutOrder = order, Text = Strings.get(if tab == "charms" then "bag_tab_charms" else "bag_tab_pets") }, bagTabRow, function()
			bagTab = tab
			refreshBag()
		end)
	end
	local staffLine = UiKit.label({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 28), TextSize = 20 }, bagBody)
	local charmList = UiKit.create("Frame", {
		Position = UDim2.fromOffset(0, 80),
		Size = UDim2.new(1, 0, 1, -80),
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

	-- Pets: earned by playing (never bought); the chosen one follows the player.
	local petList = UiKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 1, -44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Visible = false,
	}, bagBody)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, petList)
	local PET_UNLOCK_KEYS = {
		level = "pet_unlock_level",
		purifies = "pet_unlock_purifies",
		elites = "pet_unlock_elites",
		rifts = "pet_unlock_rifts",
		chests = "pet_unlock_chests",
		tower = "pet_unlock_tower",
	}
	local petRows = {}
	for order, petId in PetData.order do
		local pet = PetData.pets[petId]
		local row = UiKit.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 62), BackgroundColor3 = colors.panelLight, BorderSizePixel = 0 }, petList)
		UiKit.corner(row, 12)
		local swatch = UiKit.create("Frame", { Position = UDim2.fromOffset(10, 15), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = UiKit.rgb(pet.color), BorderSizePixel = 0 }, row)
		UiKit.corner(swatch, 16)
		local name = UiKit.label({ Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -170, 0, 26), Text = Strings.get(pet.nameKey), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local info = UiKit.label({ Position = UDim2.fromOffset(52, 30), Size = UDim2.new(1, -170, 0, 28), TextSize = 13, TextWrapped = true, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local button = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(104, 44), TextSize = 16 }, row, function()
			local progress = Attrs.pairs("PetProgress")[petId] or 0
			if progress >= pet.unlock.goal then
				equipPet:FireServer(if Attrs.get("Pet", "") == petId then "" else petId)
				Audio.play("ui")
			end
		end)
		petRows[petId] = { swatch = swatch, name = name, info = info, button = button }
	end
	local function refreshPets()
		local progress = Attrs.pairs("PetProgress")
		local active = Attrs.get("Pet", "")
		for petId, view in petRows do
			local pet = PetData.pets[petId]
			local unlock = pet.unlock
			local value = progress[petId] or 0
			local earned = value >= unlock.goal
			view.swatch.BackgroundTransparency = if earned then 0 else 0.7
			view.name.TextTransparency = if earned then 0 else 0.5
			if unlock.kind == "legend" then
				view.info.Text = Strings.get("pet_unlock_legend", Strings.get(Balance.enemies[unlock.id].nameKey))
			else
				view.info.Text = Strings.get(PET_UNLOCK_KEYS[unlock.kind], unlock.goal)
			end
			if not earned then
				view.info.Text ..= "  (" .. Strings.get("pet_progress", Format.short(value), Format.short(unlock.goal)) .. ")"
				view.button.Text = Strings.get("bag_locked_pet")
				view.button.BackgroundColor3 = colors.panel
				view.button.TextColor3 = colors.muted
			elseif active == petId then
				view.button.Text = Strings.get("pet_send_home")
				view.button.BackgroundColor3 = colors.good
				view.button.TextColor3 = colors.panel
			else
				view.button.Text = Strings.get("bag_equip")
				view.button.BackgroundColor3 = colors.accent
				view.button.TextColor3 = colors.panel
			end
		end
	end

	refreshBag = function()
		for tab, button in bagTabButtons do
			button.BackgroundColor3 = if tab == bagTab then colors.accent else colors.panelLight
			button.TextColor3 = if tab == bagTab then colors.panel else colors.text
		end
		staffLine.Visible = bagTab == "charms"
		charmList.Visible = bagTab == "charms"
		petList.Visible = bagTab == "pets"
		if bagTab == "pets" then
			refreshPets()
		end
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
		local stars = Attrs.pairs("Stars")
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
			local weaponStars = stars[weaponId] or 0
			tile.button.Text = if not unlocked
				then Strings.get("weapon_find")
				elseif weaponStars > 0 then Strings.get(WeaponData.weapons[weaponId].nameKey) .. "\n" .. Strings.get("weapon_stars", weaponStars, WeaponData.maxStars)
				else Strings.get(WeaponData.weapons[weaponId].nameKey)
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
				Progression.weaponDamage(current, Attrs.get("StaffTier", 0), level, editingSlot > 0, tonumber(slotLevels[editingSlot + 1]), stars[current]),
				stars[current] or 0,
				WeaponData.maxStars
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
			if reward.star then
				line(Strings.get("chest_reward_star", Strings.get(weapon.nameKey), reward.star, WeaponData.maxStars), UiKit.rgb(rarity.color), 22)
			elseif reward.duplicate then
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

	-- Bounty Board ---------------------------------------------------------------------------
	-- Opens from the village board (server event); rows come from the Bounties attribute
	-- ("kind:goal:progress" in board order). Closes when the player walks away.
	local board, boardBody = modal("board_title", 330)
	UiKit.label({ Size = UDim2.new(1, 0, 0, 24), Text = Strings.get("board_hint"), TextSize = 14, TextWrapped = true, TextColor3 = colors.muted }, boardBody)
	local boardRows = {}
	for slot = 1, BountyData.slots do
		local row = UiKit.create("Frame", {
			Position = UDim2.fromOffset(0, 32 + (slot - 1) * 82),
			Size = UDim2.new(1, -8, 0, 76),
			BackgroundColor3 = colors.panelLight,
			BorderSizePixel = 0,
		}, boardBody)
		UiKit.corner(row, 12)
		local name = UiKit.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -130, 0, 24), TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local reward = UiKit.label({ Position = UDim2.fromOffset(12, 28), Size = UDim2.new(1, -130, 0, 18), TextSize = 13, TextColor3 = colors.coin, TextXAlignment = Enum.TextXAlignment.Left }, row)
		local barBack = UiKit.create("Frame", { Position = UDim2.fromOffset(12, 54), Size = UDim2.new(1, -130, 0, 10), BackgroundColor3 = Color3.fromRGB(30, 26, 48), BorderSizePixel = 0 }, row)
		UiKit.corner(barBack, 5)
		local fill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.xp, BorderSizePixel = 0 }, barBack)
		UiKit.corner(fill, 5)
		local button = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(100, 44), TextSize = 17 }, row, function()
			if boardRows[slot].done then
				claimBounty:FireServer(slot)
				Audio.play("ui")
			end
		end)
		boardRows[slot] = { row = row, name = name, reward = reward, fill = fill, button = button, done = false }
	end
	local function boardEntries(): { { kind: string, goal: number, progress: number } }
		local entries = {}
		for _, item in Attrs.list("Bounties") do
			local kind, goal, value = string.match(item, "^([^:]+):(%d+):(%d+)$")
			if kind and BountyData.kinds[kind] then
				table.insert(entries, { kind = kind, goal = tonumber(goal) :: number, progress = tonumber(value) :: number })
			end
		end
		return entries
	end
	local function refreshBoard()
		local entries = boardEntries()
		local level = Attrs.get("Level", 1)
		for slot, view in boardRows do
			local entry = entries[slot]
			view.row.Visible = entry ~= nil
			if entry then
				local def = BountyData.kinds[entry.kind]
				local done = entry.progress >= entry.goal
				view.done = done
				view.name.Text = Strings.get(def.nameKey, entry.goal)
				view.reward.Text = Strings.get("bounty_reward", Format.short(Progression.incomeCoins(level, def.minutes)))
				view.fill.Size = UDim2.fromScale(math.clamp(entry.progress / entry.goal, 0, 1), 1)
				view.button.Text = if done then Strings.get("bounty_claim") else Strings.get("bounty_progress", entry.progress, entry.goal)
				view.button.BackgroundColor3 = if done then colors.good else colors.panel
				view.button.TextColor3 = if done then colors.panel else colors.muted
			end
		end
	end
	Remotes:WaitForChild("OpenBoard").OnClientEvent:Connect(function()
		refreshBoard()
		if openModal ~= board then
			showModal(board)
		end
	end)
	player:GetAttributeChangedSignal("Bounties"):Connect(function()
		if openModal == board then
			refreshBoard()
		end
	end)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		if openModal == board then
			refreshBoard()
		end
	end)
	local boardPosition = WorldData.vector(WorldData.board.position)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if openModal == board then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root or (root.Position - boardPosition).Magnitude > Balance.shopDistance + 4 then
					closeModal()
				end
			end
		end
	end)

	-- Shop: Robux packs and costumes -----------------------------------------------------------
	-- Robux products show their live price from Roblox; products without an id say "Soon".
	-- Nothing here pops up by itself: the shop only opens when the player taps it.
	local refreshStore: () -> ()
	local refreshPass: () -> ()
	local store: Frame, pass: Frame
	local priceCache: { [number]: number } = {}
	local function priceOf(productId: number): number?
		if productId == 0 then
			return nil
		end
		if priceCache[productId] == nil then
			priceCache[productId] = -1
			task.spawn(function()
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(productId, Enum.InfoType.Product)
				end)
				priceCache[productId] = if ok and info and info.PriceInRobux then info.PriceInRobux else -1
				-- Prices arrive a moment later; redraw whichever window shows them.
				if openModal == store then
					refreshStore()
				elseif openModal == pass then
					refreshPass()
				end
			end)
		end
		local price = priceCache[productId]
		return if price and price >= 0 then price else nil
	end
	local function prompt(productKey: string)
		local product = StoreData.products[productKey]
		if product and product.productId ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.productId)
		end
	end
	local function serverNow(): number
		return workspace:GetServerTimeNow()
	end

	local storeBody
	store, storeBody = modal("shop_store_title", 440)
	local tabRow = UiKit.create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 }, storeBody)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabRow)
	UiKit.label({
		Position = UDim2.fromOffset(0, 44),
		Size = UDim2.new(1, 0, 0, 30),
		Text = Strings.get("shop_note"),
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = colors.muted,
	}, storeBody)
	local function page(): ScrollingFrame
		local frame = UiKit.create("ScrollingFrame", {
			Position = UDim2.fromOffset(0, 78),
			Size = UDim2.new(1, 0, 1, -78),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 6,
			CanvasSize = UDim2.fromOffset(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}, storeBody)
		return frame
	end
	local packsPage, costumesPage = page(), page()
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, packsPage)
	UiKit.create("UIGridLayout", {
		CellSize = UDim2.fromOffset(122, 92),
		CellPadding = UDim2.fromOffset(6, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, costumesPage)
	local currentTab = "packs"
	local TAB_KEYS = { packs = "shop_tab_packs", costumes = "shop_tab_costumes" }
	local tabButtons = {}
	for order, tab in { "packs", "costumes" } do
		tabButtons[tab] = UiKit.button({ Size = UDim2.fromOffset(130, 40), TextSize = 18, LayoutOrder = order, Text = Strings.get(TAB_KEYS[tab]) }, tabRow, function()
			currentTab = tab
			refreshStore()
		end)
	end

	local packRows = {}
	for order, key in StoreData.order do
		local product = StoreData.products[key]
		if not product.costume or product.weapon then
			local row = UiKit.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, 60), BackgroundColor3 = colors.panelLight, BorderSizePixel = 0 }, packsPage)
			UiKit.corner(row, 12)
			UiKit.label({ Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -140, 0, 26), Text = Strings.get(product.nameKey), TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local gives = UiKit.label({ Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -140, 0, 24), TextSize = 14, TextWrapped = true, TextColor3 = colors.muted, TextXAlignment = Enum.TextXAlignment.Left }, row)
			local button = UiKit.button({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0.5, 0), Size = UDim2.fromOffset(112, 44), TextSize = 18 }, row, function()
				-- Owned, capped or not on sale yet: the button is greyed out and does nothing.
				if packRows[key].buyable then
					prompt(key)
				end
			end)
			packRows[key] = { gives = gives, button = button, buyable = false }
		end
	end

	local costumeTiles = {}
	for order, id in CosmeticData.order do
		local costume = CosmeticData.costumes[id]
		local tile = UiKit.create("Frame", { LayoutOrder = order, BackgroundColor3 = colors.panelLight, BorderSizePixel = 0 }, costumesPage)
		UiKit.corner(tile, 12)
		local swatch = UiKit.create("Frame", { Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = UiKit.rgb(costume.color), BorderSizePixel = 0 }, tile)
		UiKit.corner(swatch, 9)
		UiKit.label({ Position = UDim2.fromOffset(30, 4), Size = UDim2.new(1, -34, 0, 34), Text = Strings.get(costume.nameKey), TextSize = 14, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left }, tile)
		local button = UiKit.button({ AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 36), TextSize = 15 }, tile, function()
			local owned = Attrs.set("Costumes")[id]
			if owned then
				local worn = false
				for _, entry in Attrs.list("Worn") do
					if entry == costume.slot .. ":" .. id then
						worn = true
					end
				end
				equipCosmetic:FireServer(if worn then "" else id, costume.slot)
			elseif costume.source.coins then
				buyCosmetic:FireServer(id)
			elseif costume.source.robux then
				prompt(costume.source.robux)
			end
			Audio.play("ui")
		end)
		costumeTiles[id] = { button = button }
	end

	local function setButton(button: TextButton, text: string, enabled: boolean, color: Color3?)
		button.Text = text
		button.BackgroundColor3 = if enabled then (color or colors.accent) else colors.panel
		button.TextColor3 = if enabled then colors.panel else colors.muted
	end

	refreshStore = function()
		packsPage.Visible = currentTab == "packs"
		costumesPage.Visible = currentTab == "costumes"
		for tab, button in tabButtons do
			setButton(button, Strings.get(TAB_KEYS[tab]), true, if tab == currentTab then colors.accent else colors.panelLight)
		end
		local level = Attrs.get("Level", 1)
		local oneTime = Attrs.set("OneTime")
		local boostLeft = Attrs.get("BoostUntil", 0) - serverNow()
		for key, view in packRows do
			local product = StoreData.products[key]
			if product.coinMinutes and not product.once then
				local coins = Format.short(Progression.incomeCoins(level, product.coinMinutes, product.bonus))
				view.gives.Text = if (product.bonus or 0) > 0
					then Strings.get("store_gives_coins_bonus", coins, math.floor(product.bonus * 100 + 0.5))
					else Strings.get("store_gives_coins", coins)
			elseif product.boostMinutes then
				view.gives.Text = Strings.get("store_gives_boost")
			elseif product.once then
				view.gives.Text = Strings.get("store_gives_starter", Format.short(Progression.incomeCoins(level, product.coinMinutes)))
			elseif product.passPremium then
				view.gives.Text = Strings.get("store_gives_pass")
			end
			local owned = (product.once and oneTime[key]) or (product.passPremium and Attrs.get("PassPremium", false))
			local capped = product.boostMinutes and boostLeft > (StoreData.maxBoostMinutes - product.boostMinutes) * 60
			local price = priceOf(product.productId)
			view.buyable = not owned and price ~= nil and not capped
			if owned then
				setButton(view.button, Strings.get("shop_owned"), false)
			elseif not price then
				setButton(view.button, Strings.get("shop_soon"), false)
			else
				setButton(view.button, Strings.get("shop_price_robux", price), not capped, colors.good)
			end
		end
		local ownedCostumes = Attrs.set("Costumes")
		local worn = Attrs.set("Worn")
		for id, view in costumeTiles do
			local costume = CosmeticData.costumes[id]
			local source = costume.source
			if ownedCostumes[id] then
				local wearing = worn[costume.slot .. ":" .. id] == true
				setButton(view.button, Strings.get(if wearing then "costume_remove" else "costume_wear"), true, if wearing then colors.panelLight else colors.good)
			elseif source.coins then
				setButton(view.button, Strings.get("hud_coins", Format.short(source.coins)), Attrs.get("Coins", 0) >= source.coins, colors.coin)
			elseif source.robux then
				local price = priceOf(StoreData.products[source.robux].productId)
				setButton(view.button, if price then Strings.get("shop_price_robux", price) else Strings.get("shop_soon"), price ~= nil, colors.good)
			else
				setButton(view.button, Strings.get("costume_from_pass", source.pass), false)
			end
		end
	end

	-- Light Pass -----------------------------------------------------------------------------
	local passBody
	pass, passBody = modal("menu_pass", 440)
	local passTitle = UiKit.label({ Size = UDim2.new(1, 0, 0, 26), TextSize = 20, TextColor3 = colors.accent }, passBody)
	local passTier = UiKit.label({ Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 22), TextSize = 17 }, passBody)
	local passBarBack = UiKit.create("Frame", {
		Position = UDim2.fromOffset(20, 54),
		Size = UDim2.new(1, -40, 0, 12),
		BackgroundColor3 = Color3.fromRGB(30, 26, 48),
		BorderSizePixel = 0,
	}, passBody)
	UiKit.corner(passBarBack, 6)
	local passBarFill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.boss, BorderSizePixel = 0 }, passBarBack)
	UiKit.corner(passBarFill, 6)
	local passButtons = UiKit.create("Frame", { Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 }, passBody)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 10) }, passButtons)
	local claimAllButton = UiKit.button({ Size = UDim2.fromOffset(150, 42), Text = Strings.get("pass_claim_all"), TextSize = 18, LayoutOrder = 1 }, passButtons, function()
		claimPass:FireServer("all")
		Audio.play("ui")
	end)
	local premiumButton = UiKit.button({ Size = UDim2.fromOffset(170, 42), TextSize = 18, LayoutOrder = 2 }, passButtons, function()
		if not Attrs.get("PassPremium", false) then
			prompt("pass_premium")
		end
	end)
	local track = UiKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 124),
		Size = UDim2.new(1, 0, 1, -124),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.fromOffset(PassData.tiers * 86, 0),
	}, passBody)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, track)
	local function rewardText(reward, level: number): string
		if reward.costume then
			return Strings.get(CosmeticData.costumes[reward.costume].nameKey)
		end
		return Strings.get("pass_reward_coins", Format.short(Progression.incomeCoins(level, reward.coinMinutes)))
	end
	local passCells = {}
	for tier = 1, PassData.tiers do
		local column = UiKit.create("Frame", { LayoutOrder = tier, Size = UDim2.fromOffset(80, 180), BackgroundTransparency = 1 }, track)
		UiKit.label({ Size = UDim2.new(1, 0, 0, 20), Text = tostring(tier), TextSize = 16, TextColor3 = colors.muted }, column)
		local cells = {}
		for index, trackName in { "free", "premium" } do
			cells[trackName] = UiKit.button({
				Position = UDim2.fromOffset(0, 22 + (index - 1) * 80),
				Size = UDim2.fromOffset(80, 74),
				TextSize = 12,
				TextWrapped = true,
			}, column, function()
				claimPass:FireServer(tier, trackName)
			end)
		end
		passCells[tier] = cells
	end
	local function passState()
		local tier = math.min(PassData.tiers, Attrs.get("PassXp", 0) // PassData.xpPerTier)
		return tier, Attrs.set("PassFree"), Attrs.set("PassPremiumClaimed"), Attrs.get("PassPremium", false)
	end
	local function passClaimable(): number
		local tier, free, premiumClaimed, premium = passState()
		local count = 0
		for t = 1, tier do
			if not free[tostring(t)] then
				count += 1
			end
			if premium and not premiumClaimed[tostring(t)] then
				count += 1
			end
		end
		return count
	end
	refreshPass = function()
		local tier, free, premiumClaimed, premium = passState()
		local level = Attrs.get("Level", 1)
		local xp = Attrs.get("PassXp", 0)
		passTitle.Text = Strings.get("pass_title", Attrs.get("PassSeason", PassData.season))
		passTier.Text = Strings.get("pass_tier", tier, PassData.tiers)
		passBarFill.Size = UDim2.fromScale(if tier >= PassData.tiers then 1 else (xp % PassData.xpPerTier) / PassData.xpPerTier, 1)
		local premiumPrice = priceOf(StoreData.products.pass_premium.productId)
		if premium then
			setButton(premiumButton, Strings.get("pass_premium_on"), false)
		elseif premiumPrice then
			setButton(premiumButton, Strings.get("pass_get_premium") .. "  " .. Strings.get("shop_price_robux", premiumPrice), true, colors.boss)
		else
			setButton(premiumButton, Strings.get("pass_get_premium") .. "  " .. Strings.get("shop_soon"), false)
		end
		setButton(claimAllButton, Strings.get("pass_claim_all"), passClaimable() > 0, colors.good)
		for t, cells in passCells do
			for trackName, cell in cells do
				local claimed = if trackName == "free" then free[tostring(t)] else premiumClaimed[tostring(t)]
				local reached = t <= tier
				local open = trackName == "free" or premium
				cell.Text = (if trackName == "premium" then Strings.get("pass_premium") .. "\n" else "") .. rewardText(PassData.rewards[t][trackName], level)
				if claimed then
					cell.BackgroundColor3 = colors.panel
					cell.TextColor3 = colors.muted
				elseif reached and open then
					cell.BackgroundColor3 = colors.good
					cell.TextColor3 = colors.panel
				else
					cell.BackgroundColor3 = if trackName == "premium" then Color3.fromRGB(70, 50, 100) else colors.panelLight
					cell.TextColor3 = colors.text
				end
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
	UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_shop"), LayoutOrder = 6, BackgroundColor3 = colors.accent }, topRight, function()
		refreshStore()
		showModal(store)
	end)
	local passButton = UiKit.button({ Size = UDim2.fromOffset(100, 48), Text = Strings.get("menu_pass"), LayoutOrder = 7, BackgroundColor3 = colors.boss }, topRight, function()
		refreshPass()
		showModal(pass)
	end)
	local passBadge = UiKit.label({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -4, 0, 4),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = colors.accent,
		BackgroundTransparency = 0,
		Text = "!",
		TextSize = 18,
		TextColor3 = colors.panel,
		Visible = false,
	}, passButton)
	UiKit.corner(passBadge, 12)
	for _, name in { "PassXp", "PassFree", "PassPremiumClaimed", "PassPremium", "Costumes", "Worn", "OneTime", "BoostUntil", "Coins", "Level" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			passBadge.Visible = passClaimable() > 0
			if openModal == pass then
				refreshPass()
			elseif openModal == store then
				refreshStore()
			end
		end)
	end
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
	for _, name in { "StaffTier", "Upgrades", "Coins", "Level", "Charm", "Charms", "Weapon", "Companions", "Weapons", "SlotLevels", "Stars", "Pet", "PetProgress", "Chests", "Legends" } do
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
