class_name ProductionSystem
extends Node
## ProductionSystem — antrian konstruksi/produksi/repair + produksi pasif
## bangunan. Pemilik state input/output/kapsitas/waktu (DATA_CONTRACTS.md §1).
##
## Aturan: biaya dibayar saat enqueue (atomic via Economy.spend); produksi kapal
## membutuhkan minimal 1 fighter_hangar; produksi bangunan saat storage penuh
## hilang (realistis).

enum QueueKind { CONSTRUCTION, SHIP, REPAIR }

var queues: Array[Dictionary] = []


func _ready() -> void:
	add_to_group("system_production")
	TimeSystem.ticked.connect(_on_tick)


func _on_tick(_tick: int, _delta: int) -> void:
	# Produksi pasif bangunan (integer-exact per Building)
	var bs := SystemRefs.building_system()
	if bs != null:
		for b in bs.get_all_buildings():
			flush_building(b)
	# Majukan antrian
	var i := 0
	while i < queues.size():
		var q: Dictionary = queues[i]
		q["progress_ticks"] = int(q["progress_ticks"]) + 1
		if int(q["progress_ticks"]) >= int(q["total_ticks"]):
			_complete(q)
			queues.remove_at(i)
		else:
			i += 1


## Hitung produksi berjalan untuk satu bangunan dan tambahkan ke Economy.
func flush_building(b: Building) -> void:
	b.tick_production()
	var total := b.get_production_total()
	var delta := total - b.prod_earned
	if delta <= 0:
		return
	var added := Economy.earn(b.def.produces, delta)
	b.prod_earned += added
	if added < delta:
		b.prod_earned = total  ## storage penuh → sisa produksi terbuang


func enqueue_construction(def_id: StringName, pos: Vector3) -> bool:
	var def := GameData.get_building_def(def_id)
	if def == null:
		return false
	if not Economy.can_afford(def.base_cost):
		return false
	Economy.spend(def.base_cost)
	queues.append({
		"kind": QueueKind.CONSTRUCTION, "def_id": def_id, "pos": pos,
		"progress_ticks": 0, "total_ticks": def.build_time_ticks,
	})
	QaMarkers.marker("PROD", "ENQUEUE", {"kind": "construction", "id": def_id, "ticks": def.build_time_ticks})
	return true


func enqueue_ship(ship_id: StringName) -> bool:
	var def := GameData.get_ship_def(ship_id)
	if def == null:
		return false
	var bs := SystemRefs.building_system()
	if bs == null or bs.count_of(&"fighter_hangar") <= 0:
		push_warning("ProductionSystem: butuh fighter_hangar untuk produksi kapal")
		return false
	if not Economy.can_afford(def.cost):
		return false
	Economy.spend(def.cost)
	queues.append({
		"kind": QueueKind.SHIP, "def_id": ship_id,
		"progress_ticks": 0, "total_ticks": def.build_time_ticks,
	})
	QaMarkers.marker("PROD", "ENQUEUE", {"kind": "ship", "id": ship_id, "ticks": def.build_time_ticks})
	return true


func enqueue_repair(instance_id: String, amount_hp: int) -> bool:
	var bs := SystemRefs.building_system()
	if bs == null:
		return false
	var b := bs.get_building(instance_id)
	if b == null or amount_hp <= 0:
		return false
	var missing := b.get_max_hp() - b.hp
	var actual := mini(amount_hp, missing)
	if actual <= 0:
		return false
	var cost := _scale_cost(b.def.repair_cost_per_hp, actual)
	if not Economy.can_afford(cost):
		return false
	Economy.spend(cost)
	queues.append({
		"kind": QueueKind.REPAIR, "instance_id": instance_id, "amount_hp": actual,
		"progress_ticks": 0, "total_ticks": 50,
	})
	QaMarkers.marker("PROD", "ENQUEUE", {"kind": "repair", "instance": instance_id, "hp": actual})
	return true


func queue_count() -> int:
	return queues.size()


func _complete(q: Dictionary) -> void:
	match int(q["kind"]):
		QueueKind.CONSTRUCTION:
			var bs := SystemRefs.building_system()
			if bs != null:
				bs.place_building(q["def_id"], q["pos"])
				EventBus.production_completed.emit("construction", q["def_id"], 1)
		QueueKind.SHIP:
			var fs := SystemRefs.fleet_system()
			if fs != null:
				fs.spawn_ship(q["def_id"])
				EventBus.production_completed.emit("ship", q["def_id"], 1)
		QueueKind.REPAIR:
			var bs2 := SystemRefs.building_system()
			if bs2 != null:
				bs2.repair_building(q["instance_id"], int(q["amount_hp"]))
				EventBus.production_completed.emit("repair", &"", int(q["amount_hp"]))


func _scale_cost(base: Dictionary, amount: int) -> Dictionary:
	var out := {}
	for res_id in base.keys():
		out[res_id] = int(base[res_id]) * amount
	return out


func get_state() -> Dictionary:
	var arr := []
	for q in queues:
		var copy := q.duplicate(true)
		if copy.has("pos"):
			var p: Vector3 = copy["pos"]
			copy["pos"] = [p.x, p.y, p.z]
		arr.append(copy)
	return {"queues": arr}


func set_state(s: Dictionary) -> void:
	queues.clear()
	for entry in s.get("queues", []):
		var q: Dictionary = entry
		if q.has("pos"):
			var p: Array = q["pos"]
			q["pos"] = Vector3(float(p[0]), float(p[1]), float(p[2]))
		queues.append(q)
	QaMarkers.marker("PROD", "RESTORE", {"queues": queues.size()})
