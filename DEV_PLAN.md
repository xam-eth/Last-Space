# DEV PLAN — Last-Space

Milestone plan with verification gates. Governing documents: `QA_PLAN.md`
(gates: NOT STARTED → IMPLEMENTED → RUNNABLE → VERIFIED → INTEGRATED →
REGRESSION PASS), `TECH_ARCHITECTURE.md`, `DATA_CONTRACTS.md`,
`RISK_ANALYSIS.md`, `AI_GOVERNANCE.md`.

## Phase 0 — Architecture & framework preparation ✅ COMPLETE (2026-10-10)

No game code at that point (per human decision). Delivered: toolchain
re-verification, `TECH_ARCHITECTURE.md`, `DATA_CONTRACTS.md`, `QA_PLAN.md`,
`RISK_ANALYSIS.md` saved, `ROADMAP.md` updated.

## Milestone 1 — Vertical slice ✅ COMPLETE (2026-10-10)

Phases follow `RISK_ANALYSIS.md` §10 order. All gates passed per `QA_PLAN.md`.

| Phase | Scope | Status | Evidence |
|---|---|---|---|
| M1-P1 | Project skeleton (`game/`) + framework core (EventBus, TimeSystem, SeededRng, QaMarkers, GameData) + test runner + CI harness (`run_game_check.sh`) | ✅ VERIFIED | `TESTS:DONE passed=167 failed=0` (data validation, RNG, economy) |
| M1-P2 | Economy + BuildingSystem + ProductionSystem + data (economy, 6 buildings) | ✅ VERIFIED | integration tests: costs/rates/upgrade/repair/revive from data |
| M1-P3 | FleetSystem + CombatSimulator (pure, seeded) + WaveDirector + CombatVisualizer + ship/weapon/wave data | ✅ VERIFIED | unit: determinism + stats→outcome; integration: wave→sim→applied; e2e markers |
| M1-P4 | ProgressionSystem: rewards (exactly once), territory unlock + sector data | ✅ VERIFIED | integration: reward-once, unlock after defense |
| M1-P5 | SaveSystem (schema v1) + full state snapshot | ✅ VERIFIED | round-trip: save→load→identical state; no duplicate rewards |
| M1-P6 | UI: HUD (resources, fleet, build menu, ship button, battle status) | ✅ VERIFIED | e2e: HUD shows real values; screenshots pixel-verified |
| M1-P7 | E2E full loop: build→produce→fleet→defend→territory+reward→wave2 damages base→repair→upgrade→save/load | ✅ VERIFIED + INTEGRATED + REGRESSION PASS | `TESTS:DONE passed=36 failed=0` + `QA:LOOP:COMPLETE` + screenshots |

### What was built (game/)

```
game/
├── project.godot          # autoloads: EventBus, TimeSystem, GameData, Economy,
│                          #   QaMarkers, SeededRng, SaveSystem, GameManager
├── scripts/
│   ├── core/              # event_bus, time_system, seeded_rng, qa_markers,
│   │                      #   game_data, economy, save_system, game_manager
│   ├── building/          # building.gd, building_system.gd, building_def.gd
│   ├── production/        # production_system.gd
│   ├── fleet/             # ship.gd, fleet_system.gd, ship_def.gd
│   ├── combat/            # combat_simulator.gd, wave_director.gd,
│   │                      #   combat_visualizer.gd, weapon_def.gd, wave_def.gd,
│   │                      #   battle_input.gd, battle_result.gd
│   ├── progression/       # progression_system.gd, sector_def.gd, progression_config.gd
│   ├── economy/           # economy_config.gd
│   ├── ui/                # hud.gd
│   ├── utils/             # system_refs.gd
│   ├── base_scene.gd, main.gd
├── scenes/                # main.tscn, base/base_scene.tscn, tests/test_scene.tscn
├── data/                  # 17 .tres: economy, progression, 6 buildings, 3 ships,
│                          #   2 weapons, 2 waves, 2 sectors (ALL PROVISIONAL)
├── tests/                 # test_runner.gd, test_util.gd, unit/ (4), integration/ (4),
│                          #   e2e/e2e_playthrough.gd
└── shell/index.html       # web shell (mode via ?mode=game|tests|e2e)
```

### Key design decisions (verified in code)

- **Data-driven:** all balance in `data/*.tres`; code has no balance numbers.
- **Deterministic:** CombatSimulator is pure RefCounted; SeededRng splitmix64;
  economy uses integer tick math (production = rate × ticks / 600, exact).
- **Repair revives destroyed buildings** (repair bay = rebuild wreck; cost from
  `repair_cost_per_hp` × HP restored). Verified by tests.
