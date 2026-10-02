-- Story scenes: an NPC (or the narrator) speaks in short lines with a typewriter caption, the
-- camera moves to whoever is talking, and a Skip button sits in the bottom-right corner.
--   "full" scenes (talking to a quest giver, big story moments) pause the controls and show
--   letterbox bars; "soft" scenes are just a caption while the game keeps running.
-- The server only says which scene to play (Remotes.Cinematic); text, order and camera come from
-- StoryData and Strings, and nothing in a scene is needed for progress.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local StoryData = require(Shared:WaitForChild("StoryData"))
local Strings = require(Shared:WaitForChild("Strings"))
local WorldData = require(Shared:WaitForChild("WorldData"))
local Audio = require(script.Parent.Audio)
local CameraRig = require(script.Parent.CameraRig)
local UiKit = require(script.Parent.UiKit)
local Settings = require(script.Parent.Settings)
local World = require(script.Parent.World)

local player = Players.LocalPlayer
local colors = UiKit.colors

local CHARS_PER_SECOND = 48
local BAR_HEIGHT = 0.11 -- letterbox bar, as a fraction of the screen
local SOFT_MIN_SECONDS = 3.2
local SOFT_SECONDS_PER_CHAR = 0.045
local FOV = 38
-- Screens hidden while a full scene plays, so only the letterbox, caption and Skip are left.
local HIDDEN_IN_SCENES = { "Hud", "Menus", "Minimap", "Emotes", "PlayerBoard", "Controls", "WaypointEdge" }

local Cinematic = {}

local busy = false
local currentScene: string? = nil
local blockingControls = false
local queue: { string } = {}
local skipRequested = false
local advanceRequested = false

-- True while a full scene has the controls paused (Controls.wave checks this).
function Cinematic.blocking(): boolean
	return blockingControls
end

function Cinematic.playing(): boolean
	return busy
end

