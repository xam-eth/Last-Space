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

## Milestone 2 — Stability, balance & performance 🟡 IN PROGRESS (pilot asset SHP-001 ✅ VERIFIED 2026-10-10)

1. ✅ **Visual real game (human requirement) — SELESAI (pilot):** pilot asset
   `SHP-001` through full pipeline (Blender → GLB → runtime scene → Godot) +
   `ASSET_ACCEPTANCE_CRITERIA.md` — **VERIFIED** (tests 190/0, asset showcase
   11/0, vision evidence `game_asset.png`; detail di `MASTER_ASSET_INVENTORY.md`
   — Log Pilot Asset). Placeholder box kini hanya fallback untuk kapal tanpa
   `model_path` (alien). Game = visual real (interceptor 3D di base + battle).
   Berikutnya: produksi aset lain (ALN-001 dulu) setelah art decision.
2. Headless economy simulation (hundreds of game-days) → progression tempo;
   label provisional values accordingly.
3. Stress scene (target unit counts) → frame-time/memory measurement in web build.
4. Cross-system integration tests for economy edge cases; bug fixes from M1 feedback.
5. Mobile performance test (needs device-class decision).

## Out of scope for M1/M2 (explicitly)

Multiplayer/backend, monetization, commander/hero system, capital ships,
deep tech tree, boss fights, final audio, mobile-specific optimization,
WaveDirector auto-scheduling from sectors (currently API-driven).