- **Placeholder visuals** (colored boxes by category/state) until art lands.
- **Editor-less build:** `make_script_class_cache.py` generates
  `.godot/global_script_class_cache.cfg` (class_name resolution without editor).

## Phase UI/UX — Workflow desain awal + aset 2D loading ✅ COMPLETE (2026-10-10, sebelum M2)

Sesuai requirement human developer sebelum lanjut ke M2:

- [x] `UI_UX_DESIGN.md` — workflow UI/UX lengkap: prinsip desain, screen
      inventory (loading, menu, HUD, build menu, battle HUD, galaxy map,
      settings, pause), design system (palet, tipografi, komponen), workflow
      desain→aset→implementasi→verifikasi→review, acceptance criteria UI.
- [x] Aset 2D loading screen di `assets/ui/loading/`: 5 background cinematic
      16:9 (1376×768 JPG: nebula fleet, battle station, alien fleet, space
      battle, asteroid planet) + `icon_loading.png` (512×512 RGBA, dioptimasi).
- [x] Website loading screen (root `index.html`): slideshow background
      (crossfade 4s) + icon loading (spin + pulse glow) + progress bar +
      judul; tampil selama check, fade out setelah selesai (min. 2.5s).
      Diverifikasi via screenshot (icon, title, bar terlihat jelas).
- [x] Dashboard tetap 56/56 PASS setelah loading screen ditambahkan.

## Phase UI/UX — Revisi mobile-first landscape 16:9 ✅ COMPLETE (2026-10-10, setelah feedback human developer)
HUD dirombak total sesuai design system baru (`UI_UX_DESIGN.md`): mobile-first
landscape 16:9 full screen, komponen sebagai overlay di atas gameplay arena
(center clear), icon design system (12 ikon, generator `tools/ui/make_icons.py`),
design tokens + verifikasi layout via `QA:HUD:LAYOUT` + capture 2 resolusi.
Gate 4 suite PASS; debug.html 56/56 (no regresi). Root page mobile-first
full screen (viewport-fit=cover, no zoom/scroll).

## Milestone 2 — Stability, balance & performance 🟡 IN PROGRESS (items 1–4 ✅ VERIFIED 2026-10-11; pilot ALN-001 ✅ VERIFIED 2026-10-11; item 5 mobile perf — harness SIAP, BLOCKED menunggu keputusan device class — lihat DEVICE_CLASS_BRIEF.md)

1. ✅ **Visual real game (human requirement) — SELESAI (pilot):** pilot asset
   `SHP-001` through full pipeline (Blender → GLB → runtime scene → Godot) +
   `ASSET_ACCEPTANCE_CRITERIA.md` — **VERIFIED** (tests 190/0, asset showcase
   11/0, vision evidence `game_asset.png`; detail di `MASTER_ASSET_INVENTORY.md`
   — Log Pilot Asset). Placeholder box kini hanya fallback untuk kapal tanpa
   `model_path`. Game = visual real (interceptor 3D di base + battle).
   ✅ **Pilot ALN-001 "Alien Scout" SELESAI 2026-10-11 — VERIFIED** (pilot
   kedua, sisi alien: biomekanis asimetris, MAT-002 + inti hijau MAT-022 +
   senjata ungu MAT-023; 372 tris, GLB 42 KB, panjang ~3,5 m; orientasi
   weapon_z=-1,72 < engine_z=1,58; terintegrasi — `CombatVisualizer` attacker
   kini model ALN-001, stress scene attacker pakai ALN-001; detail di
   `MASTER_ASSET_INVENTORY.md` — Log Pilot Asset). Bulk aset alien (ALN-002
   dst.) menunggu art decision (ROADMAP unapproved).
2. ✅ **Headless economy simulation — SELESAI (2026-10-11):** mode `sim`
   (`game/tests/e2e/economy_sim.gd` + suite `sim` di `run_game_check.sh`,
   seed tetap 4242 → reproducible). 200 hari game = 120.000 ticks, wall 6,3s.
   Hasil terukur (12/12 PASS; **PROVISIONAL** — data balance belum di-tuning):
   kapal pertama hari 8; wave_1 (hari 12) & wave_2 (hari 17) berhasil
   dipertahankan (defense_wins=2); sektor_2 terbuka hari 12; ekonomi tidak
   pernah negatif (min E252/M39); bottleneck awal = **minerals** (5 gagal
   afford); storage penuh 165/200 hari → produksi melebihi konsumsi mid-game
   (perlu sink resource: upgrade/repair/rebuild). Metrics: `QA:SIM:METRICS`.
   Berikutnya: stress scene (item 3).
