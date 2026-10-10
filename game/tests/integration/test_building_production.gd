extends RefCounted
## TestBuildingProduction — integrasi ekonomi + bangunan + produksi dengan
## sistem nyata dan data nyata (QA_PLAN.md §3 phase 2).
## Semua ekspektasi dihitung dari res://data (bukan angka karang).


func run(t) -> void:
	TestUtil.reset_all()
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	t.check("bp.systems_present", bs != null and ps != null)
	if bs == null or ps == null:
		return

	# --- Penempatan HQ (gratis) ---
	var hq := bs.place_building(&"command_core", Vector3(0, 0, 0))
	t.check("bp.hq_placed", hq != null)
	var hq_def := GameData.get_building_def(&"command_core")
	t.check_eq("bp.hq_hp_from_data", hq_def.max_hp, hq.hp)

	# --- State awal dari data ---
	var cfg := GameData.economy_config
	var start_e := int(cfg.starting_resources.get("energy", 0))
	var start_m := int(cfg.starting_resources.get("minerals", 0))
	t.check_eq("bp.start_energy", start_e, Economy.get_amount(&"energy"))

	# --- Konstruksi energy_reactor ---
	var def := GameData.get_building_def(&"energy_reactor")
	var pos := bs.next_free_position(def.footprint)
	t.check("bp.enqueue_construction", ps.enqueue_construction(&"energy_reactor", pos))
	t.check_eq("bp.cost_deducted_energy", start_e - int(def.base_cost.get("energy", 0)), Economy.get_amount(&"energy"))
	t.check_eq("bp.cost_deducted_minerals", start_m - int(def.base_cost.get("minerals", 0)), Economy.get_amount(&"minerals"))

	TimeSystem.advance_ticks(def.build_time_ticks - 1)
	t.check_eq("bp.not_built_yet", 0, bs.count_of(&"energy_reactor"))
	TimeSystem.advance_ticks(1)
	t.check_eq("bp.reactor_built", 1, bs.count_of(&"energy_reactor"))

	# Storage bonus dari data diterapkan saat placement
	t.check_eq("bp.storage_bonus_applied",
		int(cfg.storage_caps.get("energy", 0)) + int(def.storage_bonus.get("energy", 0)),
		Economy.get_cap(&"energy"))

	# --- Produksi pasif level 1: ekspektasi dihitung dari data ---
	var ticks := 600  ## 60 detik game
	var e_before := Economy.get_amount(&"energy")
	TimeSystem.advance_ticks(ticks)
	var expected := int(def.get_production_for_level(1)) * ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	t.check_eq("bp.production_matches_data", e_before + expected, Economy.get_amount(&"energy"))

	# --- Upgrade level 2: biaya dari data (base * growth^1) ---
	var reactor := bs.get_buildings_of(&"energy_reactor")[0]
	var cost_l2 := def.get_cost_for_level(2)
	var e_mid := Economy.get_amount(&"energy")
	var m_mid := Economy.get_amount(&"minerals")
	t.check("bp.upgrade_ok", bs.try_upgrade(reactor.instance_id))
	t.check_eq("bp.upgrade_cost_energy", e_mid - int(cost_l2.get("energy", 0)), Economy.get_amount(&"energy"))
	t.check_eq("bp.upgrade_cost_minerals", m_mid - int(cost_l2.get("minerals", 0)), Economy.get_amount(&"minerals"))
	t.check_eq("bp.upgrade_level", 2, reactor.level)
	t.check_eq("bp.upgrade_max_hp", def.get_max_hp_for_level(2), reactor.hp)

	# Produksi level 2 = 2x rate data
	var e2_before := Economy.get_amount(&"energy")
	TimeSystem.advance_ticks(ticks)
	var expected2 := int(def.get_production_for_level(2)) * ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	t.check_eq("bp.production_level2_matches_data", e2_before + expected2, Economy.get_amount(&"energy"))

	# --- Damage: 150 dari 300 hp → ratio 0.5 → DAMAGED ---
	bs.apply_damage_to(reactor.instance_id, 150)
	t.check_eq("bp.damage_applied", def.get_max_hp_for_level(2) - 150, reactor.hp)
	t.check_eq("bp.state_damaged", "DAMAGED", Building.State.keys()[reactor.state])

	# --- Repair: biaya = repair_cost_per_hp × jumlah (dari data) ---
	Economy.earn(&"minerals", 500)  ## cukup untuk biaya repair
	var m_before := Economy.get_amount(&"minerals")
	var repair_cost := int(def.repair_cost_per_hp.get("minerals", 0)) * 150
	t.check("bp.repair_enqueued", ps.enqueue_repair(reactor.instance_id, 150))
	t.check_eq("bp.repair_cost", m_before - repair_cost, Economy.get_amount(&"minerals"))
	TimeSystem.advance_ticks(60)
	t.check_eq("bp.repaired", def.get_max_hp_for_level(2), reactor.hp)
	t.check_eq("bp.state_normal_after_repair", "NORMAL", Building.State.keys()[reactor.state])

	# --- Upgrade tanpa dana → gagal, tidak ada perubahan ---
	Economy.set_state({"balances": {"energy": 0, "minerals": 0}, "caps": {"energy": 1200, "minerals": 700}})
	t.check("bp.upgrade_no_funds_fails", not bs.try_upgrade(reactor.instance_id))
	t.check_eq("bp.upgrade_failed_level_unchanged", 2, reactor.level)

	# --- Bangunan hancur bisa diperbaiki (repair = rebuild wreck) ---
	bs.apply_damage_to(reactor.instance_id, 99999)
	t.check("bp.destroyed", reactor.is_destroyed())
	Economy.earn(&"minerals", 100)
	t.check("bp.repair_destroyed_enqueued", ps.enqueue_repair(reactor.instance_id, 10))
	TimeSystem.advance_ticks(60)
	t.check_eq("bp.destroyed_revived_hp", 10, reactor.hp)
	t.check("bp.revived_not_destroyed", not reactor.is_destroyed())

	# --- Save state round-trip BuildingSystem ---
	var state := bs.get_state()
	bs.set_state(state)
	t.check_eq("bp.state_roundtrip_count", 2, bs.get_all_buildings().size())
