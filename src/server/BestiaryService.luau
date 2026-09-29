-- Creature Codex: counts every purified creature for the players who helped and tells them when a
-- milestone paid coins. Rules live in BestiaryLogic; the caller syncs the profile afterwards.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Balance = require(Shared.Balance)
local Format = require(Shared.Format)
local Progression = require(Shared.Progression)
local BestiaryLogic = require(script.Parent.BestiaryLogic)
local PlayerProfiles = require(script.Parent.PlayerProfiles)

local notice = ReplicatedStorage.Remotes.Notice :: RemoteEvent

local BestiaryService = {}

function BestiaryService.onPurified(player: Player, kind: string)
	local profile = PlayerProfiles.get(player)
	if not profile then
		return
	end
	local reached = BestiaryLogic.record(profile, kind, Progression.levelForXp(profile.xp))
	if reached then
		notice:FireClient(player, "notice_codex_tier", Balance.enemies[kind].nameKey, Format.short(reached.goal), Format.short(reached.coins))
	end
end

return BestiaryService
