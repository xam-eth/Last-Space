# PROJECT STATUS

This file must reflect the actual repository state. Never copy example features into Verified without evidence.

## Current approved milestone
**Milestone 1 — Representative core loop (vertical slice): COMPLETE (2026-10-10).**
All 7 phases (P1–P7) implemented and verified with gates per `QA_PLAN.md`.
**Milestone 2 — Stability, balance & performance: IN PROGRESS.**
Pilot asset `SHP-001` (visual real game) **VERIFIED** 2026-10-10 — detail di
"Last verified state (M2 pilot)" di bawah.

## Last verified state (M1 — 2026-10-10)
Full verification in headless Chromium (Godot 4.7.2 web/WASM build):

- **Test suite (`bash tools/godot/run_game_check.sh tests`): 167 PASS / 0 FAIL.**
  - Data validation (real `res://data/*.tres`: ids, references, values, first-build affordable)
  - Unit: SeededRng determinism, Economy (transactions/caps/round-trip), CombatSimulator (determinism, stats→outcome, turret, shield)
  - Integration: building+production (costs/rates/upgrade/repair/revive from data), combat (wave→sim→applied to state), progression (reward-once, territory), save/load (round-trip identical state, no duplicate rewards)
- **E2E playthrough (`run_game_check.sh e2e`): 36 PASS / 0 FAIL.**
  Full loop: build economy → produce (values from data) → hangar+turret+4 interceptors → wave 1 defended (defender wins) → territory sector_2 unlocked + reward from data → wave 2 damages 5 buildings → repair (revives wreck) → reactor upgrade → save→reset→load round-trip identical. Marker `QA:LOOP:COMPLETE`.
- **Game mode (`run_game_check.sh game`): PASS** — playable build boots, `QA:GAME:READY`.
- **Vision evidence (pixel-verified screenshots):**
  - `tools/godot/build/game_e2e.png`: 1091 distinct colors; HUD text 9,160 light px; gold HQ 888 px; cyan reactor 2,024 px — 3D base + HUD visible.
  - `tools/godot/build/game_play.png`: HUD 6,424 light px; gold HQ 3,914 px.
- **REGRESSION PASS:** full suite (167 + 36) green after final changes.

## Last verified state (M2 pilot asset SHP-001 — 2026-10-10)
Pilot asset pertama pipeline (governance §11) — **VERIFIED** end-to-end:

- **Asset:** interceptor 3D low-poly (132 tris hull / 268 tris total), panjang
  hull 4,20 m (kontrak 2–6 m), GLB 33,5 KB (budget < 500 KB), material
  MAT-001 (metalik + tekstur panel 1024²) / MAT-007 (engine cyan) / MAT-008
  (weapon red-orange). File: `assets/ships/shp_001_basic_interceptor.glb`
  (+ `.blend`, tekstur) dan runtime `game/assets/ships/*.tscn` + `.mesh.json`.
- **Orientasi KONTRAK terbukti:** `ASSET_PIPELINE.md` §2 forward-axis yang
  tadinya **ASSUMPTION** kini **VERIFIED** — test Godot data nyata:
  `weapon_z=-2.32 < engine_z=1.70` (depan kapal = -Z di Godot). Konvensi
  Blender terverifikasi: depan menghadap **+Y** (back view).
- **Integrasi:** `Ship` load model via `ShipDef.model_path` + collision box
  hull dari AABB aktual (size=(3,50, 1,00, 4,5)); `CombatVisualizer` menampilkan
  model nyata untuk kapal pemain di battle view; `FleetSystem` formasi parkir
  3 kolom hadap musuh (+Z). Placeholder box = fallback saja.
- **Gate (`run_game_check.sh all`, 4 suite):**
  - `tests` → **190 PASS / 0 FAIL** (167 lama + `ship_model` 15 cek + `asset_stress`)
  - `e2e` → **36 PASS / 0 FAIL** (REGRESSION PASS)
  - `game` → PASS (`QA:GAME:READY`)
  - `asset` (baru) → **11 PASS / 0 FAIL** — SHP-001 di scene perwakilan (base
    game nyata): 6/6 model + collision, wave_1, battle view pakai model.
    Marker `QA:ASSET:READY`; exit code = jumlah suite FAIL = 0.
- **Stress:** 100 instance model spawn terukur (log `stress.*`: waktu spawn ms,
  total tris), cleanup bersih.
- **Vision evidence:** `tools/godot/build/game_asset.png` — kamera gameplay:
  6 interceptor 3D dalam formasi (engine glow cyan + weapon marker terlihat),
  hasil battle + explosion, HUD "Fleet: 6 ships".
- **Preview tanpa tools:** root page load dari `web/` (build di-commit, pck
  baru) — `QA:GAME:READY`, 0 page errors. ✅ re-verifikasi setelah M2.