3. ✅ **Stress scene performa — SELESAI (2026-10-11):** mode `stress`
   (`game/tests/e2e/stress_scene.gd` + suite `stress` di `run_game_check.sh`).
   Target unit PROVISIONAL (fleet size on screen belum diputuskan): 30 penyerang
   (Game_Concept.md: wave besar 30 pesawat) + 12 interceptor + 8 turret = 42 kapal
   + 8 turret; attacker kini model ALN-001 asli (update 2026-10-11 setelah
   pilot ALN-001 — sebelumnya stand-in SHP-001). Sample 12 detik.
   Hasil terukur di web build (headless Chromium, **SwiftShader software GL** —
   baseline sandbox, bukan device nyata): fps_avg=12.5 fps_min=11.0,
   frame 80.1ms avg / 144.5ms max, draw calls 230 avg, render objects 454,
   nodes 427, JS heap 8.3MB (page.metrics; Godot MEMORY_STATIC=0 karena release
   tracking off; wasm memory tidak ter-expose di headless). Tidak freeze.
   Budget numerik = TBD (butuh device class — unapproved decision).
   Bug ditemukan & diperbaiki via stress scene: HUD FLEET chip stale (tidak
   listen `fleet_changed`) → fix `hud.gd`. Berikutnya: integration tests edge
   cases (item 4).
4. ✅ **Cross-system integration tests — edge cases ekonomi SELESAI (2026-10-11):**
   `game/tests/integration/test_economy_edge.gd` (20 check, semua dari data
   `res://data`): caps (earn terbuang saat storage penuh, zero-earn saat penuh),
   interrupted production (progress antrian konstruksi tidak hilang saat
   round-trip state), production-wasted-saat-storage-penuh (tercatat penuh,
   tidak double-earn), insufficient resources (konstruksi gagal atomik — tanpa
   partial spend), repair costs (dana tidak cukup → gagal atomik; amount
   dipotong ke missing, cost = per_hp × actual dari data). reward-once sudah
   dicover `test_progression`. Total tests: **210/0**.
   Bug fix: HUD FLEET chip stale (tidak listen `fleet_changed`) → fix `hud.gd`
   (ditemukan via stress scene, item 3).
   Berikutnya: mobile performance test (item 5) — **BLOCKED**, butuh keputusan
   "minimum device class" (unapproved decision, ROADMAP).
5. ⏳ **Mobile performance test — MEASUREMENT HARNESS SIAP, menunggu keputusan
   device class (human developer):** suite `perf` (`run_game_check.sh perf`)
   mengukur stress scene (42 kapal + 8 turret) di 3 emulated device class via
   CDP CPU throttle (1x baseline / 4x ~mid-tier / 6x ~low-end budget) —
   **3 run × 8/8 PASS, exit 0** (0 pageErrors). Hasil + opsi + rekomendasi
   berbasis data nyata: **`DEVICE_CLASS_BRIEF.md`**. Data: 1x fps_avg=12,2;
   4x fps_avg=8,8; 6x fps_avg=8,5; frame_ms_max ~150; JS heap ~8 MB
   (SwiftShader software GL — indikasi, bukan device fisik).
   **BLOCKED pada:** keputusan "minimum device class" + performance budget
   (unapproved, ROADMAP). Setelah diputuskan: budget numerik di-set di
   `stress_scene.gd` dan suite `perf` jadi gate verifikasi.

**Koreksi fatal (2026-10-11, feedback human):** resolusi full screen —
sebelumnya asumsi 16:9 tanpa verifikasi aspek Android modern (19.5:9/20:9)
→ black bars + HUD tidak full width. Diperbaiki: `project.godot` aspect
`keep`→`expand` + `hud.gd` full-rect anchored edge. Diverifikasi data nyata
(5 resolusi standar: HUD full width, margin 12dp, komponen 48dp, tanpa
letterbox; evidence `res_before_*` vs `res_after_*`). Full gate 7 suite PASS.

**Visual benchmark (2026-10-11):** 7 foto hasil akhir game di
`docs/visual_benchmark/` (ALL PASS verifikasi piksel) — benchmark visual build
untuk review kualitas visual (loading, command base, armada, battle vs alien,
stress 42 unit, mobile 16:9 & 19.5:9). Script: `tools/vision/visual_benchmark.sh`
+ `verify_benchmark.py`.

