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
}

local Strings = {}
Strings.language = "tr"
Strings.tables = tables

function Strings.has(key: string): boolean
	return tables[Strings.language][key] ~= nil
end

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
