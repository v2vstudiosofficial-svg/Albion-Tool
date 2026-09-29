-- Emotes: a small button under the player card opens six emotes; the server checks the request
-- and tells nearby players, and every client draws the speech bubble over that player's head.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local EmoteData = require(Shared:WaitForChild("EmoteData"))
local Strings = require(Shared:WaitForChild("Strings"))
local Audio = require(script.Parent.Audio)
local UiKit = require(script.Parent.UiKit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local playEmote = Remotes:WaitForChild("PlayEmote") :: RemoteEvent
local player = Players.LocalPlayer
local colors = UiKit.colors

local BUBBLE_NAME = "EmoteBubble"

local Emotes = {}

local function showBubble(other: any, id: string)
	local emote = EmoteData.emotes[id]
	local character = if typeof(other) == "Instance" or type(other) == "table" then other.Character else nil
	local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
	if not emote or not head then
		return
	end
	local old = head:FindFirstChild(BUBBLE_NAME)
	if old then
		old:Destroy()
	end
	local bubble = UiKit.create("BillboardGui", {
		Name = BUBBLE_NAME,
		Size = UDim2.fromOffset(150, 44),
		StudsOffset = Vector3.new(0, 3.2, 0),
		AlwaysOnTop = true,
		MaxDistance = EmoteData.range,
	}, head)
	local panel = UiKit.panel({ Size = UDim2.fromScale(1, 1), Corner = 14 }, bubble)
	UiKit.label({ Size = UDim2.fromScale(1, 1), Text = Strings.get(emote.bubbleKey), TextSize = 22 }, panel)
	task.delay(EmoteData.duration, function()
		if bubble.Parent then
			bubble:Destroy()
		end
	end)
end

function Emotes.start()
	local gui = UiKit.create("ScreenGui", { Name = "Emotes", ResetOnSpawn = false, DisplayOrder = 4 }, player:WaitForChild("PlayerGui"))
	-- Left edge, halfway down: clear of the player card, quest panel and touch controls.
	local corner = UiKit.region(gui, Vector2.new(0, 0.5), UDim2.new(0, 12, 0.5, -20), Vector2.new(440, 46))
	local panel = UiKit.create("Frame", {
		Position = UDim2.fromOffset(106, 0),
		Size = UDim2.fromOffset(320, 46),
		BackgroundTransparency = 1,
		Visible = false,
	}, corner)
	UiKit.create("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	UiKit.button({ Size = UDim2.fromOffset(100, 40), Text = Strings.get("emote_button"), TextSize = 18, BackgroundColor3 = colors.panelLight, TextColor3 = colors.text }, corner, function()
		panel.Visible = not panel.Visible
		Audio.play("ui")
	end)
	for order, id in EmoteData.order do
		UiKit.button({
			LayoutOrder = order,
			Size = UDim2.fromOffset(46, 46),
			Text = Strings.get(EmoteData.emotes[id].nameKey),
			TextSize = 12,
			TextWrapped = true,
			BackgroundColor3 = colors.panelLight,
			TextColor3 = colors.text,
		}, panel, function()
			playEmote:FireServer(id)
			panel.Visible = false
			Audio.play("ui")
		end)
	end

	Remotes:WaitForChild("Fx").OnClientEvent:Connect(function(kind, other, id)
		if kind == "emote" and typeof(id) == "string" then
			showBubble(other, id)
		end
	end)
end

return Emotes