**Research & gameplay flow (2026-10-11):** reference UI/UX Doomsday: Last
Survivors dipelajari (screenshots `docs/references/doomsday/`), konsep
`Game_Concept.md` dibaca ulang a–z, hasilnya dokumen **`GAMEPLAY_FLOW.md`** —
scene/frame inventory (loading → command → battle → pause), komponen &
ukuran setiap card/menu (dp), state machine, mapping implementasi
(sudah ada vs prioritas M3: Build menu #1, Ship menu #2, Pause #3, Main
menu #4, Settings #5, zoom kamera #6, kerusakan visual #7).

**Research FULL frame-by-frame (2026-10-11, update):** dokumen
`docs/references/doomsday/FRAME_BY_FRAME.md` (F0–F13, 30 screenshot) —
pola baru: quest panel kiri tengah, tombol Region (world map) kiri bawah,
indikator bangunan terpilih + aksi konteks (Info/Level Up/Buff), hamburger
pause/settings, battle report. Mapping adopsi: `GAMEPLAY_FLOW.md` §0.

**M3 #1 SELESAI (2026-10-11): Build menu + quest panel + building selected.**
- `game/scripts/ui/build_menu.gd` — modal build (pola Doomsday BAG: title +
  close X + grid 5 card + detail + tombol BUILD 48dp; modal 512×252dp anchor
  center semua aspek). Dibuka dari action grid tombol "build".
- `game/scripts/progression/quest_tracker.gd` — 4 objektif slice + reward-once
  via EventBus; quest panel kiri tengah di HUD.
- Building selected: klik bangunan di arena 3D (unproject nearest, robust di
  WASM) → panah hijau indikator (PrismMesh, bob+spin) + selection panel bawah
  tengah (nama + level + HP + UPGRADE via `BuildingSystem.try_upgrade`).
- 5 ikon baru (`tools/ui/make_icons.py`: build/close/upgrade/quest/info).
- Suite baru **ui** (`?mode=ui` + `tests/e2e/ui_showcase.gd`, marker
  `QA:UI:SELECT_DONE`/`QA:UI:MENU_DONE`) — gate sekarang **8 suite**.
- Test: `test_quest_tracker.gd` (15 cek), `test_build_menu.gd` (11 cek);
  e2e tahap 4 kini include quest reward delta (data-driven).
- Evidence visual: `docs/ui_m3_build_menu/` (5 foto 1280×720 + 2340×1080,
  verifikasi piksel 12/12 PASS — `tools/vision/verify_ui_m3.py`).
- **Gate: 8/8 suite PASS exit 0** (tests 256/0, e2e 36/0, game, asset 17/0,
  sim 12/0, stress 8/0 + memory 9.5MB, ui 10/0, perf 3×8/0).
- Berikutnya: **M3 #2 Ship menu** (pola Doomsday Hero: grid ship cards +
  detail + PRODUCE).

**M3 #2 SELESAI (2026-10-11): Ship menu (Fleet/produksi kapal).**
- `game/scripts/ui/ship_menu.gd` — modal pola Doomsday Hero (F7): title
  "FLEET" + close X + grid card kapal pemain (cost non-empty dari data;
  alien tidak diproduksi) + detail (ikon + nama + class/role + stats
  HP/ATK/ARMOR/SPEED/SUPPLY dari `.tres` + biaya + waktu + tombol PRODUCE
  48dp). Atomic via `ProductionSystem.enqueue_ship` (cek hangar + dana).
  Action grid: tombol fleet (ikon interceptor) membuka menu.
- Showcase ui: step C ship menu → marker `QA:UI:SHIP_DONE` (suite waitfor
  diupdate); test `test_ship_menu.gd` (11 cek: card dari data, produce tanpa
  hangar gagal tanpa spend, biaya dari .tres, tanpa dana atomic).
- Evidence visual: foto `05_ship_menu_1280x720.png` +
  `06_ship_menu_2340x1080.png`; verifikasi piksel **16/16 PASS**.
- **Gate: 8/8 suite PASS exit 0** (tests 271/0, e2e 36/0, ui 13/0, dst).
- Berikutnya: **M3 #3 Pause menu** (isi tombol menu: Resume/Settings/Main
  Menu — tombol sudah ada, modal masih kosong).

**QA record layar per frame (2026-10-11, sebelum lanjut M3 #3 — permintaan
human):** `tools/vision/record.mjs` (CDP `Page.startScreencast`, headless
Chromium SwiftShader — sama dengan semua suite) + `analyze_record.py`
(analisis piksel per frame, Pillow). Hasil (data nyata, `docs/ui_m3_build_menu/record_*/`):
- **record_ui** (`?mode=ui`, 51 frame @4.2fps): 0 blank, 0 invalid; segmentasi
  `command_hud` (frame 0–14, selection + arrow hijau 671px) → `modal_menu`
  (frame 15–50); motion spike frame 16 (22.5 = build menu muncul) & frame 23
  (9.2 = ship menu) — transisi UI terbukti; green_px turun 671→0 saat modal
  (arrow tertutup modal).
