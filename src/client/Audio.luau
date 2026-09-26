-- Plays sounds by gameplay key. Keys with an empty id in Shared.Sounds are silently skipped.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Sounds = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Sounds"))

local Audio = {}

local enabled = true
local cache: { [string]: Sound } = {}
local music: Sound? = nil

local function soundFor(key: string): Sound?
	local entry = Sounds[key]
	if not entry or entry.id == "" then
		return nil
	end
	local sound = cache[key]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Sfx_" .. key
		sound.SoundId = entry.id
		sound.Volume = entry.volume
		sound.Parent = SoundService
		cache[key] = sound
	end
	return sound
end

function Audio.play(key: string)
	if not enabled then
		return
	end
	local sound = soundFor(key)
	if sound then
		SoundService:PlayLocalSound(sound)
	end
end

function Audio.isEnabled(): boolean
	return enabled
end

function Audio.setEnabled(value: boolean)
	enabled = value
	if music then
		music.Playing = value
	end
end

function Audio.start()
	local entry = Sounds.music
	if entry and entry.id ~= "" then
		local sound = Instance.new("Sound")
		sound.Name = "Music"
		sound.SoundId = entry.id
		sound.Volume = entry.volume
		sound.Looped = true
		sound.Parent = SoundService
		sound:Play()
		music = sound
	end
end

return Audio
