-- The chest opening moment: the screen dims, the chest drops in and shakes, the lid bursts open
-- in a flash with light rays behind it, then each reward pops in one after another (coins count
-- up, a new weapon glows in its rarity color). Rarer chests send motes of light rising behind
-- the open chest. "Continue" closes it. Purely cosmetic: the reward
-- itself was already granted by the server (Fx "chestOpened").
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SettingsData = require(Shared:WaitForChild("SettingsData"))
local ChestData = require(Shared:WaitForChild("ChestData"))
local Format = require(Shared:WaitForChild("Format"))
local Strings = require(Shared:WaitForChild("Strings"))
local WeaponData = require(Shared:WaitForChild("WeaponData"))
local Audio = require(script.Parent.Audio)
local Settings = require(script.Parent.Settings)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local colors = UiKit.colors

local RAY_BARS = 8
local LINE_GAP = 0.35 -- seconds between reward lines
local COUNT_SECONDS = 0.6 -- coins count up this long
-- Rising motes per second once the lid is open (none for wood; gifts without a chest get a few).
local MOTES = { silver = 4, gold = 9, mystic = 16 }
local GIFT_MOTES = 5

local ChestReveal = {}

local gui: ScreenGui? = nil
local parts: { [string]: any } = {}
local playToken = 0
local moteRate = 0 -- motes per second right now (0 until the lid opens)
local moteColor = Color3.new(1, 1, 1)

local function darker(color: Color3, by: number): Color3
	return Color3.new(color.R * by, color.G * by, color.B * by)
end

local function build()
	gui = UiKit.create("ScreenGui", { Name = "ChestReveal", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 7, Enabled = false }, player:WaitForChild("PlayerGui"))
	local dim = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 6, 20), BackgroundTransparency = 0.3, BorderSizePixel = 0 }, gui)
	local stage = UiKit.region(gui :: ScreenGui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(520, 520))

	local rays = UiKit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(260, 150), Size = UDim2.fromOffset(1, 1), BackgroundTransparency = 1, Visible = false }, stage)
	local rayFrames = {}
	for index = 1, RAY_BARS do
		local ray = UiKit.create("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(if index % 2 == 0 then 22 else 40, 520),
			Rotation = (index - 1) * 180 / RAY_BARS,
			BackgroundColor3 = colors.accent,
			BorderSizePixel = 0,
		}, rays)
		UiKit.create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		}, ray)
		table.insert(rayFrames, ray)
	end

	-- The chest: body with two bands, a lid on top and a gold clasp.
	local chest = UiKit.create("Frame", { Name = "Chest", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(260, 170), Size = UDim2.fromOffset(180, 150), BackgroundTransparency = 1 }, stage)
	local chestScale = UiKit.create("UIScale", nil, chest)
	local body = UiKit.create("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(170, 92), BorderSizePixel = 0 }, chest)
	UiKit.corner(body, 12)
	local bodyStroke = UiKit.create("UIStroke", { Thickness = 4 }, body)
	local bands = {}
	for _, x in { 0.25, 0.75 } do
		local band = UiKit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0), Size = UDim2.new(0, 14, 1, 0), BorderSizePixel = 0 }, body)
		table.insert(bands, band)
	end
	local lid = UiKit.create("Frame", { Name = "Lid", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -88), Size = UDim2.fromOffset(180, 54), BorderSizePixel = 0 }, chest)
	UiKit.corner(lid, 18)
	local lidStroke = UiKit.create("UIStroke", { Thickness = 4 }, lid)
	local clasp = UiKit.create("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 1, -88), Size = UDim2.fromOffset(26, 30), BackgroundColor3 = colors.accent, BorderSizePixel = 0, ZIndex = 3 }, chest)
	UiKit.corner(clasp, 6)
	UiKit.create("UIStroke", { Color = Color3.fromRGB(120, 70, 20), Thickness = 3 }, clasp)

	local flash = UiKit.create("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5 }, gui)

	local list = UiKit.create("Frame", { Name = "Rewards", Position = UDim2.fromOffset(0, 270), Size = UDim2.fromOffset(520, 200), BackgroundTransparency = 1 }, stage)
	UiKit.create("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, list)
	local continueButton = UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.fromOffset(200, 50),
		Text = Strings.get("chest_continue"),
		Visible = false,
	}, stage, function()
		ChestReveal.close()
	end)

	parts = {
		dim = dim,
		rays = rays,
		rayFrames = rayFrames,
		chest = chest,
		chestScale = chestScale,
		body = body,
		bodyStroke = bodyStroke,
		bands = bands,
		lid = lid,
		lidStroke = lidStroke,
		clasp = clasp,
		flash = flash,
		list = list,
		continueButton = continueButton,
	}
	local moteDue = 0
	RunService.Heartbeat:Connect(function(dt)
		if gui and gui.Enabled and rays.Visible then
			rays.Rotation = (rays.Rotation + dt * 20) % 360
		end
		if not (gui and gui.Enabled) or moteRate <= 0 then
			moteDue = 0
			return
		end
		moteDue += dt * moteRate
		while moteDue >= 1 do
			moteDue -= 1
			local size = math.random(8, 14)
			local x = 260 + math.random(-110, 110)
			local mote = UiKit.create("Frame", {
				Name = "Mote",
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, 230),
				Size = UDim2.fromOffset(size, size),
				BackgroundColor3 = moteColor,
				BorderSizePixel = 0,
				ZIndex = 3, -- in front of the rays and the chest, like dust in the light
			}, stage)
			UiKit.corner(mote, size)
			local rise = 1.6 + math.random() * 0.9
			UiKit.tween(mote, rise, { Position = UDim2.fromOffset(x + math.random(-30, 30), math.random(0, 70)), BackgroundTransparency = 1 }, Enum.EasingStyle.Sine).Completed:Connect(function()
				mote:Destroy()
			end)
		end
	end)
