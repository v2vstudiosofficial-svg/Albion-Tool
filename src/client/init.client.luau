local StarterGui = game:GetService("StarterGui")

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
local CameraRig = require(script.CameraRig)
local Companions = require(script.Companions)
local SkillCards = require(script.SkillCards)

Audio.start()
CameraRig.start()
Effects.start()
Companions.start()
Hud.start()
Controls.start()
Menus.start()
SkillCards.start()
Waypoint.start()
World.start()

print("[LanternValley] Client started")
