-- Sound ids by gameplay event. Empty strings are silent. The ids are Creator Store sounds from
-- ProSoundEffects and APM (Roblox's licensed libraries, free in any experience) and Roblox's own uploads.
-- `pitch` (PlaybackSpeed, default 1) lets one file serve several events; `length` plays only the
-- first that many seconds of a long file.
return {
	attack = { id = "rbxassetid://9120742729", volume = 0.35 }, -- Whoosh Thick Quick
	hit = { id = "rbxassetid://9113487341", volume = 0.4 }, -- Body Hit
	purify = { id = "rbxassetid://9116394545", volume = 0.5 }, -- Magic Glows Chiming Hits
	pickup = { id = "rbxassetid://9113849492", volume = 0.45 }, -- Coins Or Keys Jingle
	wave = { id = "rbxassetid://9125647212", volume = 0.5 }, -- Magic Whooshes Metallic Shimmering
	levelUp = { id = "rbxassetid://9116395089", volume = 0.6 }, -- Magic Glows Chiming Hits 4
	questComplete = { id = "rbxassetid://15675043410", volume = 0.6 }, -- Roblox UI Tonal Stinger
	slamWarn = { id = "rbxassetid://9113980480", volume = 0.5 }, -- Giant Crab Monster Growl
	slam = { id = "rbxassetid://9114221264", volume = 0.6, length = 2 }, -- Earthquake Debris
	-- Creature attacks, played where the creature is.
	creatureCharge = { id = "rbxassetid://9114084427", volume = 0.5 }, -- Dirt Digging With Pick
	creatureDash = { id = "rbxassetid://9126229255", volume = 0.5 }, -- Whoosh By Fast
	creatureShoot = { id = "rbxassetid://9113537815", volume = 0.45 }, -- Boink Wet Suction Pop
	creatureBlink = { id = "rbxassetid://9125648149", volume = 0.45 }, -- Magic Zoom Up
	creatureLand = { id = "rbxassetid://9118598279", volume = 0.5 }, -- Rock Hit Dirt Impact
	bossCharge = { id = "rbxassetid://9113973128", volume = 0.6 }, -- Creature Growls Lion
	ui = { id = "rbxassetid://15675059323", volume = 0.4 }, -- Roblox UI Bright Click
	uiClose = { id = "rbxassetid://15675059323", volume = 0.3, pitch = 0.8 }, -- the same click, lower and softer
	voice = { id = "rbxassetid://15675055424", volume = 0.22 }, -- Roblox UI Cute Pop (story captions, pitched per speaker)
	-- Looped backgrounds (Audio.setAmbient).
	rain = { id = "rbxassetid://9112854469", volume = 0.35 }, -- Rain On Water 1 (61 s loop)
	wind = { id = "rbxassetid://9114057128", volume = 0.4 }, -- Desert Wind Whistley Light Gusts 2 (92 s)
	thunder = { id = "rbxassetid://9120016488", volume = 0.55 }, -- Thunder Distant Boom Thud Rapid Hits 6
	heartbeat = { id = "rbxassetid://9043365727", volume = 0.35 }, -- HEARTBEAT 01 96BPM (APM, 60 s loop)
	birds = { id = "rbxassetid://9116970949", volume = 0.22 }, -- Morning Forest Birds 6 (75 s)
	crickets = { id = "rbxassetid://9112765304", volume = 0.18 }, -- Crickets Night 1 (56 s loop)
	frogs = { id = "rbxassetid://9125615469", volume = 0.3 }, -- Kenyan Frogs CU Deep Throaty Croaking (54 s)
	-- Music by place (MusicLogic.theme), APM tracks, looped; one plays at a time.
	music = {
		volume = 0.25,
		tracks = {
			village = "rbxassetid://1847410594", -- Peaceful Valley Scene A
			wilds = "rbxassetid://1837134419", -- The Magical Forest
			marsh = "rbxassetid://9048681794", -- Mysterious Forest
			peaks = "rbxassetid://9043599529", -- Frozen Forest (c)
			citadel = "rbxassetid://1839814486", -- Dark Castle
			boss = "rbxassetid://1837222909", -- Heroic Battle
			tower = "rbxassetid://81858348740186", -- Ancient Curse (underscore)
		},
	},
}
