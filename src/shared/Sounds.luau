-- Sound ids by gameplay event. Empty strings are silent. The ids are Creator Store sounds from
-- ProSoundEffects (Roblox's licensed library, free in any experience) and Roblox's own uploads.
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
	music = { id = "", volume = 0.25 },
}
