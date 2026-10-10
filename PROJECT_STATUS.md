# PROJECT STATUS

This file must reflect the actual repository state. Never copy example features into Verified without evidence.

## Current approved milestone
**Milestone 1 — Representative core loop (vertical slice): COMPLETE (2026-10-10).**
All 7 phases (P1–P7) implemented and verified with gates per `QA_PLAN.md`.
**Milestone 2 — Stability, balance & performance: NEXT.**

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

## Verified capabilities
- **Framework core:** EventBus, TimeSystem (fixed tick + manual advance), SeededRng (splitmix64, deterministic), GameData (data loader), Economy (single owner of balances), QaMarkers (QA markers with real values), SaveSystem (versioned JSON), GameManager (phase state machine).
- **Game systems:** BuildingSystem (+Building with 4 damage states + placeholder visuals), ProductionSystem (queues + passive production, integer-exact), FleetSystem, CombatSimulator (pure, deterministic), WaveDirector (telegraph→simulate→apply), CombatVisualizer (plays back actual BattleResult), ProgressionSystem (reward exactly-once, territory unlock), HUD (read-only, real values).
- **Data-driven:** all balance values in `game/data/*.tres` (17 files); code contains no balance numbers.
- **Toolchain:** vision capture, Blender bpy, Godot web runtime, editor-less packaging (`make_pck.py` + `make_script_class_cache.py` for class_name resolution without the editor), `run_game_check.sh` CI harness.

## Implemented but not verified
- None known. Placeholder visuals (colored boxes) are intentional until art assets land.

## Known blockers
1. **Godot editor GUI unavailable in this sandbox** (no X11/GL; release assets blocked). Mitigated (VERIFIED): web/WASM runtime + editor-less pck/class-cache generation. Editor binary needed on dev machines for scene editing.
2. **Bulk asset production gated** on pilot asset `SHP-001` passing `ASSET_ACCEPTANCE_CRITERIA.md` + open art decisions (camera, style, arena).

## Next smallest high-value task (Milestone 2)
1. **Pilot asset `SHP-001`** through the full Blender→GLB→Godot pipeline + acceptance criteria (validates `ASSET_PIPELINE.md` before any bulk art).
2. **Economy simulation** (headless, hundreds of game-days) to check progression tempo; label provisional values.
3. **Stress scene** for performance measurement in the web build.

## Latest verification record
- Date: 2026-10-10
- Branch: `arena/d80e2902-last-space` (working tree; changes saved, not yet committed)
- Tests actually run (all in headless Chromium, Godot 4.7.2 web/WASM):
  1. `run_game_check.sh tests` → `TESTS:DONE passed=167 failed=0 skipped=0` — PASS
  2. `run_game_check.sh e2e` → `TESTS:DONE passed=36 failed=0 skipped=0` + `QA:LOOP:COMPLETE` — PASS
  3. `run_game_check.sh game` → `QA:GAME:READY`, 0 page errors — PASS
  4. Pixel analysis of screenshots (Pillow): HUD + 3D base verified non-blank with expected colors.
- Runtime/device: sandbox Debian 12 x86_64; Chromium headless (SwiftShader WebGL2); no physical device testing.
- Limitations:
  - Placeholder visuals (boxes) until pilot asset + art pipeline proven.
  - Data values are PROVISIONAL (marked in .tres) pending economy simulation + playtest.
  - No mobile/desktop build or on-device performance measurement yet.
  - WaveDirector auto-scheduling from sectors not yet implemented (e2e schedules waves via API).

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