- **record_e2e** (`?mode=e2e`, 207 frame @4.6fps): 0 blank, 0 invalid;
  segmentasi `command_hud` (0–26) → **`battle` (27–42, t 5.9–9.1s, piksel merah
  alien hingga 209)** → `command_hud` (43–206); motion spike frame 54 (3.1,
  wave 2/repair — alien terlalu kecil di kamera jauh untuk ambang merah,
  catatan jujur seperti visual benchmark).
- **Verdict: PASS** (tidak ada frame blank/invalid, animasi & transisi
  terdeteksi dari data piksel per frame).

**M3 #3 SELESAI (2026-10-11): Pause menu.**
- `game/scripts/ui/pause_menu.gd` — modal 240×180dp center: RESUME (56dp) /
  SETTINGS (48dp) / MAIN MENU (48dp + panel konfirmasi). TimeSystem beku saat
  buka + phase PAUSE; resume saat tutup. Main menu → konfirmasi → save;
  scene main menu belum ada (M3 #4) → dilaporkan jujur (tidak fake).
  Tombol ☰ kanan atas membuka (menggantikan "coming soon").
- Showcase ui: step D pause → marker `QA:UI:PAUSE_OPEN/DONE`; test
  `test_pause_menu.gd` (13 cek: speed beku/lanjut, phase PAUSE⇄COMMAND,
  konfirmasi + save + pesan jujur).
- Evidence visual: foto `07_pause_menu_1280x720.png` +
  `08_pause_menu_2340x1080.png`; verifikasi piksel **20/20 PASS**.
- **Gate: 8/8 suite PASS exit 0** (tests 284/0, e2e 36/0, ui 17/0, dst).
- Berikutnya: **M3 #4 Main menu** (Play/Settings; saat ini root langsung
  game sesuai requirement — main menu untuk rilis).

**M3.5 SELESAI (2026-10-12): Visual & UI polish — arena + Bahasa Indonesia.**
( kritik user: UI/UX berantakan, visual placeholder kotak-kotak, tidak ada
  arena → perbaikan 2 tahap, diverifikasi data nyata. )
- **Tahap A (arena)**: `base_scene.gd::_create_environment` — sky dark +
  300 bintang MultiMesh seeded (CPUParticles3D tidak ter-render di SwiftShader,
  diverifikasi foto → diganti), planet biru r=22 + bulan r=8, platform 80×80
  + grid emissive cyan (tekstur runtime), 7 asteroid seeded. Kamera (0,20,30)
  + fov 82 (langit masuk FOV). `building.gd`: Label3D nama+Lv + glow kategori.
  `ship.gd::_add_engine_glow`: 2 bola cyan di belakang kapal.
