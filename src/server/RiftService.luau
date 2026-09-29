-- Shadow Rifts: wave events. While players are in a creature zone, a rift sometimes opens there
-- and sends waves of the zone's creatures (temporary enemies). Clearing every wave in time gives
-- each helper a chest (coins when the chest slots are full); running out of time closes the
-- rift and the rest of its creatures fade away. Rules live in RiftLogic and Balance.rifts.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local WorldData = require(Shared.WorldData)
local ChestData = require(Shared.ChestData)
local Progression = require(Shared.Progression)
local RiftLogic = require(script.Parent.RiftLogic)
local ChestLogic = require(script.Parent.ChestLogic)
local EnemyService = require(script.Parent.EnemyService)
local PlayerProfiles = require(script.Parent.PlayerProfiles)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local notice = Remotes.Notice :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

type Rift = {
	area: string,
	center: Vector3,
	wave: number,
	enemies: { [number]: boolean },
	helpers: { [Player]: boolean },
	endsAt: number,
	nextWaveAt: number?,
}

local rifts: { [string]: Rift } = {}
local cooldownUntil: { [string]: number } = {}
local random = Random.new()

local RiftService = {}

local function playersIn(areaId: string, margin: number): { Player }
	local area = WorldData.areas[areaId]
	local center = WorldData.vector(area.center)
	local list = {}
	for _, target in Targets.get() do
		local offset = target.root.Position - center
		if Vector3.new(offset.X, 0, offset.Z).Magnitude <= area.radius + margin then
			table.insert(list, target.player)
		end
	end
	return list
end

local function spawnWave(rift: Rift)
	local area = WorldData.areas[rift.area]
	local kinds = RiftLogic.kindsFor(rift.area)
	local count = RiftLogic.waveSize(rift.wave, #playersIn(rift.area, 20))
	for index = 1, count do
		local angle = index / count * math.pi * 2 + random:NextNumber() * 0.4
		local position = rift.center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * Balance.rifts.ringRadius
		local kind = kinds[random:NextInteger(1, #kinds)]
		local level = random:NextInteger(area.levels[1], area.levels[2])
		local id = EnemyService.spawnTemporary(kind, level, position, rift.area, "rift:" .. rift.area)
		rift.enemies[id] = true
	end
	fx:FireAllClients("riftWave", rift.area, rift.center, rift.wave, Balance.rifts.waves)
end

local function close(rift: Rift, success: boolean)
	rifts[rift.area] = nil
	cooldownUntil[rift.area] = os.clock() + Balance.rifts.cooldown
	for id in rift.enemies do
		EnemyService.despawn(id)
	end
	fx:FireAllClients("riftClosed", rift.area, rift.center, success)
	if not success then
		for _, player in playersIn(rift.area, 40) do
			notice:FireClient(player, "notice_rift_failed")
		end
		return
	end
	for player in rift.helpers do
		local profile = PlayerProfiles.get(player)
		if profile and player.Parent == Players then
			local chestType = Balance.rifts.chest
			if ChestLogic.give(profile, chestType, Progression.levelForXp(profile.xp)) then
				notice:FireClient(player, "notice_rift_done", ChestData.chests[chestType].nameKey)
			else
				local coins = RiftLogic.fallbackCoins(rift.area)
				profile.coins += coins
				notice:FireClient(player, "notice_rift_done_coins", coins)
			end
			PlayerProfiles.sync(player)
		end
	end
end

-- Opens a rift in a creature zone (also used by tests and the Studio helper). Returns true
-- when it opened.
function RiftService.open(areaId: string): boolean
	local area = WorldData.areas[areaId]
	if not area or not area.levels or rifts[areaId] then
		return false
	end
	local angle = random:NextNumber() * math.pi * 2
	local distance = random:NextNumber() * area.radius * 0.4
	local rift: Rift = {
		area = areaId,
		center = WorldData.vector(area.center) + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance,
		wave = 1,
		enemies = {},
		helpers = {},
		endsAt = os.clock() + Balance.rifts.timeLimit,
	}
	rifts[areaId] = rift
	fx:FireAllClients("riftOpened", areaId, rift.center)
	for _, player in playersIn(areaId, 40) do
		notice:FireClient(player, "notice_rift_open")
	end
	spawnWave(rift)
	return true
end

function RiftService.active(areaId: string): boolean
	return rifts[areaId] ~= nil
end

local function onPurified(_kind, _reward, participants, _position, enemy)
	local tag = enemy and enemy.tag
	local areaId = type(tag) == "string" and string.match(tag, "^rift:(.+)$")
	local rift = areaId and rifts[areaId]
	if not rift or not rift.enemies[enemy.id] then
		return
	end
	rift.enemies[enemy.id] = nil
	for _, player in participants do
		rift.helpers[player] = true
	end
end

local function update()
	local now = os.clock()
	for _, rift in rifts do
		if now >= rift.endsAt then
			close(rift, false)
		elseif next(rift.enemies) == nil then
			if rift.wave >= Balance.rifts.waves then
				close(rift, true)
			elseif not rift.nextWaveAt then
				rift.nextWaveAt = now + Balance.rifts.waveDelay
			elseif now >= rift.nextWaveAt then
				rift.wave += 1
				rift.nextWaveAt = nil
				spawnWave(rift)
			end
		end
	end
end

local function maybeOpen()
	local now = os.clock()
	for _, areaId in RiftLogic.zones() do
		if not rifts[areaId] and now >= (cooldownUntil[areaId] or 0) and #playersIn(areaId, 0) > 0 then
			if random:NextNumber() < Balance.rifts.chance then
				RiftService.open(areaId)
			end
		end
	end
end

function RiftService.start()
	EnemyService.connectPurified(onPurified)
	task.spawn(function()
		local sinceCheck = 0
		while true do
			sinceCheck += task.wait(1)
			update()
			if sinceCheck >= Balance.rifts.checkInterval then
				sinceCheck = 0
				maybeOpen()
			end
		end
	end)
	-- Studio-only helper: set the Workspace attribute LvDebugRift to a zone id (e.g. "glade").
	if RunService:IsStudio() then
		workspace:GetAttributeChangedSignal("LvDebugRift"):Connect(function()
			local areaId = workspace:GetAttribute("LvDebugRift")
			if typeof(areaId) == "string" then
				RiftService.open(areaId)
			end
		end)
	end
end

return RiftService
