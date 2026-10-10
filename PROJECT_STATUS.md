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
  game di-render 16:9 full landscape (viewport 1920×1080, stretch
  `canvas_items` + aspect `keep`, letterbox gelap). Dashboard debug pindah ke
  `debug.html`.
- **UI/UX workflow awal + aset 2D (sebelum M2, 2026-10-10):** `UI_UX_DESIGN.md`
  (workflow desain→aset→implementasi→verifikasi, design system, screen
  inventory) + aset loading screen di `assets/ui/loading/` (5 background
  cinematic 16:9 + icon loading PNG). Website root kini punya **loading screen**:
  slideshow background cinematic (crossfade 4s) + icon loading (spin + pulse
  glow) + progress bar — diverifikasi via screenshot.
