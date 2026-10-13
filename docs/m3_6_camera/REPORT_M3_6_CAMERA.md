# LAPORAN M3 #6 — Kamera Command Mode (zoom & pan)

Tanggal: 2026-10-13 · Branch: `arena/d80e2902-last-space` · Status: **VERIFIED**
(lihat §3 — angka gate/test/foto nyata, bukan klaim).

Format §20 `AI_GOVERNANCE.md`.

> Catatan nama: **M3 #6** = milestone ke-6 (kamera). Berkas M3.6 (design system)
> memakai nama `verify_m36.py` + `docs/m36_visual/`; berkas milestone ini memakai
> `verify_m3_6_camera.py` + `docs/m3_6_camera/` supaya tidak tertukar.

---

## 1. Milestone / Capability advanced

**Kamera Command Mode** (DEV_PLAN baris ~233, `GAMEPLAY_FLOW.md` Command Mode):
sebelumnya kamera arena **statis** (posisi (0,15,−21), look_at (0,2.6,6), fov 74;
satu-satunya gerakan = orbit idle di menu). Sekarang pemain dapat **zoom
dekat/jauh** dan **pan** di atas arena — lewat **gesture** (pinch, drag/wheel,
double-tap) **dan tombol eksplisit** (+, chip "x1,0", −) sesuai Material Design
*Gestures* ("navigational gestures supplement other explicit input methods, like
buttons").

Capability yang bekerja sekarang: dolly zoom 0,45×–1,90× dengan chip skala nyata,
pan terbatas radius 16 unit (kamera tidak bisa keluar arena), double-tap toggle
Normal↔Dekat, dan **seleksi bangunan tetap bekerja** setelah gesture (tap pendek
tidak pernah dikonsumsi sebagai gesture).

## 2. Status per komponen (label governance §2)

| Komponen | Status | Bukti |
|---|---|---|
| `CameraRig` (`game/scripts/ui/camera_rig.gd`) — zoom dolly, pan clamp, gesture, smoothing | **VERIFIED** | suite `camera_rig` (tests `cam.*`), gate `camera` 12/12 |
| Tombol zoom HUD (`ZoomCluster`: + / chip / −) 48dp berlabel | **VERIFIED** | `cam.hud_button_size_48dp min=96x96 px`, `cam.hud_button_labeled`, `QA:HUD:LABELS labeled=18` |
| Chip skala = state nyata (mis. "x1,6") + reset | **VERIFIED** | `cam.chip_updates chip=x1,9`, `cam.chip_reset_text chip=x1,0`; foto 01 (x1,6) & 02 (x0,6) |
| Zoom NYATA di piksel (bukan hanya angka log) | **VERIFIED** | platform emas 1370 → 2021 px (close) / 486 px (far); grid lantai 114 → 145,5 → 76,2 px |
| Pan NYATA di piksel | **VERIFIED** | centroid platform bergeser (135, 70) px; grid tidak berubah skala (1,04×) |
| Label dunia tidak menembus panel HUD (deklutter di semua zoom) | **VERIFIED** | `QA:SCENE:LABEL_HUD_OVERLAP count=0`; close zoom = **0 px teks** di koridor label |
| HUD tanpa tumpukan (termasuk ZoomCluster + portrait) | **VERIFIED** | `QA:HUD:OVERLAP count=0` di 1280×720 **dan** 1080×2340 (mode sempit) |
| Pinch/double-tap di perangkat sentuh nyata | **LIKELY** | gesture diuji dengan event `InputEventScreenTouch/Drag` sintetis (bukan jari nyata); perilaku di browser Android belum diuji manual |
| Gesture saat modal terbuka | **VERIFIED** | gesture dimatikan saat build/ship/pause/menu (`cam.gesture_*` tidak jalan; guard modal di `_unhandled_input`) |

## 3. Verifikasi (angka nyata)

**Suite test (headless, `run_game_check.sh tests`)**
`QA:TESTS:DONE passed=420 failed=0 skipped=0 -> PASS` (naik dari 368 sebelum M3 #6;
+52 cek `cam.*`). Contoh cek: `cam.default_scale scale=1.00`,
`cam.dolly_closed`, `cam.pan_clamped |pan|=16.00 (batas 16.0)`,
`cam.pan_delta_applied Δ=(2.5,-0.5)`, `cam.double_tap_toggle`, `cam.pinch_open_zoom_in`,
`cam.pan_screen_scale k=…` (k = 2·d·tan(fov/2)/vp_h).

**Gate `camera` (build WebGL nyata + capture + 12 cek Python): 12/12 PASS**
`rig siap + QA:CAM:READY` · `suite showcase tanpa gagal` · `tombol HUD zoom (48dp)
memindahkan kamera` · `jarak piksel landmark membesar saat zoom in` · `mengecil
saat tombol −` · `chip zoom ikut state nyata + reset` · `gesture: wheel + double
tap + pinch` · `pan menggeser kamera & dibatasi radius` · `tap pendek tetap
memilih bangunan setelah pan` · `HUD tanpa tumpukan dengan cluster zoom` · `label
dunia tidak menembus panel HUD (zoom)` · `deklutter BENAR-BENAR menyembunyikan
label saat zoom dekat`.
Angka: **`SPAN landmark: 312,8 px → 1011,1 px (rasio 3,23)`** setelah 2 klik
tombol **+** (scale 1,00 → 1,92; dist 29,71 → 15,45); double-tap → zoom 0,62;
pinch → 0,50; wheel 1 notch → 0,88; `QA:CAMERA:DONE failed=0`; `pageErrors=0`.

**Checker piksel `tools/vision/verify_m3_6_camera.py`: 66/66 PASS**
atas 5 foto `docs/m3_6_camera/` (1280×720 @dpr2: default/close/far/pan +
1080×2340 @dpr3 portrait close) — semua angka diambil dari piksel + log marker:

| Ukur | default | close | far | pan |
|---|---|---|---|---|
| piksel platform emas (px) | 1370 | **2021** (1,48×) | **486** (0,35×) | 718 |
| jarak grid lantai (px) | 114,0 | **145,5** (1,28×) | **76,2** (0,67×) | 118,0 (1,04×) |
| tinta klaster zoom (px) | 578 | 573 | 755 | 574 |
| teks di koridor label (px) | 829 | **0** | 276 | 581 |
| centroid platform | (639,462) | (640,507) | (667,421) | **(774,392)** |

Marker zoom/chip: default `zoom=1,0 chip=x1,0` · close `zoom=0,625 chip=x1,6` ·
far `zoom=1,6 chip=x0,6` — cocok dengan tombol/langkah showcase.
Deklutter: default/far/pan `visible=1`, close `hidden=1` (0 tumpukan di semua).
Portrait: `QA:HUD:OVERLAP count=0`, `QA:HUD:ZONES narrow=true design=720x1560`,
`ZoomCluster[888,930 144x480]` (tetap di tepi kanan, 48dp).

**Gate `all` (seluruh suite, dijalankan setelah SEMUA perubahan di turn ini): 0 suite FAIL**
`tests 420/0` (fails=0, skips=0, pageErrors=0) · `e2e 36/0` · `game_play` (menu
M3 #4, 9 MENU CHECK PASS) · `menu` (12/12 + save/load ticks) · `settings` (10/10)
· **`camera` (12/12, `SPAN landmark: 312,8 → 1011,1 px`) ** · `asset 17/0` ·
`sim 12/0` · `stress 8/0` (`QA:STRESS:METRICS ships=42 turrets=8`) · `ui`
showcase (`QA:UI:DONE passed=32 failed=0`) · `perf` t1/t4/t6 8/0
(fps_avg 3,08/2,33/1,67 — SwiftShader software GL, bukan angka device nyata).
Log penuh: `docs/m3_6_camera/gate_all_summary.log`.

## 4. Changes (file)

- **Baru**: `game/scripts/ui/camera_rig.gd` (rig zoom/pan/gesture + marker),
  `game/tests/integration/test_camera_rig.gd` (52 cek), `game/tests/e2e/camera_showcase.gd`
  (mode `?mode=camera&step=default|close|far|pan|auto`), `tools/vision/capture_camera_evidence.sh`,
  `tools/vision/verify_m3_6_camera.py`.
- **Diubah**: `game/scripts/base_scene.gd` (integrasi rig: setup, reset saat play,
  `apply()` di `_process`, gesture-first di `_unhandled_input`, API
  `camera_set_scale/camera_pan_world/camera_reset`, deklutter label pakai kotak
  proyeksi + zona HUD, `audit_label_hud_overlap()`), `game/scripts/ui/hud.gd`
  (`ZoomCluster` + `get_zoom_chip_text()` + `get_chrome_rects()` + `_apply_zone_offsets()`
  mode sempit + `_sync_info_visibility()` + audit anti-tumpuk memantau ZoomCluster),
  `game/scripts/building/building.gd` (`label_screen_rect()`/`label_world_size()` +
  `pixel_size` label konstan dalam dp), `game/scripts/core/event_bus.gd`
  (3 sinyal kamera: `camera_changed`, `camera_zoom_requested`, `camera_reset_requested`),
  `game/scripts/main.gd` (mode `camera`, arg `--camera`), `game/tests/test_runner.gd`
  (daftar suite `camera_rig`), `game/shell/index.html` (daftar mode), 
  `tools/godot/run_game_check.sh` (suite `camera`, 12 cek), `web/game.pck`,
  `DEV_PLAN.md`, `PROJECT_STATUS.md`, `UI_UX_DESIGN.md` (§4b).

## 5. Temuan jujur yang ditemukan & diperbaiki di turn ini

Semua temuan di bawah **ditemukan oleh test/foto**, bukan dugaan; semuanya
diperbaiki di turn ini kecuali yang ditandai LIKELY/UNKNOWN di §2.

1. **Pinch tidak bekerja** — baseline pinch hanya di-set saat drag pertama
   bergerak, sehingga jari pertama yang mendarat tidak pernah mengubah zoom
   (`cam.pinch_open_zoom_in` gagal: zoom tetap 1,000). Fix: hitung
   `_pinch_dist`/`_pinch_center` **saat sentuhan kedua mendarat**.
2. **Double-tap tidak kembali ke Normal** — satu tap hanya dicatat (memang harus
   begitu supaya seleksi bangunan tetap jalan); uji memakai 1 tap. Fix uji: 2
   pasang tap per toggle (dan perilaku rig tidak diubah).
3. **Assert zoom-in salah asumsi** — `zoom > 1,0` setelah zoom-in dari 0,88 gagal
   karena 0,88 + 0,12 = 1,00; perbandingan diubah relatif terhadap nilai
   sebelumnya.
4. **Label dunia menembus panel OBJEKTIF saat zoom dekat** (temuan foto putaran
   pertama: teks "Pusat Komando Lv1" menimpa panel). Perbaikan pertama
   (menyembunyikan label yang beririsan dengan zona HUD) **tidak bekerja** karena
   `label_extent_px()` = estimasi 12 px/karakter yang hanya benar di zoom default
   → kotak label 2× terlalu kecil. Fix: `label_screen_rect()` menghitung kotak
   dari **geometri Label3D nyata** (font, pixel_size) lalu diproyeksikan kamera.
   Bukti: 0 px teks di koridor label saat close zoom.
5. **Audit label memakai method yang tidak ada** (`is_label_visible()`) →
   melaporkan `hidden=1` palsu; diganti `label_visible()`.
6. **Portrait 360dp: `ActionGrid-InfoPanel` bertumpuk 168×228 px** (temuan
   `verify_m3_6_camera.py` atas foto 1080×2340; band bawah butuh 848 design px,
   layar portrait hanya 720). Fix: `_apply_zone_offsets()` — mode sempit
   (< 900 design px) menaikkan band bawah **di atas** baris aksi (grid tetap
   bottom-right = target sentuh tidak berpindah) + panel info disembunyikan saat
   panel seleksi tampil → `QA:HUD:OVERLAP count=0`. Audit anti-tumpuk kini juga
   memantau `ZoomCluster` (sebelumnya tidak, jadi bisa lolos dari cek).
7. **Label dunia di portrait membesar ~2,2× dan terpotong tepi layar** (fov
   vertikal + canvas portrait 2340 px). Fix: `pixel_size` label dikoreksi
   `k = (720 / tinggi_viewport_px) × (dpr / 2)` → konstan dalam dp (landscape
   dpr2/dpr3 k = 1,0 sehingga foto lanskap sebelumnya tetap sah).
8. **Marker `QA:CAM:STATE` spam 10 Hz** walau state tidak berubah → emit hanya
   saat berubah (`zoom` target vs `zoom_cur` berjalan dipisah).
9. **Landmark span antar-bangunan = 0 px** karena gameplay hanya menempatkan
   `command_core` saat start; diganti dua titik dunia tetap (−7,1,−6)→(7,1,6).
10. **Gate Python tanpa penjaga pembagian nol** → `ZeroDivisionError` saat span
    nol; ditambah guard `spans[0] > 1,0`.
11. **Nama berkas bentrok** — `tools/vision/verify_m36.py` sudah dipakai M3.6
    (design system); checker milestone ini dinamai `verify_m3_6_camera.py`,
    bukti ke `docs/m3_6_camera/`.
12. **Proses capture gagal ENOENT** karena direktori bukti dipindah saat proses
    masih berjalan (kesalahan operator, bukan cacat produk) → capture dijalankan
    ulang dan seluruh foto final diambil dari satu build.

## 6. Bukti (path)

- Foto: `docs/m3_6_camera/00_zoom_default_1280x720.png`,
  `01_zoom_close_1280x720.png`, `02_zoom_far_1280x720.png`, `03_pan_1280x720.png`,
  `04_zoom_close_portrait_1080x2340.png` (+ `.json` log marker per foto).
- Checker: `tools/vision/verify_m3_6_camera.py` → `docs/m3_6_camera/verify_m3_6_camera.json`
  (**66/66 PASS**).
- Capture: `tools/vision/capture_camera_evidence.sh`.
- Gate: `bash tools/godot/run_game_check.sh camera` (12/12) — ringkasan penuh
  `docs/m3_6_camera/gate_all_summary.log`.

## 7. Blockers / batasan yang dilaporkan terbuka

- **Gesture diuji sintetis**: pinch/drag/double-tap diuji dengan
  `InputEventScreenTouch`/`InputEventScreenDrag` buatan, bukan jari di perangkat.
  Perilaku nyata di Chrome Android belum diuji manual (label **LIKELY**).
- **Kamera tidak diuji untuk pengguna dengan tremor/zoom ekstrem berulang**:
  clamp bekerja (radius 16 unit, zoom 0,45–1,90), tetapi kenyamanan panjang belum
  diukur (UNKNOWN).
- Label dunia disembunyikan bila akan menembus panel HUD (bukan digeser) — pilihan
  desain; bila nanti diinginkan label selalu terlihat, perlu mekanisme offset.
- Metrik piksel platform/grid bergantung tone render; ambang di checker
  dikalibrasi dari foto nyata turn ini (bukan angka teoretis) dan akan gagal bila
  palet berubah besar.

## 8. Next action

**M3 #7 — kerusakan visual bangunan** (`DAMAGED/CRITICAL/DESTROYED`): data sudah
ada (`building.gd` `enum State`, `building_model.gd tint()`), yang kurang adalah
visual kerusakan + bukti foto/verifikasi piksel seperti milestone ini.
