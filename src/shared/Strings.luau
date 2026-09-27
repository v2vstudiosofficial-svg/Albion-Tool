local tables = {
	tr = {
		npc_elder_name = "Bilge Nur",
		npc_demir_name = "Usta Demir",
		npc_talk_action = "Konuş",
		npc_shop_action = "Asa Tezgâhı",

		enemy_gloomling_name = "Gölgecik",
		enemy_sporeling_name = "Sporcuk",
		enemy_rockling_name = "Taşçık",
		enemy_warden_name = "Gölge Bekçisi",

		landmark_old_oak = "Yaşlı Meşe",
		landmark_glow_pond = "Işıltılı Gölet",
		landmark_star_rock = "Yıldız Kayası",
		flower_name = "Fener Çiçeği",
		flower_action = "Topla",

		charm_swift_name = "Rüzgâr Tılsımı",
		charm_swift_desc = "Daha hızlı koşarsın.",
		charm_guard_name = "Kabuk Tılsımı",
		charm_guard_desc = "Daha az hasar alırsın.",
		charm_glow_name = "Parıltı Tılsımı",
		charm_glow_desc = "Işık Dalgası daha sık ve daha geniş.",

		elder_offer_first_purify = "Fenerler söndü! Ormandaki 3 Gölgeciği ışık asanla arındır.",
		elder_offer_lantern_flowers = "Ormanda parlayan 5 Fener Çiçeği var. Topla da köy renklensin!",
		elder_offer_forest_explore = "Ormanın üç gizemli yerini keşfet. Parlayan işaretleri izle!",
		elder_offer_first_upgrade = "Usta Demir'e git ve asanı güçlendir.",
		elder_offer_ruin_vines = "Harabe kapısını sarmaşıklar kapatmış. Işık Dalgası ile temizle!",
		elder_offer_warden = "Gölge Bekçisi harabelerde. Onu arındır, vadi yeniden parlasın!",
		elder_welcome = "Hoş geldin, küçük Işık Koruyucusu! Yanıma gel, sana bir görevim var.",
		elder_quest_active = "Görevin devam ediyor. Parlayan işareti takip et!",
		elder_need_level = "Biraz daha güçlenmelisin. Seviye %d olunca gel!",
		elder_all_done = "Vadimiz ışıl ışıl! Sen gerçek bir Işık Koruyucususun.",
		demir_greet = "Asanı güçlendirelim mi? Sikkelerini getir!",

		quest_first_purify_title = "İlk Arındırma",
		quest_first_purify_objective = "Gölgecik arındır: %d/%d",
		quest_lantern_flowers_title = "Fener Çiçekleri",
		quest_lantern_flowers_objective = "Fener Çiçeği topla: %d/%d",
		quest_forest_explore_title = "Orman Keşfi",
		quest_forest_explore_objective = "Gizemli yerleri keşfet: %d/%d",
		quest_first_upgrade_title = "Asanı Güçlendir",
		quest_first_upgrade_objective = "Usta Demir'de asanı güçlendir: %d/%d",
		quest_ruin_vines_title = "Harabelere Hazırlık",
		quest_ruin_vines_objective = "Sarmaşıkları Işık Dalgası ile temizle: %d/%d",
		quest_warden_title = "Gölge Bekçisi",
		quest_warden_objective = "Gölge Bekçisi'ni arındır: %d/%d",
		quest_talk_to_elder = "Bilge Nur ile konuş",
		quest_need_level = "Yaratıkları arındırıp Seviye %d ol, sonra Bilge Nur'a dön",
		goal_title = "Hikâye tamam! Sıradaki hedef",
		goal_level = "Seviye %d ol (şimdi %d)",
		goal_staff_ready = "Usta Demir'de asanı %d. seviyeye yükselt",
		goal_staff_coins = "Asa seviyesi %d için %d sikke daha topla",
		goal_all = "Tüm hedefler tamam! Sen gerçek bir Işık Koruyucususun",

		hud_level = "Sv %d",
		hud_coins = "%d",
		hud_xp = "%d / %d XP",
		hud_xp_max = "EN YÜKSEK SEVİYE",
		reward_purify = "Dost oldu! +%d XP  +%d Sikke",
		reward_quest = "Görev tamamlandı! +%d XP  +%d Sikke",
		notice_level_up = "Seviye %d! Canın doldu.",
		notice_wave_unlocked = "Işık Dalgası açıldı!",
		notice_charm_gained = "Yeni tılsım: %s! Çantandan takabilirsin.",
		notice_flower = "Fener Çiçeği toplandı!",
		notice_discovered = "Keşfedildi: %s",
		notice_vine = "Sarmaşık temizlendi!",
		notice_restore_gardens = "Köyde çiçekler açtı!",
		notice_restore_lanterns = "Köyün fenerleri yandı!",
		notice_restore_festival = "Büyük Fener yandı! Köyde şenlik var!",
		notice_upgrade_done = "Asan güçlendi! Asa seviyesi %d",
		notice_upgrade_no_coins = "%d sikke daha gerekli",
		notice_upgrade_max = "Asan zaten en güçlü hâlinde!",
		notice_can_upgrade = "Sikken yetiyor! Usta Demir'de asanı güçlendir.",
		notice_boss_reset = "Gölge Bekçisi dinlenip toparlandı.",
		friend_popup = "Dost oldu!",
		banner_quest_complete = "Görev tamamlandı!",
		banner_boss = "Gölge Bekçisi uyandı!",
		banner_boss_sub = "Kırmızı halkalardan kaç, kürelerin boşluğundan geç!",
		banner_boss_down = "Gölge Bekçisi arındı!",
		banner_boss_down_sub = "Harabeler yeniden ışıl ışıl!",
		notice_respawn = "Köyde yeniden doğdun. Hiçbir şey kaybetmedin!",

		attack_button = "IŞIK",
		wave_button = "DALGA",
		wave_locked = "Sv %d",
		hint_attack_pc = "Sol tık / F: Işık at",
		hint_attack_touch = "IŞIK tuşuna dokun",
		hint_wave_pc = "Q: Işık Dalgası",

		menu_bag = "Çanta",
		menu_settings = "Ayarlar",
		close = "Kapat",
		shop_title = "Asa Tezgâhı",
		shop_tier = "Asa seviyesi: %d / %d",
		shop_damage = "Güç: %d  →  %d",
		shop_cost = "Bedel: %d Sikke",
		shop_upgrade = "Güçlendir",
		shop_max = "Asan en güçlü hâlinde!",
		bag_title = "Çanta",
		bag_staff = "Işık Asası: seviye %d  (güç %d)",
		bag_equip = "Tak",
		bag_unequip = "Çıkar",
		bag_locked = "Görevle kazanılır",
		settings_title = "Ayarlar",
		settings_sound = "Ses: %s",
		settings_fps = "Performans göstergesi: %s",
		setting_on = "Açık",
		setting_off = "Kapalı",
		perf_line = "FPS %d  ·  Ping %d ms",

		data_loading = "Kaydın yükleniyor...",
		data_failed_title = "Kayıt şu an yüklenemedi",
		data_failed_body = "İlerlemen güvende, hiçbir şey silinmedi. Birazdan tekrar dene.",
		data_retry = "Tekrar Dene",
		data_session_ended = "Kaydın başka bir sunucuda açıldı. Lütfen yeniden katıl.",
	},
	en = {
		npc_elder_name = "Elder Nur",
		npc_demir_name = "Master Demir",
		npc_talk_action = "Talk",
		npc_shop_action = "Staff Bench",

		enemy_gloomling_name = "Gloomling",
		enemy_sporeling_name = "Sporeling",
		enemy_rockling_name = "Rockling",
		enemy_warden_name = "Shadow Warden",

		landmark_old_oak = "Old Oak",
		landmark_glow_pond = "Glow Pond",
		landmark_star_rock = "Star Rock",
		flower_name = "Lantern Flower",
		flower_action = "Pick",

		charm_swift_name = "Wind Charm",
		charm_swift_desc = "You run faster.",
		charm_guard_name = "Shell Charm",
		charm_guard_desc = "You take less damage.",
		charm_glow_name = "Sparkle Charm",
		charm_glow_desc = "Light Wave is faster and wider.",

		elder_offer_first_purify = "The lanterns went dark! Purify 3 Gloomlings in the forest with your light staff.",
		elder_offer_lantern_flowers = "There are 5 glowing Lantern Flowers in the forest. Pick them to bring color to the village!",
		elder_offer_forest_explore = "Discover the forest's three mystery spots. Follow the glowing markers!",
		elder_offer_first_upgrade = "Go to Master Demir and power up your staff.",
		elder_offer_ruin_vines = "Vines have blocked the ruins gate. Clear them with Light Wave!",
		elder_offer_warden = "The Shadow Warden is in the ruins. Purify it and the valley will shine again!",
		elder_welcome = "Welcome, little Light Keeper! Come over, I have a quest for you.",
		elder_quest_active = "Your quest is still going. Follow the glowing marker!",
		elder_need_level = "You need to grow a bit stronger. Come back at Level %d!",
		elder_all_done = "Our valley is shining bright! You are a true Light Keeper.",
		demir_greet = "Shall we power up your staff? Bring your coins!",

		quest_first_purify_title = "First Purify",
		quest_first_purify_objective = "Purify Gloomlings: %d/%d",
		quest_lantern_flowers_title = "Lantern Flowers",
		quest_lantern_flowers_objective = "Pick Lantern Flowers: %d/%d",
		quest_forest_explore_title = "Forest Explorer",
		quest_forest_explore_objective = "Discover mystery spots: %d/%d",
		quest_first_upgrade_title = "Power Up",
		quest_first_upgrade_objective = "Upgrade your staff at Master Demir: %d/%d",
		quest_ruin_vines_title = "Road to the Ruins",
		quest_ruin_vines_objective = "Clear the vines with Light Wave: %d/%d",
		quest_warden_title = "Shadow Warden",
		quest_warden_objective = "Purify the Shadow Warden: %d/%d",
		quest_talk_to_elder = "Talk to Elder Nur",
		quest_need_level = "Purify creatures to reach Level %d, then return to Elder Nur",
		goal_title = "Story complete! Next goal",
		goal_level = "Reach Level %d (now %d)",
		goal_staff_ready = "Upgrade your staff to level %d at Master Demir",
		goal_staff_coins = "Staff level %d needs %d more coins",
		goal_all = "All goals done! You are a true Light Keeper",

		hud_level = "Lv %d",
		hud_coins = "%d",
		hud_xp = "%d / %d XP",
		hud_xp_max = "MAX LEVEL",
		reward_purify = "Friend made! +%d XP  +%d Coins",
		reward_quest = "Quest complete! +%d XP  +%d Coins",
		notice_level_up = "Level %d! Health refilled.",
		notice_wave_unlocked = "Light Wave unlocked!",
		notice_charm_gained = "New charm: %s! Equip it from your bag.",
		notice_flower = "Lantern Flower picked!",
		notice_discovered = "Discovered: %s",
		notice_vine = "Vine cleared!",
		notice_restore_gardens = "Flowers bloomed in the village!",
		notice_restore_lanterns = "The village lanterns are lit!",
		notice_restore_festival = "The Great Lantern is lit! Festival time!",
		notice_upgrade_done = "Your staff got stronger! Staff level %d",
		notice_upgrade_no_coins = "%d more coins needed",
		notice_upgrade_max = "Your staff is already at full power!",
		notice_can_upgrade = "You have enough coins! Upgrade your staff at Master Demir.",
		notice_boss_reset = "The Shadow Warden rested and recovered.",
		friend_popup = "Friend made!",
		banner_quest_complete = "Quest complete!",
		banner_boss = "The Shadow Warden woke up!",
		banner_boss_sub = "Dodge the red rings, slip through the gap in the orbs!",
		banner_boss_down = "Shadow Warden purified!",
		banner_boss_down_sub = "The ruins are shining again!",
		notice_respawn = "You respawned in the village. Nothing was lost!",

		attack_button = "LIGHT",
		wave_button = "WAVE",
		wave_locked = "Lv %d",
		hint_attack_pc = "Left click / F: Cast light",
		hint_attack_touch = "Tap the LIGHT button",
		hint_wave_pc = "Q: Light Wave",

		menu_bag = "Bag",
		menu_settings = "Settings",
		close = "Close",
		shop_title = "Staff Bench",
		shop_tier = "Staff level: %d / %d",
		shop_damage = "Power: %d  →  %d",
		shop_cost = "Cost: %d Coins",
		shop_upgrade = "Upgrade",
		shop_max = "Your staff is at full power!",
		bag_title = "Bag",
		bag_staff = "Light Staff: level %d  (power %d)",
		bag_equip = "Equip",
		bag_unequip = "Remove",
		bag_locked = "Earned from a quest",
		settings_title = "Settings",
		settings_sound = "Sound: %s",
		settings_fps = "Performance display: %s",
		setting_on = "On",
		setting_off = "Off",
		perf_line = "FPS %d  ·  Ping %d ms",

		data_loading = "Loading your save...",
		data_failed_title = "Your save could not load right now",
		data_failed_body = "Your progress is safe, nothing was deleted. Try again in a moment.",
		data_retry = "Try Again",
		data_session_ended = "Your save was opened on another server. Please rejoin.",
	},
}

local Strings = {}
Strings.fallback = "tr"
Strings.language = Strings.fallback
Strings.tables = tables

-- Roblox locale ids look like "tr-tr" or "en-us"; anything we don't translate gets English.
function Strings.languageFor(localeId: string?): string
	local code = string.lower(string.sub(localeId or "", 1, 2))
	if tables[code] then
		return code
	end
	return "en"
end

function Strings.setLanguage(language: string)
	if tables[language] then
		Strings.language = language
	end
end

local function lookup(language: string, key: string): string?
	local own = tables[language]
	return (own and own[key]) or tables[Strings.fallback][key]
end

function Strings.has(key: string): boolean
	return lookup(Strings.language, key) ~= nil
end

function Strings.getIn(language: string, key: string, ...: any): string
	local text = lookup(language, key)
	if text == nil then
		return key
	end
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

function Strings.get(key: string, ...: any): string
	return Strings.getIn(Strings.language, key, ...)
end

return Strings
