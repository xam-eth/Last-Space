class_name ShipDef
extends Resource
## Definisi kapal (data-driven — DATA_CONTRACTS.md §2.3).

@export var id: StringName
@export var display_name: String
@export var ship_class: String  ## fighter | corvette | frigate | capital
@export var role: String  ## interceptor | bomber | support | ...
@export var max_hp: int
@export var speed: float  ## unit/detik (game space)
@export var turn_rate: float  ## radian/detik
@export var weapon_id: StringName  ## referensi WeaponDef (wajib resolve)
@export var weapon_count: int = 1
@export var armor: int
@export var cost: Dictionary = {}
@export var build_time_ticks: int
@export var repair_cost_per_hp: Dictionary = {}
@export var fleet_supply: int
@export var model_path: String = ""  ## kosong = visual placeholder
