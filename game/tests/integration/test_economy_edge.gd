extends RefCounted
## TestEconomyEdge — integrasi cross-system: edge cases ekonomi (ROADMAP M2:
## insufficient resources, caps, interrupted production, repair costs).
## Ekspektasi dihitung dari res://data (bukan angka karang).
## (reward-once sudah dicover test_progression — tidak diduplikasi.)


func run(t) -> void:
	TestUtil.reset_all()
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	t.check("ee.systems_present", bs != null and ps != null)
	if bs == null or ps == null:
		return
	var cfg := GameData.economy_config
	var cap_e := int(cfg.storage_caps.get("energy", 0))
	var cap_m := int(cfg.storage_caps.get("minerals", 0))

	# --- CAPS: earn terbuang saat storage penuh (ekspektasi dari data) ---
	Economy.set_state({"balances": {"energy": cap_e - 10, "minerals": cap_m - 10}, "caps": {"energy": cap_e, "minerals": cap_m}})
	var added := Economy.earn(&"energy", 50)
	t.check_eq("ee.earn_clamped_to_cap", 10, added)
	t.check_eq("ee.balance_at_cap", cap_e, Economy.get_amount(&"energy"))
	var added2 := Economy.earn(&"energy", 50)
	t.check_eq("ee.earn_zero_when_full", 0, added2)

	# --- INTERRUPTED PRODUCTION: progress antrian tidak hilang saat round-trip ---
	var def := GameData.get_building_def(&"energy_reactor")
	var pos := bs.next_free_position(def.footprint)
	t.check("ee.enqueue_construction", ps.enqueue_construction(&"energy_reactor", pos))
	TimeSystem.advance_ticks(40)
	t.check_eq("ee.queue_progress_40", 40, int(ps.queues[0]["progress_ticks"]))
	var saved := ps.get_state()
	ps.set_state(saved)
	t.check_eq("ee.queue_progress_survives", 40, int(ps.queues[0]["progress_ticks"]))
	t.check_eq("ee.not_built_before_complete", 0, bs.count_of(&"energy_reactor"))
	TimeSystem.advance_ticks(def.build_time_ticks - 40)
	t.check_eq("ee.built_after_full_time", 1, bs.count_of(&"energy_reactor"))

	# --- PRODUCTION WASTED saat storage penuh (tercatat penuh, tidak double-earn) ---
	var reactor := bs.get_buildings_of(&"energy_reactor")[0]
	Economy.set_state({"balances": {"energy": cap_e, "minerals": 0}, "caps": {"energy": cap_e, "minerals": cap_m}})
	reactor.reset_production_counters()
	var ticks := 600  ## 60 detik game
	TimeSystem.advance_ticks(ticks)
	var expected := int(def.get_production_for_level(1)) * ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	t.check_eq("ee.storage_full_no_earn", cap_e, Economy.get_amount(&"energy"))
	t.check_eq("ee.prod_earned_matches_data", expected, reactor.prod_earned)

	# --- INSUFFICIENT RESOURCES: konstruksi gagal atomik (tidak ada partial spend) ---
	Economy.set_state({"balances": {"energy": 10, "minerals": 0}, "caps": {"energy": cap_e, "minerals": cap_m}})
	var ext_def := GameData.get_building_def(&"mineral_extractor")
	t.check("ee.construction_no_funds_fails",
		not ps.enqueue_construction(&"mineral_extractor", bs.next_free_position(ext_def.footprint)))
	t.check_eq("ee.no_partial_spend_energy", 10, Economy.get_amount(&"energy"))
	t.check_eq("ee.queue_empty_after_fail", 0, ps.queue_count())

	# --- REPAIR: dana tidak cukup → gagal atomik, tidak ada perubahan ---
	bs.apply_damage_to(reactor.instance_id, 50)  ## rusak 50 hp
	t.check("ee.repair_no_funds_fails", not ps.enqueue_repair(reactor.instance_id, 50))
	t.check_eq("ee.repair_failed_hp_unchanged", def.get_max_hp_for_level(1) - 50, reactor.hp)
	t.check_eq("ee.repair_failed_queue_empty", 0, ps.queue_count())

	# --- REPAIR COST: amount dipotong ke missing (cost = per_hp × actual, dari data) ---
	Economy.earn(&"minerals", 500)
	var m_before := Economy.get_amount(&"minerals")
	var missing := reactor.get_max_hp() - reactor.hp  ## 50
	var per_hp := maxi(1, int(def.repair_cost_per_hp.get("minerals", 0)))
	t.check("ee.repair_clamped_to_missing", ps.enqueue_repair(reactor.instance_id, 150))  ## minta 150, actual=50
	t.check_eq("ee.repair_cost_actual", m_before - per_hp * missing, Economy.get_amount(&"minerals"))
	TimeSystem.advance_ticks(60)
	t.check_eq("ee.repaired_to_full", reactor.get_max_hp(), reactor.hp)
