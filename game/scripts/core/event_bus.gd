extends Node
## EventBus — hub signal global. Seluruh komunikasi antarmodul game melewati
## sini (TECH_ARCHITECTURE.md §5). UI hanya mendengar, tidak pernah memancarkan
## perubahan state.

# Ekonomi
signal resource_changed(resource_id: StringName, old_amount: int, new_amount: int, delta: int)

# Bangunan
signal building_placed(building_id: StringName, instance_id: String, position: Vector3)
signal building_upgraded(instance_id: String, old_level: int, new_level: int)
signal building_damaged(instance_id: String, hp: int, state: String)
signal building_destroyed(instance_id: String)
signal building_repaired(instance_id: String, hp: int)

# Produksi
signal production_completed(kind: String, id: StringName, amount: int)

# Armada
signal ship_built(ship_id: StringName, instance_id: String)
signal ship_destroyed(instance_id: String)
signal fleet_changed()

# Pertempuran
signal wave_incoming(wave_id: StringName, eta_ticks: int)
signal combat_started(seed: int)
signal combat_finished(result: BattleResult)
signal combat_visual_done(result: BattleResult)

# Progresi
signal territory_unlocked(sector_id: StringName)
signal reward_granted(rewards: Dictionary, source: String)

# Quest (M3 #1 — quest panel kiri tengah, pola Doomsday F3/F8)
signal quest_progress(quest_id: StringName, current: int, target: int)
signal quest_completed(quest_id: StringName)

# Pengaturan (M3 #5): layar UI mendengarkan, SettingsSystem yang mengubah.
signal settings_changed(key: String, value)

# --- M3 #9: mode PENEMPATAN (ghost) — logika build ala game strategi -------
## UI meminta masuk mode penempatan; pemilik arena (BaseScene) yang mengeksekusi
## sehingga biaya baru dibayar saat pemain KONFIRMASI (pola CoC: shop → ghost →
## centang). Marker QA:BUILD:* mencatat seluruh alur untuk gate/verifikasi.
signal placement_requested(def_id: StringName)
signal placement_finished(def_id: StringName, ok: bool, reason: String)
## M3 #7: umpan balik aksi yang DITOLAK (temuan pemain: tombol ter-disabled tanpa
## penjelasan = "tidak bisa diklik"). Menu mengirim alasan; HUD menampilkan toast
## supaya pemain tahu APA yang kurang (bukan diam saja).
signal ui_message(text: String, level: String)

# ------------------------------------------------------- kamera (M3 #6) ----
## Permintaan dari HUD (tombol zoom eksplisit — pelengkap gesture, standar
## Material "gestures supplement other explicit input methods, like buttons").
signal camera_zoom_requested(zoom_in: bool)
signal camera_reset_requested()
## Laporan dari CameraRig ke HUD (chip "x1,0" ikut state nyata).
signal camera_changed(scale: float, pan: Vector2)

# Save/load
signal game_saved(slot: String)
signal game_loaded(slot: String)

# M3 #4: navigasi antar layar utama (pause → menu utama; menu → gameplay).
signal main_menu_requested()
