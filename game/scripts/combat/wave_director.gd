class_name WaveDirector
extends Node
## WaveDirector — jadwal & komposisi wave alien + menjalankan simulasi.
## Mengumpulkan BattleInput dari state aktual sistem, menjalankan
## CombatSimulator, lalu MENERAPKAN hasilnya ke sistem (losses, damage).

var threat: int = 0
var pending_wave: StringName = &""
var countdown_ticks: int = -1  ## -1 = idle
var current_input: BattleInput = null
var last_result: BattleResult = null


func _ready() -> void:
	add_to_group("system_wave_director")
	TimeSystem.ticked.connect(_on_tick)


func schedule_wave(wave_id: StringName, delay_ticks: int = -1) -> void:
	var def := GameData.get_wave_def(wave_id)
	if def == null:
		push_error("WaveDirector: unknown wave %s" % wave_id)
		return
	pending_wave = wave_id
	countdown_ticks = def.telegraph_ticks if delay_ticks < 0 else delay_ticks
	EventBus.wave_incoming.emit(wave_id, countdown_ticks)
	QaMarkers.marker("WAVE", "INCOMING", {"id": wave_id, "eta_ticks": countdown_ticks})


func is_idle() -> bool:
	return countdown_ticks < 0


func _on_tick(_tick: int, _delta: int) -> void:
	if countdown_ticks < 0:
		return
	countdown_ticks -= 1
	if countdown_ticks <= 0:
		_launch_wave()


func _launch_wave() -> void:
	var def := GameData.get_wave_def(pending_wave)
	if def == null:
		countdown_ticks = -1
		return

	var input := BattleInput.new()
	for ship_id in def.composition.keys():
		for i in int(def.composition[ship_id]):
			input.attacker.append(ship_id)
	input.seed = SeededRng.next_int_range(1, 2147483647)

	var fs := SystemRefs.fleet_system()
	if fs != null:
		for s in fs.get_alive_ships():
			input.defender_ships.append(s.def.id)
	var bs := SystemRefs.building_system()
	if bs != null:
		for b in bs.get_defense_buildings():
			input.defender_turrets.append({"weapon_id": b.def.weapon_id, "count": 1, "hp": b.hp})
		for b in bs.get_all_buildings():
			input.defender_buildings.append({
				"instance_id": b.instance_id, "hp": b.hp,
				"max_hp": b.def.get_max_hp_for_level(b.level),
			})
		for b in bs.get_buildings_of(&"shield_generator"):
			if not b.is_destroyed():
				input.shield_hp += b.def.get_shield_pool_for_level(b.level)

	current_input = input
	EventBus.combat_started.emit(input.seed)
	QaMarkers.marker("COMBAT", "START", {
		"wave": pending_wave, "attackers": input.attacker.size(),
		"defender_ships": input.defender_ships.size(),
		"turrets": input.defender_turrets.size(),
		"buildings": input.defender_buildings.size(),
		"shield": input.shield_hp, "seed": input.seed,
	})

	var result := CombatSimulator.new().simulate(input)
	last_result = result
	_apply_result(result)
	EventBus.combat_finished.emit(result)
	threat += def.threat
	countdown_ticks = -1
	QaMarkers.marker("COMBAT", "FINISH", {
		"winner": result.winner,
		"duration_ticks": result.duration_ticks,
		"attacker_losses": result.attacker_losses.size(),
		"defender_ship_losses": result.defender_ship_losses.size(),
		"building_damage": result.building_damage.size(),
		"shield_damage": result.shield_damage,
		"seed": result.seed,
	})


func _apply_result(result: BattleResult) -> void:
	var fs := SystemRefs.fleet_system()
	var bs := SystemRefs.building_system()
	for ship_id in result.defender_ship_losses.keys():
		if fs != null:
			fs.destroy_ships_of_type(ship_id, int(result.defender_ship_losses[ship_id]))
	if bs != null:
		var defense_buildings := bs.get_defense_buildings()
		for idx in result.turret_damage.keys():
			var i := int(idx)
			if i < defense_buildings.size():
				bs.apply_damage_to(defense_buildings[i].instance_id, int(result.turret_damage[idx]))
		for instance_id in result.building_damage.keys():
			bs.apply_damage_to(String(instance_id), int(result.building_damage[instance_id]))
		if result.shield_damage > 0:
			for b in bs.get_buildings_of(&"shield_generator"):
				bs.apply_damage_to(b.instance_id, result.shield_damage)
				break


func get_state() -> Dictionary:
	return {
		"threat": threat,
		"pending_wave": pending_wave,
		"countdown_ticks": countdown_ticks,
	}


func set_state(s: Dictionary) -> void:
	threat = int(s.get("threat", 0))
	pending_wave = s.get("pending_wave", &"")
	countdown_ticks = int(s.get("countdown_ticks", -1))
	QaMarkers.marker("WAVE", "RESTORE", {"threat": threat, "countdown": countdown_ticks})
