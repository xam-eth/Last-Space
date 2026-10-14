class_name BuildingSystem
extends Node
## BuildingSystem — penempatan, upgrade, damage, repair bangunan.
## Pemilik state daftar bangunan (DATA_CONTRACTS.md §1).

var buildings: Dictionary = {}  ## instance_id -> Building
var _next_instance: int = 0
var _occupied: Dictionary = {}  ## "gx,gz" -> true (grid cells)

const GRID_SPACING := 2.0
const GRID_SIZE := 24


func _ready() -> void:
	add_to_group("system_building")


## Tempatkan bangunan (dipanggil saat konstruksi selesai / game baru).
func place_building(def_id: StringName, pos: Vector3) -> Building:
	var def := GameData.get_building_def(def_id)
	if def == null:
		push_error("BuildingSystem: unknown building %s" % def_id)
		return null
	_next_instance += 1
	var b := Building.new()
	b.setup(def, "%s_%d" % [def.id, _next_instance])
	b.position = pos
	add_child(b)
	buildings[b.instance_id] = b
	_mark_area(_cell(pos.x), _cell(pos.z), def.footprint)
	for res_id in def.storage_bonus.keys():
		Economy.add_cap(res_id, int(def.storage_bonus[res_id]))
	EventBus.building_placed.emit(def.id, b.instance_id, pos)
	QaMarkers.marker("BUILD", "PLACE", {
		"id": def.id, "instance": b.instance_id, "level": b.level,
		"pos": "%d,%d" % [int(pos.x), int(pos.z)], "hp": b.hp,
	})
	return b


func get_building(instance_id: String) -> Building:
	return buildings.get(instance_id)


func get_all_buildings() -> Array[Building]:
	var out: Array[Building] = []
	for b in buildings.values():
		out.append(b)
	return out


func get_buildings_of(def_id: StringName) -> Array[Building]:
	var out: Array[Building] = []
	for b in buildings.values():
		if b.def.id == def_id:
			out.append(b)
	return out


func count_of(def_id: StringName) -> int:
	return get_buildings_of(def_id).size()


## Bangunan defense yang bisa menembak (punya weapon).
func get_defense_buildings() -> Array[Building]:
	var out: Array[Building] = []
	for b in buildings.values():
		if b.def.category == "defense" and b.def.weapon_id != &"" and not b.is_destroyed():
			out.append(b)
	return out


## =====================================================================
## M3 #9 — LOGIKA PENEMPATAN (build logic) ala game building strategi
## ---------------------------------------------------------------------
## Riset (lihat docs/m3_9/REPORT_M3_9.md §2): pada Clash of Clans /
## Last War / Rise of Kingdoms, menempatkan bangunan adalah proses DUA LANGKAH
## dengan aturan berikut — dan inilah yang kami terapkan:
##   1. Area bangun TERBATAS di dalam dinding plataran (outside = tidak boleh).
##   2. Bangunan menempati FOOTPRINT grid; tumpang tindih = ditolak + ALASAN.
##   3. Pratinjau "ghost" mengikuti penunjuk; hijau = sah, merah = tidak, plus
##      alasan yang dibaca pemain (bukan diam-diam gagal).
##   4. Konfirmasi eksplisit sebelum biaya dibayar; batal = tidak ada biaya.
##   5. Rencana tata letak awal: inti di tengah, produksi ring-1, pertahanan
##      ring-2 (menjangkau ring-1), perisai/penyimpanan dekat inti.
## =====================================================================

const PLATE_HALF := 32.0    ## setengah sisi area BANGUN (di dalam dinding plataran 40)
const MIN_GAP_CELLS := 0    ## 0 = boleh berdempet; CoC mengizinkan dinding menempel

## Sel grid dari koordinat dunia — konsisten untuk nilai NEGATIF (bug lama:
## `int()` memotong ke arah nol sehingga sel -0,5 dan +0,5 dianggap sama).
static func _cell(v: float) -> int:
	## round() GDScript = setengah menjauhi nol → posisi +9 dan −9 menghasilkan
	## sel +5 dan −5 (simetris). Versi floor(v+0.5) memberi +5/−4 (miring 1 sel).
	return int(round(v / GRID_SPACING))


func can_place(def_id: StringName, pos: Vector3) -> Dictionary:
	## Validasi penempatan — SATU sumber kebenaran untuk ghost, UI, dan test.
	var def := GameData.get_building_def(def_id)
	if def == null:
		return {"ok": false, "reason": "bangunan_tidak_dikenal"}
	var fp: Vector2i = def.footprint
	var half := float(fp.x) * GRID_SPACING * 0.5
	if absf(pos.x) + half > PLATE_HALF or absf(pos.z) + half > PLATE_HALF:
		return {"ok": false, "reason": "di_luar_plataran",
			"detail": "area bangun ±%.0f unit" % PLATE_HALF}
	var gx := _cell(pos.x)
	var gz := _cell(pos.z)
	if not _is_area_free(gx, gz, fp):
		return {"ok": false, "reason": "sudah_terisi", "detail": "grid %d,%d" % [gx, gz]}
	return {"ok": true, "reason": "ok", "grid": Vector2i(gx, gz)}