## Last verified state (UI/UX mobile-first landscape 16:9 — 2026-10-10, revisi setelah feedback)
Revisi total UI/UX sesuai arahan human developer: **mobile-first landscape
16:9 full screen**, semua komponen design system sebagai **overlay di atas
gameplay arena** (center arena clear), referensi langsung ke design system
game mobile landscape (sitasi di `UI_UX_DESIGN.md` §7).

- **Design system:** `UI_UX_DESIGN.md` ditulis ulang — layout zone (top bar
  chips / action grid kanan-bawah / info panel kiri-bawah / toast top-center /
  center arena clear), design tokens (spacing 8px grid, touch target 112px,
  margin 32), komponen standar, **icon design system** (rounded-square glossy
  badge, 1024→256 PNG, 12 ikon, generator `tools/ui/make_icons.py`).
- **HUD in-game (`hud.gd`) diimplementasi ulang** sesuai design system:
  top bar resource chips (ikon + nilai aktual + progress bar), action grid
  ikon 4×2 (7 aksi: 6 bangunan + Interceptor, label pendek, affordability
  real-time via `Economy.can_afford`), info panel, toast (auto-hide 5s),
  wave indicator. UI read-only; tombol memanggil API sistem yang sama.
- **Layout diverifikasi data nyata** (QA marker `HUD:LAYOUT`):
  `TopBar[32,16 1856x128]`, `ActionGrid[1392,748 496x300]` (cell 112×142,
  7/7 fully visible), `InfoPanel[32,824 720x224]`, `Toast[540,160 840x76]`.
  Bug yang ditemukan & diperbaiki via gate: TextureButton/TextureRect minimum
  size = ukuran tekstur (256) → grid overflow (row 2 off-canvas) — fix
  `ignore_texture_size = true`; label melebihi tombol → short names + wrap cap.
- **Ikon:** 12 ikon di-generate (PIL) sesuai icon design system; runtime via
  `game/assets/ui/icons.json` (embedded base64 — wasm tanpa loader .png);
  source PNG di `assets/ui/icons/`. Pixel-verified (glyph terdeteksi semua).
- **Root page mobile-first full screen:** viewport `viewport-fit=cover`,
  `user-scalable=no`, CSS full-screen (no scroll/bounce/zoom, touch-action
  none) — di-scope ke `body.game-page` (dashboard debug tetap scroll normal).
- **Verifikasi:** gate `run_game_check.sh all` → **4 suite PASS, exit 0**
  (tests 190/0, e2e 36/0, game PASS, asset 11/0); capture 2 resolusi
  (1280×720 & 896×414 mobile landscape) — HUD konsisten (anchor-based), center
  arena clear (0 piksel HUD di center, pixel-verified); toast "BATTLE:
  defender won" terlihat; `debug.html` tetap **56/56 PASS** (no regresi).
- **Evidence:** `tools/godot/build/game_play.png`, `game_asset.png`,
  `game_mobile_landscape.png`, `debug_uiux.png`.

## Last verified state (Revisi mobile-first ANDROID — 2026-10-11, feedback ke-3: resolusi, komponen terlalu besar, loading masih vertikal)

Berdasarkan **riset standar mobile-first Android** (sitasi `UI_UX_DESIGN.md` §7 [13]–[18], bukan asumsi):

- **Resolusi — root viewport ADAPTIF full screen:** `project.godot`
  `viewport_width/height=0` → viewport = window aktual (VERIFIED dari source
  Godot 4.7.2 `scene/main/window.cpp:1328`: `content_scale_size == 0` →
  `final_size = size`). Tidak ada lagi letterbox — game full screen di semua
  aspek (16:9 desktop sampai 19.5:9–21:9 Android). Design canvas HUD tetap
  **1280×720 = 640×360dp @2x** (screen referensi Android 360×640dp landscape
  16:9 [13]; "1280×720 for vector art" [16]); HUD di-scale uniform match-height
  (`hud.gd` `_apply_design_frame`, re-apply saat `size_changed`) — ukuran fisik
  komponen sama di semua device (tombol 96px design = 48dp di ponsel 3×/1080p).
- **Komponen design system (semua token dalam dp, 1px = 0,5dp):** touch target
  aksi **96px = 48dp** (Material minimum/optimal [13][14]; sebelumnya 112px =
  56dp — terlalu besar), `GRID_GAP` 16px = 8dp, chip 220×72 (36dp), info panel
  420×140 (70dp), toast 560×56, font 18–28px (9–14dp). Action grid **ikon-only**
  (label dibuang — label di dalam/atas tombol terbukti meng-inflate tinggi cell,
  evidence `HUD:LAYOUT` sebelum fix: cells 96×126/157, grid overflow 731>696);
  nama + biaya di tooltip. Komposisi action grid 208px = **29%** tinggi canvas
  (sebelumnya 41%).
