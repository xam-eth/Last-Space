# Laporan M3.7 — HUD berlabel penuh & arena 3D naik kelas

**Tanggal:** 2026-10-13 · **Branch:** `arena/d80e2902-last-space` · **Mode:** implementasi + verifikasi

## §20 Format Laporan (wajib, AI_GOVERNANCE.md)

### 1. Milestone
M3.7a (perbaikan layout HUD — jawaban kritik #3 & #4) dan M3.7b (kualitas visual
canvas 3D). Keduanya **selesai dan terverifikasi** dalam turn ini.

### 2. Capability advanced
| Sebelum | Sesudah |
|---|---|
| Card ikon-saja (BANGUN/ARMADA = ikon; tombol menu ikon-X) | 3 card berlabel teks 11dp + ikon 48dp, tombol "TUTUP" berlabel |
| Panel seleksi tanpa label biaya/HP | `HP` berlabel, card `TINGKATKAN Lv N` + biaya / `LEVEL MAKS` |
| Modal build/ship tanpa label field | `KATEGORI`, `BIAYA`, `WAKTU BANGUN`, `DIBANGUN n` + subjudul cara pakai |
| Kontrol tanpa label tidak terdeteksi otomatis | `HUD.audit_labels()` → 20/20 berlabel, 0 unlabeled (gate + verifier) |
| Label 3D bisa saling menimpa (foto e2e terbukti) | Declutter 20 Hz → `LABEL_OVERLAP count=0` |
| Arena = bidang + kotak | Model prosedural per tipe (9–17 mesh, 3–5 emissive), rim/pylon/pad, KeyLight, props |
| Bangunan baru tumbuh di belakang kamera | Kamera menghadap sumbu pertumbuhan pangkalan (+Z) — diverifikasi dari data `next_free_position` |

### 3. Status
- **VERIFIED (runtime, build web nyata):** gate `run_game_check.sh all` 8/8 PASS.
- **VERIFIED (script, dari JSON gate & foto):** `verify_m37.py` 9/9,
  `verify_hud_layout.py` 7/7, `verify_m36.py` 31/31, `verify_ui_m3.py` 20/20.
- **IMPLEMENTED, belum diverifikasi di device fisik:** performa nyata GPU
  (semua angka perf berasal dari SwiftShader).

### 4. Evidence
- Gate: `tools/godot/build/*.png.json` — tests **285/285**, e2e **36/36**,
  asset 17/17, sim 12/12, stress 8/8, perf t1/t4/t6 8/8, ui/play smoke PASS.
- Marker kunci:
  - `QA:HUD:OVERLAP count=0`, `QA:HUD:FIT …ok`, `QA:HUD:LABELS total=20 labeled=20 unlabeled=[]`
  - `QA:HUD:LAYOUT zones=… TopBar[32,32 1216x112] ActionGrid[880,536 368x152] SelectionPanel[448,480 416x208] QuestPanel[32,160 440x234] cell0[880,536 112x152]`
  - `QA:MODEL:BUILD` — command_core 17 mesh/3 glow, energy_reactor 10/4,
    mineral_extractor 10/3, fighter_hangar 9/5, laser_turret 9/4
  - `QA:SCENE:ENV stars=350 planet=1 asteroids=7 rim=4 pylons=4 pads=2`
  - `QA:SCENE:LABEL_OVERLAP count=0 visible=3 hidden=2 total=5` (mode e2e)
- Foto: `docs/m37_visual/` (hud_16x9 @dpr2, hud_19_5x9 @dpr3, hud_21x9,
  hud_desktop, arena_all_buildings, command_selected_16x9, build/ship/pause menu,
  record_game 12 frame) + 9 foto HUD di `docs/ui_m3_build_menu/` (recapture).
- Verifier: `docs/m37_visual/verify_m37.json` (9/9),
  `docs/m37_visual/verify_hud_layout_ui.json` (7/7),
  `docs/m36_visual/verify_m36.json` (31/31),
  `docs/ui_m3_build_menu/report.json` (20/20).

