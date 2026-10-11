extends Node
## StressScene — pengukuran performa REPRESENTATIF di web build (DEV_PLAN M2 #3,
## ROADMAP M2: "stress scene with expected unit counts; frame-time stability,
## memory, draw calls" — numerical budgets TBD setelah device class diputuskan).
##
## Target unit (PROVISIONAL — "fleet size on screen" belum diputuskan, ROADMAP
## unapproved decisions): 30 penyerang (Game_Concept.md: wave besar = 30 pesawat)
## + 12 interceptor pemain + 8 turret = 42 kapal + 8 turret (+ HQ). Alien sementara
## memakai model SHP-001 (pilot ALN-001 belum diproduksi — lihat DEV_PLAN M2).
##
## Diukur (data nyata, sample tiap 1 detik selama 12 detik): FPS, frame time
## (dari delta frame aktual), process time, memory (Godot static + JS heap via
## JavaScriptBridge), draw calls, render objects, node count.

var passed := 0
var failed := 0

const SAMPLE_SECONDS := 12
const N_DEFENDER := 12
const N_ATTACKER := 30
const N_TURRETS := 8
const SEED := 555

var _bs: BuildingSystem = null
var _fs: FleetSystem = null
var _samples := 0
var _sample_acc := 0.0
var _done := false
var _t0 := 0
var _fps_sum := 0.0
var _fps_min := 999999.0
var _frame_ms_sum := 0.0
var _frame_ms_sample_sum := 0.0
var _frame_count := 0
var _frame_ms_max := 0.0
var _proc_ms_max := 0.0
var _mem_max_mb := 0.0
var _draw_sum := 0.0
var _obj_max := 0
var _nodes_max := 0


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


func _run() -> void:
	_bs = SystemRefs.building_system()
	_fs = SystemRefs.fleet_system()
	if _bs == null or _fs == null:
		check("stress.systems_present", false)
		_finish()
		return
	check("stress.systems_present", true)

	# Kamera framing seluruh formasi (z 8..47 untuk 42 kapal, 3 kolom).
	var base = get_parent().get_node_or_null("BaseScene")
	if base != null and base.camera != null:
		base.camera.position = Vector3(0, 55, 85)
		base.camera.look_at(Vector3(0, 0, 25), Vector3.UP)
	## M3.5: benchmark gameplay, bukan dekorasi — kurangi environment berat
	## (bintang/planet/grid emissive) supaya SwiftShader cukup fps.
	if base != null and base.has_method("reduce_environment_for_benchmark"):
		base.reduce_environment_for_benchmark()

	# Spawn 42 kapal (12 defender SHP-001 + 30 attacker ALN-001 — model asli
	# kedua belah pihak, hasil pilot ALN-001 2026-10-11) + 8 turret.
	for i in N_DEFENDER:
		_fs.spawn_ship(&"shp_001_interceptor")
	for i in N_ATTACKER:
		_fs.spawn_ship(&"aln_001_scout")
	var turret_def := GameData.get_building_def(&"laser_turret")
	for i in N_TURRETS:
		_bs.place_building(&"laser_turret", _bs.next_free_position(turret_def.footprint))

	_t0 = Time.get_ticks_msec()
	QaMarkers.marker("STRESS", "START", {
		"defender": N_DEFENDER, "attacker": N_ATTACKER, "turrets": N_TURRETS,
		"sample_seconds": SAMPLE_SECONDS, "seed": SEED, "target_counts": "PROVISIONAL",
	})
	# _process mengumpulkan sample; TimeSystem jalan normal (game realistis).


func _process(delta: float) -> void:
	if _done:
		return
	var frame_ms := delta * 1000.0
	_frame_ms_sum += frame_ms
	_frame_count += 1
	if frame_ms > _frame_ms_max:
		_frame_ms_max = frame_ms
	_sample_acc += delta
	if _sample_acc < 1.0:
		return
	_sample_acc -= 1.0
	_sample()
	if _samples >= SAMPLE_SECONDS:
		_done = true
		_report()


func _sample() -> void:
	_samples += 1
	var fps := float(Performance.get_monitor(Performance.TIME_FPS))
	_fps_sum += fps
	if fps < _fps_min:
		_fps_min = fps
	var proc := float(Performance.get_monitor(Performance.TIME_PROCESS))
	if proc > _proc_ms_max:
		_proc_ms_max = proc
	var mem := float(Performance.get_monitor(Performance.MEMORY_STATIC)) / 1048576.0
	if mem > _mem_max_mb:
		_mem_max_mb = mem
	_draw_sum += float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var obj := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	if obj > _obj_max:
		_obj_max = obj
	var nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))
	if nodes > _nodes_max:
		_nodes_max = nodes
	_frame_ms_sample_sum += _frame_ms_sum / _frame_count
	_frame_ms_sum = 0.0
	_frame_count = 0


func _report() -> void:
	var elapsed := Time.get_ticks_msec() - _t0
	var fps_avg := _fps_sum / _samples
	var frame_avg := _frame_ms_sample_sum / _samples
	var draw_avg := _draw_sum / _samples
	check("stress.units_spawned",
		_fs.total_count() == N_DEFENDER + N_ATTACKER and _bs.count_of(&"laser_turret") == N_TURRETS,
		"ships=%d turrets=%d" % [_fs.total_count(), _bs.count_of(&"laser_turret")])
	check("stress.samples_recorded", _samples >= SAMPLE_SECONDS, "samples=%d" % _samples)
	check("stress.fps_recorded", fps_avg > 0, "avg=%.1f min=%.1f" % [fps_avg, _fps_min])
	check("stress.frame_time_recorded", frame_avg > 0,
		"avg=%.2fms max=%.2fms" % [frame_avg, _frame_ms_max])
	check("stress.fps_min_recorded", _fps_min > 0, "fps_min=%.1f" % _fps_min)
	# Memory: Godot MEMORY_STATIC=0 (release build, tracking off) — JS heap diukur
	# via page.metrics() di capture.mjs, diverifikasi di run_game_check.sh (suite stress).
	QaMarkers.marker("STRESS", "MEMORY", {
		"godot_static_mb": _mem_max_mb,
		"source": "capture page.metrics (JS heap); wasm memory tidak ter-expose di headless",
	})
	check("stress.no_freeze", _frame_ms_max < 1000.0, "max_frame_ms=%.1f" % _frame_ms_max)
	check("stress.node_count_recorded", _nodes_max > 0, "nodes=%d" % _nodes_max)
	QaMarkers.marker("STRESS", "METRICS", {
		"ships": _fs.total_count(), "turrets": _bs.count_of(&"laser_turret"),
		"samples": _samples, "wall_ms": elapsed,
		"fps_avg": fps_avg, "fps_min": _fps_min,
		"frame_ms_avg": frame_avg, "frame_ms_max": _frame_ms_max, "process_ms_max": _proc_ms_max,
		"memory_static_max_mb": _mem_max_mb,
		"memory_js_heap": "via capture page.metrics",
		"draw_calls_avg": draw_avg, "render_objects_max": _obj_max, "nodes_max": _nodes_max,
		"target_counts": "PROVISIONAL", "budget": "TBD (device class)",
		"models": "defender=shp_001_interceptor attacker=aln_001_scout",
	})
	_finish()


func _finish() -> void:
	print("TESTS:DONE passed=%d failed=%d skipped=0" % [passed, failed])
	QaMarkers.marker("TESTS", "DONE", {"passed": passed, "failed": failed, "skipped": 0})
	QaMarkers.marker("STRESS", "COMPLETE", {"passed": passed, "failed": failed})
