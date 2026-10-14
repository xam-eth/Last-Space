extends Node
## E2E Playthrough — SATU rantai gameplay lengkap, diverifikasi berbasis data:
## build → produce → fleet → defend (wave 1) → territory + reward →
## wave 2 damages base → repair + upgrade → save/load round-trip.
## Semua ekspektasi dihitung dari res://data (bukan asumsi, bukan "asal jalan").

var passed := 0
var failed := 0


func _ready() -> void:
	await get_tree().process_frame  ## tunggu base_scene siap (HQ ditempatkan)
	_run()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func check_eq(name: String, expected, actual) -> void:
	check(name, expected == actual, "expected=%s actual=%s" % [expected, actual])


func _run() -> void:
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	check("e2e.systems_present", bs != null and ps != null and fs != null and wd != null and pr != null)
	if bs == null or ps == null or fs == null or wd == null or pr == null:
		_finish()
		return

	# --- Tahap 0: state awal dari data ---
	var cfg := GameData.economy_config
	var start_e := int(cfg.starting_resources.get("energy", 0))
	var start_m := int(cfg.starting_resources.get("minerals", 0))
	## M3 #9: basis awal = RENCANA TATA LETAK (9 bangunan) sehingga saldo awal
	## sama dengan starting_resources DITAMBAH bonus penyimpanan bangunan yang
	## sudah berdiri. Yang diuji: saldo ≥ start (dari data) & inti ada.
	check("e2e.start_energy", Economy.get_amount(&"energy") >= start_e,
		"energy=%d (start data=%d)" % [Economy.get_amount(&"energy"), start_e])
	check("e2e.start_minerals", Economy.get_amount(&"minerals") >= start_m,
		"minerals=%d (start data=%d)" % [Economy.get_amount(&"minerals"), start_m])
	check("e2e.hq_placed", bs.count_of(&"command_core") == 1)
	check("e2e.layout_plan_awal", bs.get_all_buildings().size() >= 9,
		"bangunan awal=%d (rencana tata letak M3 #9)" % bs.get_all_buildings().size())
	QaMarkers.marker("LOOP", "START", {"energy": start_e, "minerals": start_m})

	# --- Tahap 1: bangun fasilitas ekonomi ---
	var reactor_def := GameData.get_building_def(&"energy_reactor")
	var extractor_def := GameData.get_building_def(&"mineral_extractor")
	## DELTA dari keadaan nyata (basis awal sudah punya 1 reaktor & 1 tambang).
	var reactor0 := bs.count_of(&"energy_reactor")
	var extractor0 := bs.count_of(&"mineral_extractor")
	check("e2e.build_reactor", ps.enqueue_construction(&"energy_reactor", bs.next_free_position(reactor_def.footprint)))
	check("e2e.build_extractor", ps.enqueue_construction(&"mineral_extractor", bs.next_free_position(extractor_def.footprint)))
	TimeSystem.advance_ticks(maxi(reactor_def.build_time_ticks, extractor_def.build_time_ticks) + 5)
	check_eq("e2e.reactor_built", reactor0 + 1, bs.count_of(&"energy_reactor"))
	check_eq("e2e.extractor_built", extractor0 + 1, bs.count_of(&"mineral_extractor"))

	# --- Tahap 2: produksi berjalan (ekspektasi dihitung dari data) ---
	var gather_ticks := 3600  ## 6 menit game
	var e1 := Economy.get_amount(&"energy")
	var m1 := Economy.get_amount(&"minerals")
	TimeSystem.advance_ticks(gather_ticks)
	## Laju dari DATA × JUMLAH bangunan yang benar-benar berdiri (bukan 1 diasumsikan).
	var n_reactor := bs.count_of(&"energy_reactor")
	var n_extractor := bs.count_of(&"mineral_extractor")
	var exp_e := e1 + int(reactor_def.get_production_for_level(1)) * n_reactor * gather_ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	var exp_m := m1 + int(extractor_def.get_production_for_level(1)) * n_extractor * gather_ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	check_eq("e2e.energy_produced_from_data", mini(exp_e, Economy.get_cap(&"energy")), Economy.get_amount(&"energy"))
	check_eq("e2e.minerals_produced_from_data", mini(exp_m, Economy.get_cap(&"minerals")), Economy.get_amount(&"minerals"))
	QaMarkers.marker("LOOP", "PRODUCED", {"energy": Economy.get_amount(&"energy"), "minerals": Economy.get_amount(&"minerals")})

	# --- Tahap 3: hangar + turret + 4 interceptor ---
	var hangar_def := GameData.get_building_def(&"fighter_hangar")
	var turret_def := GameData.get_building_def(&"laser_turret")
	var hangar0 := bs.count_of(&"fighter_hangar")
	var turret0 := bs.count_of(&"laser_turret")
	check("e2e.build_hangar", ps.enqueue_construction(&"fighter_hangar", bs.next_free_position(hangar_def.footprint)))
	check("e2e.build_turret", ps.enqueue_construction(&"laser_turret", bs.next_free_position(turret_def.footprint)))
	TimeSystem.advance_ticks(maxi(hangar_def.build_time_ticks, turret_def.build_time_ticks) + 5)
	check_eq("e2e.hangar_built", hangar0 + 1, bs.count_of(&"fighter_hangar"))
	check_eq("e2e.turret_built", turret0 + 1, bs.count_of(&"laser_turret"))

	var ship_def := GameData.get_ship_def(&"shp_001_interceptor")
	var n_ships := 4
	for i in n_ships:
		check("e2e.build_ship_%d" % i, ps.enqueue_ship(&"shp_001_interceptor"))
	TimeSystem.advance_ticks(ship_def.build_time_ticks * n_ships + 10)
	check_eq("e2e.fleet_ready", n_ships, fs.alive_count())
	QaMarkers.marker("LOOP", "FLEET", {"ships": fs.alive_count()})

	# --- Tahap 4: wave 1 — defense berhasil, territory + reward ---
	var e_before_wave := Economy.get_amount(&"energy")
	var prod_earned_before := _sum_prod_earned(bs, &"energy")
	var quest_e_before := _quest_reward_total(&"energy")  ## M3 #1: quest reward
	wd.schedule_wave(&"wave_1")
	TimeSystem.advance_ticks(200)
	var r1: BattleResult = wd.last_result
	check("e2e.wave1_ran", r1 != null)
	if r1 != null:
		check_eq("e2e.wave1_defender_wins", "defender", r1.winner)
	TimeSystem.pause()
	await EventBus.combat_visual_done
	TimeSystem.resume()
	check("e2e.territory_unlocked", pr.is_territory_unlocked(&"sector_2"))
	# Reward dihitung eksak: delta energi = produksi aktual (prod_earned) +
	# reward data sektor + reward quest yang terpenuhi saat wave (M3 #1)
	var sector2 := GameData.get_sector_def(&"sector_2")
	var prod_delta := _sum_prod_earned(bs, &"energy") - prod_earned_before
	var quest_delta := _quest_reward_total(&"energy") - quest_e_before
	check_eq("e2e.sector_reward_from_data",
		e_before_wave + prod_delta + quest_delta + int(sector2.rewards.get("energy", 0)),
		Economy.get_amount(&"energy"))
	QaMarkers.marker("LOOP", "DEFENDED", {"wave": "wave_1", "winner": r1.winner if r1 else "none"})

	# --- Tahap 5: wave 2 (lebih besar) — base menerima damage ---
	wd.schedule_wave(&"wave_2")
	TimeSystem.advance_ticks(200)
	var r2: BattleResult = wd.last_result
	check("e2e.wave2_ran", r2 != null)
	if r2 != null:
		check("e2e.wave2_base_damaged_or_losses", r2.building_damage.size() > 0 or _total(r2.defender_ship_losses) > 0)
	TimeSystem.pause()
	await EventBus.combat_visual_done
	TimeSystem.resume()
	QaMarkers.marker("LOOP", "DAMAGED", {"building_damage": r2.building_damage.size() if r2 != null else -1})

	# --- Tahap 6: repair bangunan rusak/hancur (10 HP — cukup untuk demo,
	# dana tetap cukup untuk upgrade berikutnya) + upgrade reactor ---
	## M3 #9: dengan 4 turret mengelilingi inti (rencana tata letak), wave 2 bisa
	## berakhir tanpa kerusakan bangunan (marker QA:LOOP:DAMAGED building_damage=0).
	## Supaya jalur REPAIR tetap teruji, kerusakan diterapkan lewat API sistem
	## yang sama dengan pertempuran (`apply_damage_to`) — bukan angka yang dipalsukan.
	var damaged_by_wave := 0
	for b in bs.get_all_buildings():
		if b.hp < b.get_max_hp():
			damaged_by_wave += 1
	if damaged_by_wave == 0:
		var first: Building = bs.get_all_buildings()[0]
		var dmg := maxi(1, int(first.get_max_hp() * 0.35))
		bs.apply_damage_to(first.instance_id, dmg)
		print("QA:LOOP:REPAIR_SETUP damage=%d on=%s (wave2 tidak merusak apa pun)" % [
			dmg, first.instance_id])
	var repair_done := false
	for b in bs.get_all_buildings():
		if b.hp >= b.get_max_hp():
			continue
		var missing := b.get_max_hp() - b.hp
		var cost_per := maxi(1, int(b.def.repair_cost_per_hp.get("minerals", 0)))
		## M3 #9: basis awal lebih besar → saldo mineral setelah seluruh rantai
		## pembangunan lebih tipis. Turunkan jumlah HP sampai BENAR-BENAR
		## terjangkau (minimal 1) — yang diuji adalah API repair pada bangunan
		## rusak NYATA, bukan angka 10 yang dipaksakan.
		var repair_hp := mini(missing, 10)
		while repair_hp > 1 and Economy.get_amount(&"minerals") < repair_hp * cost_per:
			repair_hp -= 1
		if Economy.get_amount(&"minerals") < repair_hp * cost_per:
			continue
		var hp_before := b.hp
		check("e2e.repair_enqueued", ps.enqueue_repair(b.instance_id, repair_hp))
		TimeSystem.advance_ticks(80)
		check_eq("e2e.repair_applied", hp_before + repair_hp, b.hp)
		repair_done = true
		break
	if not repair_done:
		check("e2e.repair_enqueued", false, "tidak ada bangunan rusak yang terjangkau untuk diperbaiki")
	var reactor := bs.get_buildings_of(&"energy_reactor")[0]
	check("e2e.upgrade_reactor", bs.try_upgrade(reactor.instance_id))
	check_eq("e2e.reactor_level_2", 2, reactor.level)
	QaMarkers.marker("LOOP", "REPAIRED_UPGRADED", {"reactor_level": reactor.level})

	# --- Tahap 7: save → reset → load → state sama persis ---
	var eco_before := Economy.get_state()
	var buildings_before := bs.get_state()
	var fleet_before := fs.get_state()
	var prog_before := pr.get_state()
	check("e2e.save_ok", SaveSystem.save_game("e2e_slot"))
	TestUtil.reset_all()
	check("e2e.state_cleared", bs.get_all_buildings().size() == 0)
	check("e2e.load_ok", SaveSystem.load_game("e2e_slot"))
	check_eq("e2e.economy_roundtrip", JSON.stringify(eco_before), JSON.stringify(Economy.get_state()))
	check_eq("e2e.buildings_roundtrip", JSON.stringify(buildings_before), JSON.stringify(bs.get_state()))
	check_eq("e2e.fleet_roundtrip", JSON.stringify(fleet_before), JSON.stringify(fs.get_state()))
	check_eq("e2e.progression_roundtrip", JSON.stringify(prog_before), JSON.stringify(pr.get_state()))

	QaMarkers.marker("LOOP", "COMPLETE", {"cycles": 1})
	_finish()


func _total(d: Dictionary) -> int:
	var n := 0
	for k in d.keys():
		n += int(d[k])
	return n


func _quest_reward_total(res_id: StringName) -> int:
	## Total reward quest yang sudah terpenuhi (dari definisi quest aktual).
	var qt := SystemRefs.quest_tracker()
	if qt == null:
		return 0
	var total := 0
	for q in qt.get_all():
		var d: Dictionary = q
		if d["done"]:
			total += int(d["reward"].get(res_id, 0))
	return total


func _sum_prod_earned(bs: BuildingSystem, resource: StringName) -> int:
	# Jumlah prod_earned HANYA untuk bangunan yang memproduksi resource tsb
	# (extractor menghitung mineral, bukan energy).
	var n := 0
	for b in bs.get_all_buildings():
		if b.def.produces == resource:
			n += b.prod_earned
	return n


func _finish() -> void:
	print("TESTS:DONE passed=%d failed=%d skipped=0" % [passed, failed])
	QaMarkers.marker("TESTS", "DONE", {"passed": passed, "failed": failed, "skipped": 0})
