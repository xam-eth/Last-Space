extends RefCounted
## TestEconomy — unit test ekonomi berdasarkan data nyata (bukan angka karang).


func run(t) -> void:
	Economy.reset()
	var cfg := GameData.economy_config
	var start_e := int(cfg.starting_resources.get("energy", 0))
	var start_m := int(cfg.starting_resources.get("minerals", 0))

	t.check_eq("economy.starting_energy", start_e, Economy.get_amount(&"energy"))
	t.check_eq("economy.starting_minerals", start_m, Economy.get_amount(&"minerals"))
	t.check_eq("economy.starting_cap_energy", int(cfg.storage_caps.get("energy", 0)), Economy.get_cap(&"energy"))

	# earn bertambah sesuai nominal
	var added := Economy.earn(&"energy", 50)
	t.check_eq("economy.earn_added", 50, added)
	t.check_eq("economy.earn_balance", start_e + 50, Economy.get_amount(&"energy"))

	# storage cap ditegakkan
	var cap := Economy.get_cap(&"energy")
	var added2 := Economy.earn(&"energy", cap * 2)
	t.check_eq("economy.cap_enforced", cap - (start_e + 50), added2)
	t.check_eq("economy.balance_at_cap", cap, Economy.get_amount(&"energy"))

	# spend: cukup → terpotong; tidak cukup → gagal total tanpa perubahan
	Economy.reset()
	t.check("economy.can_afford", Economy.can_afford({"energy": start_e}))
	t.check("economy.cannot_afford", not Economy.can_afford({"energy": start_e + 1}))
	t.check("economy.spend_ok", Economy.spend({"energy": 10, "minerals": 5}))
	t.check_eq("economy.spend_balance_energy", start_e - 10, Economy.get_amount(&"energy"))
	t.check_eq("economy.spend_balance_minerals", start_m - 5, Economy.get_amount(&"minerals"))
	t.check("economy.spend_fail_no_funds", not Economy.spend({"energy": 999999}))
	t.check_eq("economy.failed_spend_unchanged_energy", start_e - 10, Economy.get_amount(&"energy"))
	t.check_eq("economy.failed_spend_unchanged_minerals", start_m - 5, Economy.get_amount(&"minerals"))

	# add_cap dari storage_bonus bangunan
	var cap_before := Economy.get_cap(&"energy")
	Economy.add_cap(&"energy", 200)
	t.check_eq("economy.add_cap", cap_before + 200, Economy.get_cap(&"energy"))

	# state round-trip (dipakai save/load)
	var state := Economy.get_state()
	Economy.reset()
	Economy.set_state(state)
	t.check_eq("economy.state_roundtrip_energy", start_e - 10, Economy.get_amount(&"energy"))
