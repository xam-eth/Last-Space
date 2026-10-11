extends Node
## SaveSystem — save/load versi (JSON) seluruh state authoritative
## (TECH_ARCHITECTURE.md §7, DATA_CONTRACTS.md §2.8, AI_GOVERNANCE.md §16).
##
## Sistem game diambil via group (bukan autoload) agar save/load bekerja untuk
## scene apa pun yang menyediakan sistem tersebut.

const SCHEMA_VERSION := 1
const SAVE_DIR := "user://"


## Simpan seluruh state. Mengembalikan false jika sistem belum lengkap
## (save tidak boleh parsial — integritas).
func save_game(slot: String = "default") -> bool:
	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	var qt: QuestTracker = SystemRefs.quest_tracker()
	if bs == null or ps == null or fs == null or pr == null or wd == null or qt == null:
		push_error("SaveSystem: sistem belum lengkap, save dibatalkan")
		return false

	var data := {
		"schema_version": SCHEMA_VERSION,
		"engine_version": "4.7.2",
		"save_version": 1,
		"game_time_ticks": TimeSystem.tick_count,
		"rng_seed": SeededRng.get_seed(),
		"phase": GameManager.phase,
		"economy": Economy.get_state(),
		"buildings": bs.get_state(),
		"production": ps.get_state(),
		"fleet": fs.get_state(),
		"progression": pr.get_state(),
		"wave_director": wd.get_state(),
		"quests": qt.get_state(),
	}
	var json := JSON.stringify(data, "\t")
	var path := SAVE_DIR + slot + ".json"
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: tidak bisa menulis %s" % path)
		return false
	f.store_string(json)
	f.close()
	EventBus.game_saved.emit(slot)
	QaMarkers.marker("SAVE", "SAVED", {"slot": slot, "bytes": json.length(), "ticks": TimeSystem.tick_count})
	return true


func load_game(slot: String = "default") -> bool:
	var path := SAVE_DIR + slot + ".json"
	if not FileAccess.file_exists(path):
		push_error("SaveSystem: tidak ada save di %s" % path)
		return false
	var f := FileAccess.open(path, FileAccess.READ)
	var json_text := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(json_text)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		push_error("SaveSystem: JSON save tidak valid")
		return false
	var data: Dictionary = parsed
	if int(data.get("schema_version", 0)) != SCHEMA_VERSION:
		push_error("SaveSystem: schema_version %s tidak didukung" % data.get("schema_version"))
		return false

	TimeSystem.tick_count = int(data.get("game_time_ticks", 0))
	SeededRng.set_seed(int(data.get("rng_seed", 1)))
	GameManager.set_phase_direct(int(data.get("phase", 2)))
	Economy.set_state(data.get("economy", {}))

	var bs: BuildingSystem = SystemRefs.building_system()
	var ps: ProductionSystem = SystemRefs.production_system()
	var fs: FleetSystem = SystemRefs.fleet_system()
	var pr: ProgressionSystem = SystemRefs.progression_system()
	var wd: WaveDirector = SystemRefs.wave_director()
	var qt: QuestTracker = SystemRefs.quest_tracker()
	if bs == null or ps == null or fs == null or pr == null or wd == null or qt == null:
		push_error("SaveSystem: sistem belum lengkap, load dibatalkan")
		return false
	bs.set_state(data.get("buildings", {}))
	ps.set_state(data.get("production", {}))
	fs.set_state(data.get("fleet", {}))
	pr.set_state(data.get("progression", {}))
	wd.set_state(data.get("wave_director", {}))
	qt.set_state(data.get("quests", {}))

	EventBus.game_loaded.emit(slot)
	QaMarkers.marker("SAVE", "LOADED", {"slot": slot, "ticks": TimeSystem.tick_count})
	return true


func has_save(slot: String = "default") -> bool:
	return FileAccess.file_exists(SAVE_DIR + slot + ".json")
