extends Node3D
## BaseScene — scene utama (Command Mode): kamera, base, sistem, HUD.
## Menempatkan Command Core saat game baru (idempotent — skip jika sudah ada,
## misal setelah load).

@onready var camera: Camera3D = $Camera3D


func _ready() -> void:
	camera.position = Vector3(0, 18, 26)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var bs: BuildingSystem = $BuildingSystem
	if bs.count_of(&"command_core") == 0:
		bs.place_building(&"command_core", Vector3(0, 0, 0))
	QaMarkers.marker("SCENE", "READY", {})
