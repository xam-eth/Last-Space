extends Node3D
## BaseScene — scene utama (Command Mode): kamera, base, sistem, HUD.
## Menempatkan Command Core saat game baru (idempotent — skip jika sudah ada,
## misal setelah load).
##
## M3 #1: klik bangunan di arena 3D → indikator panah hijau + selection panel
## (HUD.select_building, pola Doomsday F4 — GAMEPLAY_FLOW.md §0/§3).
## Pick pakai proyeksi kamera (unproject) + nearest — tanpa physics server,
## robust di build WASM dan deterministik untuk test.

@onready var camera: Camera3D = $Camera3D
@onready var hud: Control = $HUD/HUDControl

const PICK_RADIUS_PX := 96.0  ## radius pick 96px @1280 lebar (~7,5% lebar layar)

var _arrow: MeshInstance3D
var _arrow_target: String = ""
var _bob_t := 0.0


func _ready() -> void:
	camera.position = Vector3(0, 18, 26)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	var bs: BuildingSystem = $BuildingSystem
	if bs.count_of(&"command_core") == 0:
		bs.place_building(&"command_core", Vector3(0, 0, 0))
	_create_arrow()
	EventBus.building_destroyed.connect(_on_building_destroyed)
	QaMarkers.marker("SCENE", "READY", {})


# ------------------------------------------------------------ arrow ----
func _create_arrow() -> void:
	## Panah hijau di atas bangunan terpilih (indikator, pola Doomsday F4).
	_arrow = MeshInstance3D.new()
	_arrow.name = "SelectionArrow"
	var prism := PrismMesh.new()
	prism.size = Vector3(0.9, 1.4, 0.9)
	_arrow.mesh = prism
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 1.0, 0.53)
	mat.emission_enabled = true
	mat.emission = Color(0.30, 1.0, 0.53)
	mat.emission_energy_multiplier = 1.5
	_arrow.mesh.material = mat
	_arrow.rotation_degrees = Vector3(180, 0, 0)  ## prisma default apex +Y → ke bawah
	_arrow.visible = false
	add_child(_arrow)


func _process(delta: float) -> void:
	if not _arrow.visible or _arrow_target == "":
		return
	var bs: BuildingSystem = $BuildingSystem
	var b := bs.get_building(_arrow_target)
	if b == null or b.is_destroyed():
		deselect()
		return
	_bob_t += delta
	## tinggi bangunan dari footprint (placeholder visual 1.5×footprint, y/2)
	var h := maxf(1.0, float(b.def.footprint.y)) * 1.5
	_arrow.position = b.position + Vector3(0, h / 2.0 + 1.2 + sin(_bob_t * 3.0) * 0.15, 0)
	_arrow.rotation_degrees = Vector3(180, _bob_t * 60.0, 0)  ## spin pelan


# ------------------------------------------------------------- pick ----
func _unhandled_input(event: InputEvent) -> void:
	if hud != null and (hud.is_build_menu_open() or hud.is_ship_menu_open() or hud.is_pause_menu_open()):
		return  ## modal terbuka — jangan pick
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_pick(mb.position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_pick(st.position)


func _pick(screen_pos: Vector2) -> void:
	## Proyeksi semua bangunan ke layar, pilih terdekat dalam radius pick.
	var bs: BuildingSystem = $BuildingSystem
	var best: Building = null
	var best_d := PICK_RADIUS_PX
	for b in bs.get_all_buildings():
		if b.is_destroyed():
			continue
		var sp := camera.unproject_position(b.global_position + Vector3(0, 1.0, 0))
		var d := sp.distance_to(screen_pos)
		if d <= best_d:
			best_d = d
			best = b
	if best != null:
		select_building(best)
	else:
		deselect()


func select_building(b: Building) -> void:
	_arrow_target = b.instance_id
	_arrow.visible = true
	_bob_t = 0.0
	if hud != null:
		hud.select_building(b.instance_id)


func deselect() -> void:
	_arrow_target = ""
	_arrow.visible = false
	if hud != null:
		hud.deselect_building()


func get_arrow_target() -> String:
	return _arrow_target


func _on_building_destroyed(instance_id: String) -> void:
	if instance_id == _arrow_target:
		deselect()