### 5. Changes (file)
- `game/scripts/ui/hud.gd` — konstanta baru (ACTIONS_COLS, ACTION_CARD_W/H,
  GRID_W, INFO_W, SEL_MIN_W), `_make_action_card()`, `_card_style()`,
  `_build_selection_panel()` baru, `audit_labels()`, dump layout rekursif.
- `game/scripts/ui/build_menu.gd`, `ship_menu.gd`, `pause_menu.gd` — tombol tutup
  berlabel `TUTUP`, label field (`KATEGORI/BIAYA/WAKTU/DIBANGUN`), subjudul.
- `game/scripts/building/building_model.gd` (baru) — generator model prosedural
  per tipe + animasi + tint state (+ `simple_mode` untuk benchmark).
- `game/scripts/building/building.gd` — visual komposit, animasi idle, marker
  `QA:MODEL:BUILD`, API label (`set_label_visible`, `label_extent_px`, …).
- `game/scripts/base_scene.gd` — kamera + langit, KeyLight, rim/pylon/pad,
  props arena, declutter label 20 Hz (`QA:SCENE:LABEL_OVERLAP`).
- `game/tests/e2e/ui_showcase.gd` — test `ui.labels_all`, `ui.labels_min_count`.
- `tools/godot/run_game_check.sh` — gate tambahan: `QA:SCENE:ENV` &
  `QA:HUD:LAYOUT` wajib ada (script error tidak lagi lolos sebagai PASS).
- `tools/vision/verify_m37.py` (baru), `verify_hud_layout.py` (cek label &
  card 48dp, fix parsing `--out`), `verify_m36.py` (target app bar 56dp),
  `verify_ui_m3.py` (rekalibrasi region panel ke layout M3.7).

### 6. Verification (cara mengulang)
```bash
bash tools/godot/run_game_check.sh all                     # 8/8 PASS
python3 tools/vision/verify_m37.py docs/m37_visual \
    tools/godot/build/game_ui.png.json tools/godot/build/game_e2e.png.json \
    docs/m37_visual/arena_all_buildings.png.json --out docs/m37_visual/verify_m37.json
python3 tools/vision/verify_hud_layout.py tools/godot/build/game_ui.png.json
python3 tools/vision/verify_m36.py docs/m36_visual && python3 tools/vision/verify_ui_m3.py docs/ui_m3_build_menu
bash tools/vision/capture_ui_evidence.sh                    # 8 foto HUD
```

### 7. Blockers
- **Renderer software (SwiftShader)** ≈1 fps: angka perf & fps tidak
  merepresentasikan device nyata; gate perf tetap dijalankan sebagai batas
  relatif, bukan absolut. Budget device class masih `TBD`.
- Verifikasi di GPU/perangkat fisik (Android) **belum dilakukan** (UNKNOWN).

### 8. Next action
- Pilihan berikutnya (butuh keputusan user): **M3 #4 main menu** (Play/Pengaturan),
  atau perluasan konten (M3 #5+), atau porting/uji device Android nyata.

### 9. Scope change
- Tambahan di luar rencana awal: gate baru anti-regresi marker scene/HUD di
  `run_game_check.sh`, decluttering label dunia, dan `verify_m37.py`.
- Kriteria baru yang diminta user (semua card berlabel) diangkat menjadi aturan
  desain §14 di `UI_UX_DESIGN.md`.

## Catatan jujur (yang tidak boleh dibaca sebagai "semua sempurna")
1. Benchmark stress memakai `BuildingModel.simple_mode = true` + KeyLight shadow
   OFF — angka perf tidak mewakili kualitas penuh.
2. Emisi/glow 3D bagus di foto statis; di motion (record SwiftShader ≈0,6 fps)
   animasi belum layak dinilai.
3. Dua bug ditemukan saat verifikasi dan sudah diperbaiki di turn yang sama:
   `var c := [...]` (parse error, LOLOS gate lama karena hanya cek marker boot)
   dan label 3D berdempet di jendela 0,2 s.
