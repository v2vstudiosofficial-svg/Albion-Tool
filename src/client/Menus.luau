-- Bag (charms), staff shop, settings, performance overlay and the save-loading overlay.
-- Only one modal is open at a time so the screen never fills up with windows.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Balance = require(Shared:WaitForChild("Balance"))
local Progression = require(Shared:WaitForChild("Progression"))
local Strings = require(Shared:WaitForChild("Strings"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local player = Players.LocalPlayer
local colors = UiKit.colors

local Menus = {}

local function attr(name: string, default: any): any
	local value = player:GetAttribute(name)
	if value == nil then
		return default
	end
	return value
end

local function csvSet(value: any): { [string]: boolean }
	local set = {}
	if typeof(value) == "string" then
		for item in string.gmatch(value, "[^,]+") do
			set[item] = true
		end
	end
	return set
end

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
	local topRight = UiKit.region(gui, Vector2.new(1, 0), UDim2.new(1, -12, 0, 12), Vector2.new(236, 52))
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 10),
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
			local owned = csvSet(attr("Charms", ""))
			if not owned[charmId] then
				return
			end
			local equipped = attr("Charm", "") == charmId
			Remotes.EquipCharm:FireServer(if equipped then "" else charmId)
			Audio.play("ui")
		end)
		charmRows[charmId] = { row = row, gem = gem, name = name, desc = desc, button = button }
	end

	local function refreshBag()
		local tier = attr("StaffTier", 0)
		staffLine.Text = Strings.get("bag_staff", tier + 1, Progression.staffDamage(tier, attr("Level", 1)))
		local owned = csvSet(attr("Charms", ""))
		local equipped = attr("Charm", "")
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

	-- Shop ----------------------------------------------------------------------------------
	local shop, shopBody = modal("shop_title", 300)
	local shopTier = UiKit.label({ Size = UDim2.new(1, 0, 0, 30) }, shopBody)
	local shopDamage = UiKit.label({ Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 30), TextColor3 = colors.xp }, shopBody)
	local shopCost = UiKit.label({ Position = UDim2.fromOffset(0, 68), Size = UDim2.new(1, 0, 0, 30), TextColor3 = colors.coin }, shopBody)
	local shopButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.fromOffset(220, 64),
		Text = Strings.get("shop_upgrade"),
		TextSize = 28,
	}, shopBody, function()
		Remotes.UpgradeStaff:FireServer()
	end)

	local function refreshShop()
		local tier = attr("StaffTier", 0)
		local level = attr("Level", 1)
		local maxTier = Progression.maxStaffUpgrade()
		shopTier.Text = Strings.get("shop_tier", tier + 1, maxTier + 1)
		if tier >= maxTier then
			shopDamage.Text = Strings.get("shop_max")
			shopCost.Text = ""
			shopButton.Visible = false
			return
		end
		local cost = Balance.staff.tiers[tier + 2].cost
		shopDamage.Text = Strings.get("shop_damage", Progression.staffDamage(tier, level), Progression.staffDamage(tier + 1, level))
		shopCost.Text = Strings.get("shop_cost", cost)
		shopButton.Visible = true
		local affordable = attr("Coins", 0) >= cost
		shopButton.BackgroundColor3 = if affordable then colors.accent else colors.panelLight
		shopButton.TextColor3 = if affordable then colors.panel else colors.muted
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
		perfLabel.Visible = perfVisible
		refreshSettings()
	end)
	refreshSettings()

	local frames, windowStart = 0, os.clock()
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

	UiKit.button({ Size = UDim2.fromOffset(110, 48), Text = Strings.get("menu_bag"), LayoutOrder = 1 }, topRight, function()
		refreshBag()
		showModal(bag)
	end)
	UiKit.button({
		Size = UDim2.fromOffset(110, 48),
		Text = Strings.get("menu_settings"),
		LayoutOrder = 2,
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
	for _, name in { "StaffTier", "Coins", "Level", "Charm", "Charms" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if openModal == bag then
				refreshBag()
			elseif openModal == shop then
				refreshShop()
			end
		end)
	end

	-- Close the shop when walking away from Usta Demir.
	local demir = WorldData.vector(WorldData.npcs.Demir.position)
	task.spawn(function()
		while true do
			task.wait(0.5)
			if openModal == shop then
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if not root or (root.Position - demir).Magnitude > Balance.shopDistance + 4 then
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
		Remotes.RetryLoad:FireServer()
	end)
	local function refreshData()
		local state = attr("DataState", "loading")
		loadingLabel.Visible = state == "loading"
		failed.Visible = state == "failed"
		retryButton.Visible = state == "failed"
		topRight.Visible = state == "ready"
	end
	player:GetAttributeChangedSignal("DataState"):Connect(refreshData)
	refreshData()
end

return Menus
