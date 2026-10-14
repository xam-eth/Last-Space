extends Node
## EconomySim — simulasi ekonomi HEADLESS ratusan hari game (DEV_PLAN M2 #2,
## ROADMAP M2: "headless economy simulation (hundreds of game-days) to check
## progression tempo; provisional values labeled").
##
## Tanpa interaksi pemain: strategi build order sederhana (semua angka dari
## res://data — bukan asumsi), wave dijadwalkan via API WaveDirector (auto-
## schedule dari sektor = out of scope M1/M2), waktu dimajukan deterministik
## via TimeSystem.advance_ticks dengan seed tetap → reproducible.
##
## 1 hari game = 600 ticks (60 detik × TimeSystem.TICKS_PER_SECOND = 10 tps).
##
## Yang diukur (data nyata, tersimpan di marker QA:SIM:METRICS):
## tempo progression (hari: kapal pertama, sektor_2 terbuka), hasil wave,
## bottleneck resource (gagal afford terbanyak), hari storage penuh,
## saldo minimum (tidak pernah negatif), waktu wall simulasi.
##
## PERHATIAN: semua nilai balance di data .tres berlabel PROVISIONAL — hasil
## tempo ini juga PROVISIONAL sampai balance di-tuning (RISK_ANALYSIS).

var passed := 0
var failed := 0

const TICKS_PER_DAY := 600  ## 60 detik × 10 tps
const SIM_DAYS := 200       ## ratusan hari game
const SIM_SEED := 4242      ## seed tetap → reproducible

var _day := 0
var _t0 := 0
var _first_ship_day := -1
var _sector2_day := -1
var _wave_results := {}     ## wave_id -> winner (String)
var _bottleneck := {}       ## resource_id -> jumlah gagal afford
## M3 #9: jumlah bangunan tiap tipe pada basis awal (rencana tata letak).
var _awal_reactor := 0
var _awal_extractor := 0
var _awal_hangar := 0
var _awal_turret := 0
var _awal_shield := 0
var _storage_full_days := 0
var _min_balance_e := 2147483647
var _min_balance_m := 2147483647
var _metrics_recorded := false
var _wave2_scheduled := false
var _wd: WaveDirector = null

## Build order (data-driven): ekonomi dulu, baru produksi kapal & defense.
var _build_order: Array[StringName] = [
	&"energy_reactor", &"mineral_extractor", &"energy_reactor", &"mineral_extractor",
	&"fighter_hangar", &"laser_turret", &"laser_turret", &"shield_generator",
	&"energy_reactor", &"laser_turret", &"laser_turret",
]
var _target_ships := 6
var _target_turrets := 4


func _ready() -> void:
	await get_tree().process_frame  ## tunggu base_scene siap (HQ ditempatkan)
	TimeSystem.pause()  ## waktu hanya maju via advance_ticks (deterministik)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.territory_unlocked.connect(_on_territory_unlocked)
	_run()


func check(name: String, condition: bool, detail: String = "") -> void:
	if condition:
		passed += 1
		print("TEST:PASS %s %s" % [name, detail])
	else:
		failed += 1
		print("TEST:FAIL %s %s" % [name, detail])


