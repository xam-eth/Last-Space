extends Node
## PlacementShowcase — foto bukti LOGIKA BUILD M3 #9 (mode `?mode=place`).
## Menjalankan alur NYATA lewat API arena: katalog → BANGUN → mode penempatan
## (hantu) di posisi SAH dan TIDAK SAH, lalu berhenti dengan hantu terlihat
## supaya capture menangkap bilah LETAKKAN + warna validasi.
## Marker: QA:PLACE:READY step=valid|invalid

var _base: Node


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for c in get_parent().get_children():
		if c.has_method("get_hud"):
			_base = c
	if _base == null:
		print("QA:PLACE:READY step=none error=base_scene_tidak_ada")
		return
	var step := "valid"
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		if a.begins_with("--step="):
			step = a.substr(7)
	## Masuk mode penempatan seperti pemain: buka katalog → tekan BANGUN.
	var hud: Control = _base.call("get_hud")
	hud.call("open_build_menu")
	await get_tree().process_frame
	var bm: Control = hud.call("get_build_menu")
	bm.call("select", &"laser_turret")
	bm.call("press_build")
	await get_tree().process_frame
	await get_tree().process_frame
	## Pindahkan hantu: sah = dalam plataran, tidak sah = di luar plataran
	if step == "invalid":
		_base.call("update_placement_at", Vector3(60.0, 0, 0))
	else:
		## Pilih titik dunia yang proyeksinya JATUH DI TENGAH layar (bukan di tepi
		## atau di bawah bilah penempatan) supaya hantu terlihat jelas di foto.
		var cam: Camera3D = _base.get("camera")
		var best := Vector3(10.0, 0, 10.0)
		var best_score := -1.0
		for gx in range(-24, 25, 4):
			for gz in range(-16, 25, 4):
				var w := Vector3(gx, 0, gz)
				if not bool((SystemRefs.building_system() as BuildingSystem).can_place(&"laser_turret", w)["ok"]):
					continue
				var sp: Vector2 = cam.unproject_position(w)
				if sp.y < 400.0 or sp.y > 530.0 or sp.x < 420.0 or sp.x > 980.0:
					continue
				## jangan menempel bangunan yang sudah ada (hantu harus terbaca jelas)
				var too_close := false
				for b in (SystemRefs.building_system() as BuildingSystem).get_all_buildings():
					if b.position.distance_to(w) < 9.0:
						too_close = true
						break
				if too_close:
					continue
				var score := 530.0 - absf(sp.y - 470.0) - absf(sp.x - 700.0) * 0.4
				if score > best_score:
					best_score = score
					best = w
		_base.call("update_placement_at", best)
	await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	var st: Dictionary = _base.call("placement_state")
	print("QA:PLACE:READY step=%s id=%s valid=%s reason=%s pos=%s bar=%s" % [
		step, String(st["id"]), str(st["valid"]), String(st["reason"]), String(st["pos"]),
		str(hud.call("placement_bar_visible"))])
	## diamkan: kamera & hantu tidak bergerak supaya foto deterministik
	set_process(false)
