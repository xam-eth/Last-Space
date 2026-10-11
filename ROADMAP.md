# ROADMAP — Last-Space

Long-term source of truth for the project. The **current approved milestone**
governs immediate work. Derived from `ROADMAP_TEMPLATE.md`, `Game_Concept.md`
(§10 vertical slice), `Asset_Request_List.md` (§19, §24), and
`RISK_ANALYSIS.md` (work order §10). All work follows `AI_GOVERNANCE.md`;
verification gates and QA per phase are defined in `QA_PLAN.md`.

## Standing limits (from RISK_ANALYSIS.md — conclusion)

Three boundaries that apply before any large-scale production:

1. **Technical limit:** every core system must have testable completion
   criteria (see `QA_PLAN.md` gates).
2. **Production limit:** do not multiply assets before the 3D asset pipeline
   is proven with a pilot asset (see `ASSET_ACCEPTANCE_CRITERIA.md`).
3. **Gameplay limit:** do not treat feature count as proof the game is fun —
   validate one complete gameplay loop first.

## Project baseline (confirmed)

- **Game:** Last-Space — 3D space base-building + fleet combat strategy.
  Core loop (`Game_Concept.md` §6): build base → produce resources → build
  fleet → attack territory → seize resources → aliens attack → defend →
  repair/upgrade → unlock tech → strike alien source → unlock sectors.
- **Engine:** Godot 4.7.2 (`4.7.2.stable`), GDScript, `gl_compatibility`
  (WebGL 2.0) renderer for the web build.
- **3D assets:** Blender 4.5 LTS (headless `bpy`) → `.glb` → Godot.
- **Verification runtime:** Godot web (WASM) build in headless Chromium
  (`@sparticuz/chromium` + `puppeteer-core`) with screenshot/vision capture —
  see `TOOLCHAIN.md` and `tools/`.
- **Architecture:** `TECH_ARCHITECTURE.md` (framework modules, data-driven,
  deterministic simulation, single source of truth).
- **Data contracts:** `DATA_CONTRACTS.md` (all balance values in
  `res://data/*.tres`; nothing hardcoded in code).
- **Target platforms (order):** Web (primary verification target) → desktop →
  mobile (device class TBD — unapproved decision).
