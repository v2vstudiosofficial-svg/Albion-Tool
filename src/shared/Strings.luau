-- Every player-facing text in the game (English).
local texts = {
	npc_elder_name = "Elder Nora",
	npc_smith_name = "Smith Bram",
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
	elder_offer_first_upgrade = "Go to Smith Bram and power up your staff.",
	elder_offer_ruin_vines = "Vines have blocked the ruins gate. Clear them with Light Wave!",
	elder_offer_warden = "The Shadow Warden is in the ruins. Purify it and the valley will shine again!",
	elder_welcome = "Welcome, little Light Keeper! Come over, I have a quest for you.",
	elder_quest_active = "Your quest is still going. Follow the glowing marker!",
	elder_need_level = "You need to grow a bit stronger. Come back at Level %d!",
	elder_all_done = "Our valley is shining bright! You are a true Light Keeper.",
	smith_greet = "Shall we power up your staff? Bring your coins!",

	quest_first_purify_title = "First Purify",
	quest_first_purify_objective = "Purify Gloomlings: %d/%d",
	quest_lantern_flowers_title = "Lantern Flowers",
	quest_lantern_flowers_objective = "Pick Lantern Flowers: %d/%d",
	quest_forest_explore_title = "Forest Explorer",
	quest_forest_explore_objective = "Discover mystery spots: %d/%d",
	quest_first_upgrade_title = "Power Up",
	quest_first_upgrade_objective = "Upgrade your staff at Smith Bram: %d/%d",
	quest_ruin_vines_title = "Road to the Ruins",
	quest_ruin_vines_objective = "Clear the vines with Light Wave: %d/%d",
	quest_warden_title = "Shadow Warden",
	quest_warden_objective = "Purify the Shadow Warden: %d/%d",
	quest_talk_to_elder = "Talk to Elder Nora",
	quest_need_level = "Purify creatures to reach Level %d, then return to Elder Nora",
	goal_title = "Story complete! Next goal",
	goal_level = "Reach Level %d (now %d)",
	goal_staff_ready = "Upgrade your staff to level %d at Smith Bram",
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
	notice_can_upgrade = "You have enough coins! Upgrade your staff at Smith Bram.",
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
}

local Strings = {}
Strings.texts = texts

function Strings.has(key: string): boolean
	return texts[key] ~= nil
end

function Strings.get(key: string, ...: any): string
	local text = texts[key]
	if text == nil then
		return key
	end
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

return Strings
