local tables = {
	tr = {
		npc_elder_name = "Bilge Nur",
		npc_talk_action = "Konuş",
		enemy_gloomling_name = "Gölgecik",

		elder_quest_first_purify = "Fenerler söndü! Ormandaki Gölgeciği ışık asanla arındır.",
		elder_quest_active = "Gölgecik ormanda. Patikayı takip et!",
		elder_all_done = "Harika iş! Yakında yeni görevler olacak.",

		quest_first_purify_objective = "Gölgeciği arındır: %d/%d",
		quest_talk_to_elder = "Bilge Nur ile konuş",
		quest_all_done = "Görevler tamam! Yakında daha fazlası",

		hud_coins = "Sikke: %d",
		hud_xp = "XP: %d",
		reward_purify = "Arındırıldı! +%d XP  +%d Sikke",
		reward_quest = "Görev tamamlandı! +%d XP  +%d Sikke",
		attack_button = "Işık",
	},
}

local Strings = {}
Strings.language = "tr"
Strings.tables = tables

function Strings.get(key: string, ...: any): string
	local text = tables[Strings.language][key]
	if text == nil then
		return key
	end
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

return Strings
