class_name FleetSystem
extends Node
## FleetSystem — pemilik state armada pemain (daftar unit, jumlah, kondisi).

var ships: Dictionary = {}  ## instance_id -> Ship
var _next_instance: int = 0


func _ready() -> void:
	add_to_group("system_fleet")


func spawn_ship(def_id: StringName) -> Ship:
	var def := GameData.get_ship_def(def_id)
	if def == null:
		push_error("FleetSystem: unknown ship %s" % def_id)
		return null
	_next_instance += 1
	var s := Ship.new()
	s.setup(def, "%s_%d" % [def.id, _next_instance])
	s.position = Vector3(0, 1, 8 + _next_instance * 1.5)
	add_child(s)
	ships[s.instance_id] = s
	EventBus.ship_built.emit(def.id, s.instance_id)
	EventBus.fleet_changed.emit()
	QaMarkers.marker("FLEET", "SPAWN", {"id": def.id, "instance": s.instance_id, "hp": s.hp})
	return s


func get_alive_ships() -> Array[Ship]:
	var out: Array[Ship] = []
	for s in ships.values():
		if not s.is_destroyed():
			out.append(s)
	return out


func alive_count() -> int:
	return get_alive_ships().size()


func total_count() -> int:
	return ships.size()


func count_of(def_id: StringName) -> int:
	var n := 0
	for s in ships.values():
		if s.def.id == def_id:
			n += 1
	return n


func alive_count_of(def_id: StringName) -> int:
	var n := 0
	for s in ships.values():
		if s.def.id == def_id and not s.is_destroyed():
			n += 1
	return n


## Hancurkan n kapal hidup bertipe def_id (dipakai hasil simulasi).
func destroy_ships_of_type(def_id: StringName, n: int) -> int:
	var destroyed := 0
	for s in ships.values():
		if destroyed >= n:
			break
		if s.def.id == def_id and not s.is_destroyed():
			s.take_damage(s.hp)  ## hancur total
			destroyed += 1
	if destroyed > 0:
		EventBus.fleet_changed.emit()
		QaMarkers.marker("FLEET", "LOSSES", {"id": def_id, "count": destroyed})
	return destroyed


func remove_ship(instance_id: String) -> void:
	var s := ships.get(instance_id)
	if s != null:
		ships.erase(instance_id)
		s.queue_free()
		EventBus.fleet_changed.emit()


func get_state() -> Dictionary:
	var arr := []
	for s in ships.values():
		arr.append(s.get_state())
	return {"ships": arr}


func set_state(s: Dictionary) -> void:
	for sh in ships.values():
		sh.queue_free()
	ships.clear()
	_next_instance = 0
	for entry in s.get("ships", []):
		var def := GameData.get_ship_def(entry.get("id"))
		if def == null:
			push_error("FleetSystem: unknown ship in save: %s" % entry.get("id"))
			continue
		_next_instance += 1
		var sh := Ship.new()
		sh.setup(def, String(entry.get("instance")))
		add_child(sh)
		ships[sh.instance_id] = sh
		sh.set_state(entry)
	QaMarkers.marker("FLEET", "RESTORE", {"count": ships.size()})
