class_name BuildingDef
extends Resource
## Definisi bangunan (data-driven — DATA_CONTRACTS.md §2.2).
## Tidak ada angka balance di kode game; semua di file .tres.
##
## Skala level: effective_max_hp = max_hp * level;
## production = production_per_minute * level; biaya level n = base_cost * cost_growth^(n-1).

@export var id: StringName
@export var display_name: String
@export var category: String  ## hq | economy | production | defense | research
@export var max_level: int = 10
@export var base_cost: Dictionary = {}  ## {resource: amount} untuk level 1
@export var cost_growth: float = 1.6
@export var build_time_ticks: int = 0
@export var max_hp: int = 100
@export var produces: StringName = &""  ## resource yang diproduksi, &"" jika tidak ada
@export var production_per_minute: int = 0
@export var storage_bonus: Dictionary = {}  ## tambahan storage cap saat dibangun
@export var repair_cost_per_hp: Dictionary = {}
@export var weapon_id: StringName = &""  ## diisi untuk bangunan defense yang menembak
@export var shield_pool: int = 0  ## pool serap damage (shield generator)
@export var footprint: Vector2i = Vector2i(1, 1)
@export var scene_path: String = ""  ## kosong = visual placeholder (sampai aset masuk)


func get_cost_for_level(level: int) -> Dictionary:
	var mult := pow(cost_growth, level - 1)
	var out := {}
	for res_id in base_cost.keys():
		out[res_id] = int(round(float(base_cost[res_id]) * mult))
	return out


func get_max_hp_for_level(level: int) -> int:
	return max_hp * level


func get_production_for_level(level: int) -> int:
	return production_per_minute * level


func get_shield_pool_for_level(level: int) -> int:
	return shield_pool * level
