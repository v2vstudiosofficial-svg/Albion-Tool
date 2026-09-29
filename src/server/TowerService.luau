-- Shadow Tower: one shared arena run at a time. Players step through the village gate, fight
-- floor after floor of creatures together, and leave through the pad (or when defeated).
-- Rules and numbers live in TowerLogic / Balance.tower; this file runs the arena.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
local ChestData = require(Shared.ChestData)
local Progression = require(Shared.Progression)
local TowerLogic = require(script.Parent.TowerLogic)
local ChestLogic = require(script.Parent.ChestLogic)
local EnemyService = require(script.Parent.EnemyService)
local PassService = require(script.Parent.PassService)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

type Run = {
	anchor: number,
	floor: number,
	enemies: { [number]: boolean },
	-- Players who hit something on this floor (they share its reward).
	helpers: { [Player]: boolean },
	inside: { [Player]: boolean },
	-- os.clock() when the next floor starts; nil while creatures remain.
	nextFloorAt: number?,
}

local run: Run? = nil
local random = Random.new()
local center: Vector3
local gateBody: BasePart
local exitPad: BasePart

local TowerService = {}

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Moves the whole character (PivotTo keeps every part together).
local function moveTo(target: Targets.Target, position: Vector3)
	local character = target.root.Parent :: Model
	character:PivotTo(CFrame.new(position))
end

local function playersInside(current: Run): { Player }
	local list = {}
	for player in current.inside do
		table.insert(list, player)
	end
	return list
end

local function setFloorAttribute(player: Player, floor: number)
	player:SetAttribute("TowerFloor", floor)
end

