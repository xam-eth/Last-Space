extends RefCounted
## test_build_logic.gd — M3 #9: LOGIKA PENEMPATAN bangunan ala game building
## strategi (riset CoC/Last War; lihat docs/m3_9/REPORT_M3_9.md §2).
##
## Yang diuji dari STATE NYATA (bukan asumsi):
##   1. Validasi penempatan: di luar plataran ditolak, tumpang tindih ditolak,
##      keduanya dengan ALASAN yang bisa dibaca UI.
##   2. Snap grid: posisi selalu terkunci ke sel grid.
##   3. Rencana tata letak: inti di tengah, 4 turret menutup inti (jarak ≤
##      jangkauan DATA), produksi di lapis luar, tanpa tumpang tindih.
##   4. apply_layout_plan idempoten (tidak menggandakan bangunan).
##   5. move_building: sah = pindah, tidak sah = posisi lama TIDAK rusak.

func run(t) -> void:
	var bs: BuildingSystem = SystemRefs.building_system()
	var core_def := GameData.get_building_def(&"command_core")
	t.check("bl.def_core", core_def != null)
	if core_def == null:
		return

	# --- 0. prasyarat: inti harus ADA di (0,0) (di game dipasang BaseScene) ---
	if bs.count_of(&"command_core") == 0:
		bs.place_building(&"command_core", Vector3(0, 0, 0))
	t.check("bl.ada_inti", bs.count_of(&"command_core") >= 1,
		"inti=%d" % bs.count_of(&"command_core"))

	# --- 1. validasi area: luar plataran & tumpang tindih (dengan alasan) ---
	var far := bs.can_place(&"energy_reactor", Vector3(80, 0, 0))
	t.check("bl.tolak_luar_plataran", not bool(far["ok"]), "reason=%s" % String(far["reason"]))
	t.check_eq("bl.alasan_luar_plataran", "di_luar_plataran", String(far["reason"]))
	var ok_pos := bs.can_place(&"energy_reactor", Vector3(28, 0, 0))
	t.check("bl.terima_dalam_plataran", bool(ok_pos["ok"]), "reason=%s" % String(ok_pos["reason"]))
	## inti sudah ada di (0,0) → area yang sama harus DITOLAK
	var on_core := bs.can_place(&"energy_reactor", Vector3(0, 0, 0))
	t.check("bl.tolak_tumpang_tindih", not bool(on_core["ok"]), "reason=%s" % String(on_core["reason"]))
	t.check_eq("bl.alasan_sudah_terisi", "sudah_terisi", String(on_core["reason"]))
	var unknown := bs.can_place(&"tidak_ada_bangunan", Vector3(20, 0, 20))
	t.check("bl.tolak_def_tidak_kenal", not bool(unknown["ok"]), "reason=%s" % String(unknown["reason"]))

	# --- 2. snap grid (posisi selalu di kelipatan GRID_SPACING) ---
	var snapped := bs.snap_to_grid(Vector3(7.3, 0, -4.6))
	t.check("bl.snap_ke_grid",
		absf(fposmod(snapped.x, BuildingSystem.GRID_SPACING)) < 0.001
			and absf(fposmod(snapped.z, BuildingSystem.GRID_SPACING)) < 0.001,
		"7,3/-4,6 → %s (spacing %.1f)" % [str(snapped), BuildingSystem.GRID_SPACING])

	# --- 3. rencana tata letak: inti ditutup turret, tanpa tumpang tindih ---
	bs.apply_layout_plan()
	var plan := bs.layout_plan()
	var turrets := bs.get_buildings_of(&"laser_turret")
	t.check("bl.plan_turret_4", turrets.size() >= 4, "turret=%d" % turrets.size())
	var cov := bs.core_covered_by_defense()
	t.check("bl.inti_ditutup_pertahanan", bool(cov["ok"]), String(cov["detail"]))
	## produksi harus di lapis LUAR turret (strategi: pertahanan lapis tengah)
	var react := bs.get_buildings_of(&"energy_reactor")
	if not react.is_empty():
		var d_turret := 0.0
		for tt in turrets:
			d_turret = maxf(d_turret, tt.position.length())
		t.check("bl.produksi_di_lapis_luar", react[0].position.length() > d_turret,
			"produksi %.1f > turret %.1f" % [react[0].position.length(), d_turret])
	## tidak ada dua bangunan yang berbagi sel grid
	var cells := {}
	var dup := 0
	for b in bs.get_all_buildings():
		var gx := int(floor(b.position.x / BuildingSystem.GRID_SPACING + 0.5))
		var gz := int(floor(b.position.z / BuildingSystem.GRID_SPACING + 0.5))
		var key := "%d,%d" % [gx, gz]
		if cells.has(key):
			dup += 1
		cells[key] = true
	t.check("bl.tanpa_duplikat_sel", dup == 0, "bangunan=%d sel=%d duplikat=%d" % [
		bs.get_all_buildings().size(), cells.size(), dup])
	## semua isi rencana lolos validasi area (rintisan tidak melanggar aturan sendiri)
	var violations: Array[String] = []
	for item in plan:
		var chk := bs.can_place(item["id"], bs.snap_to_grid(item["pos"]))
		if not bool(chk["ok"]) and String(chk["reason"]) != "sudah_terisi":
			violations.append("%s:%s" % [item["id"], chk["reason"]])
	t.check("bl.rencana_valid_terhadap_aturan", violations.is_empty(), str(violations))

	# --- 4. idempoten: memanggil ulang rencana tidak menggandakan ---
	var n_before := bs.get_all_buildings().size()
	var placed_again := bs.apply_layout_plan()
	t.check("bl.idempoten", placed_again == 0 and bs.get_all_buildings().size() == n_before,
		"ditambah=%d jumlah %d→%d" % [placed_again, n_before, bs.get_all_buildings().size()])

	# --- 5. move_building: sah pindah, tidak sah TIDAK merusak posisi lama ---
	var reactor: Building = bs.get_buildings_of(&"energy_reactor")[0] if not react.is_empty() else null
	if reactor != null:
		var old_pos := reactor.position
		var ok_move := bs.move_building(reactor.instance_id, Vector3(24, 0, -20))
		t.check("bl.pindah_sah", bool(ok_move["ok"]) and reactor.position.distance_to(Vector3(24, 0, -20)) < 0.01,
			"pos=%s" % str(reactor.position))
		var to_core := bs.move_building(reactor.instance_id, Vector3(0, 0, 0))
		t.check("bl.pindah_ke_area_terisi_ditolak", not bool(to_core["ok"]),
			"reason=%s" % String(to_core["reason"]))
		t.check("bl.posisi_lama_pulih_setelah_tolak", reactor.position.distance_to(Vector3(24, 0, -20)) < 0.01,
			"pos=%s (harus tetap 24,-20)" % str(reactor.position))
		## setelah ditolak, kotak lama tetap terisi (tidak bocor)
		var leak := bs.can_place(&"laser_turret", Vector3(24, 0, -20))
		t.check("bl.sel_tidak_bocor_setelah_tolak", not bool(leak["ok"]),
			"reason=%s" % String(leak["reason"]))
		bs.move_building(reactor.instance_id, old_pos)

	# --- 6. penempatan gameplay divalidasi + marker QA:BUILD:REJECT ---
	var rej := bs.place_building_checked(&"energy_reactor", Vector3(0, 0, 0))
	t.check("bl.place_checked_menolak_tumpang", not bool(rej["ok"]), "reason=%s" % String(rej["reason"]))
	var good := bs.place_building_checked(&"energy_reactor", Vector3(28, 0, 28))
	t.check("bl.place_checked_menerima_valid", bool(good["ok"]), "instance=%s" % str(good["instance"]))
	## bersihkan bangunan uji supaya tidak mengganggu suite lain
	var extra: Building = bs.get_building(String(good["instance"])) if good["instance"] != null else null
	if extra != null:
		bs.buildings.erase(extra.instance_id)
		extra.queue_free()
