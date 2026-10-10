class_name WaveDef
extends Resource
## Definisi wave serangan alien (data-driven — DATA_CONTRACTS.md §2.5).

@export var id: StringName
@export var composition: Dictionary = {}  ## {ship_id: count}
@export var telegraph_ticks: int  ## waktu peringatan sebelum wave tiba
@export var spawn_interval_ticks: int
@export var threat: int  ## untuk scaling kesulitan
