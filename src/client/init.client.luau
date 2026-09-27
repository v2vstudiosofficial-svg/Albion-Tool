local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Pick the UI language before any module builds text.
local Strings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Strings"))
Strings.setLanguage(Strings.languageFor(Players.LocalPlayer.LocaleId))

-- No tools are used, and our Bag/Settings buttons live where the player list would sit on PC.
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)

local Audio = require(script.Audio)
local Effects = require(script.Effects)
local World = require(script.World)
local Hud = require(script.Hud)
local Controls = require(script.Controls)
local Menus = require(script.Menus)
local Waypoint = require(script.Waypoint)

Audio.start()
Effects.start()
Hud.start()
Controls.start()
Menus.start()
Waypoint.start()
World.start()

print("[LanternValley] Client started")
