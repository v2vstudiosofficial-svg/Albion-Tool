-- The Settings window: four pages (Graphics, Audio, Gameplay, Interface) built from SettingsData.
-- Switches, choices and sliders all work with mouse, touch and gamepad (sliders also have - / +
-- buttons). Graphics has quality presets; changing any single graphics option switches to
-- "Custom". Values come from Client/Settings; changes go to the server through `send`.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsData = require(Shared:WaitForChild("SettingsData"))
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)

local colors = UiKit.colors

local SettingsMenu = {}

local CATEGORY_KEYS = {
	graphics = "settings_cat_graphics",
	audio = "settings_cat_audio",
	gameplay = "settings_cat_gameplay",
	interface = "settings_cat_interface",
}
-- Text for each choice value (Strings keys; one table so nothing is built from pieces).
local OPTION_KEYS = {
	auto = "opt_auto", low = "opt_low", medium = "opt_medium", high = "opt_high", ultra = "opt_ultra", custom = "opt_custom",
	small = "opt_small", normal = "opt_normal", large = "opt_large",
}
local DESCRIPTION_KEYS = {
	quality = "set_quality_desc", detail = "set_detail_desc", shadows = "set_shadows_desc", effects = "set_effects_desc",
	bloom = "set_bloom_desc", atmosphere = "set_atmosphere_desc", fov = "set_fov_desc", sound = "set_sound_desc",
	master = "set_master_desc", sfx = "set_sfx_desc", shake = "set_shake_desc", cinematics = "set_cinematics_desc",
	damageNumbers = "set_damage_numbers_desc", rangeRing = "set_range_ring_desc", uiScale = "set_ui_scale_desc",
	minimap = "set_minimap_desc", playerTags = "set_player_tags_desc", enemyBars = "set_enemy_bars_desc", perf = "set_perf_desc",
}
local ROW_HEIGHT = 58

type Row = { key: string, refresh: () -> () }

-- A pill switch: the knob slides right when on.
local function buildSwitch(parent: Instance, key: string, change: (any) -> ()): () -> ()
	local pill = UiKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(64, 30),
		Text = "",
		Corner = 15,
	}, parent, function()
		change(not Settings.get(key))
		Audio.play("ui")
	end)
	local knob = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(24, 24),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
	}, pill)
	UiKit.corner(knob, 12)
	local stateLabel = UiKit.label({ Size = UDim2.fromScale(1, 1), TextSize = 12, TextColor3 = colors.panel }, pill)
	return function()
		local on = Settings.get(key) == true
		pill.BackgroundColor3 = if on then colors.good else colors.panel
		UiKit.tween(knob, 0.12, { Position = if on then UDim2.new(1, -27, 0.5, 0) else UDim2.new(0, 3, 0.5, 0) })
		stateLabel.Text = if on then Strings.get("setting_on") else Strings.get("setting_off")
		stateLabel.TextXAlignment = if on then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right
		stateLabel.Position = UDim2.fromOffset(if on then 8 else -8, 0)
	end
end

-- Segmented buttons, one per option.
local function buildChoice(parent: Instance, key: string, change: (any) -> ()): () -> ()
	local def = SettingsData.settings[key]
	local holder = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(#def.options * 76, 34),
		BackgroundTransparency = 1,
	}, parent)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, holder)
	local buttons = {}
	for order, option in def.options do
		buttons[option] = UiKit.button({ LayoutOrder = order, Size = UDim2.fromOffset(72, 34), Text = Strings.get(OPTION_KEYS[option]), TextSize = 15, Corner = 8 }, holder, function()
			change(option)
			Audio.play("ui")
		end)
	end
	return function()
		local current = Settings.get(key)
		for option, button in buttons do
			button.BackgroundColor3 = if option == current then colors.accent else colors.panel
			button.TextColor3 = if option == current then colors.panel else colors.text
		end
	end
end

