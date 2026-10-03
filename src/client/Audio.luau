-- Plays sounds by gameplay key. Keys with an empty id in Shared.Sounds are silently skipped.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Sounds = require(Shared:WaitForChild("Sounds"))
local MusicLogic = require(Shared:WaitForChild("MusicLogic"))

local player = Players.LocalPlayer

local Audio = {}

local enabled = true
-- Volume sliders from Settings (0-1): `master` scales everything, `sfx` the sound effects.
local masterVolume, sfxVolume, musicVolume = 1, 1, 1
local cache: { [string]: Sound } = {}

-- Music: one track per place (MusicLogic). When the place changes, the old track fades out
-- completely before the new one fades in, so two tracks never play together.
local MUSIC_FADE = 1.5 -- seconds for each fade
local MUSIC_SETTLE = 1 -- a new place must hold this long before the music changes (no flicker at edges)
local tracks: { [string]: Sound } = {}
local music: Sound? = nil -- the track playing or fading
local musicTheme: string? = nil
local wantedTheme: string? = nil
local wantedFor = 0
local fade = 0 -- 0..1, how loud `music` is right now

-- Looped backgrounds (the marsh rain): client/Ambience sets how loud (0-1) and the sound eases
-- there, so leaving the marsh fades the rain out instead of cutting it.
local AMBIENT_FADE = 1.5 -- seconds from silent to full
local ambient: { [string]: { sound: Sound, level: number, target: number } } = {}

-- Pitch (with its random `vary`) and, for long files, the part of the file that plays.
local function shape(sound: Sound, entry)
	sound.PlaybackSpeed = (entry.pitch or 1) * (1 + (math.random() * 2 - 1) * (entry.vary or 0))
	sound.PlaybackRegionsEnabled = entry.length ~= nil
	if entry.length then
		sound.PlaybackRegion = NumberRange.new(0, entry.length)
	end
end

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

-- `pitch` (PlaybackSpeed) replaces the entry's own for this play.
function Audio.play(key: string, pitch: number?)
	if not enabled then
		return
	end
	local sound = soundFor(key)
	if sound then
		sound.Volume = Sounds[key].volume * masterVolume * sfxVolume
		shape(sound, Sounds[key])
		if pitch then
			sound.PlaybackSpeed = pitch
		end
		SoundService:PlayLocalSound(sound)
	end
end

-- Plays `key` from `emitter` (a part in the world), so it is louder near it and fades with distance.
-- The caller removes `emitter` (and so the sound) after a few seconds.
function Audio.playAt(key: string, emitter: Instance)
	local entry = Sounds[key]
	if not enabled or not entry or entry.id == "" then
		return
	end
	local sound = Instance.new("Sound")
	sound.Name = "Sfx_" .. key
	sound.SoundId = entry.id
	sound.Volume = entry.volume * masterVolume * sfxVolume
	shape(sound, entry)
	sound.RollOffMaxDistance = 90
	sound.Parent = emitter
	sound:Play()
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

function Audio.setVolumes(master: number, sfx: number, musicShare: number)
	masterVolume, sfxVolume, musicVolume = math.clamp(master, 0, 1), math.clamp(sfx, 0, 1), math.clamp(musicShare, 0, 1)
end

local function track(theme: string?): Sound?
	local id = theme and Sounds.music.tracks[theme]
	if not id then
		return nil
	end
	local sound = tracks[theme]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "Music_" .. theme
		sound.SoundId = id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		tracks[theme] = sound
	end
	return sound
end

local function stepMusic(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local theme = MusicLogic.theme(root.Position.X, root.Position.Z)
		if theme ~= wantedTheme then
			wantedTheme, wantedFor = theme, 0
		else
			wantedFor += dt
		end
	end
	local target = if wantedFor >= MUSIC_SETTLE then wantedTheme else musicTheme
	if target ~= musicTheme then
		fade = math.max(fade - dt / MUSIC_FADE, 0)
		if fade == 0 or not music then
			if music then
				music:Stop()
			end
			musicTheme, music, fade = target, track(target), 0
			if music then
				music.Volume = 0
				music.Playing = enabled
			end
		end
	else
		fade = math.min(fade + dt / MUSIC_FADE, 1)
	end
	if music then
		music.Volume = Sounds.music.volume * masterVolume * musicVolume * fade
	end
end

function Audio.setAmbient(key: string, target: number)
	local entry = ambient[key]
	if not entry then
		if target <= 0 then
			return
		end
		local sound = Instance.new("Sound")
		sound.Name = "Ambient_" .. key
		sound.SoundId = Sounds[key].id
		sound.Looped = true
		sound.Volume = 0
		sound.Parent = SoundService
		entry = { sound = sound, level = 0, target = 0 }
		ambient[key] = entry
	end
	entry.target = math.clamp(target, 0, 1)
end

local function stepAmbient(dt: number)
	for key, entry in ambient do
		local step = dt / AMBIENT_FADE
		entry.level = if entry.target > entry.level then math.min(entry.target, entry.level + step) else math.max(entry.target, entry.level - step)
		entry.sound.Volume = Sounds[key].volume * masterVolume * sfxVolume * entry.level
		local audible = enabled and entry.level > 0
		if entry.sound.Playing ~= audible then
			entry.sound.Playing = audible
		end
	end
end

function Audio.start()
	RunService.Heartbeat:Connect(function(dt)
		stepMusic(dt)
		stepAmbient(dt)
	end)
end

return Audio
