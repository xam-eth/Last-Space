class_name BattleResult
extends Resource
## Hasil simulasi pertempuran (runtime resource — DATA_CONTRACTS.md §2.7).
## Sumber kebenaran hasil pertempuran; visualizer menampilkan hasil INI.

@export var attacker_losses: Dictionary = {}  ## {ship_id: count}
@export var defender_ship_losses: Dictionary = {}  ## {ship_id: count}
@export var turret_damage: Dictionary = {}  ## {turret_index: damage}
@export var shield_damage: int = 0
@export var building_damage: Dictionary = {}  ## {building_instance: damage}
@export var duration_ticks: int = 0
@export var winner: String = ""  ## "attacker" | "defender" | "draw"
@export var seed: int = 0