end

function ChestReveal.isOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function ChestReveal.close()
	playToken += 1
	moteRate = 0
	if gui then
		gui.Enabled = false
	end
end

-- reward = { chest, coins, weapon?, duplicate?, star?, slots = { {slot, gained, newLevel} }, titleKey?, color? }
function ChestReveal.show(reward: { [string]: any })
	if not gui then
		build()
	end
	playToken += 1
	local token = playToken
	local data = ChestData.chests[reward.chest]
	-- Not only chests: a reward may bring its own name and colour (the daily gift).
	local nameKey = reward.titleKey or (data and data.nameKey) or "chests_title"
	local color = if reward.color then reward.color elseif data then UiKit.rgb(data.color) else colors.accent
	for _, child in parts.list:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	-- Reset the chest to closed.
	parts.body.BackgroundColor3 = color
	parts.bodyStroke.Color = darker(color, 0.45)
	for _, band in parts.bands do
		band.BackgroundColor3 = darker(color, 0.6)
	end
	parts.lid.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.15)
	parts.lidStroke.Color = darker(color, 0.45)
	parts.lid.Position = UDim2.new(0.5, 0, 1, -88)
	parts.lid.Rotation = 0
	parts.lid.BackgroundTransparency = 0
	parts.clasp.Visible = true
	parts.chest.Rotation = 0
	parts.chestScale.Scale = 0.3
	parts.rays.Visible = false
	for _, ray in parts.rayFrames do
		ray.BackgroundColor3 = color:Lerp(colors.accent, 0.5)
	end
	parts.flash.BackgroundTransparency = 1
	parts.continueButton.Visible = false
	moteRate = 0
	moteColor = color:Lerp(Color3.new(1, 1, 1), 0.75)
	gui.Enabled = true

	local function alive(): boolean
		return token == playToken
	end
	local order = 0
	local function line(text: string, lineColor: Color3?, size: number?): TextLabel
		order += 1
		local label = UiKit.label({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, (size or 22) + 10),
			Text = text,
			TextSize = size or 22,
			TextWrapped = true,
			TextColor3 = lineColor or colors.text,
			TextStrokeTransparency = 0.3,
		}, parts.list)
		UiKit.pop(label)
		return label
	end

	task.spawn(function()
		-- 1. The chest drops in.
		UiKit.tween(parts.chestScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		task.wait(0.4)
		-- 2. It rattles, harder each time.
		for index, angle in { 6, -9, 12 } do
			if not alive() then
				return
			end
			UiKit.tween(parts.chest, 0.09, { Rotation = angle })
			task.wait(0.1 + index * 0.02)
		end
		UiKit.tween(parts.chest, 0.08, { Rotation = 0 })
		task.wait(0.1)
		if not alive() then
			return
		end
		-- 3. The lid bursts open in a flash, light rays fan out behind.
		parts.clasp.Visible = false
		UiKit.tween(parts.lid, 0.35, { Position = UDim2.new(0.5, -30, 1, -160), Rotation = -28 })
		if Settings.get("flashes") then
			parts.flash.BackgroundTransparency = 0.25
			UiKit.tween(parts.flash, 0.45, { BackgroundTransparency = 1 })
		end
		parts.rays.Visible = true
		moteRate = (if data then MOTES[reward.chest] or 0 else GIFT_MOTES) * (SettingsData.effectDensity[Settings.get("effects")] or 1)
		UiKit.pop(parts.chest)
		Audio.play("levelUp")
		task.wait(0.35)
		-- 4. The rewards, one by one.
		line(Strings.get("chest_reward_title", Strings.get(nameKey)), colors.accent, 26)
		task.wait(LINE_GAP)
		if not alive() then
			return
		end
		local coins = reward.coins or 0
		local coinsLine = line(Strings.get("chest_reward_coins", Format.short(0)), colors.coin, 24)
		local started = os.clock()
		while alive() and os.clock() - started < COUNT_SECONDS do
			local shown = math.floor(coins * (os.clock() - started) / COUNT_SECONDS)
			coinsLine.Text = Strings.get("chest_reward_coins", Format.short(shown))
			task.wait(0.03)
		end
		coinsLine.Text = Strings.get("chest_reward_coins", Format.short(coins))
		Audio.play("pickup")
		local weapon = WeaponData.weapons[reward.weapon or ""]
		if weapon then
			task.wait(LINE_GAP)
			if not alive() then
				return
			end
			local rarity = WeaponData.rarities[weapon.rarity]
			local rarityColor = UiKit.rgb(rarity.color)
			local label
			if reward.star then
				label = line(Strings.get("chest_reward_star", Strings.get(weapon.nameKey), reward.star, WeaponData.maxStars), rarityColor, 24)
			elseif reward.duplicate then
				label = line(Strings.get("chest_reward_duplicate", Strings.get(weapon.nameKey)), colors.muted)
			else
				label = line(Strings.get("chest_reward_weapon", Strings.get(weapon.nameKey), Strings.get(rarity.nameKey)), rarityColor, 26)
				-- A brand new weapon reads in its rarity color with a deep outline of the same hue.
				label.TextStrokeColor3 = darker(rarityColor, 0.3)
				label.TextStrokeTransparency = 0
			end
			Audio.play("purify")
		end
		for _, entry in reward.slots or {} do
			task.wait(LINE_GAP)
			if not alive() then
				return
			end
			local slot, gained, newLevel = entry[1], entry[2], entry[3]
			local slotName = if slot == 0 then Strings.get("bag_main") else Strings.get("bag_slot", slot)
			line(Strings.get("chest_reward_slot", slotName, newLevel, gained), colors.xp)
		end
		task.wait(LINE_GAP)
		if alive() then
			parts.continueButton.Visible = true
			UiKit.pop(parts.continueButton)
		end
	end)
end

return ChestReveal
