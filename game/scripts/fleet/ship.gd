class_name Ship
extends Node3D
## Ship — satu unit armada: HP + kondisi. Statistik asal ShipDef (data).

@export var def: ShipDef

var instance_id: String = ""
var hp: int = 0

var _mesh: MeshInstance3D


func _ready() -> void:
	if def != null:
		_create_placeholder_visual()


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


func _create_placeholder_visual() -> void:
	# Visual sementara sampai aset GLB masuk (ASSET_PIPELINE.md).
	_mesh = MeshInstance3D.new()
	_mesh.mesh = BoxMesh.new()
	(_mesh.mesh as BoxMesh).size = Vector3(1.2, 0.5, 2.0)  ## moncong ke -Z (depan)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.STEEL_BLUE
	_mesh.mesh.material = mat
	add_child(_mesh)
