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
	_mark_area(int(pos.x / GRID_SPACING), int(pos.z / GRID_SPACING), def.footprint)
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
		_mark_area(int(b.position.x / GRID_SPACING), int(b.position.z / GRID_SPACING), def.footprint)
		# Catatan: storage bonus TIDAK di-apply ulang di sini — caps sudah
		# termasuk bonus di state Economy yang di-restore (hindari double-count).
	QaMarkers.marker("BUILD", "RESTORE", {"count": buildings.size()})


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
