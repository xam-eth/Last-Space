class_name QuestTracker
extends Node
## QuestTracker — objektif misi slice untuk QUEST PANEL kiri tengah
## (pola Doomsday F3/F8, GAMEPLAY_FLOW.md §0/§3 Frame 4). Pemilik state
## progress objektif (DATA_CONTRACTS.md §1).
##
## Aturan: dengar EventBus secara read-only (tidak mengubah sistem lain);
## reward diberikan SEKALI (reward-once) saat objektif terpenuhi; reward
## masuk via Economy.earn (storage cap tetap dihormati).
##
## Definisi objektif & reward = konten slice PROVISIONAL (belum ada data
## .tres khusus quest — kesepakatan human untuk balance ada di data).

var quests: Dictionary = {}  ## id -> Dictionary {id,title,kind,wave_id,target,current,done,reward}
var _last_wave: StringName = &""


func _ready() -> void:
	add_to_group("system_quest")
	reset()
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.ship_built.connect(_on_ship_built)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.combat_finished.connect(_on_combat_finished)


func reset() -> void:
	quests.clear()
	_last_wave = &""
	quests[&"q_power"] = _def(&"q_power", "Power Up", "build", &"", &"energy_reactor", 1, {"energy": 100})
	quests[&"q_hangar"] = _def(&"q_hangar", "First Hangar", "build", &"", &"fighter_hangar", 1, {"minerals": 100})
	quests[&"q_squad"] = _def(&"q_squad", "First Squadron", "ship", &"", &"shp_001_interceptor", 2, {"energy": 50, "minerals": 50})
	quests[&"q_defend"] = _def(&"q_defend", "Hold the Line", "wave_win", &"wave_1", &"", 1, {"energy": 200, "minerals": 100})
	QaMarkers.marker("QUEST", "INIT", {"count": quests.size()})


func _def(id: StringName, title: String, kind: String, wave_id: StringName,
		building_id: StringName, target: int, reward: Dictionary) -> Dictionary:
	return {
		"id": id, "title": title, "kind": kind, "wave_id": wave_id,
		"building_id": building_id, "target": target,
		"current": 0, "done": false, "reward": reward,
	}


func get_progress(quest_id: StringName) -> int:
	var q: Dictionary = quests.get(quest_id, {})
	return int(q.get("current", 0))


func get_target(quest_id: StringName) -> int:
	var q: Dictionary = quests.get(quest_id, {})
	return int(q.get("target", 0))


func is_done(quest_id: StringName) -> bool:
	var q: Dictionary = quests.get(quest_id, {})
	return bool(q.get("done", false))


func get_all() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in [&"q_power", &"q_hangar", &"q_squad", &"q_defend"]:
		out.append(quests[id])
	return out


func _add_progress(quest_id: StringName, amount: int) -> void:
	var q: Dictionary = quests.get(quest_id)
	if q == null or bool(q["done"]) or amount <= 0:
		return
	q["current"] = mini(int(q["current"]) + amount, int(q["target"]))
	EventBus.quest_progress.emit(quest_id, int(q["current"]), int(q["target"]))
	QaMarkers.marker("QUEST", "PROGRESS", {"id": quest_id, "current": q["current"], "target": q["target"]})
	if int(q["current"]) >= int(q["target"]):
		_complete(q)


func _complete(q: Dictionary) -> void:
	q["done"] = true
	var rewards: Dictionary = q["reward"]
	for res_id in rewards.keys():
		Economy.earn(StringName(res_id), int(rewards[res_id]))
	EventBus.reward_granted.emit(rewards, "quest:%s" % String(q["id"]))
	EventBus.quest_completed.emit(q["id"])
	QaMarkers.marker("QUEST", "COMPLETE", {"id": q["id"], "reward": rewards})


# ------------------------------------------------------------- events ----
func _on_building_placed(building_id: StringName, _instance_id: String, _pos: Vector3) -> void:
	for q in quests.values():
		var d: Dictionary = q
		if d["kind"] == "build" and d["building_id"] == building_id:
			_add_progress(d["id"], 1)


func _on_ship_built(ship_id: StringName, _instance_id: String) -> void:
	for q in quests.values():
		var d: Dictionary = q
		if d["kind"] == "ship" and d["building_id"] == ship_id:
			_add_progress(d["id"], 1)


func _on_wave_incoming(wave_id: StringName, _eta: int) -> void:
	_last_wave = wave_id


func _on_combat_finished(result: BattleResult) -> void:
	for q in quests.values():
		var d: Dictionary = q
		if d["kind"] == "wave_win" and result.winner == "defender" and _last_wave == d["wave_id"]:
			_add_progress(d["id"], 1)


# --------------------------------------------------------- save/load ----
func get_state() -> Dictionary:
	var arr := []
	for q in quests.values():
		var d: Dictionary = q
		arr.append({
			"id": d["id"], "current": d["current"], "done": d["done"],
		})
	return {"quests": arr, "last_wave": String(_last_wave)}


func set_state(s: Dictionary) -> void:
	reset()
	_last_wave = StringName(s.get("last_wave", ""))
	var by_id: Dictionary = {}
	for q in quests.values():
		var d: Dictionary = q
		by_id[d["id"]] = d
	for entry in s.get("quests", []):
		var e: Dictionary = entry
		var q: Dictionary = by_id.get(e.get("id"))
		if q == null:
			continue
		q["current"] = mini(int(e.get("current", 0)), int(q["target"]))
		q["done"] = bool(e.get("done", false))
		if q["done"] and int(q["current"]) < int(q["target"]):
			q["current"] = int(q["target"])  ## konsistensi: done = target terpenuhi
	QaMarkers.marker("QUEST", "RESTORE", {"count": quests.size()})
