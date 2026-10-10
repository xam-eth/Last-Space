class_name BattleInput
extends Resource
## Input simulasi pertempuran (runtime resource — DATA_CONTRACTS.md §2.7).

@export var attacker: Array[StringName] = []  ## ship ids (alien)
@export var defender_ships: Array[StringName] = []  ## ship ids (pemain)
@export var defender_turrets: Array[Dictionary] = []  ## {weapon_id, count, hp}
@export var defender_buildings: Array[Dictionary] = []  ## {instance_id, hp, max_hp}
@export var shield_hp: int = 0
@export var seed: int = 0
