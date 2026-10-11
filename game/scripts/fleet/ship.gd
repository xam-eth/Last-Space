class_name Ship
extends Node3D
## Ship — satu unit armada: HP + kondisi. Statistik asal ShipDef (data).
## Visual: model GLB dari ShipDef.model_path (pilot asset SHP-001, ASSET_PIPELINE.md);
## placeholder box hanya fallback jika model_path kosong / gagal load.

@export var def: ShipDef

var instance_id: String = ""
var hp: int = 0

var model_root: Node3D = null  ## instance model GLB (null = placeholder box)
var _mesh: MeshInstance3D  ## placeholder


func _ready() -> void:
	if def != null:
		_create_visual()


func setup(p_def: ShipDef, p_instance_id: String) -> void:
	def = p_def
	instance_id = p_instance_id
	hp = def.max_hp


func take_damage(amount: int) -> bool:
	## Kembalikan true jika hancur karena damage ini.
	if hp <= 0 or amount <= 0:
		return false
	hp = maxi(0, hp - amount)
	if hp <= 0:
		EventBus.ship_destroyed.emit(instance_id)
		EventBus.fleet_changed.emit()
		return true
	return false


func is_destroyed() -> bool:
	return hp <= 0


func get_state() -> Dictionary:
	return {"id": def.id, "instance": instance_id, "hp": hp}


func set_state(s: Dictionary) -> void:
	hp = int(s.get("hp", def.max_hp))


func _create_visual() -> void:
	if def.model_path != "":
		var ps := load(def.model_path) as PackedScene
		if ps != null:
			var inst := ps.instantiate() as Node3D
			add_child(inst)
			model_root = inst
			_add_engine_glow()
			_add_hull_collision(inst)
			QaMarkers.marker("SHIP", "MODEL", {"id": def.id, "path": def.model_path})
			return
		push_warning("Ship: model_path tidak bisa di-load, fallback placeholder: %s" % def.model_path)
	_create_placeholder_visual()


func _create_placeholder_visual() -> void:
	# Visual sementara sampai aset GLB masuk (ASSET_PIPELINE.md).
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = Vector3(1.2, 0.5, 2.0)  ## moncong ke -Z (depan)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.STEEL_BLUE
	_mesh.mesh.material = mat
	add_child(_mesh)
	_add_engine_glow()


func _add_engine_glow() -> void:
	## M3.5: cahaya mesin (2 bola emissive cyan) di belakang kapal — kapal
	## terlihat hidup, bukan kotak/box polos. Kapal hadap +Z (rotation.y=PI),
	## belakang = -Z world.
	for side in ["L", "R"]:
		var dx := -0.35 if side == "L" else 0.35
		var glow := MeshInstance3D.new()
		glow.name = "EngineGlow_" + side  ## nama unik (Godot rename jika duplikat)
		glow.mesh = SphereMesh.new()
		(glow.mesh as SphereMesh).radius = 0.14
		(glow.mesh as SphereMesh).height = 0.28
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.3, 0.9, 1.0)
		mat.emission_enabled = true
		mat.emission = Color(0.3, 0.9, 1.0)
		mat.emission_energy_multiplier = 2.5
		glow.mesh.material = mat
		glow.position = Vector3(dx, 0.1, -1.2)
		add_child(glow)


func _add_hull_collision(root: Node3D) -> void:
	## Collision box hull dari AABB aktual mesh (data nyata, bukan asumsi).
	## Kapal kecil = box hull (kontrak ASSET_PIPELINE.md §2).
	var aabb := MeshUtil.model_aabb(root)
	if not (aabb.size.length() > 0.001):  ## juga menolak NaN
		push_warning("Ship: AABB kosong, collision hull dilewati: %s" % def.id)
		return
	var body := StaticBody3D.new()
	body.name = "HullCollision"
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	(shape.shape as BoxShape3D).size = aabb.size
	shape.position = aabb.get_center()
	body.add_child(shape)
	root.add_child(body)
