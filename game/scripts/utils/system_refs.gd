class_name SystemRefs
## SystemRefs — helper mengambil sistem game dari scene tree via group.
## Dipakai oleh autoload (SaveSystem) dan sistem yang butuh sistem lain.


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree


static func building_system() -> BuildingSystem:
	return _tree().get_first_node_in_group("system_building")


static func production_system() -> ProductionSystem:
	return _tree().get_first_node_in_group("system_production")


static func fleet_system() -> FleetSystem:
	return _tree().get_first_node_in_group("system_fleet")


static func progression_system() -> ProgressionSystem:
	return _tree().get_first_node_in_group("system_progression")


static func wave_director() -> WaveDirector:
	return _tree().get_first_node_in_group("system_wave_director")


static func quest_tracker() -> QuestTracker:
	return _tree().get_first_node_in_group("system_quest")
