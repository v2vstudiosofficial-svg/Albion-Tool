-- The daily gift button: appears left of the mini map (same region) while today's gift is waiting (the server
-- replicates DailyReady). Taking it is validated on the server; nothing is lost by skipping a day. Once
-- it is taken, a quiet countdown in its place says when the next one comes (gifts follow UTC days).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local ChestReveal = require(script.Parent.ChestReveal)
local Cinematic = require(script.Parent.Cinematic)
local Hud = require(script.Parent.Hud)
local Minimap = require(script.Parent.Minimap)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local DAY_SECONDS = 24 * 60 * 60
local claimDaily = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimDailyGift") :: RemoteEvent

local DailyGift = {}

function DailyGift.start()
	-- Shares the mini map's region (left edge), so the two scale together and never overlap.
	local region = Minimap.region
	if not region then
		return
	end
	local coinsBefore: number? = nil
	local button = UiKit.button({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(Minimap.giftWidth, 56),
		Text = Strings.get("daily_gift_button"),
		TextSize = 17,
		TextWrapped = true,
		BackgroundColor3 = UiKit.colors.coin,
	}, region, function()
		coinsBefore = player:GetAttribute("Coins") or 0
		claimDaily:FireServer()
		Audio.play("ui")
	end)
	button.Name = "DailyGiftButton"
	UiKit.withIcon(button, Strings.get("icon_gift"), 24)
	local countdown = UiKit.label({
		Name = "NextGift",
		Size = UDim2.fromOffset(Minimap.giftWidth, 44),
		BackgroundColor3 = UiKit.colors.panel,
		BackgroundTransparency = 0.35,
		TextSize = 13,
		TextWrapped = true,
		TextColor3 = UiKit.colors.muted,
		Visible = false,
	}, region)
	UiKit.corner(countdown, 10)
	local announced = false
	local function refresh()
		local ready = player:GetAttribute("DataState") == "ready" and player:GetAttribute("DailyReady") == true
		button.Visible = ready and not Cinematic.playing()
		local waiting = player:GetAttribute("DataState") == "ready" and player:GetAttribute("DailyReady") == false
		countdown.Visible = waiting and not Cinematic.playing()
		if countdown.Visible then
			local left = DAY_SECONDS - workspace:GetServerTimeNow() % DAY_SECONDS
			countdown.Text = Strings.get("daily_next", math.floor(left / 3600), math.floor(left % 3600 / 60))
		end
		if ready and not announced then
			announced = true
			Hud.toast(Strings.get("notice_daily_ready"), UiKit.colors.coin)
		elseif not ready and player:GetAttribute("DailyReady") == false then
			announced = false
		end
	end
	-- Taking the gift opens it like a chest: a golden box, coins counting up.
	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Notice").OnClientEvent:Connect(function(key)
		if key ~= "notice_daily_gift" or not coinsBefore then
			return
		end
		local before = coinsBefore
		coinsBefore = nil
		task.wait(0.15) -- the coins attribute lands with the notice
		local gained = math.max(0, (player:GetAttribute("Coins") or 0) - before)
		ChestReveal.show({ chest = "gift", coins = gained, titleKey = "daily_gift_title", color = UiKit.colors.coin, slots = {} })
	end)
	for _, name in { "DataState", "DailyReady" } do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	task.spawn(function()
		while true do
			refresh()
			task.wait(0.5)
		end
	end)
end

return DailyGift
