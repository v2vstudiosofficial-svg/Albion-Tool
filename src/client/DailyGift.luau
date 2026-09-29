-- The daily gift button: appears left of the mini map (same region) while today's gift is waiting (the server
-- replicates DailyReady). Taking it is validated on the server; nothing is lost by skipping a day.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local Cinematic = require(script.Parent.Cinematic)
local Hud = require(script.Parent.Hud)
local Minimap = require(script.Parent.Minimap)
local UiKit = require(script.Parent.UiKit)

local player = Players.LocalPlayer
local claimDaily = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ClaimDailyGift") :: RemoteEvent

local DailyGift = {}

function DailyGift.start()
	-- Shares the mini map's region (left edge), so the two scale together and never overlap.
	local region = Minimap.region
	if not region then
		return
	end
	local button = UiKit.button({
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(Minimap.giftWidth, 56),
		Text = Strings.get("daily_gift_button"),
		TextSize = 17,
		TextWrapped = true,
		BackgroundColor3 = UiKit.colors.coin,
	}, region, function()
		claimDaily:FireServer()
		Audio.play("ui")
	end)
	button.Name = "DailyGiftButton"
	local announced = false
	local function refresh()
		local ready = player:GetAttribute("DataState") == "ready" and player:GetAttribute("DailyReady") == true
		button.Visible = ready and not Cinematic.playing()
		if ready and not announced then
			announced = true
			Hud.toast(Strings.get("notice_daily_ready"), UiKit.colors.coin)
		elseif not ready and player:GetAttribute("DailyReady") == false then
			announced = false
		end
	end
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