func snap_to_grid(pos: Vector3) -> Vector3:
	## Bangunan selalu duduk di grid (kunci ke tengah sel) — pola CoC.
	return Vector3(_cell(pos.x) * GRID_SPACING, 0.0, _cell(pos.z) * GRID_SPACING)


func place_building_checked(def_id: StringName, pos: Vector3) -> Dictionary:
	## Penempatan gameplay: divalidasi dulu; mengembalikan {ok, reason, instance}.
	var check := can_place(def_id, pos)
	if not check["ok"]:
		QaMarkers.marker("BUILD", "REJECT", {"id": def_id, "reason": check["reason"],
			"pos": "%d,%d" % [int(pos.x), int(pos.z)]})
		return {"ok": false, "reason": check["reason"], "instance": null}
	var b := place_building(def_id, snap_to_grid(pos))
	return {"ok": b != null, "reason": "ok", "instance": b.instance_id if b != null else null}


func layout_plan() -> Array:
	## Rencana tata letak basis awal (dipakai game baru & tombol "TATA ULANG").
	## Jarak dipilih dari DAMPAK STRATEGIS, bukan estetika:
	##   - inti (command_core) di tengah → dikelilingi semua ring.
	##   - produksi (reaktor/tambang/hanggar) ring ~12 → terlindungi turret
	##     ring ~22 (jangkauan tembak turret 24 menutup inti + produksi).
	##   - perisai dekat inti (radius perisai melindungi inti lebih dulu).
	##   - 4 turret di diagonal ring 22 → menutup dua sumbu, tidak menumpuk.
	## Jarak dari DATA (bukan asumsi): laser_turret memakai laser_cannon dengan
	## `range = 10` (game/data/weapons/laser_cannon.tres). Karena itu turret
	## diletakkan di ring 9 (≤ 10 → INTI benar-benar tertutup tembakan), dan
	## produksi di ring 15 sebagai lapis luar. Pola ini sesuai riset: pertahanan
	## di lapis tengah (melindungi inti), kolektor/produksi di lapis luar.
	return [
		{"id": &"command_core", "pos": Vector3(0, 0, 0)},
		{"id": &"laser_turret", "pos": Vector3(9, 0, 0)},
		{"id": &"laser_turret", "pos": Vector3(-9, 0, 0)},
		{"id": &"laser_turret", "pos": Vector3(0, 0, 9)},
		{"id": &"laser_turret", "pos": Vector3(0, 0, -9)},
		{"id": &"energy_reactor", "pos": Vector3(15, 0, 0)},
		{"id": &"mineral_extractor", "pos": Vector3(-15, 0, 0)},
		{"id": &"fighter_hangar", "pos": Vector3(0, 0, 15)},
		{"id": &"shield_generator", "pos": Vector3(0, 0, -15)},
	]


func apply_layout_plan() -> int:
	## Tetapkan rencana tata letak untuk SEMUA bangunan di rencana (idempoten:
	## hasil ulang tidak menggandakan bangunan yang sudah sesuai posisi).
	var placed := 0
	for item in layout_plan():
		var want: Vector3 = snap_to_grid(item["pos"])
		var same_type := get_buildings_of(item["id"])
		var already := false
		for b in same_type:
			if b.position.distance_to(want) < 0.01:
				already = true
				break
		if already:
			continue
		var res := place_building_checked(item["id"], want)
		if res["ok"]:
			placed += 1
		else:
			print("QA:BUILD:LAYOUT_SKIP id=%s reason=%s" % [item["id"], res["reason"]])
	print("QA:BUILD:LAYOUT placed=%d total=%d types=%d" % [
		placed, get_all_buildings().size(), layout_plan().size()])
	return placed


func move_building(instance_id: String, new_pos: Vector3) -> Dictionary:
	## Pindahkan bangunan yang SUDAH ada (mode tata letak): validasi area,
	## lepas sel lama, isi sel baru. Bangunan lain tidak boleh tergusur.
	var b: Building = buildings.get(instance_id)
	if b == null:
		return {"ok": false, "reason": "tidak_ada"}
	var fp: Vector2i = b.def.footprint
	var old := Vector2i(_cell(b.position.x), _cell(b.position.z))
	_release_area(old.x, old.y, fp)
	var check := can_place(b.def.id, new_pos)
	if not check["ok"]:
		_mark_area(old.x, old.y, fp)   ## pulihkan (tidak merusak state)
		return {"ok": false, "reason": check["reason"]}
	var snapped := snap_to_grid(new_pos)
	_mark_area(_cell(snapped.x), _cell(snapped.z), fp)
	b.position = snapped
	QaMarkers.marker("BUILD", "MOVE", {"instance": instance_id,
		"from": "%d,%d" % [old.x, old.y],
		"to": "%d,%d" % [_cell(snapped.x), _cell(snapped.z)]})
	return {"ok": true, "reason": "ok", "pos": snapped}


