class_name Building
extends Node3D
## Building — satu instance bangunan: HP, level, state, produksi, visual.
## State: NORMAL / DAMAGED / CRITICAL / DESTROYED (Asset_Request_List.md §18).
##
## Produksi memakai integer math (exact, deterministik): total produksi =
## production_per_minute * level * prod_ticks / (60 * TICKS_PER_SECOND);
## state rusak → total dibagi 2.

enum State { NORMAL, DAMAGED, CRITICAL, DESTROYED }

@export var def: BuildingDef

var instance_id: String = ""
var level: int = 1
var hp: int = 0
var state: State = State.NORMAL
var prod_ticks: int = 0   ## tick aktif sejak counter terakhir di-reset
var prod_earned: int = 0  ## total yang sudah masuk ke Economy

var _mesh: MeshInstance3D
var _label: Label3D  ## M3.5: nama + level di atas bangunan (kotak jelas itu apa)


func _ready() -> void:
	if def != null:
		_create_placeholder_visual()
		_update_label()
		_apply_state_visual()


func setup(p_def: BuildingDef, p_instance_id: String) -> void:
	def = p_def
	instance_id = p_instance_id
	level = 1
	hp = def.max_hp
	_update_state()


func get_max_hp() -> int:
	return def.get_max_hp_for_level(level)


## Naik level. Upgrade memulihkan struktur (HP penuh di max baru).
func upgrade() -> void:
	var old_level := level
	level = mini(level + 1, def.max_level)
	hp = get_max_hp()
	_update_state()
	EventBus.building_upgraded.emit(instance_id, old_level, level)
	_update_label()
	_apply_state_visual()


func take_damage(amount: int) -> void:
	if state == State.DESTROYED or amount <= 0:
		return
	hp = maxi(0, hp - amount)
	_update_state()
	EventBus.building_damaged.emit(instance_id, hp, State.keys()[state])
	if state == State.DESTROYED:
		EventBus.building_destroyed.emit(instance_id)
	_apply_state_visual()


## Perbaiki bangunan. Bangunan HANCUR pun bisa diperbaiki (repair bay membangun
## ulang struktur) — biaya dihitung dari HP yang dipulihkan.
func repair(amount_hp: int) -> void:
	if amount_hp <= 0:
		return
	hp = mini(get_max_hp(), hp + amount_hp)
	_update_state()
	EventBus.building_repaired.emit(instance_id, hp)
	_apply_state_visual()


func is_destroyed() -> bool:
	return state == State.DESTROYED


# --- Produksi (integer-exact, lihat header class) ---

func tick_production() -> void:
	prod_ticks += 1


func get_production_total() -> int:
	if def.produces == &"" or state == State.DESTROYED:
		return 0
	var base := int(def.get_production_for_level(level)) * prod_ticks / (60 * TimeSystem.TICKS_PER_SECOND)
	if state == State.NORMAL:
		return base
	return base / 2  ## rusak → produksi turun


func reset_production_counters() -> void:
	prod_ticks = 0
	prod_earned = 0


func _update_state() -> void:
	var max_hp := get_max_hp()
	var ratio := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	var new_state := State.NORMAL
	if hp <= 0:
		new_state = State.DESTROYED
	elif ratio <= 0.25:
		new_state = State.CRITICAL
	elif ratio <= 0.6:
		new_state = State.DAMAGED
	state = new_state


func get_state() -> Dictionary:
	return {
		"id": def.id,
		"instance": instance_id,
		"level": level,
		"hp": hp,
		"state": State.keys()[state],
		"position": [position.x, position.z],
		"prod_ticks": prod_ticks,
		"prod_earned": prod_earned,
	}


func set_state(s: Dictionary) -> void:
	level = int(s.get("level", 1))
	hp = int(s.get("hp", get_max_hp()))
	prod_ticks = int(s.get("prod_ticks", 0))
	prod_earned = int(s.get("prod_earned", 0))
	_update_state()
	_update_label()
	_apply_state_visual()


func _create_placeholder_visual() -> void:
	# Visual sementara (sampai aset GLB masuk — lihat ASSET_PIPELINE.md).
	# Ukuran mengikuti footprint; warna mengikuti kategori.
	_mesh = MeshInstance3D.new()
	var size := Vector3(maxf(1.0, float(def.footprint.x)) * 1.5, 1.5, maxf(1.0, float(def.footprint.y)) * 1.5)
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = _category_color()
	mat.emission_enabled = true
	mat.emission = _category_color() * 0.45  ## glow kategori (M3.5: tidak polos)
	mat.emission_energy_multiplier = 0.7
	_mesh.mesh.material = mat
	_mesh.position = Vector3(0, size.y / 2.0, 0)
	add_child(_mesh)
	# Label 3D: nama + level di atas bangunan (billboard, selalu terbaca)
	_label = Label3D.new()
	_label.name = "NameLabel"
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.012  ## ~1.2cm per pixel → teks ~0.5m
	_label.font_size = 40
	_label.outline_size = 6
	_label.outline_color = Color(0.02, 0.03, 0.08, 0.9)
	_label.modulate = Color(0.92, 0.96, 1.0)
	_label.position = Vector3(0, size.y / 2.0 + 0.7, 0)
	add_child(_label)


func _update_label() -> void:
	if _label != null and def != null:
		_label.text = "%s  Lv%d" % [def.display_name, level]


func _apply_state_visual() -> void:
	if _mesh == null:
		return
	var mat := _mesh.mesh.material as StandardMaterial3D
	if mat == null:
		return
	var c := Color.BLACK
	match state:
		State.NORMAL:
			c = _category_color()
		State.DAMAGED:
			c = _category_color().lerp(Color.ORANGE, 0.5)
		State.CRITICAL:
			c = Color.DARK_RED
		State.DESTROYED:
			c = Color.BLACK
	mat.albedo_color = c
	if mat.emission_enabled:
		mat.emission = c * 0.45  ## glow ikut state (rusak lebih redup)


func _category_color() -> Color:
	match def.category:
		"hq":
			return Color.GOLD
		"economy":
			return Color.CYAN
		"production":
			return Color.GREEN
		"defense":
			return Color.ORANGE_RED
		"research":
			return Color.PURPLE
		_:
			return Color.GRAY