local function localRoot(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return humanoid, root
end

-- Pauses or resumes the default movement controls (does nothing where they do not exist).
local function setControls(enabled: boolean)
	local ok, controls = pcall(function()
		local module = (player :: any).PlayerScripts:WaitForChild("PlayerModule", 2)
		return require(module):GetControls()
	end)
	if ok and controls then
		pcall(function()
			if enabled then
				controls:Enable()
			else
				controls:Disable()
			end
		end)
	end
end

-- Where the camera looks and stands for one line. NPCs are filmed from the front (the way they
-- face), the hero from just ahead of the player, the narrator from a wide shot of the focus.
local function shotFor(speaker: string, focusName: string, progress: number): CameraRig.Shot?
	local _, root = localRoot()
	local dolly = 1 - progress * 0.18 -- a slow push-in over the scene
	local npc = WorldData.npcs[speaker]
	if npc then
		local position = WorldData.vector(npc.position)
		local facing = (WorldData.vector(npc.lookAt) - position) * Vector3.new(1, 0, 1)
		facing = if facing.Magnitude > 0.1 then facing.Unit else Vector3.new(0, 0, 1)
		local right = facing:Cross(Vector3.new(0, 1, 0))
		local focus = position + Vector3.new(0, 2.4, 0)
		return { from = focus + (facing * 9 + right * 2.6) * dolly + Vector3.new(0, 0.8, 0), focus = focus, fov = FOV }
	end
	if speaker == "Hero" and root then
		local focus = root.Position + Vector3.new(0, 1.8, 0)
		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
		return { from = focus + (look * 8 + look:Cross(Vector3.new(0, 1, 0)) * 2) * dolly + Vector3.new(0, 1, 0), focus = focus, fov = FOV }
	end
	if focusName == "lantern" then
		local lantern = WorldData.vector(WorldData.plaza) + Vector3.new(0, 8, 0)
		return { from = lantern + Vector3.new(11, -1, 30) * dolly, focus = lantern, fov = 45 }
	end
	if root then
		local focus = root.Position + Vector3.new(0, 3, 0)
		return { from = focus + Vector3.new(6, 6, 20) * dolly, focus = focus, fov = 45 }
	end
	return nil
end

function Cinematic.start()
	local gui = UiKit.create("ScreenGui", { Name = "Cinematic", ResetOnSpawn = false, DisplayOrder = 8, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))

	local top = UiKit.create("Frame", { Name = "BarTop", Size = UDim2.fromScale(1, 0), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Visible = false }, gui)
	local bottom = UiKit.create("Frame", {
		Name = "BarBottom",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 0),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BorderSizePixel = 0,
		Visible = false,
	}, gui)

	local region = UiKit.region(gui, Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -18), Vector2.new(620, 168))
	local panel = UiKit.panel({ Size = UDim2.fromOffset(620, 160), Visible = false, Corner = 16 }, region)
	local nameLabel = UiKit.label({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -40, 0, 30),
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	}, panel)
	local textLabel = UiKit.label({
		Position = UDim2.fromOffset(20, 44),
		Size = UDim2.new(1, -40, 0, 80),
		TextSize = 21,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
	}, panel)
	local hint = UiKit.label({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -8),
		Size = UDim2.fromOffset(220, 22),
		Text = Strings.get("cinematic_continue"),
		TextSize = 15,
		TextColor3 = colors.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
	}, panel)
	-- Tapping the caption goes on to the next line.
	local tap = UiKit.create("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, panel)
	tap.Activated:Connect(function()
		advanceRequested = true
	end)

	-- Bottom-right corner: skips the whole scene.
	local skipRegion = UiKit.region(gui, Vector2.new(1, 1), UDim2.new(1, -16, 1, -16), Vector2.new(130, 52))
	local skip = UiKit.button({ Size = UDim2.fromScale(1, 1), Text = Strings.get("cinematic_skip"), TextSize = 22, BackgroundColor3 = colors.panelLight, TextColor3 = colors.text, Visible = false }, skipRegion, function()
		skipRequested = true
		Audio.play("ui")
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not busy or processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.Space or input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.E then
			advanceRequested = true
		end
	end)

	local function setBars(on: boolean)
		if on then
			top.Visible, bottom.Visible = true, true
		end
		UiKit.tween(top, 0.5, { Size = UDim2.fromScale(1, if on then BAR_HEIGHT else 0) })
		UiKit.tween(bottom, 0.5, { Size = UDim2.fromScale(1, if on then BAR_HEIGHT else 0) })
		if not on then
			task.delay(0.55, function()
				if not busy then
					top.Visible, bottom.Visible = false, false
				end
			end)
		end
	end

	local function setHud(on: boolean)
		World.setMarkersHidden(not on)
		local playerGui = player:FindFirstChild("PlayerGui")
		for _, name in HIDDEN_IN_SCENES do
			local screen = playerGui and playerGui:FindFirstChild(name)
			if screen and screen:IsA("ScreenGui") then
				screen.Enabled = on
			end
		end
	end

	local function playScene(sceneId: string)
		local scene = StoryData.scenes[sceneId]
		if not scene then
			return
		end
		busy, skipRequested, advanceRequested = true, false, false
		-- The first story scene waits for the loading screen to fade, so it is not missed under it.
		local playerGui = player:FindFirstChild("PlayerGui")
		while playerGui and playerGui:FindFirstChild("LoadingScreen") do
			task.wait(0.1)
		end
		currentScene = sceneId
		-- With "camera scenes" turned off in Settings every scene is just captions.
		local full = scene.mode == "full" and Settings.get("cinematics")
		local humanoid = select(1, localRoot())
		if full then
			blockingControls = true
			setControls(false)
			setBars(true)
			setHud(false)
			-- Full scenes keep the caption above the letterbox bar.
			region.Position = UDim2.new(0.5, 0, 1 - BAR_HEIGHT, -14)
		else
			-- A caption right after a full scene must not inherit its bars.
			top.Visible, bottom.Visible = false, false
			top.Size, bottom.Size = UDim2.fromScale(1, 0), UDim2.fromScale(1, 0)
			region.Position = UDim2.new(0.5, 0, 1, -18)
		end
		panel.Visible = true
		skip.Visible = true
		UiKit.pop(panel)
		Audio.play("ui")

		local total = #scene.lines
		for index, line in scene.lines do
			if skipRequested or (humanoid and humanoid.Health <= 0) then
				break
			end
			local speaker = StoryData.speakers[line.speaker]
			local npc = WorldData.npcs[line.speaker]
			nameLabel.Text = if speaker and speaker.nameKey then Strings.get(speaker.nameKey) else ""
			local color = if speaker then UiKit.rgb(speaker.color) else colors.text
			nameLabel.TextColor3 = color
			textLabel.TextColor3 = if line.speaker == "Narrator" then colors.muted else colors.text
			textLabel.Font = if line.speaker == "Narrator" then Enum.Font.SourceSansItalic else UiKit.font
			local text = Strings.get(line.key)
			if full then
				CameraRig.setShot(shotFor(line.speaker, scene.focus, (index - 1) / math.max(1, total - 1)))
			end
			World.setSpeaking(if npc then line.speaker else nil)
			if npc and index == 1 or (npc and scene.lines[index - 1] and scene.lines[index - 1].speaker ~= line.speaker) then
				World.greet(line.speaker)
			end
			-- Typewriter: letters appear quickly; a tap finishes the line, another tap moves on.
			advanceRequested = false
			hint.Visible = false
			local shown = 0
			local started = os.clock()
			while shown < #text and not skipRequested do
				if advanceRequested then
					advanceRequested = false
					shown = #text
				else
					shown = math.min(#text, math.floor((os.clock() - started) * CHARS_PER_SECOND) + 1)
				end
				textLabel.Text = string.sub(text, 1, shown)
				if shown % 4 == 0 then
					Audio.play("ui")
				end
				task.wait(0.03)
			end
			textLabel.Text = text
			hint.Visible = full
			if full and index == total then
				hint.Text = Strings.get("cinematic_end")
			else
				hint.Text = Strings.get("cinematic_continue")
			end
			-- Wait for a tap (full scenes) or read time (soft scenes); the camera keeps gliding.
			local waited = 0
			local readSeconds = math.max(SOFT_MIN_SECONDS, #text * SOFT_SECONDS_PER_CHAR)
			while not skipRequested and not advanceRequested and (full or waited < readSeconds) do
				if humanoid and humanoid.Health <= 0 then
					skipRequested = true
					break
				end
				if full then
					CameraRig.setShot(shotFor(line.speaker, scene.focus, (index - 1 + math.min(1, waited / 6)) / math.max(1, total - 1)))
				end
				waited += task.wait(0.05)
			end
			advanceRequested = false
		end

		World.setSpeaking(nil)
		panel.Visible = false
		skip.Visible = false
		if full then
			CameraRig.setShot(nil)
			setBars(false)
			setHud(true)
			blockingControls = false
			setControls(true)
		end
		busy = false
		currentScene = nil
		local nextScene = table.remove(queue, 1)
		if nextScene then
			task.delay(0.4, Cinematic.play, nextScene)
		end
	end

	Cinematic.play = function(sceneId: string)
		if busy then
			-- Talking to the same person again must not stack the same scene.
			if sceneId ~= currentScene and not table.find(queue, sceneId) and #queue < 4 then
				table.insert(queue, sceneId)
			end
			return
		end
		task.spawn(playScene, sceneId)
	end

	ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Cinematic").OnClientEvent:Connect(function(sceneId)
		if typeof(sceneId) == "string" then
			Cinematic.play(sceneId)
		end
	end)
end

Cinematic.play = function(_sceneId: string) end

return Cinematic