- **Loading screen — komposisi LANDSCAPE:** bottom bar horizontal (satu baris,
  searah game): kiri brand (ikon + judul + status), kanan progress (persen +
  bar). Full-bleed cinematic slideshow. Update: `index.html`, `debug.html`,
  `debug/style.css`, `debug/loading.js`. Background 5 JPG **1376×768 (16:9)**,
  ukuran aktual diverifikasi PIL. Visual VERIFIED via capture
  (`tools/godot/build/loading_landscape.png` @896×414).
- **Verifikasi (data nyata):** gate `run_game_check.sh all` → **4 suite PASS,
  exit 0** (tests 190/0, e2e 36/0, game PASS, asset 11/0). `HUD:LAYOUT`
  @1280×720: `viewport[1280x720] scale[1.000] TopBar[24,12 1232x96]
  ActionGrid[824,488 432x208] InfoPanel[24,556 420x140] Toast[360,120 560x56]`,
  cells 7/7 **96×96**. `HUD:LAYOUT` @896×414 (mobile landscape ~19.5:9):
  `viewport[896x414] scale[0.575]` — arena full screen tanpa letterbox (edge
  pixel stdev 4–10 = scene, bukan bar), HUD scaled+centered (cells 55×55 =
  96×0.575). `debug.html` **56/56 PASS** (no regresi). Evidence:
  `tools/godot/build/game_play.png`, `game_mobile_landscape.png`,
  `loading_landscape.png`, `debug_res.png`.

## Last verified state (M2 #2 — Simulasi ekonomi headless 200 hari — 2026-10-11)

- **EconomySim** (`game/tests/e2e/economy_sim.gd`, mode `sim`, suite `sim` di
  `run_game_check.sh`): strategi build order data-driven, wave terjadwal via
  API, waktu deterministik (`TimeSystem.advance_ticks`, seed tetap 4242).
  1 hari = 600 ticks; **200 hari = 120.000 ticks, wall 6,3s** (web build).
- **Hasil terukur (PROVISIONAL — data balance belum di-tuning):**
  `QA:SIM:METRICS days=200 ticks=120000 seed=4242 wall_ms=6349
  final_energy=1600 final_minerals=900 min_energy=252 min_minerals=39
  ships_alive=6 buildings=12 turrets=4 shields=1 first_ship_day=8
  sector2_day=12 wave1_winner=defender wave2_winner=defender defense_wins=2
  bottleneck_top=minerals bottleneck_events=5 storage_full_days=165`
- **Interpretasi:** tempo progression sehat (kapal hari 8, sektor hari 12,
  dua wave berhasil). Bottleneck awal = **minerals**; storage penuh 165/200
  hari → produksi > konsumsi mid-game (perlu sink: upgrade/repair/rebuild).
- **Verifikasi:** gate `run_game_check.sh all` → **5 suite PASS, exit 0**
  (tests 190/0, e2e 36/0, game PASS, asset 11/0, **sim 12/0**); 0 pageErrors.
- **Evidence:** `tools/godot/build/game_sim.png(.json)`.

## Last verified state (M2 #3 — Stress scene performa — 2026-10-11)

- **StressScene** (`game/tests/e2e/stress_scene.gd`, mode `stress`, suite
  `stress`): 42 kapal (30 attacker + 12 defender, model SHP-001 sementara) + 8
  turret; target counts PROVISIONAL. Sample FPS/frame-time/memory/draw-calls
  tiap 1 detik selama 12 detik.
- **Hasil terukur (web build, headless Chromium — SwiftShader SOFTWARE GL,
  baseline sandbox; budget TBD menunggu device class):**
  `QA:STRESS:METRICS ships=42 turrets=8 samples=12 wall_ms=13501 fps_avg=12.5
  fps_min=11.0 frame_ms_avg=80.1 frame_ms_max=144.5 process_ms_max=0.14
  draw_calls_avg=230 render_objects_max=454 nodes_max=427`; JS heap 8.3MB
  (page.metrics; Godot MEMORY_STATIC=0 — release tracking off; wasm memory tidak
  ter-expose di headless). Tidak ada freeze (max frame 144.5ms).
- **Bug ditemukan & diperbaiki:** HUD FLEET chip stale (tidak listen
  `fleet_changed`) → fix `hud.gd` (`_on_fleet_changed`).
- **Verifikasi:** gate `run_game_check.sh all` → **6 suite PASS, exit 0**
  (tests 190/0, e2e 36/0, game PASS, asset 11/0, sim 12/0, stress 8/0 +
  memory PASS); 0 pageErrors.
- **Evidence:** `tools/godot/build/game_stress.png(.json)` (formasi 42 kapal
  terlihat, kamera framing penuh).

## Last verified state (M2 #4 — Integration tests edge cases ekonomi — 2026-10-11)

- **TestEconomyEdge** (`game/tests/integration/test_economy_edge.gd`, 20 check,
  semua ekspektasi dari `res://data`): caps (earn terbuang saat penuh, zero-earn
  saat penuh), interrupted production (progress antrian konstruksi survive
  round-trip state), production-wasted saat storage penuh (tercatat penuh,
  tidak double-earn), insufficient resources (konstruksi gagal atomik — tanpa
  partial spend), repair costs (no-funds → gagal atomik; amount dipotong ke
  missing; cost = per_hp × actual). reward-once sudah dicover test_progression.
