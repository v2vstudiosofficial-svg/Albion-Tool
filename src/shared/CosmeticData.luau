-- Costumes: purely visual, never stronger. One per slot (hat, back, aura). `source` says how to
-- get it: coins (Forge-free shop), pass (Light Pass tier/track), robux (StoreData product) or
-- rebirth (given at that many rebirths, see server/RebirthLogic).
return {
	slots = { "hat", "back", "aura" },
	order = {
		"lantern_hat", "leaf_crown", "frost_hood", "star_crown",
		"explorer_cape", "petal_wings", "shadow_cloak", "crystal_wings",
		"sparkle_aura", "ember_aura", "golden_aura", "rainbow_aura",
		"dawn_aura", "phoenix_wings",
	},
	costumes = {
		lantern_hat = { nameKey = "costume_lantern_hat", slot = "hat", color = { 255, 210, 110 }, source = { coins = 2000 } },
		leaf_crown = { nameKey = "costume_leaf_crown", slot = "hat", color = { 120, 200, 110 }, source = { pass = 5, track = "free" } },
		frost_hood = { nameKey = "costume_frost_hood", slot = "hat", color = { 190, 230, 255 }, source = { coins = 25000 } },
		star_crown = { nameKey = "costume_star_crown", slot = "hat", color = { 255, 225, 90 }, source = { pass = 30, track = "premium" } },
		explorer_cape = { nameKey = "costume_explorer_cape", slot = "back", color = { 200, 90, 70 }, source = { coins = 5000 } },
		petal_wings = { nameKey = "costume_petal_wings", slot = "back", color = { 255, 160, 200 }, source = { pass = 15, track = "premium" } },
		shadow_cloak = { nameKey = "costume_shadow_cloak", slot = "back", color = { 80, 50, 120 }, source = { pass = 45, track = "premium" } },
		crystal_wings = { nameKey = "costume_crystal_wings", slot = "back", color = { 150, 220, 255 }, source = { robux = "crystal_wings" } },
		sparkle_aura = { nameKey = "costume_sparkle_aura", slot = "aura", color = { 255, 245, 200 }, source = { pass = 20, track = "free" } },
		ember_aura = { nameKey = "costume_ember_aura", slot = "aura", color = { 255, 140, 70 }, source = { coins = 100000 } },
		golden_aura = { nameKey = "costume_golden_aura", slot = "aura", color = { 255, 205, 70 }, source = { robux = "golden_aura" } },
		rainbow_aura = { nameKey = "costume_rainbow_aura", slot = "aura", color = { 200, 150, 255 }, source = { pass = 50, track = "premium" } },
		dawn_aura = { nameKey = "costume_dawn_aura", slot = "aura", color = { 255, 190, 150 }, source = { rebirth = 1 } },
		phoenix_wings = { nameKey = "costume_phoenix_wings", slot = "back", color = { 255, 130, 60 }, source = { rebirth = 3 } },
	},
}
