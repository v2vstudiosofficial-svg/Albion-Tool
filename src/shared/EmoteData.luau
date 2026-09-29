-- Village emotes. All are free and open from the start. An emote shows a speech bubble over the
-- player's head for everyone within `range` studs; `action` adds a small move on the server
-- ("jump" hops, "sit" sits down). No animation assets are used.
return {
	cooldown = 1.5,
	duration = 3,
	range = 90,

	order = { "wave", "dance", "cheer", "sit", "bow", "laugh" },
	emotes = {
		wave = { nameKey = "emote_wave", bubbleKey = "emote_wave_bubble" },
		dance = { nameKey = "emote_dance", bubbleKey = "emote_dance_bubble", action = "jump" },
		cheer = { nameKey = "emote_cheer", bubbleKey = "emote_cheer_bubble", action = "jump" },
		sit = { nameKey = "emote_sit", bubbleKey = "emote_sit_bubble", action = "sit" },
		bow = { nameKey = "emote_bow", bubbleKey = "emote_bow_bubble" },
		laugh = { nameKey = "emote_laugh", bubbleKey = "emote_laugh_bubble" },
	},
}
