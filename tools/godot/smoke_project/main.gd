extends Node3D
## Toolchain smoke test: boots the real Godot engine, builds a small 3D
## scene at runtime, and prints a marker line that the vision capture tool
## waits for before taking the verification screenshot.

var _cube: MeshInstance3D


func _ready() -> void:
	var version_info := Engine.get_version_info()
	print("GODOT_ENGINE_VERSION: ", version_info["string"])
	print("GODOT_PROJECT: ", ProjectSettings.get_setting("application/config/name"))
	print("LAST_SPACE_TOOLCHAIN_SMOKE: READY")

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	camera.position = Vector3(0, 2.5, 7)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	var light := DirectionalLight3D.new()
	light.name = "DirectionalLight3D"
	light.position = Vector3(4, 6, 4)
	add_child(light)
	light.look_at(Vector3.ZERO, Vector3.UP)

	_cube = MeshInstance3D.new()
	_cube.name = "SmokeCube"
	_cube.mesh = BoxMesh.new()
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.6, 1.0)
	material.emission_enabled = true
	material.emission = Color(0.1, 0.3, 0.8)
	_cube.set_surface_override_material(0, material)
	add_child(_cube)

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.02, 0.03, 0.08)
	world.environment = env
	add_child(world)


func _process(delta: float) -> void:
	if _cube:
		_cube.rotate_y(delta * 0.8)