- **Bug fix:** HUD FLEET chip stale (tidak listen `fleet_changed`) → fix
  `hud.gd` (ditemukan via stress scene M2 #3).
- **Verifikasi:** gate `run_game_check.sh all` → **6 suite PASS, exit 0**
  (tests **210/0**, e2e 36/0, game PASS, asset 11/0, sim 12/0, stress 8/0 +
  memory PASS); 0 pageErrors.
- **M2 tersisa:** item 5 mobile performance test — **BLOCKED**, butuh keputusan
  "minimum device class" (unapproved decision, ROADMAP) dari human developer.

## Verified capabilities
- **Framework core:** EventBus, TimeSystem (fixed tick + manual advance), SeededRng (splitmix64, deterministic), GameData (data loader), Economy (single owner of balances), QaMarkers (QA markers with real values), SaveSystem (versioned JSON), GameManager (phase state machine).
- **Game systems:** BuildingSystem (+Building with 4 damage states + placeholder visuals), ProductionSystem (queues + passive production, integer-exact), FleetSystem, CombatSimulator (pure, deterministic), WaveDirector (telegraph→simulate→apply), CombatVisualizer (plays back actual BattleResult), ProgressionSystem (reward exactly-once, territory unlock), HUD (read-only, real values).
- **Data-driven:** all balance values in `game/data/*.tres` (17 files); code contains no balance numbers.
- **Toolchain:** vision capture, Blender bpy, Godot web runtime, editor-less packaging (`make_pck.py` + `make_script_class_cache.py` for class_name resolution without the editor), `run_game_check.sh` CI harness (4 suite: tests/e2e/game/asset).
- **Asset pipeline (pilot VERIFIED):** Blender headless → GLB (kontrak) +
  editor-less runtime scene (.tscn + mesh.json via `asset_model_scene.gd`,
  tekstur embedded base64 — karena build wasm tidak punya loader glTF/.png)
  → terintegrasi di game (fleet + battle view) dengan acceptance test
  (orientasi/skala/material/collision dari data nyata). Generator:
  `tools/blender/make_shp_001.py` (reproducible; source `.blend` di `assets/`).

## Implemented but not verified
- Alien ships (`ALN-*`) masih placeholder box di battle view — pilot berikutnya
  `ALN-001` setelah art decision. Player ships sudah model nyata (SHP-001).

## Known blockers
1. **Godot editor GUI unavailable in this sandbox** (no X11/GL; release assets blocked). Mitigated (VERIFIED): web/WASM runtime + editor-less pck/class-cache generation. Editor binary needed on dev machines for scene editing.
2. **Bulk asset production gated** on open art decisions (camera, style,
   arena) — pilot asset `SHP-001` sudah VERIFIED (gate pilot selesai).

## Next smallest high-value task (Milestone 2)
1. ✅ Pilot asset `SHP-001` — VERIFIED (2026-10-10).
2. **Economy simulation** (headless, hundreds of game-days) to check progression tempo; label provisional values.
3. **Stress scene** for performance measurement in the web build (sudah ada
   `asset_stress` untuk model: 100 instance terukur; berikutnya stress penuh
   dengan banyak unit + efek di scene game).
4. **Pilot asset berikutnya `ALN-001`** (alien scout) — mengganti placeholder
   attacker di battle view; pipeline sudah terbukti (reuse generator pattern).

## Latest verification record
- Date: 2026-10-10 (update M2 pilot asset)
- Branch: `arena/d80e2902-last-space`
- Tests actually run (all in headless Chromium, Godot 4.7.2 web/WASM):
  1. `run_game_check.sh tests` → `TESTS:DONE passed=190 failed=0 skipped=0` — PASS
  2. `run_game_check.sh e2e` → `TESTS:DONE passed=36 failed=0 skipped=0` + `QA:LOOP:COMPLETE` — PASS
  3. `run_game_check.sh game` → `QA:GAME:READY`, 0 page errors — PASS
  4. `run_game_check.sh asset` (baru) → `TESTS:DONE passed=11 failed=0` + `QA:ASSET:READY` — PASS (pilot SHP-001 di scene perwakilan)
  5. Root page (preview tanpa tools, load dari `web/`) → `QA:GAME:READY`, 0 page errors — PASS
  6. Pixel/visual analysis of screenshots (Pillow + manual view): `game_asset.png` menunjukkan 6 interceptor 3D (engine glow cyan + weapon marker), battle + explosion, HUD — model nyata terlihat di kamera gameplay.
  7. UI/UX mobile-first landscape: HUD layout dump (`QA:HUD:LAYOUT`) semua zona sesuai design tokens; capture 2 resolusi (1280×720 + 896×414) konsisten; center arena clear (pixel-verified); `debug.html` 56/56 PASS (no regresi CSS).
- Runtime/device: sandbox Debian 12 x86_64; Chromium headless (SwiftShader WebGL2); no physical device testing.
- Limitations:
  - Alien ships masih placeholder (pilot ALN-001 berikutnya); player ships sudah model nyata.
  - Tidak ada LOD/animasi/rig untuk SHP-001 (pengecualian terdokumentasi sesuai kontrak kapal kecil).
  - Data values are PROVISIONAL (marked in .tres) pending economy simulation + playtest.
  - No mobile/desktop build or on-device performance measurement yet.
  - WaveDirector auto-scheduling from sectors not yet implemented (e2e schedules waves via API).
  - Build wasm tidak punya loader glTF/.png runtime → pipeline editor-less (.tscn + mesh.json + tekstur embedded); editor Godot di dev machine tetap bisa import .glb langsung.

## Decisions requiring human approval
- Multiplayer/backend scope (default: local single-player, none planned).
- Monetization (none planned).
- Minimum device class (blocks mobile performance budget).
- Performance budget (after device class + stress scene).
- Commander/hero system (expansion, not vertical slice).
- Art decisions blocking bulk asset production: camera (isometric/top-down, rotatable?), combat arena (separate vs one world), fleet size on screen, fortress modular vs single model, visual style (realistic vs stylized).

## Requirements (recorded from human developer, 2026-10-10)
- **Visual harus real game — bukan "asal jalan".** Visual placeholder (kotak
  berwarna) di M1 bersifat sementara. Sebelum produksi konten/asset, visual
  harus diganti aset nyata melalui pilot asset `SHP-001` +
  `ASSET_ACCEPTANCE_CRITERIA.md` + `ART_DIRECTION.md` (lihat `DEV_PLAN.md` M2).
- **Debug & preview lewat HTML/JS di root repo** (bukan UI Godot): `index.html`
  meng-import `debug/*.js`, di-serve dengan
  `python3 -m http.server 8000 --bind 0.0.0.0` dari root repo. Dashboard
  menjalankan check setup + logika (berbasis data nyata) dan menampilkan
  preview game (iframe ke build Godot web).
- **Halaman utama website = GAME (bukan debug), 16:9 full landscape.**
  Root `index.html` menampilkan loading screen cinematic lalu game playable;
  game di-render full landscape ADAPTIF (viewport = window, `viewport_width/height=0`
  — full screen tanpa letterbox; design canvas HUD 1280×720 = 640×360dp,
  di-scale match-height).
  Dashboard debug pindah ke `debug.html`.
- **UI/UX workflow awal + aset 2D (sebelum M2, 2026-10-10):** `UI_UX_DESIGN.md`
  (workflow desain→aset→implementasi→verifikasi, design system, screen
  inventory) + aset loading screen di `assets/ui/loading/` (5 background
  cinematic 16:9 + icon loading PNG). Website root kini punya **loading screen**:
  slideshow background cinematic (crossfade 4s) + icon loading (spin + pulse
  glow) + progress bar — diverifikasi via screenshot.

## Last verified state (M2 — Pilot ALN-001 "Alien Scout" — 2026-10-11)

- **Pilot aset kedua (sisi alien) SELESAI & VERIFIED** — `ALN-001` melalui
  pipeline penuh (Blender → GLB → runtime scene → Godot), acceptance
  `test_ship_model_aln.gd` (13 cek, data nyata): model biomekanis ASIMETRIS
  (ART_DIRECTION §2 Alien), MAT-002 chitin gelap + tekstur 1024, inti energi
  hijau terang (MAT-022, focal), mesin hijau (MAT-021), senjata ungu (MAT-023)
  — aksen alien diputuskan saat pilot (beda dari manusia cyan/red-orange).
  372 tris total, GLB 42 KB (< 500 KB budget), panjang ~3,5 m (kontrak 2–6 m),
  orientasi **weapon_z=-1,72 < engine_z=1,58 (depan -Z, konsisten SHP-001)**.
  Generator: `tools/blender/make_aln_001.py`; source
  `assets/ships/aln_001_scout.glb/.blend` + tekstur chitin.
- **Terintegrasi:** `aln_001_scout.tres` `model_path` diisi → `Ship` load model
  + collision hull; **CombatVisualizer attacker kini model ALN-001** (bukan
  placeholder box); stress scene attacker 30 unit pakai ALN-001; asset showcase
  cek model alien (`asset.aln_*`, `asset.battle_view_has_alien_models`).
- **Gate:** `run_game_check.sh all` → 6 suite PASS, exit 0 (tests **230/0** —
  +20 cek `ship_model_aln`, e2e 36/0, game PASS, asset **17/0** — +6 cek ALN
  termasuk `asset.battle_view_has_alien_models battle_alien_models=4`,
  sim 12/0, stress 8/0 + memory PASS 8,1MB; `web/` ter-sync).
  Stress scene kini: attacker 30 unit = model ALN-001 asli
  (`models=defender=shp_001_interceptor attacker=aln_001_scout`).
  Vision evidence: `tools/godot/build/game_asset.png` (6 interceptor formasi +
  HUD; FLEET chip 6 ships — fix stale terbukti), `game_stress.png` (42 kapal
  formasi + 8 turret, FLEET 42 ships).
- **Art decision (dari pilot):** aksen energi alien = hijau, senjata = ungu
  (konsisten untuk semua aset alien berikutnya). Bulk aset alien (ALN-002 dst.)
  tetap menunggu art decision besar (ROADMAP unapproved: camera, combat arena,
  fleet size, visual style).
- **Berikutnya:** M2 item 5 mobile performance test — **BLOCKED** (butuh
  keputusan "minimum device class", unapproved, ROADMAP); setelah M2 → M3
  (konten & balance) menunggu input human developer.

## Last verified state (M2 #5 — Device-class perf measurement harness — 2026-10-11)

- **M2 item 5 (mobile performance test) masih BLOCKED** pada keputusan
  "minimum device class" (unapproved, ROADMAP) — tetapi **harness pengukuran
  sudah siap & terverifikasi**: suite `perf` baru di `tools/godot/run_game_check.sh`
  (`--throttle` via CDP `Emulation.setCPUThrottlingRate` di `capture.mjs`).
- **Hasil ukur (data nyata, 3 run × 8/8 stress PASS, exit 0, 0 pageErrors):**
  throttle **1x** (baseline) fps_avg=12,2 / fps_min=11,0 / frame 81,3–147,9 ms;
  **4x** (~mid-tier) fps_avg=8,8 / fps_min=7,0 / frame 112,7–150,0 ms;
  **6x** (~low-end budget) fps_avg=8,5 / fps_min=5,0 / frame 111,8–150,0 ms;
  JS heap ~8 MB (via `page.metrics`). Renderer = SwiftShader software GL
  (indikasi sensitivitas CPU, **bukan** device fisik). Reports:
  `tools/godot/build/game_perf_t{1,4,6}.png.json`.
- **Decision brief:** `DEVICE_CLASS_BRIEF.md` — tabel hasil, interpretasi jujur
  (VERIFIED/LIKELY/ASSUMPTION/UNKNOWN), 3 opsi device class (A low-end / B
  mid-tier / C high-end) + rekomendasi berbasis data (**B mid-tier**).
  Keputusan tetap pada human developer.
- **Berikutnya setelah keputusan:** budget numerik (fps target, frame max,
  memory cap) di-set di `stress_scene.gd`; suite `perf` jadi gate verifikasi.
- **Full gate:** `run_game_check.sh all` → **7 suite PASS, exit 0** (tests 230/0,
  e2e 36/0, game PASS, asset 17/0, sim 12/0, stress 8/0 + memory 8,4MB,
  perf 3×8/0); `web/` ter-sync.

## Last verified state (KOREKSI FATAL — resolusi full screen semua aspek — 2026-10-11)

**Kesalahan diakui (feedback human):** resolusi/ukuran layar salah — dibuat
berdasarkan asumsi 16:9 tanpa verifikasi di aspek Android modern. **Akar
masalah (data nyata):** `stretch/aspect="keep"` + HUD design-frame 1280×720
di-center → di layar 19.5:9/20:9 (mayoritas Android modern) HUD hanya 1920px
 di tengah, kiri/kanan kosong pekat (terlihat seperti black bars besar).

**Perbaikan (2 perubahan):**
1. `project.godot`: `stretch/aspect` `keep` → **`expand`** (full screen semua
   aspek).
2. `hud.gd` `_apply_design_frame()`: design-frame center → **full-rect**
   (root = full window, `size = vp/scale`, scale match-height) — zona HUD
   di-anchor ke edge window; ukuran fisik komponen tetap (ikon 48dp, margin
   12dp).

**Verifikasi data nyata (5 resolusi standar mobile Android):**
`QA:HUD:LAYOUT` — 1280×720 (margin 24px), 1920×1080 (36px), **2340×1080
(19.5:9)**: TopBar[36,18 2268×144] → kanan = 2304, sisa 36px = **full width**;
ActionGrid kanan 2304; **2400×1080 (20:9)**: TopBar sampai 2364 (sisa 36);
**2560×1440**: TopBar sampai 2512 (sisa 48). Komponen tetap 48dp
(96/144/192px). Tidak ada letterbox/black bars. Evidence:
`tools/godot/build/res_before_*` vs `res_after_*`.

**Gate:** `run_game_check.sh all` → **7 suite PASS, exit 0** (tests 230/0,
e2e 36/0, game PASS, asset 17/0, sim 12/0, stress 8/0 + memory 7,8MB,
perf 3×8/0); `web/` ter-sync.

## Last verified state (Visual benchmark — 7 foto hasil akhir game — 2026-10-11)

- **Visual benchmark SELESAI — 7 foto hasil akhir game secara visual** di
  `docs/visual_benchmark/` (data nyata dari web build, diverifikasi piksel
  via Pillow sesuai QA_PLAN.md vision check — valid PNG, dimensi benar,
  tidak blank, warna khas aspek terlihat; ALL 7 PASS):
  1. `01_loading_screen.png` — loading cinematic (nebula + planet + fleet,
     brand, progress bar).
  2. `02_command_base.png` — game utama: HUD + 3D base (kamera gameplay).
  3. `03_fleet_formation.png` — 6 interceptor SHP-001 formasi (engine cyan).
  4. `04_battle_vs_alien.png` — battle defender vs attacker ALN-001
     (alien hijau terlihat; toast hasil "DEFENDER WON").
  5. `05_stress_42units.png` — 42 kapal (12 SHP-001 + 30 ALN-001) + 8 turret.
  6. `06_mobile_1920x1080_16x9.png` — mobile 16:9 full screen.
  7. `07_mobile_2340x1080_19.5x9.png` — mobile 19.5:9 full screen (HUD full
     width sampai edge kanan — diverifikasi piksel).
- Report: `docs/visual_benchmark/report.json` + `VISUAL_BENCHMARK.md`.
  Warna opsional (ungu weapon / hijau engine di kamera jauh) dicatat jujur
  di report (tidak wajib — terlalu kecil di kamera).
- Cara generate ulang: `bash tools/vision/visual_benchmark.sh`
  (butuh `source tools/env.sh`).
- Mengikuti instruksi: QA_PLAN.md (vision check), ASSET_ACCEPTANCE_CRITERIA.md
  §5.3 (vision evidence kamera gameplay), ART_DIRECTION.md §1 (3 lapisan
  visual: base/command, armada, alien — ketiganya tercakup foto 2/3/4).

## Last verified state (Research UI/UX + Gameplay flow a–z — 2026-10-11)

- **Research reference UI/UX "Domsday" (Doomsday: Last Survivors, IGG)** —
  pola yang dipelajari dari screenshot (tersimpan `docs/references/doomsday/`):
  top bar resource chips + nama pemain; gameplay = canvas 3D full screen +
  HUD minimal pojok; modal menu = panel tengah + title + close + sidebar tabs
  + grid of cards (ikon + quantity) + detail panel + tombol besar; dialog
  bubble bawah; countdown wave.
- **Pembacaan ulang `Game_Concept.md`** (a–z): 3 lapisan gameplay
  (base-building visual 3D, combat pesawat hasil simulasi + visualisasi,
  ekspansi wilayah); 2 mode (Command/Combat); loop 10 langkah; kondisi
  kerusakan bangunan; identitas visual §7; risiko §9; vertical slice §10.
- **Dokumen baru `GAMEPLAY_FLOW.md`** — gambaran utuh sebelum logika:
  mekanisme a–z, state machine (BOOT→LOADING→MAIN_MENU→COMMAND⇄BATTLE→
  PAUSE→GAME_OVER), **scene/frame inventory (Frame 1 loading → Frame 9
  territory unlocked)** dengan elemen/komponen/ukuran dp/posisi/logika tiap
  scene, komponen & ukuran standar (card/menu), mapping sudah-ada vs
  prioritas M3 (Build menu #1, Ship menu #2, Pause #3, Main menu #4,
  Settings #5, zoom kamera #6, kerusakan visual #7).
- **Tidak ada kode game yang diubah** — ini fase pemahaman (sesuai instruksi
  human: pahami konsep & reference dulu, tanpa itu logika akan asal-asalan).

## Last verified state (Research FULL frame-by-frame Doomsday — 2026-10-11)

- **Research diperdalam sesuai feedback human** ("belum research full frame by
  frame"): dokumen lengkap **`docs/references/doomsday/FRAME_BY_FRAME.md`** —
  F0 splash/loading → F1 login/menu → F2 tutorial (dialog bubble + panah) →
  **F3 shelter base view (HUD lengkap: top bar resource + quest panel kiri
  tengah + Region kiri bawah + chat + tombol Info/Intel/Events tengah bawah +
  Campaign/Bag/Alliance/Hero kanan bawah + hamburger)** → F4 building selected
  (nama + level + panah hijau + aksi konteks Info/Level Up/Buff) → F5 build
  menu → F6 BAG modal (sidebar tabs + grid cards + detail + USE) → F7 hero
  menu → F8 radar/intel/events → F9 world map/region (zona foto landscape) →
  F10 march/battle + report → F11 alliance → F12 shop/VIP → F13 settings.
- **30 screenshot referensi** tersimpan di `docs/references/doomsday/`
  (milik IGG — research internal, bukan aset game).
- **Pola baru yang diadopsi** (update `GAMEPLAY_FLOW.md` §0): quest/mission
  panel kiri tengah; tombol Region (world map) kiri bawah; indikator bangunan
  terpilih + aksi konteks (Info/Level Up/Buff); event icons → notifikasi game;
  hamburger → pause/settings; battle report panel.
- **Ukuran terukur dari screenshot** (1000×481 ≈ tinggi 360dp): top bar 48dp;
  tombol bawah 48–64dp; chip 110×36dp; card 56dp square; sidebar tab 48dp;
  modal ≤ 80% lebar; margin 12dp — konsisten dengan UI_UX_DESIGN §3.
- **Tidak ada kode game yang diubah** — fase research/pemahaman.

## Last verified state (M3 #1 — Build menu + quest panel + building selected)

- **Status: VERIFIED + REGRESSION PASS** (gate `run_game_check.sh all`:
  **8/8 suite PASS exit 0** — tests 256/0 [tambah 26: quest_tracker 15 +
  build_menu 11], e2e 36/0 [quest reward delta], game, asset 17/0, sim 12/0,
  stress 8/0 + JSHeap 9.5MB, **ui 10/0 (suite baru)**, perf 3×8/0).
- **Build menu** (`game/scripts/ui/build_menu.gd`, pola Doomsday BAG,
  GAMEPLAY_FLOW.md Frame 5): modal 512×252dp (80%×70%) anchor center semua
  aspek, title + close X + grid 5 card (ikon+nama+biaya+count) + detail panel
  (efek dari data .tres + biaya + waktu + tombol BUILD 48dp). Atomic via
  `ProductionSystem.enqueue_construction`. Action grid: tombol "build" (ikon
  baru) + interceptor.
- **Quest panel kiri tengah** (pola Doomsday F3/F8): `quest_tracker.gd` — 4
  objektif slice (Power Up / First Hangar / First Squadron / Hold the Line),
  progress via EventBus, reward-once, save/load round-trip. Event baru:
  `quest_progress`, `quest_completed`.
- **Building selected** (pola Doomsday F4): klik bangunan di arena 3D
  (unproject nearest — tanpa physics server, robust di WASM) → panah hijau
  indikator + selection panel bawah tengah (nama + level + HP + UPGRADE).
  `base_scene.gd` pick via `_unhandled_input`.
- **5 ikon baru** (`tools/ui/make_icons.py`): build, close, upgrade, quest,
  info (total 17 ikon, ikut icon design system).
- **Evidence visual**: `docs/ui_m3_build_menu/` — 5 foto (baseline, command
  selected, build menu; 1280×720 + 2340×1080) + `report.json` +
  `UI_M3_REPORT.md`. Verifikasi piksel **12/12 PASS** (`verify_ui_m3.py`):
  modal center (border x=402 @2340×1080), quest/selection panel border,
  arrow hijau 674px saat selection vs 0px baseline, top bar full width tanpa
  black bars.
- **Catatan balance (ditemukan, belum diputuskan human)**: `command_core`
  base_cost = {} → upgrade gratis (data PROVISIONAL). Masuk daftar keputusan
  balance human.
- **web/ tersinkron** (build WebGL dengan M3 #1 — preview tanpa install tools).
- Berikutnya: **M3 #2 Ship menu** (pola Doomsday Hero).

## Last verified state (M3 #2 — Ship menu / produksi kapal)

- **Status: VERIFIED + REGRESSION PASS** (gate `run_game_check.sh all`:
  **8/8 suite PASS exit 0** — tests 271/0 [+11 ship_menu], e2e 36/0,
  game, asset 17/0, sim 12/0, stress 8/0 + JSHeap 9.5MB, **ui 13/0**
  [+3 ship menu, marker `QA:UI:SHIP_DONE`], perf 3×8/0).
- **Ship menu** (`game/scripts/ui/ship_menu.gd`, pola Doomsday Hero F7,
  GAMEPLAY_FLOW.md Frame 6): modal sama (512×252dp, anchor center semua
  aspek), title "FLEET" + close X + grid card kapal pemain (cost non-empty
  dari data — hanya `shp_001_interceptor`; alien tidak diproduksi) + detail
  (stats HP/ATK/ARMOR/SPEED/SUPPLY dari `.tres`, biaya, waktu, tombol
  PRODUCE 48dp). Atomic via `ProductionSystem.enqueue_ship` (cek hangar +
  dana; tanpa keduanya → gagal tanpa partial spend).
- Action grid: tombol **fleet** (ikon interceptor) membuka ship menu.
- **Evidence visual**: foto `05_ship_menu_1280x720.png` +
  `06_ship_menu_2340x1080.png`; verifikasi piksel **16/16 PASS** (modal
  center kedua aspek, border terdeteksi).
- **web/ tersinkron** (build dengan M3 #1 + M3 #2).
- Berikutnya: **M3 #3 Pause menu** (tombol menu sudah ada, modal masih
  "coming soon").