- **Scope gate:** local single-player only; no multiplayer/backend unless
  explicitly approved (RISK_ANALYSIS bottleneck #8).

## Milestone 0 — Baseline, toolchain & architecture ✅ COMPLETE

- [x] **Tools VERIFIED** (re-verified 2026-10-10 after sandbox reset):
      Chromium vision tool (HeadlessChrome 153, valid PNG + pixel check),
      Blender bpy 4.5.14 LTS (GLB export/re-import), Godot 4.7.2 web/WASM
      (engine boots a real project in Chromium, 3D render pixel-verified).
- [x] Toolchain fully reproducible: `tools/setup_stublibs.sh` (auto
      stub-lib generation), `tools/godot/setup_godot_web.sh`,
      `tools/godot/make_pck.py`, `tools/godot/run_smoke.sh`,
      `tools/vision/capture.mjs` (auto-creates output dirs, `--serve`,
      `--wait-for`).
- [x] **Architecture prepared (no game code, per human decision):**
      `TECH_ARCHITECTURE.md` (framework module design),
      `DATA_CONTRACTS.md` (schemas + ownership), `QA_PLAN.md`
      (verification gates + per-phase QA), `RISK_ANALYSIS.md` (saved).
- [x] Governance pack installed; `PROJECT_STATUS.md` reflects actual state.

**Acceptance:** baseline + architecture reproducible and documented with
evidence — met. Evidence: `TOOLCHAIN.md`, `PROJECT_STATUS.md`.

## Milestone 1 — Representative core loop (vertical slice) 🔵 NEXT

Phases follow the work order in `RISK_ANALYSIS.md` §10 (phases 1–5) and the
detailed task list in `DEV_PLAN.md`. Each phase must pass the gates in
`QA_PLAN.md` (NOT STARTED → IMPLEMENTED → RUNNABLE → VERIFIED → INTEGRATED →
REGRESSION PASS) — verified repeatedly with tests + QA markers based on real
data, not assumptions.

Scope (10 minimum features, `Game_Concept.md` §10):

1. Command Fortress (HQ) with health/damage states.
2. Energy + mineral gathering (production + storage caps).
3. One Fighter Hangar.
4. Hangar produces interceptors (queue + timer).
5. One defense turret.
6. Alien fleet attacks (telegraphed wave).
7. Ships + turret fight (deterministic simulation + 3D visualization of the
   actual result).
8. Fortress takes damage if defense fails (Normal/Damaged/Critical/Destroyed).
9. Repair and upgrade.
10. New territory unlocks after a successful defense.

Plus: save/load (fresh start → play → save → reload → continue) and
data-driven definitions in `res://data/`.

**Acceptance — MET:** connected end-to-end loop passes VERIFIED + INTEGRATED +
REGRESSION PASS gates with automated evidence:
- `run_game_check.sh tests` → 167 PASS / 0 FAIL
- `run_game_check.sh e2e` → 36 PASS / 0 FAIL + `QA:LOOP:COMPLETE`
- `run_game_check.sh game` → playable build PASS
- Screenshots pixel-verified (HUD + 3D base visible)
Evidence: `PROJECT_STATUS.md`, `tools/godot/build/game_*.png(.json)`.

## Milestone 2 — Stability, balance & performance

- Cross-system integration tests; economy/progression edge cases (insufficient
  resources, caps, interrupted production, repair costs, reward-once).
- Headless economy simulation (hundreds of game-days) to check progression
  tempo; provisional values labeled.
- Representative performance measurement in the web build: stress scene with
  expected unit counts; frame-time stability, memory, draw calls, overdraw.
  Numerical budgets only after the target device class is decided.
- Mobile performance test on the intended device class (needs the unapproved
  "minimum device class" decision). **Measurement harness ready (2026-10-11):**
  suite `perf` measures the stress scene at 3 emulated device classes (CPU
  throttle 1x/4x/6x) — recorded numbers + options in `DEVICE_CLASS_BRIEF.md`;
  still BLOCKED on the human decision (device class + budget).

**Acceptance:** integration tests green; economy edge cases tested; performance
measured in a representative build with recorded numbers.

## Milestone 3 — Content expansion

Add approved buildings, ships, enemy roles, sectors, missions, bosses per
`MASTER_ASSET_INVENTORY.md` priorities and `Asset_Request_List.md` §24
(phases Tahap 2–4). Every item must have a distinct gameplay purpose and reuse
validated systems (governance §9, §14; RISK_ANALYSIS bottleneck #7). No bulk
asset generation before the pilot asset passes `ASSET_ACCEPTANCE_CRITERIA.md`.

## Milestone 4 — Player validation

Test comprehension, fun, friction, and reasons to return; make changes based on
evidence (RISK_ANALYSIS §10 phase 10). Fix what the evidence shows before adding
more content.

## Unapproved decisions to resolve when needed

- **Multiplayer/backend scope:** default = local single-player, no backend.
- **Monetization:** none planned.
- **Minimum device class:** TBD — blocks mobile performance budgets.
- **Performance budget:** TBD — after device class + stress scene.
- **Commander/hero system:** expansion (Kelompok L), not vertical slice.
- **Art decisions blocking bulk asset production:** camera (isometric/top-down,
  rotatable?), combat arena (separate vs one world), fleet size on screen,
  fortress modular vs single model, visual style (realistic vs stylized).

## Change control

Changes to engine, renderer, core architecture, asset format, data contracts,
or backend direction require evidence, impact/migration analysis, alternatives,
and human approval (governance §7). This roadmap is updated minimally and only
to reflect actual changes.
