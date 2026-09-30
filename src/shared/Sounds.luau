-- Sound ids by gameplay event. Empty strings are intentionally silent until a real,
-- license-checked sound id (e.g. "rbxassetid://123") from the Creator Store is filled in.
-- The rbxasset:// entries are files that ship with the Roblox client (content/sounds). `pitch`
-- (PlaybackSpeed, default 1) lets one file serve several events; `length` plays only the first
-- that many seconds of a long file.
return {
	attack = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.35, pitch = 2.2, length = 0.6 },
	hit = { id = "", volume = 0.4 },
	purify = { id = "rbxasset://sounds/impact_water.mp3", volume = 0.45, pitch = 1.8 },
	pickup = { id = "rbxasset://sounds/volume_slider.ogg", volume = 0.5, pitch = 1.4 },
	wave = { id = "", volume = 0.6 },
	levelUp = { id = "", volume = 0.7 },
	questComplete = { id = "", volume = 0.7 },
	slamWarn = { id = "", volume = 0.5 },
	slam = { id = "rbxasset://sounds/impact_explosion_03.mp3", volume = 0.5, pitch = 0.8 },
	-- Creature attacks, played where the creature is.
	creatureCharge = { id = "rbxasset://sounds/action_footsteps_plastic.mp3", volume = 0.55, pitch = 0.7, length = 0.8 },
	creatureDash = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.5, pitch = 0.6 },
	creatureShoot = { id = "rbxasset://sounds/action_jump.mp3", volume = 0.4, pitch = 1.7 },
	creatureBlink = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.45, pitch = 1.4, length = 1 },
	creatureLand = { id = "rbxasset://sounds/action_jump_land.mp3", volume = 0.5, pitch = 0.8 },
	bossCharge = { id = "rbxasset://sounds/action_swim.mp3", volume = 0.6, pitch = 0.5, length = 1.2 },
	ui = { id = "", volume = 0.4 },
	music = { id = "", volume = 0.25 },
}
