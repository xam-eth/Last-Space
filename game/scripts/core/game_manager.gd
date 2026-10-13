extends Node
## GameManager — state machine fase game + orkestrasi mode
## (TECH_ARCHITECTURE.md §3).

enum Phase { BOOT, MENU, COMMAND, COMBAT, PAUSE }

var phase: Phase = Phase.BOOT
var rng_seed: int = 1


func _ready() -> void:
	rng_seed = int(Time.get_unix_time_from_system()) & 0x7FFFFFFF
	SeededRng.set_seed(rng_seed)
	_change_phase(Phase.MENU)
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_finished.connect(_on_combat_finished)
	QaMarkers.marker("GAME", "BOOT", {"seed": rng_seed})


## Mulai game baru: reset ekonomi ke state awal data, fase COMMAND.
func start_new_game(seed_value: int = 0) -> void:
	if seed_value > 0:
		rng_seed = seed_value
	SeededRng.set_seed(rng_seed)
	Economy.reset()
	_change_phase(Phase.COMMAND)
	QaMarkers.marker("GAME", "NEW", {"seed": rng_seed})


func get_phase_name() -> String:
	return Phase.keys()[phase]


## M3 #4: kembali ke menu utama (dari pause: save dulu oleh pemanggil).
## Fase MENU = base idle di belakang panel menu (GAMEPLAY_FLOW.md §3 Frame 3).
func return_to_menu() -> void:
	_change_phase(Phase.MENU)


func is_in_menu() -> bool:
	return phase == Phase.MENU


## M3 #4: masuk gameplay dari menu utama (Play/Continue) — mencetak marker
## GAME:PHASE seperti transisi fase lain (bukan set diam-diam).
func enter_gameplay() -> void:
	if phase != Phase.COMMAND:
		_change_phase(Phase.COMMAND)


## Dipakai SaveSystem saat load (tanpa marker ganda).
func set_phase_direct(p: int) -> void:
	phase = p as Phase


func _change_phase(p: Phase) -> void:
	phase = p
	QaMarkers.marker("GAME", "PHASE", {"phase": get_phase_name()})


func _on_combat_started(_seed: int) -> void:
	if phase == Phase.COMMAND:
		_change_phase(Phase.COMBAT)


func _on_combat_finished(_result: BattleResult) -> void:
	if phase == Phase.COMBAT:
		_change_phase(Phase.COMMAND)
