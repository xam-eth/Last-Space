class_name CombatVisualizer
extends Node3D
## CombatVisualizer — menampilkan hasil BattleResult (simulasi aktual) di 3D.
## TIDAK mengarang hasil: jumlah kapal dari BattleInput, kehancuran dari
## BattleResult (AI_GOVERNANCE.md §8, RISK_ANALYSIS.md bottleneck #5).
##
## Visual sementara (box) sampai aset masuk; yang penting: state akhir sama
## persis dengan hasil simulasi.

var _attacker_meshes: Array[MeshInstance3D] = []
var _defender_meshes: Array[MeshInstance3D] = []
var _explosions: Array[MeshInstance3D] = []
var _animating := false
var _anim_elapsed := 0.0
var _anim_duration := 2.5
var _pending_result: BattleResult = null
var _pending_input: BattleInput = null


func _ready() -> void:
	add_to_group("system_combat_visualizer")
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.combat_finished.connect(_on_combat_finished)


func _process(delta: float) -> void:
	if not _animating:
		return
	_anim_elapsed += delta
	# Gerakkan kapal attacker menuju base (origin)
	for m in _attacker_meshes:
		if is_instance_valid(m):
			var dir := (Vector3.ZERO - m.position).normalized()
			m.position += dir * 12.0 * delta
			m.rotate_y(delta * 2.0)
	if _anim_elapsed >= _anim_duration:
		_animating = false
		_finish_visual()


func _on_combat_started(_seed: int) -> void:
	var wd := SystemRefs.wave_director()
	if wd == null or wd.current_input == null:
		return
	_pending_input = wd.current_input
	_clear_visuals()
	# Spawn kapal attacker (merah) dari arc, defender (biru) dekat base
	var n_attackers := _pending_input.attacker.size()
	for i in n_attackers:
		var m := _make_ship_mesh(Color.RED)
		var angle := float(i) / float(maxi(1, n_attackers)) * TAU
		m.position = Vector3(cos(angle) * 25.0, 2.0, sin(angle) * 25.0)
		add_child(m)
		_attacker_meshes.append(m)
	var n_defenders := _pending_input.defender_ships.size()
	for i in n_defenders:
		var m := _make_ship_mesh(Color.STEEL_BLUE)
		m.position = Vector3(-6.0 + i * 2.0, 1.0, 6.0)
		add_child(m)
		_defender_meshes.append(m)
	_anim_elapsed = 0.0
	_animating = true
	QaMarkers.marker("COMBAT", "VISUAL_START", {"attackers": n_attackers, "defenders": n_defenders})


func _on_combat_finished(result: BattleResult) -> void:
	_pending_result = result


func _finish_visual() -> void:
	if _pending_result == null:
		return
	var result := _pending_result
	# Hapus kapal yang hancur sesuai hasil simulasi (NYATA, bukan animasi)
	var attacker_losses := 0
	for k in result.attacker_losses.keys():
		attacker_losses += int(result.attacker_losses[k])
	var defender_losses := 0
	for k in result.defender_ship_losses.keys():
		defender_losses += int(result.defender_ship_losses[k])
	_remove_meshes(_attacker_meshes, attacker_losses)
	_remove_meshes(_defender_meshes, defender_losses)
	# Explosion marker di kapal yang hancur
	_spawn_explosions(attacker_losses + defender_losses)
	QaMarkers.marker("COMBAT", "VISUAL_DONE", {
		"attacker_losses": attacker_losses,
		"defender_losses": defender_losses,
		"winner": result.winner,
	})
	_pending_result = null
	_pending_input = null
	EventBus.combat_visual_done.emit(result)


func _remove_meshes(pool: Array[MeshInstance3D], n: int) -> void:
	var removed := 0
	for m in pool:
		if removed >= n:
			break
		if is_instance_valid(m):
			m.queue_free()
			removed += 1


func _spawn_explosions(n: int) -> void:
	for i in mini(n, 6):
		var m := MeshInstance3D.new()
		m.mesh = SphereMesh.new()
		(m.mesh as SphereMesh).radius = 0.6
		(m.mesh as SphereMesh).height = 1.2
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color.ORANGE
		mat.emission_enabled = true
		mat.emission = Color.ORANGE
		m.mesh.material = mat
		m.position = Vector3(randf_range(-8, 8), 1.5, randf_range(-4, 8))
		add_child(m)
		_explosions.append(m)


func _make_ship_mesh(color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = BoxMesh.new()
	(m.mesh as BoxMesh).size = Vector3(1.0, 0.5, 1.8)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	m.mesh.material = mat
	return m


func _clear_visuals() -> void:
	for m in _attacker_meshes:
		if is_instance_valid(m):
			m.queue_free()
	for m in _defender_meshes:
		if is_instance_valid(m):
			m.queue_free()
	for m in _explosions:
		if is_instance_valid(m):
			m.queue_free()
	_attacker_meshes.clear()
	_defender_meshes.clear()
	_explosions.clear()