-- A slider: drag the knob (mouse or touch) or use the - / + buttons for exact steps.
local function buildSlider(parent: Instance, key: string, change: (any) -> ()): () -> ()
	local def = SettingsData.settings[key]
	local holder = UiKit.create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(250, 34),
		BackgroundTransparency = 1,
	}, parent)
	local function stepBy(direction: number)
		change(SettingsData.clean(key, Settings.get(key) + direction * def.step))
		Audio.play("ui")
	end
	UiKit.button({ Size = UDim2.fromOffset(34, 34), Text = "-", TextSize = 24, Corner = 8, BackgroundColor3 = colors.panel, TextColor3 = colors.text }, holder, function()
		stepBy(-1)
	end)
	UiKit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(34, 34), Text = "+", TextSize = 24, Corner = 8, BackgroundColor3 = colors.panel, TextColor3 = colors.text }, holder, function()
		stepBy(1)
	end)
	local track = UiKit.create("TextButton", {
		Name = "Track",
		Position = UDim2.fromOffset(42, 0),
		Size = UDim2.new(1, -84, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, holder)
	local bar = UiKit.create("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = colors.panel, BorderSizePixel = 0 }, track)
	UiKit.corner(bar, 4)
	local fill = UiKit.create("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = colors.accent, BorderSizePixel = 0 }, bar)
	UiKit.corner(fill, 4)
	local knob = UiKit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, bar)
	UiKit.corner(knob, 10)
	local valueLabel = UiKit.label({ Position = UDim2.new(0, 42, 0, -14), Size = UDim2.new(1, -84, 0, 14), TextSize = 13, TextColor3 = colors.muted }, holder)

	local function show(value: number)
		local fraction = (value - def.min) / (def.max - def.min)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
		valueLabel.Text = tostring(value) .. (if key == "fov" then "" else "%")
	end
	-- Dragging shows the value at once and saves it when the finger or mouse lets go.
	local dragging: any = nil
	local pending: number? = nil
	local function valueAt(x: number): number
		local left, width = track.AbsolutePosition.X, math.max(1, track.AbsoluteSize.X)
		return SettingsData.clean(key, def.min + math.clamp((x - left) / width, 0, 1) * (def.max - def.min))
	end
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = input
			pending = valueAt(input.Position.X)
			show(pending :: number)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseMovement) then
			pending = valueAt(input.Position.X)
			show(pending :: number)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input == dragging or input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
			if pending and pending ~= Settings.get(key) then
				change(pending)
			end
			pending = nil
		end
	end)
	return function()
		if not dragging then
			show(Settings.get(key))
		end
	end
end

-- Builds the whole window inside `body` (a Frame with width x height to fill). `send` delivers a
-- table of changes to the server (SetSetting).
function SettingsMenu.build(body: Frame, send: (any) -> ()): () -> ()
	local page = "graphics"
	local rows: { Row } = {}
	local tabButtons = {}
	local presetButtons = {}
	local qualityNote: TextLabel

	-- One change from the menu. A single graphics option switches the preset to "Custom" and keeps
	-- the rest of the graphics choices as they are on screen right now.
	local function change(key: string, value: any)
		if SettingsData.settings[key].preset then
			local changes: { [string]: any } = { quality = "custom" }
			for other, def in SettingsData.settings do
				if def.preset then
					changes[other] = Settings.get(other)
				end
			end
			changes[key] = value
			send(changes)
		else
			send({ [key] = value })
		end
	end

	-- Left: page tabs.
	local tabs = UiKit.create("Frame", { Size = UDim2.new(0, 132, 1, -52), BackgroundTransparency = 1 }, body)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tabs)
	-- Right: the page.
	local content = UiKit.create("Frame", { Position = UDim2.fromOffset(144, 0), Size = UDim2.new(1, -144, 1, -52), BackgroundTransparency = 1 }, body)
	local presetRow = UiKit.create("Frame", { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1, Visible = true }, content)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, presetRow)
	for order, preset in { "auto", "low", "medium", "high", "ultra" } do
		presetButtons[preset] = UiKit.button({ LayoutOrder = order, Size = UDim2.fromOffset(78, 38), Text = Strings.get(OPTION_KEYS[preset]), TextSize = 16, Corner = 10 }, presetRow, function()
			send({ quality = preset })
			Audio.play("ui")
		end)
	end
	qualityNote = UiKit.label({
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 13,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, content)
	local list = UiKit.create("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 66),
		Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, content)
	UiKit.create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)

	local containers: { [string]: Frame } = {}
	local order = 0
	for _, key in SettingsData.order do
		local def = SettingsData.settings[key]
		if key ~= "quality" then
			order += 1
			local row = UiKit.create("Frame", { LayoutOrder = order, Size = UDim2.new(1, -10, 0, ROW_HEIGHT), BackgroundColor3 = colors.panelLight, BorderSizePixel = 0 }, list)
			UiKit.corner(row, 10)
			UiKit.label({ Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -330, 0, 24), Text = Strings.get(def.nameKey), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left }, row)
			UiKit.label({
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -330, 0, 24),
				Text = Strings.get(DESCRIPTION_KEYS[key]),
				TextSize = 12,
				TextWrapped = true,
				TextColor3 = colors.muted,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}, row)
			local send1 = function(value: any)
				change(key, value)
			end
			local refresh = if def.kind == "bool" then buildSwitch(row, key, send1) elseif def.kind == "choice" then buildChoice(row, key, send1) else buildSlider(row, key, send1)
			table.insert(rows, { key = key, refresh = refresh })
			containers[key] = row
		end
	end

	-- Bottom: reset this page.
	local resetButton = UiKit.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(190, 44),
		Text = Strings.get("settings_reset"),
		TextSize = 17,
		BackgroundColor3 = colors.panelLight,
		TextColor3 = colors.text,
	}, body, function()
		send({ reset = page })
		Audio.play("ui")
	end)

	local function refresh()
		for _, category in SettingsData.categories do
			tabButtons[category].BackgroundColor3 = if category == page then colors.accent else colors.panelLight
			tabButtons[category].TextColor3 = if category == page then colors.panel else colors.text
		end
		presetRow.Visible = page == "graphics"
		qualityNote.Visible = page == "graphics"
		list.Position = UDim2.fromOffset(0, if page == "graphics" then 66 else 0)
		list.Size = UDim2.new(1, 0, 1, if page == "graphics" then -66 else 0)
		local quality = Settings.saved().quality
		for preset, button in presetButtons do
			button.BackgroundColor3 = if preset == quality then colors.accent else colors.panel
			button.TextColor3 = if preset == quality then colors.panel else colors.text
		end
		qualityNote.Text = if quality == "custom" then Strings.get("settings_custom_note") elseif quality == "auto" then Strings.get("settings_auto_note", Strings.get(OPTION_KEYS[SettingsData.resolveQuality("auto", UiKit.isTouch())])) else ""
		for _, row in rows do
			containers[row.key].Visible = SettingsData.settings[row.key].category == page
			row.refresh()
		end
		resetButton.Text = Strings.get("settings_reset")
	end
	for tabOrder, category in SettingsData.categories do
		tabButtons[category] = UiKit.button({ LayoutOrder = tabOrder, Size = UDim2.new(1, 0, 0, 46), Text = Strings.get(CATEGORY_KEYS[category]), TextSize = 19, Corner = 10 }, tabs, function()
			page = category
			refresh()
			Audio.play("ui")
		end)
	end
	Settings.onChanged(refresh)
	refresh()
	return refresh
end

return SettingsMenu
