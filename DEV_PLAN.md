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

## Out of scope for M1/M2 (explicitly)

Multiplayer/backend, monetization, commander/hero system, capital ships,
deep tech tree, boss fights, final audio, mobile-specific optimization,
WaveDirector auto-scheduling from sectors (currently API-driven).