func _run() -> void:
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	_wd = SystemRefs.wave_director()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	if bs == null or ps == null or fs == null or _wd == null or pr == null:
		check("sim.systems_present", false)
		_finish()
		return
	check("sim.systems_present", true)
	## M3 #9: rekam jumlah bangunan AWAL (rencana tata letak) sebagai basis target.
	_awal_reactor = bs.count_of(&"energy_reactor")
	_awal_extractor = bs.count_of(&"mineral_extractor")
	_awal_hangar = bs.count_of(&"fighter_hangar")
	_awal_turret = bs.count_of(&"laser_turret")
	_awal_shield = bs.count_of(&"shield_generator")
	QaMarkers.marker("SIM", "START_BASE", {"reactor": _awal_reactor, "extractor": _awal_extractor,
		"hangar": _awal_hangar, "turret": _awal_turret, "shield": _awal_shield,
		"total": bs.get_all_buildings().size()})

	# Jadwalkan wave_1 via API (hari 12). WaveDirector hanya punya SATU slot
	# pending — wave_2 dijadwalkan setelah wave_1 selesai (lihat loop hari).
	_wd.schedule_wave(&"wave_1", 12 * TICKS_PER_DAY)

	_t0 = Time.get_ticks_msec()
	QaMarkers.marker("SIM", "START", {"days": SIM_DAYS, "seed": SIM_SEED, "ticks_per_day": TICKS_PER_DAY})
	for day in range(1, SIM_DAYS + 1):
		_day = day
		_strategy(bs, ps, fs)
		TimeSystem.advance_ticks(TICKS_PER_DAY)
		_observe()
		# Wave berikutnya dijadwalkan setelah wave sebelumnya selesai (idle).
		if not _wave2_scheduled and _wave_results.has("wave_1"):
			_wd.schedule_wave(&"wave_2", 5 * TICKS_PER_DAY)  ## +5 hari setelah wave_1
			_wave2_scheduled = true
		if _first_ship_day < 0 and fs.alive_count() > 0:
			_first_ship_day = day
		if _sector2_day < 0 and pr.is_territory_unlocked(&"sector_2"):
			_sector2_day = day
	_report(bs, fs, pr)
	_finish()


## Strategi per hari: produksi kapal (target 6) + satu konstruksi bangunan
## sesuai build order. Semua keputusan dari data (cost/def dari GameData).
func _strategy(bs: BuildingSystem, ps: ProductionSystem, fs: FleetSystem) -> void:
	# Kapal: jika hangar sudah ada & (alive + queued) < target → interceptor.
	if bs.count_of(&"fighter_hangar") > 0:
		var queued := 0
		for q in ps.queues:
			if int(q["kind"]) == ProductionSystem.QueueKind.SHIP:
				queued += 1
		if fs.alive_count() + queued < _target_ships:
			var ship_def := GameData.get_ship_def(&"shp_001_interceptor")
			if ship_def != null and not ps.enqueue_ship(&"shp_001_interceptor"):
				_note_bottleneck(ship_def.cost)
	# Bangunan: satu konstruksi per hari, pertama yang affordable di build order.
	for def_id in _build_order:
		if _enough(bs, def_id):
			continue
		var def := GameData.get_building_def(def_id)
		if def == null:
			continue
		if ps.enqueue_construction(def_id, bs.next_free_position(def.footprint)):
			return
		_note_bottleneck(def.base_cost)
		return


func _enough(bs: BuildingSystem, def_id: StringName) -> bool:
	## M3 #9: basis awal sudah berisi tiap tipe (rencana tata letak) → target
	## RELATIF terhadap jumlah awal supaya simulasi tetap membangun & bottleneck
	## ekonomi tetap terukur (bukan "selesai" di hari 0).
	match def_id:
		&"energy_reactor":
			return bs.count_of(def_id) >= _awal_reactor + 2
		&"mineral_extractor":
			return bs.count_of(def_id) >= _awal_extractor + 1
		&"fighter_hangar":
			return bs.count_of(def_id) >= _awal_hangar
		&"laser_turret":
			return bs.count_of(def_id) >= _awal_turret + _target_turrets
		&"shield_generator":
			return bs.count_of(def_id) >= _awal_shield + 1
	return false


func _note_bottleneck(cost: Dictionary) -> void:
	for res_id in cost.keys():
		if Economy.get_amount(StringName(res_id)) < int(cost[res_id]):
			var rid := String(res_id)
			_bottleneck[rid] = int(_bottleneck.get(rid, 0)) + 1


func _observe() -> void:
	var e := Economy.get_amount(&"energy")
	var m := Economy.get_amount(&"minerals")
	_min_balance_e = mini(_min_balance_e, e)
	_min_balance_m = mini(_min_balance_m, m)
	if e >= Economy.get_cap(&"energy") or m >= Economy.get_cap(&"minerals"):
		_storage_full_days += 1


func _on_combat_finished(result: BattleResult) -> void:
	if _wd != null:
		_wave_results[String(_wd.pending_wave)] = result.winner


func _on_territory_unlocked(sector_id: StringName) -> void:
	if sector_id == &"sector_2" and _sector2_day < 0:
		_sector2_day = _day