- **Tahap B (UI)**: semua label utama Bahasa Indonesia (keputusan sementara,
  Settings bahasa = M3 #5; istilah teknis tetap Inggris); card build/ship
  **2 kolom landscape** (ikon 48dp kiri, nama 24px, biaya 20px); quest &
  display_name `.tres` diterjemahkan.
- **Verifikasi**: verify_m35_arena **5/5 PASS** (bintang 1371px, planet 10123px,
  bulan 2269px, grid cyan 5016px, engine glow 4315px); verify_ui_m3 tetap
  **20/20 PASS**; record per frame PASS (11 frame, 0 blank/invalid);
  **gate 8/8 PASS exit 0** (tests 285/0, e2e 36/0, asset 17/0, sim 12/0,
  stress 8/0 + heap 8.2MB, ui, perf 3×8/0). Evidence `docs/m35_visual/`.
- **Catatan jujur**: stress/perf scene panggil `reduce_environment_for_benchmark()`
  (SwiftShader terlalu lambat dengan dekorasi penuh); fps record dengan dekorasi
  turun ke ~0.5 (SwiftShader + screencast; GPU device asli belum terukur).
- Berikutnya: **M3 #4 Main menu** atau M3 #6/#7.

**M3.6 SELESAI (2026-10-12): Resolusi & design system (mobile-first ANDROID).**
( kritik user: resolusi salah, component design system kurang tepat, size
  komposisi tidak sesuai/terlalu besar, loading "masih vertikal" → riset
  standar resmi dulu, ukur build nyata, perbaiki; temuan + sitasi di
  `docs/m36_visual/M36_REPORT.md` dan `UI_UX_DESIGN.md` §3/§6/§7b. )
- **Skala HUD standar dp**: `scale = dpr / 2` (design px = dp × 2; dpr =
  `DisplayServer.screen_get_scale()` = `window.devicePixelRatio`, VERIFIED dari
  source Godot 4.7.2) menggantikan match-height → komponen tetap 48dp/16dp di
  semua device (temuan: sebelumnya membesar di layar dp besar).
- **Token**: margin 16dp, chip 118×48dp, tombol sekunder 48dp (dari 40dp),
  spacing kelipatan 4/8dp, quest panel 144dp, top bar offset 16dp (notch).
- **Type scale M3**: tidak ada teks < 11dp (labelSmall 11 / bodySmall 12 /
  bodyMedium 14 / bodyLarge 16 / titleLarge 22).
- **Modal build/ship dihitung ulang**: 544×272dp (< max-width dialog 560dp;
  terukur 543dp dari foto); card 166×64dp + nama autowrap (teks tidak terpotong);
  detail 180dp (tidak meluber); strip resource di judul modal.
- **Loading page landscape responsif dp** (clamp): ikon 40–64dp, judul 20–34dp,
  bar 160–360px; scrim gradient; safe-area; emoji → SVG/teks.
- **Rotate prompt portrait** (overlay "Putar ke LANDSCAPE") — game landscape.
- **Harness device class**: `capture.mjs`/`record.mjs` `--dpr`; harness capture
  CSS 640×360 @dpr2 (ponsel 16:9 360dp); marker `QA:DPR:` + `QA:HUD:LAYOUT`.
- **Verifikasi**: verify_m36 **30/30 PASS** (loading landscape 16:9/19.5:9,
  rotate prompt portrait, HUD 6 device class); verify_ui_m3 tetap **20/20**;
  **gate 8/8 PASS exit 0**; record per frame 20 frame 0 blank. Evidence
  `docs/m36_visual/` + `docs/ui_m3_build_menu/` (9 foto re-capture).
- **Catatan jujur**: `JavaScriptBridge.eval("window.LS_DPR")` = null di build
  ini → skala memakai API Godot; komposisi loading memang sudah landscape sejak
  2026-10-11 (foto lama = mid-fade), ukuran/komposisinya yang diperbaiki.
- Berikutnya: **M3 #4 Main menu** atau M3 #6/#7.

**M3 #4 SELESAI (2026-10-13): Main menu (Play/Continue/Settings) + boot fase MENU.**
( item DEV_PLAN berikutnya setelah M3.7c; spec GAMEPLAY_FLOW Frame 3 + UI_UX_DESIGN §8 #2. )
- **Riset dulu, bukan asumsi**: `docs/REFERENCES_MAIN_MENU.md` — referensi lokal
  (Doomsday F1: latar scene 3D + tombol Start besar bawah-tengah) + sumber web
  (blog resmi Supercell/CoC revamp: "base = bintang, sisanya UI", progressive
  disclosure; therookies: thumb zone aksi di 1/3 bawah; Material 3: 56/48dp,
  dialog ≤560dp; kritik pemain r/ClashOfClans: jangan perkecil tombol kritis,
  posisi konsisten) → tabel aturan → implementasi → bukti.
- **Integrasi** (keputusan): root default TETAP game (requirement human) —
  `index.html` → game → boot **fase MENU** dengan base 3D idle (kamera orbit
  halus ±5,7°/dolly ±3,5%, `TimeSystem.pause`) + chrome HUD disembunyikan;
  tombol Play → `GameManager.start_new_game()` / `SaveSystem.load_game()` →
  fase COMMAND (HUD chrome kembali). Pause menu Frame 8 → MAIN MENU = navigasi
  NYATA (save + fase MENU + panel menu sesi) — placeholder M3 #3 dihapus.
- **Design system**: `game/scripts/ui/ui_theme.gd` (`class_name UiTheme`) —
  token warna/radius/margin/type-style + `style_button` (state lengkap) +
  `apply_design_frame`; dipakai main menu, siap dipakai layar berikutnya
  (migrasi build/ship/pause dicatat sebagai pekerjaan menyusul, bukan klaim).
- **Verifikasi**: gate `menu` **12/12 cek** (boot fase MENU beku, save nyata,
  LANJUTKAN PERMAINAN, resume tanpa reset, menu dingin LANJUTKAN → LOAD
  mengembalikan tick tersimpan 600==600, PENGATURAN jujur M3 #5, KREDIT modal,
  kembali COMMAND) + gate `game` 8/8 cek (menu muncul di boot, `QA:MENU:FIT
  fit=ok credits_fit=ok`, `QA:MENU:DUMP primary_dp=56 secondary_dp=48`,
  **anti-tumpuk `QA:MENU:OVERLAP count=0`**, chrome `_hidden`, speed=0);
  tests **321/0** (+36 cek: `test_main_menu.gd` baru + pause menu diperbarui);
  gate `all` **0 suite FAIL** (`EXIT_ALL=0`; tests 321/0, e2e 36/0, stress 8/8,
  perf 3 device class, ui/asset/sim PASS) dan gate `game` 9/9 cek menu;
  foto `docs/m3_main_menu/00–08` (1280×720, 2340×1080, portrait) +
  `tools/vision/verify_menu.py` **55 PASS / 0 FAIL** (marker + piksel: rect
  panel DIHITUNG dari marker, pita teks tidak bertumpuk, padding ≥8dp tiap
  tepi, nol tinta di luar panel, label dunia 3D tidak muncul, konsistensi
  konten dalam dp antar dpr: `content 502x513` identik & baris judul 34,0 vs
  34,7 dp).
- **Temuan jujur yang diperbaiki di turn ini**: (1) save yang dibuat saat fase
  PAUSE/MENU ikut ter-restore → setelah "LANJUTKAN" pemain berhenti di menu;
  kini `MainMenu` memanggil `GameManager.enter_gameplay()` (marker GAME:PHASE);
  (2) audit anti-tumpuk awal mengukur SEBELUM container settle (15 pasangan
  palsu) → ditunda 2 frame (pelajaran sama seperti `_modal_overflow` M3.7c);
  (3) min-size Label autowrap = per-kata (kredit 123×6222 px) → teks kredit
  baris eksplisit + panel kredit diukur dari konten;
  (4) **ditemukan dari FOTO, bukan dari marker**: chip ENERGI/MINERAL/ARMADA
  masih terlihat di menu padahal marker `_hidden` sudah hijau — sebabnya
  `hud._top_bar` **variabel mati** (tidak pernah di-assign sejak refactor
  M3.6) sehingga `set_chrome_visible` melewatinya; diperbaiki + gate diperkuat
  jadi memeriksa 6 zona chrome (`TopBar/QuestPanel/InfoPanel/SelectionPanel/
  ActionGrid/Toast` semua `_hidden`).
- **Temuan lanjutan (5)–(8) — semua diperbaiki + diverifikasi ulang**:
  (5) modal KREDIT memakai permukaan panel semi-transparan (α=0.92) sehingga
  teks/tombol panel di belakangnya SAMAR TERBACA di atas dialog (kesan teks
  bertumpuk, kritik #3) → dialog kini punya permukaan sendiri `UiTheme.C_MODAL`
  (α=0.995) + scrim modal penuh yang menangkap tap di luar dialog (standar
  Material: tap luar menutup) + marker `QA:MENU:MODAL scrim/surface_alpha`;
  (6) **ditemukan dari foto portrait**: label dunia 3D "Pusat Komando Lv1"
  terlihat besar di atas panel menu (marker lama melaporkan `vis=true` →
  `LABEL_DBG` memang menunjuk label yang benar-benar tampil) → `_declutter_labels`
  kini menyembunyikan SEMUA label saat `_menu_idle` + marker terukur
  `QA:SCENE:LABEL_MENU state=hidden total=1` (gate `game` memeriksanya) dan
  verifikasi piksel "teks netral panjang di luar panel = 0 baris" (foto lama:
  45 baris span 616 px → foto baru: 0);
  (7) panel menu (672 design px) meluber di portrait 360dp (`fit=MELIMPAH`,
  `SHOWCASE:DONE fail=1`) → lebar adaptif (`clamp(672 … avail-8dp sisi)`),
  kini `side_dp=12` di portrait & `fit=ok`;
  (8) cek gate `panel menu fit` menulis regex yang mengandaikan URUTAN token
  (`fit=ok` sebelum `credits_fit=ok`) → cek dipecah menjadi dua pencarian;
  pelajaran: jangan menulis cek berbasis urutan token marker.
**M3 #5 SELESAI (2026-10-13): Panel pengaturan nyata (audio / tampilan / ukuran UI / bahasa).**
- **Panel** `game/scripts/ui/settings_panel.gd` (`class_name SettingsPanel`) — satu
  komponen untuk menu utama & pause menu, dimiliki HUD (`hud.get_settings_panel()`,
  `open_settings()`): dialog 520dp × 320dp (≤560dp batas dialog Material) center,
  header + footer TETAP, isi seksi di `ScrollContainer` (layar landscape 360dp hanya
  muat ~4 baris), mode kolom-tunggal bila lebar < 450dp. Setiap kontrol ≥48dp.
- **Sistem nyata, bukan kosmetik**: `SettingsSystem` (autoload) menulis
  `user://settings.json` dan menerapkan ke **AudioServer** (bus Master/SFX/Music),
  **DisplayServer** (fullscreen, nilai disamakan dengan mode nyata bila browser
  menolak), `SettingsPanel`/HUD (scale = dpr/2 × hud_scale) dan **TranslationServer**
  (`I18n` id/en, 37 pesan). `AudioSystem` memuat SFX prosedural (`assets/audio/*.wav`
  + `game/assets/audio/sfx.json`, dibuat `tools/audio/make_sfx.py`: click 55 ms 900 Hz,
  confirm, cancel, wave alarm) ke bus SFX lewat pool 6 pemutar.
- **Gate baru** `settings`: 10/10 cek (bus nyata, slider → volume bus, ukuran UI → HUD
  scale, bahasa → locale, persistensi + reload, reset default, panel ≤560dp & di dalam
  layar, anti-tumpuk 0, bank SFX). Gate `ui` +4 cek (PENGATURAN dari pause menu =
  instance yang sama) dan gate `menu` memverifikasi `QA:SET:PANEL_OPEN`.
- **Temuan jujur yang diperbaiki di turn ini** (semua ditemukan lewat gate/foto, bukan
  dugaan): (1) `load_settings` hanya mengubah memori, tidak menerapkan ke bus audio;
  (2) `set_anchors_preset` tanpa offsets → root panel berukuran 0 sehingga dialog
  melimpah 1104×1147 px; (3) `custom_minimum_size` panel dihitung di luar margin
  stylebox → 552dp; (4) audit anti-tumpuk menghitung isi yang ter-clip ScrollContainer
  → 3 tumpukan palsu; (5) panel sebagai anak menu terpotong rect panel menu di portrait
  (footer keluar bingkai) → dipindah jadi milik HUD; (6) mode kolom-tunggal tidak
  berjalan setelah restrukturisasi scroll (iterasi baris masih ke `_body`); (7) pelaporan
  `on_screen` memakai skala asumsi dpr/2 → "TIDAK" palsu saat ukuran UI "Besar";
  (8) suite test memakai `await` → cek setelah await hilang senyap (runner sinkron).
- Bukti: `docs/m35_settings/REPORT_M35.md` + 5 foto (1280×720, 2340×1080, portrait
  1080×2340, pause menu) + `verify_m35.py`.
- Berikutnya: **M3 #6/#7** (misi/sector map atau audio final) — lihat DEV_PLAN
  milestone M3 di atas.

**M3.7c SELESAI (2026-10-13): Card katalog tanpa label kata (tiruan referensi).**
( kritik user: "cek lagi dan search lagi reference ui ux card layout game strategi lain,
  tata letaknya dll, tiru itu. Satu catatan yg paling utama: semua card itu 70% tidak ada
  teks label; yang pakai label cuma menu, itu pun tidak semua." )
- **Riset dulu, bukan asumsi**: `docs/REFERENCES_CARD_LAYOUT.md` — sumber (blog resmi
  Supercell/Clash of Clans, gameuidatabase, interfaceingame, tekrevol, bandurart, itch.io kit,
  + foto lokal `docs/references/doomsday/`) lalu tabel pemetaan referensi → komponen.
- **Komponen bersama** `CatalogTile` (tile 76dp ikon 70% + badge ANGKA, tab kategori 48dp
  ikon-saja, overlay gembok) dipakai BANGUN & ARMADA; marker `QA:CARD:TILE`/`QA:CARD:SUMMARY`.
- **Koreksi tafsir kritik #4**: audit label dipecah — chrome menu/HUD wajib berlabel
  (`QA:HUD:LABELS 10/10, catalog_tiles=16`), tile katalog tanpa label kata (`with_text=0`,
  `label_free_pct=100` ≥ 70 kriteria user).
- **Verifikasi**: gate `ui` 29/29 (7 check card/fit/badge baru), `verify_ui_m3` 20/20,
  `verify_hud_layout` 63/63 atas 9 foto baru; cacat yang ditemukan di turn ini (tombol PRODUKSI
  keluar modal + check fit lolos-palsu) diperbaiki dan dilaporkan terbuka.
- Berikutnya: **M3 #4 Main menu** atau M3 #6/#7.

## Out of scope for M1/M2 (explicitly)

Multiplayer/backend, monetization, commander/hero system, capital ships,
deep tech tree, boss fights, final audio, mobile-specific optimization,
WaveDirector auto-scheduling from sectors (currently API-driven).
