extends Control
## HUD — read-only view of game state. UI TIDAK pernah menjadi sumber
## kebenaran: semua nilai dibaca dari Economy/sistem (DATA_CONTRACTS.md §1).
## Tombol memanggil API sistem yang sama dengan yang dipakai gameplay.

var _energy_label: Label
var _minerals_label: Label
var _fleet_label: Label
var _status_label: Label
var _result_label: Label
var _build_buttons: Dictionary = {}


func _ready() -> void:
	_energy_label = Label.new()
	_energy_label.position = Vector2(10, 10)
	add_child(_energy_label)
	_minerals_label = Label.new()
	_minerals_label.position = Vector2(10, 30)
	add_child(_minerals_label)
	_fleet_label = Label.new()
	_fleet_label.position = Vector2(10, 50)
	add_child(_fleet_label)
	_status_label = Label.new()
	_status_label.position = Vector2(10, 92)
	add_child(_status_label)
	_result_label = Label.new()
	_result_label.position = Vector2(10, 690)
	add_child(_result_label)

	# Tombol bangun: satu per bangunan yang sudah di-unlock (dari data)
	var pr := SystemRefs.progression_system()
	var x := 10.0
	if pr != null:
		for id in pr.unlocked:
			var def := GameData.get_building_def(id)
			if def == null:
				continue
			var btn := Button.new()
			btn.text = "Build %s (E%d M%d)" % [
				def.display_name,
				int(def.base_cost.get("energy", 0)),
				int(def.base_cost.get("minerals", 0)),
			]
			btn.position = Vector2(x, 130)
			btn.pressed.connect(_on_build_pressed.bind(id))
			add_child(btn)
			_build_buttons[id] = btn
			x += 170.0

	var ship_btn := Button.new()
	ship_btn.text = "Build Interceptor"
	ship_btn.position = Vector2(10, 170)
	ship_btn.pressed.connect(_on_ship_pressed)
	add_child(ship_btn)

	EventBus.resource_changed.connect(_on_resource_changed)
	EventBus.combat_finished.connect(_on_combat_finished)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.territory_unlocked.connect(_on_territory_unlocked)
	_refresh()


func _refresh() -> void:
	_energy_label.text = "Energy: %d / %d" % [Economy.get_amount(&"energy"), Economy.get_cap(&"energy")]
	_minerals_label.text = "Minerals: %d / %d" % [Economy.get_amount(&"minerals"), Economy.get_cap(&"minerals")]
	var fs := SystemRefs.fleet_system()
	_fleet_label.text = "Fleet: %d ships" % (fs.alive_count() if fs != null else 0)


func _on_resource_changed(_res, _old, _new, _delta) -> void:
	_refresh()


func _on_build_pressed(def_id: StringName) -> void:
	var bs := SystemRefs.building_system()
	var ps := SystemRefs.production_system()
	if bs == null or ps == null:
		return
	var def := GameData.get_building_def(def_id)
	if def == null:
		return
	var pos := bs.next_free_position(def.footprint)
	if ps.enqueue_construction(def_id, pos):
		_status_label.text = "Building %s..." % def.display_name
	else:
		_status_label.text = "Cannot afford %s" % def.display_name


func _on_ship_pressed() -> void:
	var ps := SystemRefs.production_system()
	if ps == null:
		return
	if ps.enqueue_ship(&"shp_001_interceptor"):
		_status_label.text = "Building Interceptor..."
	else:
		_status_label.text = "Cannot build Interceptor (need hangar + funds)"


func _on_wave_incoming(wave_id: StringName, eta: int) -> void:
	_status_label.text = "WARNING: alien wave %s incoming in %d ticks!" % [wave_id, eta]


func _on_combat_finished(result: BattleResult) -> void:
	_result_label.text = "Battle result: %s won in %d ticks" % [result.winner, result.duration_ticks]


func _on_territory_unlocked(sector_id: StringName) -> void:
	_status_label.text = "Territory unlocked: %s" % sector_id
