-- Emotes: validates the request (known emote, cooldown, alive) and shows it to nearby players.
-- The optional small move (hop, sit) happens here; the speech bubble is drawn by each client.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EmoteData = require(Shared.EmoteData)
local EmoteLogic = require(script.Parent.EmoteLogic)
local Targets = require(script.Parent.Targets)

local Remotes = ReplicatedStorage.Remotes
local playEmote = Remotes.PlayEmote :: RemoteEvent
local fx = Remotes.Fx :: RemoteEvent

local lastEmote: { [Player]: number } = {}

local EmoteService = {}

local function onEmote(player: Player, id: unknown)
	if not EmoteLogic.valid(id) then
		return
	end
	local now = os.clock()
	if not EmoteLogic.ready(lastEmote[player], now) then
		return
	end
	local target = Targets.of(player)
	if not target then
		return
	end
	lastEmote[player] = now
	local origin = target.root.Position
	local entries = {}
	for _, other in Targets.get() do
		table.insert(entries, { player = other.player, position = { x = other.root.Position.X, z = other.root.Position.Z } })
	end
	for _, entry in EmoteLogic.audience({ x = origin.X, z = origin.Z }, entries) do
		fx:FireClient(entry.player, "emote", player, id)
	end
	local action = EmoteData.emotes[id :: string].action
	local humanoid = target.humanoid
	if action == "jump" then
		humanoid.Jump = true
	elseif action == "sit" then
		humanoid.Sit = true
	end
end

function EmoteService.start()
	playEmote.OnServerEvent:Connect(onEmote)
	Players.PlayerRemoving:Connect(function(player)
		lastEmote[player] = nil
	end)
end

return EmoteService