local function spawnFloor(current: Run)
	local count = TowerLogic.count(current.floor, #playersInside(current))
	local elites = TowerLogic.eliteCount(current.floor)
	local level, extra = TowerLogic.floorLevel(current.anchor, current.floor)
	local hp, damage = TowerLogic.scale(extra)
	local kinds = TowerLogic.kindsFor(level)
	local scale = if extra > 0 then { hp = hp, damage = damage } else nil
	for index = 1, count do
		local angle = index / count * math.pi * 2 + random:NextNumber() * 0.4
		local position = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Balance.tower.ringRadius
		local kind = kinds[random:NextInteger(1, #kinds)]
		local id = EnemyService.spawnTemporary(kind, level, position, "tower", "tower", index <= elites, scale)
		current.enemies[id] = true
	end
	current.helpers = {}
	current.nextFloorAt = nil
	for player in current.inside do
		setFloorAttribute(player, current.floor)
		fx:FireClient(player, "towerFloor", current.floor, count)
	end
end

local function close(current: Run)
	run = nil
	for id in current.enemies do
		EnemyService.despawn(id)
	end
	for player in current.inside do
		setFloorAttribute(player, 0)
	end
end

local function removePlayer(player: Player, current: Run, message: boolean)
	current.inside[player] = nil
	current.helpers[player] = nil
	if player.Parent == Players then
		setFloorAttribute(player, 0)
		local profile = PlayerProfiles.get(player)
		if message and profile then
			notice:FireClient(player, "notice_tower_ended", profile.towerBest)
		end
	end
end

-- Pays a cleared floor to the players who fought on it.
local function payFloor(current: Run)
	local floor = current.floor
	for player in current.helpers do
		local profile = PlayerProfiles.get(player)
		if profile and current.inside[player] then
			local level = Progression.levelForXp(profile.xp)
			local coins = TowerLogic.floorCoins(level, floor)
			local isRecord = TowerLogic.record(profile, floor)
			if isRecord then
				coins += TowerLogic.recordCoins(level)
			end
			profile.coins += coins
			PassService.award(player, "tower")
			local chestType = TowerLogic.chestFor(floor)
			if chestType and ChestLogic.give(profile, chestType, level) then
				notice:FireClient(player, "notice_tower_chest", ChestData.chests[chestType].nameKey)
			elseif chestType then
				local extraCoins = TowerLogic.recordCoins(level)
				profile.coins += extraCoins
				coins += extraCoins
			end
			PlayerProfiles.sync(player)
			notice:FireClient(player, if isRecord then "notice_tower_record" else "notice_tower_floor", floor, coins)
			fx:FireClient(player, "towerCleared", floor)
		end
	end
end

local function update()
	local current = run
	if not current then
		return
	end
	-- Anyone defeated, gone or outside the arena leaves the run.
	local limit = WorldData.areas.tower.radius + Balance.tower.leaveMargin
	for player in current.inside do
		local target = Targets.of(player)
		if player.Parent ~= Players or not target or flat(target.root.Position - center).Magnitude > limit then
			removePlayer(player, current, true)
		end
	end
	if next(current.inside) == nil then
		close(current)
		return
	end
	local now = os.clock()
	if next(current.enemies) == nil then
		if not current.nextFloorAt then
			payFloor(current)
			current.floor += 1
			current.nextFloorAt = now + Balance.tower.floorDelay
		elseif now >= current.nextFloorAt then
			spawnFloor(current)
		end
	end
end

local function onPurified(_kind, _reward, participants, _position, enemy)
	local current = run
	if not current or not enemy or enemy.tag ~= "tower" or not current.enemies[enemy.id] then
		return
	end
	current.enemies[enemy.id] = nil
	for _, player in participants do
		current.helpers[player] = true
	end
end

local function nearGate(player: Player): boolean
	local target = Targets.of(player)
	return target ~= nil and (target.root.Position - gateBody.Position).Magnitude <= Balance.shopDistance
end

-- Returns true when the player entered the tower.
function TowerService.enter(player: Player): boolean
	local profile = PlayerProfiles.get(player)
	local target = Targets.of(player)
	if not profile or not target or (run and run.inside[player]) then
		return false
	end
	local level = Progression.levelForXp(profile.xp)
	local ok, reason = TowerLogic.canEnter(level, if run then run.anchor else nil)
	if not ok then
		if reason == "level" then
			notice:FireClient(player, "notice_tower_level", Balance.tower.minLevel)
		else
			notice:FireClient(player, "notice_tower_low")
		end
		return false
	end
	local current = run
	if not current then
		current = {
			anchor = level,
			floor = 1,
			enemies = {},
			helpers = {},
			inside = {},
			nextFloorAt = os.clock() + Balance.tower.startDelay,
		}
		run = current
	end
	current = current :: Run
	current.inside[player] = true
	moveTo(target, center + Vector3.new(0, 4, 14))
	setFloorAttribute(player, current.floor)
	return true
end

function TowerService.leave(player: Player)
	local current = run
	if current and current.inside[player] then
		local target = Targets.of(player)
		if target then
			moveTo(target, WorldData.vector(WorldData.spawn))
		end
		removePlayer(player, current, true)
	end
end

function TowerService.active(): boolean
	return run ~= nil
end

function TowerService.start(map: Folder)
	center = WorldData.vector(WorldData.areas.tower.center)
	gateBody = map.Village.TowerGate.Body :: BasePart
	exitPad = map.Tower.ExitPad :: BasePart
	local gatePrompt = gateBody.TalkPrompt :: ProximityPrompt
	gatePrompt.Triggered:Connect(function(player)
		if nearGate(player) then
			TowerService.enter(player)
		end
	end)
	local leavePrompt = exitPad.LeavePrompt :: ProximityPrompt
	leavePrompt.Triggered:Connect(function(player)
		local target = Targets.of(player)
		if target and (target.root.Position - exitPad.Position).Magnitude <= Balance.shopDistance then
			TowerService.leave(player)
		end
	end)
	EnemyService.connectPurified(onPurified)
	task.spawn(function()
		while true do
			task.wait(1)
			update()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		local current = run
		if current then
			removePlayer(player, current, false)
		end
	end)
end

return TowerService
