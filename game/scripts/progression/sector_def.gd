class_name SectorDef
extends Resource
## Definisi sektor/teritori (data-driven — DATA_CONTRACTS.md §2.6).
## unlock_condition: "start" (terbuka awal) atau "defend_home_base_N" (terbuka
## setelah pemain berhasil mempertahankan base untuk ke-N kalinya).

@export var id: StringName
@export var display_name: String
@export var unlock_condition: String
@export var rewards: Dictionary = {}
@export var threat: int
@export var waves: Array[StringName] = []