func defense_coverage() -> Array:
	## Ring jangkauan semua bangunan pertahanan (untuk indikator visual +
	## verifikasi "tata letak menutup inti"). Angka dari DATA (bukan asumsi).
	var out: Array = []
	for b in get_defense_buildings():
		var rng := 0.0
		if b.def.weapon_id != &"":
			var w = GameData.get_weapon_def(b.def.weapon_id)
			if w != null:
				rng = float(w.range)
		out.append({"instance": b.instance_id, "pos": b.position, "range": rng})
	return out


func core_covered_by_defense() -> Dictionary:
	## Apakah inti berada di dalam jangkauan minimal 2 turret? (tata letak sehat)
	var cores := get_buildings_of(&"command_core")
	if cores.is_empty():
		return {"ok": false, "covering": 0, "detail": "inti tidak ada"}
	var core: Building = cores[0]
	var covering := 0
	for c in defense_coverage():
		if (c["pos"] as Vector3).distance_to(core.position) <= float(c["range"]):
			covering += 1
	return {"ok": covering >= 2, "covering": covering,
		"detail": "inti ditutup %d turret" % covering}


func next_free_position(footprint: Vector2i) -> Vector3:
	for gz in range(0, GRID_SIZE):
		for gx in range(0, GRID_SIZE):
			if _is_area_free(gx, gz, footprint):
				return Vector3(gx * GRID_SPACING, 0, gz * GRID_SPACING)
	return Vector3(0, 0, 0)


func upgrade_building(instance_id: String) -> bool:
	var b := get_building(instance_id)
	if b == null or b.level >= b.def.max_level:
		return false
	b.upgrade()
	QaMarkers.marker("BUILD", "UPGRADE", {"instance": instance_id, "level": b.level, "hp": b.hp})
	return true


## Upgrade dengan biaya (atomic: cek saldo → flush produksi → bayar → upgrade).
func try_upgrade(instance_id: String) -> bool:
	var b := get_building(instance_id)
	if b == null or b.level >= b.def.max_level:
		return false
	var cost := b.def.get_cost_for_level(b.level + 1)
	if not Economy.can_afford(cost):
		return false
	var ps := SystemRefs.production_system()
	if ps != null:
		ps.flush_building(b)
	Economy.spend(cost)
	b.upgrade()
	b.reset_production_counters()
	QaMarkers.marker("BUILD", "UPGRADE", {"instance": instance_id, "level": b.level, "hp": b.hp})
	return true


func apply_damage_to(instance_id: String, amount: int) -> void:
	var b := get_building(instance_id)
	if b != null:
		b.take_damage(amount)


func repair_building(instance_id: String, amount_hp: int) -> void:
	var b := get_building(instance_id)
	if b != null:
		b.repair(amount_hp)


func get_state() -> Dictionary:
	var arr := []
	for b in buildings.values():
		arr.append(b.get_state())
	return {"buildings": arr}


func set_state(s: Dictionary) -> void:
	for b in buildings.values():
		b.queue_free()
	buildings.clear()
	_occupied.clear()
	_next_instance = 0
	for entry in s.get("buildings", []):
		var def := GameData.get_building_def(entry.get("id"))
		if def == null:
			push_error("BuildingSystem: unknown building in save: %s" % entry.get("id"))
			continue
		_next_instance += 1
		var b := Building.new()
		b.setup(def, String(entry.get("instance")))
		var pos: Array = entry.get("position", [0, 0])
		b.position = Vector3(float(pos[0]), 0, float(pos[1]))
		add_child(b)
		buildings[b.instance_id] = b
		b.set_state(entry)
		_mark_area(_cell(b.position.x), _cell(b.position.z), def.footprint)
		# Catatan: storage bonus TIDAK di-apply ulang di sini — caps sudah
		# termasuk bonus di state Economy yang di-restore (hindari double-count).
	QaMarkers.marker("BUILD", "RESTORE", {"count": buildings.size()})


func _release_area(gx: int, gz: int, footprint: Vector2i) -> void:
	for dx in range(0, footprint.x):
		for dz in range(0, footprint.y):
			_occupied.erase("%d,%d" % [gx + dx, gz + dz])


func _is_area_free(gx: int, gz: int, footprint: Vector2i) -> bool:
	for dx in range(0, footprint.x):
		for dz in range(0, footprint.y):
			if _occupied.has("%d,%d" % [gx + dx, gz + dz]):
				return false
	return true


func _mark_area(gx: int, gz: int, footprint: Vector2i) -> void:
	for dx in range(0, footprint.x):
		for dz in range(0, footprint.y):
			_occupied["%d,%d" % [gx + dx, gz + dz]] = true