func _report(bs: BuildingSystem, fs: FleetSystem, pr: ProgressionSystem) -> void:
	var elapsed := Time.get_ticks_msec() - _t0
	var final_e := Economy.get_amount(&"energy")
	var final_m := Economy.get_amount(&"minerals")
	var bn_total := 0
	var bn_top := ""
	var bn_top_n := -1
	for res in _bottleneck.keys():
		if int(_bottleneck[res]) > bn_top_n:
			bn_top_n = int(_bottleneck[res])
			bn_top = String(res)
		bn_total += int(_bottleneck[res])

	check("sim.completed", _day == SIM_DAYS, "days=%d" % _day)
	check("sim.first_interceptor_built", _first_ship_day > 0 and _first_ship_day <= 15,
		"day=%d" % _first_ship_day)
	check("sim.economy_never_negative", _min_balance_e >= 0 and _min_balance_m >= 0,
		"min_e=%d min_m=%d" % [_min_balance_e, _min_balance_m])
	check("sim.economy_grows", final_e + final_m > 450,
		"final_e=%d final_m=%d (start=300/150)" % [final_e, final_m])
	check("sim.wave1_ran", _wave_results.has("wave_1"), "results=%s" % str(_wave_results))
	check("sim.wave1_defender_wins", _wave_results.get("wave_1", "") == "defender",
		"winner=%s" % _wave_results.get("wave_1", "none"))
	check("sim.sector2_unlocked", _sector2_day > 0, "day=%d" % _sector2_day)
	check("sim.wave2_ran", _wave_results.has("wave_2"),
		"winner=%s" % _wave_results.get("wave_2", "none"))
	## M3 #9: basis awal = rencana tata letak (punya reaktor + tambang sejak hari 0)
	## sehingga pendapatan lebih besar dan "gagal afford" tidak selalu terjadi.
	## Yang tetap WAJIB: salah satu dari dua kesimpulan ini benar — (a) ada
	## bottleneck terukur, atau (b) SEMUA target bangunan strategi tercapai.
	var target_tercapai := 0
	for def_id in _build_order:
		if _enough(bs, def_id):
			target_tercapai += 1
	check("sim.bottleneck_atau_target",
		bn_total > 0 or target_tercapai == _build_order.size(),
		"events=%d top=%s target tercapai=%d/%d" % [bn_total, bn_top, target_tercapai,
			_build_order.size()])
	QaMarkers.marker("SIM", "BOTTLENECK", {"events": bn_total, "top": str(bn_top),
		"target_tercapai": target_tercapai, "total_target": _build_order.size()})

	var metrics := {
		"days": SIM_DAYS,
		"ticks": SIM_DAYS * TICKS_PER_DAY,
		"seed": SIM_SEED,
		"wall_ms": elapsed,
		"final_energy": final_e,
		"final_minerals": final_m,
		"min_energy": _min_balance_e,
		"min_minerals": _min_balance_m,
		"ships_alive": fs.alive_count(),
		"buildings": bs.get_all_buildings().size(),
		"turrets": bs.count_of(&"laser_turret"),
		"shields": bs.count_of(&"shield_generator"),
		"first_ship_day": _first_ship_day,
		"sector2_day": _sector2_day,
		"wave1_winner": _wave_results.get("wave_1", "none"),
		"wave2_winner": _wave_results.get("wave_2", "none"),
		"defense_wins": pr.defense_wins,
		"bottleneck_top": bn_top,
		"bottleneck_events": bn_total,
		"storage_full_days": _storage_full_days,
		"values": "PROVISIONAL",
	}
	QaMarkers.marker("SIM", "METRICS", metrics)
	_metrics_recorded = true
	check("sim.metrics_recorded", _metrics_recorded, "wall_ms=%d" % elapsed)
	check("sim.wall_time_recorded", elapsed > 0, "ms=%d" % elapsed)


func _finish() -> void:
	print("TESTS:DONE passed=%d failed=%d skipped=0" % [passed, failed])
	QaMarkers.marker("TESTS", "DONE", {"passed": passed, "failed": failed, "skipped": 0})
	QaMarkers.marker("SIM", "COMPLETE", {"passed": passed, "failed": failed})
