-- Run: rojo build default.project.json -o build/test.rbxlx && lune run tests/place build/test.rbxlx
-- Compiles every source file and checks the Rojo output places scripts under the right services.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local failures = 0
local function check(condition: boolean, message: string)
	if not condition then
		failures += 1
		print("FAIL " .. message)
	end
end

local compiled = 0
local function compileTree(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			compileTree(path)
		elseif string.sub(name, -5) == ".luau" then
			local ok, err = pcall(luau.compile, fs.readFile(path))
			check(ok, path .. ": " .. tostring(err))
			compiled += 1
		end
	end
end
compileTree("src")
compileTree("tests")

local placePath = process.args[1]
assert(placePath, "usage: lune run tests/place <place.rbxlx>")
local game = roblox.deserializePlace(fs.readFile(placePath))

local function expectClass(instance: any, className: string, label: string)
	check(instance ~= nil and instance.ClassName == className, `{label} should be {className}`)
end

local replicated = game:GetService("ReplicatedStorage")
local shared = replicated:FindFirstChild("Shared")
expectClass(shared, "Folder", "ReplicatedStorage.Shared")
for _, name in { "Strings", "Balance", "QuestData", "WorldData", "Progression", "Sounds", "Goals" } do
	expectClass(shared and shared:FindFirstChild(name), "ModuleScript", "Shared." .. name)
end
local remotes = replicated:FindFirstChild("Remotes")
for _, name in {
	"EquipWeapon",
	"RequestWave",
	"Interact",
	"UpgradeStaff",
	"EquipCharm",
	"RetryLoad",
	"RewardGranted",
	"Notice",
	"NpcSay",
	"OpenShop",
	"Fx",
} do
	expectClass(remotes and remotes:FindFirstChild(name), "RemoteEvent", "Remotes." .. name)
end

local server = game:GetService("ServerScriptService"):FindFirstChild("Server")
expectClass(server, "Script", "ServerScriptService.Server")
for _, name in {
	"MapBuilder",
	"Profile",
	"PlayerProfiles",
	"QuestLogic",
	"QuestService",
	"ShopService",
	"CharacterService",
	"Targets",
	"Projectiles",
	"EnemyLogic",
	"EnemyModels",
	"EnemyService",
	"WardenBehavior",
	"CombatService",
} do
	expectClass(server and server:FindFirstChild(name), "ModuleScript", "Server." .. name)
end

local playerScripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
expectClass(playerScripts, "StarterPlayerScripts", "StarterPlayerScripts")
local client = playerScripts and playerScripts:FindFirstChild("Client")
expectClass(client, "LocalScript", "StarterPlayerScripts.Client")
local packages = server and server:FindFirstChild("Packages")
expectClass(packages, "Folder", "Server.Packages")
expectClass(packages and packages:FindFirstChild("ProfileStore"), "ModuleScript", "Packages.ProfileStore")
for _, name in { "UiKit", "Attrs", "Audio", "Effects", "World", "Hud", "Controls", "Menus", "Waypoint" } do
	expectClass(client and client:FindFirstChild(name), "ModuleScript", "Client." .. name)
end

check(game:GetService("Workspace").StreamingEnabled == false, "Workspace.StreamingEnabled should be false (small map, simpler client code)")
check(game:GetService("Lighting"):FindFirstChildOfClass("Atmosphere") ~= nil, "Lighting has an Atmosphere")

print(`place check: compiled {compiled} files, {failures} failures`)
if failures > 0 then
	error("place check failed")
end
