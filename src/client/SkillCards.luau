-- Level-up skill cards: pick one of up to three offered skills. The panel opens by itself when a
-- new offer arrives; "Later" hides it and a small button under the player card brings it back.
-- The server decides the offer and validates the pick (SkillService).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SkillData = require(Shared:WaitForChild("SkillData"))
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local Attrs = require(script.Parent.Attrs)
local UiKit = require(script.Parent.UiKit)

local pickSkill = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("PickSkill") :: RemoteEvent
local player = Players.LocalPlayer
local colors = UiKit.colors

local COIN_CARD = "coins"
local CARD_COLOR_COINS = { 255, 200, 70 }

local SkillCards = {}

function SkillCards.start()
	local gui = UiKit.create("ScreenGui", { Name = "SkillCards", ResetOnSpawn = false, DisplayOrder = 6 }, player:WaitForChild("PlayerGui"))
	local center = UiKit.region(gui, Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), Vector2.new(460, 290))
	local panel = UiKit.panel({ Size = UDim2.fromOffset(460, 290), Visible = false, Corner = 18 }, center)
	UiKit.label({
		Position = UDim2.fromOffset(0, 8),
		Size = UDim2.new(1, 0, 0, 32),
		Text = Strings.get("skills_title"),
		TextSize = 26,
		TextColor3 = colors.accent,
	}, panel)
	local row = UiKit.create("Frame", {
		Position = UDim2.fromOffset(12, 46),
		Size = UDim2.new(1, -24, 0, 180),
		BackgroundTransparency = 1,
	}, panel)
	UiKit.create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, row)

	local cards = {}
	local offer: { string } = {}
	for index = 1, SkillData.offerCount do
		local card = UiKit.button({
			LayoutOrder = index,
			Size = UDim2.fromOffset(136, 180),
			Text = "",
			BackgroundColor3 = colors.panelLight,
		}, row, function()
			local choice = offer[index]
			if choice then
				pickSkill:FireServer(choice)
				Audio.play("ui")
			end
		end)
		local stripe = UiKit.create("Frame", {
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.new(1, -20, 0, 8),
			BorderSizePixel = 0,
		}, card)
		UiKit.corner(stripe, 4)
		local name = UiKit.label({ Position = UDim2.fromOffset(6, 24), Size = UDim2.new(1, -12, 0, 44), TextSize = 18, TextWrapped = true }, card)
		local desc = UiKit.label({
			Position = UDim2.fromOffset(8, 70),
			Size = UDim2.new(1, -16, 0, 76),
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = colors.muted,
			TextYAlignment = Enum.TextYAlignment.Top,
		}, card)
		local rank = UiKit.label({ Position = UDim2.new(0, 0, 1, -30), Size = UDim2.new(1, 0, 0, 24), TextSize = 15, TextColor3 = colors.xp }, card)
		cards[index] = { card = card, stripe = stripe, name = name, desc = desc, rank = rank }
	end
	UiKit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(150, 44),
		Text = Strings.get("skill_later"),
		BackgroundColor3 = colors.panelLight,
		TextColor3 = colors.text,
	}, panel, function()
		panel.Visible = false
		Audio.play("ui")
	end)

	-- Reopens the cards later; sits just under the player card in the top-left corner.
	local corner = UiKit.region(gui, Vector2.new(0, 0), UDim2.fromOffset(12, 146), Vector2.new(210, 46))
	local reopen = UiKit.button({ Size = UDim2.fromOffset(200, 42), TextSize = 18, BackgroundColor3 = colors.good, Visible = false }, corner, function()
		panel.Visible = true
		UiKit.pop(panel)
		Audio.play("ui")
	end)

	local function refresh()
		offer = Attrs.list("SkillOffer")
		local skills = Attrs.pairs("Skills")
		local pending = Attrs.get("PendingPicks", 0)
		for index, view in cards do
			local choice = offer[index]
			view.card.Visible = choice ~= nil
			if choice == COIN_CARD then
				view.stripe.BackgroundColor3 = UiKit.rgb(CARD_COLOR_COINS)
				view.name.Text = Strings.get("skill_coins_name")
				view.desc.Text = Strings.get("skill_coins_desc")
				view.rank.Text = Strings.get("hud_coins", SkillData.fallbackCoins)
			elseif choice and SkillData.skills[choice] then
				local skill = SkillData.skills[choice]
				view.stripe.BackgroundColor3 = UiKit.rgb(skill.color)
				view.name.Text = Strings.get(skill.nameKey)
				view.desc.Text = Strings.get(skill.descKey)
				view.rank.Text = Strings.get("skill_rank", (skills[choice] or 0) + 1, skill.maxRank)
			end
		end
		-- An offer always means a pick is waiting (PendingPicks may replicate a moment later).
		if #offer == 0 then
			panel.Visible = false
		end
		reopen.Visible = #offer > 0 and not panel.Visible
		reopen.Text = Strings.get("skill_button", math.max(pending, 1))
	end

	-- The first offer after joining is saved progress: show the button, not a surprise panel.
	local knownOffer = player:GetAttribute("SkillOffer")
	player:GetAttributeChangedSignal("SkillOffer"):Connect(function()
		local current = player:GetAttribute("SkillOffer")
		local isNew = knownOffer ~= nil and current ~= knownOffer and current ~= ""
		knownOffer = current
		if isNew then
			panel.Visible = true
			UiKit.pop(panel)
		end
		refresh()
	end)
	for _, name in { "PendingPicks", "Skills" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	panel:GetPropertyChangedSignal("Visible"):Connect(refresh)
	refresh()
end

return SkillCards
