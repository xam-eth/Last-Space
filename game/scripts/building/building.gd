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
var _model: Node3D  ## M3.7: struktur komposit (BuildingModel) — bukan kotak polos
var _label: Label3D  ## M3.5: nama + level di atas bangunan
var _t := 0.0


func _ready() -> void:
	if def != null:
		_create_visual()
		_update_label()
		_apply_state_visual()


func _process(delta: float) -> void:
	## Animasi idle struktur (antena/stabilizer berputar, inti berdenyut).
	if _model == null:
		return
	_t += delta
	BuildingModel.animate(_model, delta, _t)


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


func set_label_visible(v: bool) -> void:
	## Decluttering label dunia (M3.7): label disembunyikan bila bertumpuk dengan
	## label bangunan lain di layar — kritik user "teks masih bertumpuk" berlaku
	## juga untuk teks di canvas 3D, bukan hanya HUD.
	if _label != null and _label.visible != v:
		_label.visible = v


func label_visible() -> bool:
	return _label != null and _label.visible


func label_text() -> String:
	return _label.text if _label != null else ""


func label_extent_px() -> Vector2:
	## Perkiraan ukuran kotak label di layar (design px): Label3D font 44 dengan
	## pixel_size 0.022 ≈ 12 px per karakter pada kamera default gameplay.
	## Dipakai untuk deteksi tumpuk ANTAR label secara geometris (M3.7).
	if _label == null:
		return Vector2.ZERO
	return Vector2(maxf(60.0, float(_label.text.length()) * 12.0), 40.0)


func label_anchor() -> Vector3:
	## Titik jangkar label di ruang dunia (untuk proyeksi ke layar + cek tumpuk).
	if _label == null:
		return global_position + Vector3(0, 2.0, 0)
	return _label.global_position


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


func _create_visual() -> void:
	## M3.7: struktur komposit per tipe (BuildingModel). Bila tipe belum punya
	## model, JATUH ke kotak lama (fallback aman — tidak pernah gagal render).
	_model = BuildingModel.make(def.id, def.footprint)
	if _model != null:
		_model.name = "Model"
		add_child(_model)
		var n_mesh := _model.find_children("*", "MeshInstance3D", true, false).size()
		QaMarkers.marker("MODEL", "BUILD", {"id": def.id, "meshes": n_mesh,
			"emissive": _emissive_count()})
		var top := _model_top() + 0.7
		_label = Label3D.new()
		_label.name = "NameLabel"
		_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_label.pixel_size = 0.022  ## M3.7: terbaca dari kamera gameplay (0,015,21)
		_label.font_size = 44
		_label.outline_size = 8
		_label.outline_color = Color(0.02, 0.03, 0.08, 0.9)
		_label.modulate = Color(0.92, 0.96, 1.0)
		_label.position = Vector3(0, top, 0)
		add_child(_label)
		return
	# ---- fallback: kotak kategori (perilaku lama) ----
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


func _emissive_count() -> int:
	## Bukti struktur punya aksen emissive (bukan kotak mati).
	var n := 0
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).mesh.material as StandardMaterial3D
		if mat != null and mat.emission_enabled:
			n += 1
	return n


func _model_top() -> float:
	## Tinggi puncak struktur (untuk menaruh label) — dihitung dari AABB mesh.
	var top := 1.0
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D)
		var box := m.get_aabb()
		top = maxf(top, m.position.y + box.end.y)
	return top


func _update_label() -> void:
	if _label != null and def != null:
		_label.text = "%s  Lv%d" % [def.display_name, level]


func _apply_state_visual() -> void:
	var base := _category_color()
	var c := Color.BLACK
	var glow := 0.45
	match state:
		State.NORMAL:
			c = base
		State.DAMAGED:
			c = base.lerp(Color.ORANGE, 0.5)
			glow = 0.3
		State.CRITICAL:
			c = Color.DARK_RED
			glow = 0.18
		State.DESTROYED:
			c = Color.BLACK
			glow = 0.0
	if _model != null:
		## Struktur komposit: warna state hanya untuk DAMAGED ke bawah supaya
		## warna khas tiap bagian (metal cyan/amber/hijau) tetap terbaca normal;
		## rusak/kritis/hancur = tint menyeluruh (terbaca jelas dari jauh).
		if state != State.NORMAL:
			BuildingModel.tint(_model, c, glow)
		return
	if _mesh == null:
		return
	var mat := _mesh.mesh.material as StandardMaterial3D
	if mat == null:
		return
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
