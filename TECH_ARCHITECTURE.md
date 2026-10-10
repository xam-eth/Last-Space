# TECH ARCHITECTURE — Last-Space (Framework & Arsitektur Teknis)

Dokumen arsitektur lengkap untuk framework game. **Ini adalah tahap persiapan
(Phase 0): tidak ada kode game yang ditulis.** Dokumen ini menjadi kontrak
antara desain, implementasi, dan verifikasi. Semua keputusan di sini diambil
berdasarkan `Game_Concept.md`, `RISK_ANALYSIS.md` (bottleneck #1, #3, #5),
`AI_GOVERNANCE.md` §8/§13/§16, dan `DATA_CONTRACTS.md`.

## 1. Prinsip Arsitektur (mengikat untuk semua kode)

| # | Prinsip | Konsekuensi |
|---|---|---|
| A1 | **Data-driven** | Semua nilai balance (biaya, rate, HP, damage, waktu) hanya di `res://data/*.tres`. Kode tidak boleh mengandung angka balance. |
| A2 | **Single source of truth** | Setiap domain state punya SATU pemilik (lihat `DATA_CONTRACTS.md`). Sistem lain membaca/memutasi lewat API atau event — tidak ada state duplikat. |
| A3 | **Deterministic & testable** | Simulasi pertempuran adalah kelas murni (tanpa scene tree), RNG ber-seed, ekonomi pakai integer tick. Hasil bisa direproduksi dan diuji. |
| A4 | **Simulasi terpisah dari visualisasi** | `CombatSimulator` menghitung hasil; `CombatVisualizer` menampilkan hasil aktual tersebut. Visual tidak pernah mengarang hasil (governance §8). |
| A5 | **Decoupled via event bus** | komunikasi antarmodul lewat `EventBus` (autoload signal). UI hanya membaca state, tidak pernah menjadi pemilik state. |
| A6 | **Verifiable — bukan "asal jalan"** | Setiap sistem mengekspor marker QA (`QA:...`) dengan nilai state NYATA. Verifikasi dilakukan oleh test + capture tool, berdasarkan data nyata. |
| A7 | **Save/load adalah sistem inti** | Semua state yang harus bertahan terdefinisi dalam skema save versi (bukan polish di akhir). |
| A8 | **Performa sadar sejak awal** | Pooling untuk proyektil/VFX, instancing untuk objek berulang, LOD untuk kapal besar, quality settings. Diukur, tidak diasumsikan. |

## 2. Struktur Proyek (res://)

```
res://
├── project.godot
├── addons/                  # (kosong dulu; dev tools jika perlu)
├── assets/                  # lihat ASSET_PIPELINE.md §4
├── scenes/
│   ├── main.tscn            # entry scene → boot GameManager
│   ├── base/                # scene benteng (Command Mode)
│   ├── combat/              # scene arena pertempuran (Combat Mode)
│   ├── galaxy_map/
│   ├── menus/
│   └── ui/
├── scripts/
│   ├── core/                # ★ FRAMEWORK INTI (lihat §3)
│   │   ├── event_bus.gd
│   │   ├── game_manager.gd
│   │   ├── time_system.gd
│   │   ├── economy.gd
│   │   ├── save_system.gd
│   │   ├── game_data.gd
│   │   ├── qa_markers.gd
│   │   └── seeded_rng.gd
│   ├── building/
│   │   ├── building_system.gd
│   │   ├── building.gd
│   │   └── building_def.gd
│   ├── production/
│   │   └── production_system.gd
│   ├── fleet/
│   │   ├── fleet_system.gd
│   │   ├── ship.gd
│   │   └── ship_def.gd
│   ├── combat/
│   │   ├── combat_simulator.gd     # ★ pure logic, deterministic
│   │   ├── weapon_def.gd
│   │   ├── wave_director.gd
│   │   ├── battle_result.gd        # resource hasil simulasi
│   │   └── combat_visualizer.gd    # ★ playback hasil nyata
│   ├── progression/
│   │   └── progression_system.gd
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── build_menu.gd
│   │   ├── battle_hud.gd
│   │   └── galaxy_map_ui.gd
│   └── utils/
├── data/                    # ★ SEMUA DATA GAME (source of truth balance)
│   ├── economy.tres         # EconomyConfig
│   ├── buildings/*.tres     # BuildingDef (command_core, energy_reactor, ...)
│   ├── ships/*.tres         # ShipDef (shp_001_interceptor, ...)
│   ├── weapons/*.tres       # WeaponDef
│   ├── waves/*.tres         # WaveDef
│   └── sectors/*.tres       # SectorDef
├── tests/                   # ★ verification harness (lihat §8)
│   ├── unit/
│   ├── integration/
│   └── e2e/
└── shaders/
```

## 3. Framework Core (`scripts/core/`) — autoload (singleton)

| Modul | Tanggung jawab | State yang dimiliki |
|---|---|---|
| `EventBus` | Hub signal global. Semua komunikasi antarmodul lewat sini. | Tidak ada (hanya routing) |
| `GameManager` | State machine fase game: `BOOT → MENU → COMMAND → COMBAT → PAUSE`. Orkestrasi transisi mode. | Fase aktif, mode aktif |
| `TimeSystem` | Game clock dengan fixed tick (default 10 tick/detik game-time). Mendukung pause/speed 0×/1×/2×. Semua sistem berbasis waktu mendengar tick ini. | Waktu game, kecepatan |
| `Economy` | **Pemilik saldo & transaksi.** `add_resource()`, `spend()`, `can_afford()`, `get_amount()`, storage caps. | Saldo energy/mineral, caps |
| `SaveSystem` | Save/load versi (skema v1, lihat §7). Validasi saat load. | Tidak ada (I/O) |
| `GameData` | Load semua `.tres` dari `res://data/` saat boot; registry by id. API: `get_building_def(id)`, `get_ship_def(id)`, dst. | Registry definitions |
| `QaMarkers` | Mencetak marker verifikasi ke console: `QA:<PHASE>:<EVENT> key=value ...` dengan nilai state NYATA. Dipakai `--wait-for` di capture tool dan test assertions. | Tidak ada (logging) |
| `SeededRNG` | RNG deterministik (seed dapat disimpan → replay). Dipakai CombatSimulator & WaveDirector. | Seed aktif |

**Aturan autoload:** hanya `core/` yang boleh menjadi autoload. Modul game
lain adalah node/resource yang di-attach ke scene dan komunikasi via EventBus
atau referensi eksplisit dari GameManager.

## 4. Modul Game — batas & kontrak

| Modul | Tanggung jawab | Memilik state | Dipublish (event) | Bergantung pada |
|---|---|---|---|---|
| `BuildingSystem` | Penempatan, upgrade, demolish, grid konstruksi | Daftar bangunan aktif, level, status | `building_placed`, `building_upgraded`, `building_destroyed` | Economy, GameData, TimeSystem |
| `Building` (node) | Satu bangunan: HP, state (Normal/Damaged/Critical/Destroyed), produksi | HP, state, queue produksi | `building_damaged`, `building_repaired` | BuildingDef (data) |
| `ProductionSystem` | Antrian produksi & konstruksi, timer, output ke Economy/Fleet | Queue, progress | `production_completed`, `ship_built`, `construction_completed` | TimeSystem, Economy, FleetSystem |
| `FleetSystem` | Daftar kapal pemain, HP, formasi, repair | Armada (unit + kondisi) | `ship_spawned`, `ship_destroyed`, `fleet_changed` | ShipDef (data) |
| `CombatSimulator` | ★ **Pure logic** — input: attacker wave + defender (fleet + turrets + shield) + seed → output: `BattleResult` (damage, losses, duration). Tanpa node tree, tanpa UI. | Tidak ada (stateless) | — (dipanggil langsung) | ShipDef/WeaponDef/WaveDef, SeededRNG |
| `WaveDirector` | Jadwal & komposisi wave alien, telegraph (radar warning → countdown), scaling kesulitan | Wave schedule, threat level | `wave_incoming`, `wave_started`, `wave_defeated` | WaveDef, ProgressionSystem |
| `CombatVisualizer` | ★ Menampilkan hasil `BattleResult` di 3D: kapal terbang, turret menembak, VFX pooled, bangunan berubah state sesuai damage aktual. | Tidak ada (visualisasi) | `combat_visual_started/finished` | BattleResult, scene combat |
| `ProgressionSystem` | Unlock (bangunan/kapal/teknologi), territory, hadiah (diberikan tepat 1×) | Unlock flags, territory yang dikuasai | `territory_unlocked`, `reward_granted` | SaveSystem, Economy |
| `SaveSystem` | Snapshot semua state (lihat §7) | — | `game_saved`, `game_loaded` | Semua sistem (via serialize API) |
| `UISystem` (HUD/menus) | Menampilkan state. **Read-only.** | Tidak ada | — (subscribe semua event) | EventBus |

## 5. Katalog Event (EventBus)

| Event | Payload | Dipublish oleh | Didengar oleh |
|---|---|---|---|
| `resource_changed` | resource_id, old, new, delta | Economy | UI, SaveSystem |
| `building_placed` | building_id, instance_id, position | BuildingSystem | UI, SaveSystem, Progression |
| `building_upgraded` | instance_id, old_level, new_level | BuildingSystem | UI, Economy, SaveSystem |
| `building_damaged` | instance_id, hp, state | Building | UI, SaveSystem, CombatVisualizer |
| `building_destroyed` | instance_id | Building | UI, Progression, SaveSystem |
| `production_completed` | type, id, amount | ProductionSystem | Economy/Fleet, UI, SaveSystem |
| `ship_built` | ship_id, instance_id | ProductionSystem | FleetSystem, UI |
| `wave_incoming` | wave_id, eta_seconds | WaveDirector | UI, Audio |
| `combat_started` | battle_seed, attacker, defender | WaveDirector/GameManager | CombatVisualizer, UI |
| `combat_finished` | BattleResult | CombatSimulator | Progression, Economy, UI, SaveSystem |
| `territory_unlocked` | sector_id | ProgressionSystem | UI, SaveSystem |
| `reward_granted` | rewards, source | ProgressionSystem | Economy, UI (1× dijamin) |
| `game_saved` / `game_loaded` | slot, version | SaveSystem | UI |

## 6. Determinisme & Testability

- **CombatSimulator** adalah `RefCounted` murni: input = `BattleInput` (resource),
  output = `BattleResult` (resource). Tidak ada akses node tree, UI, atau waktu
  nyata — semua delta waktu disimulasikan dari tick.
- **SeededRNG**: seed dicatat di save; hasil simulasi dapat direplay.
- **Economy** pakai integer (hindari float drift): produksi akumulasi
  `rate_per_tick` dalam integer; saldo selalu integer.
- **TimeSystem** fixed tick → semua timer (produksi, konstruksi, cooldown)
  berbasis tick, bukan `Timer` node yang bisa drift.
- **Aturan verifikasi data nyata (A6):** setiap perubahan state yang penting
  mencetak marker `QA:...` berisi nilai aktual dari state (bukan konstanta).
  Contoh: `QA:ECONOMY:PRODUCE energy=120 (+20/tick)` — angka 120 dibaca dari
  `Economy.get_amount("energy")` saat itu.

## 7. Format Save (v1)

```json
{
  "schema_version": 1,
  "engine_version": "4.7.2",
  "save_version": 1,
  "created_at": "...",
  "game_time_ticks": 0,
  "rng_seed": 0,
  "phase": "COMMAND",
  "economy": { "energy": 0, "minerals": 0 },
  "buildings": [ { "id": "energy_reactor", "instance": "...", "level": 1, "hp": 100, "state": "normal", "position": [0,0,0] } ],
  "production": { "queues": [ ... ] },
  "fleet": [ { "id": "shp_001", "instance": "...", "hp": 100 } ],
  "progression": { "unlocked": [], "territories": [], "pending_rewards": [] },
  "wave_director": { "next_wave_id": "...", "threat": 0 },
  "settings": { "quality": "medium", "sfx_volume": 1.0 }
}
```

- **Validasi load:** cek `schema_version` kompatibel; semua required key ada;
  referensi id (building/ship/wave) resolve ke GameData; nilai dalam batas
  wajar (hp ≥ 0, level ≥ 1); state tidak duplikat. State invalid → error
  jelas + fallback ke save baru (jangan crash).
- **Reward 1×:** `reward_granted` dicatat di `progression.pending_rewards`/
  sudah-applied — load tidak mengulang pemberian (governance §16).
- **Round-trip test wajib:** fresh start → play → save → load → state sama
  persis (diuji otomatis, bukan asumsi).

## 8. Verification Harness (`tests/`) — "bukan asal jalan"

| Level | Lokasi | Apa yang diuji | Cara jalan |
|---|---|---|---|
| **Unit** | `tests/unit/` | Logika murni: Economy math, SeededRNG determinism, CombatSimulator (fixed seed → hasil sama), save round-trip, validasi data | Scene test runner di WASM runtime; hasil via console |
| **Data** | `tests/unit/test_data_validation.gd` | **Data nyata divalidasi**: semua def terdaftar & unik; semua referensi resolve (ship→weapon, wave→ship, sector→reward); biaya/rate valid (non-negatif, rate > 0); ekonomi awal cukup untuk first build | Load `res://data/*.tres` asli, assert |
| **Integration** | `tests/integration/` | Sistem ↔ sistem via EventBus: build → produce → fleet → combat → reward → progression | Scene test dengan sistem nyata |
| **E2E** | `tests/e2e/` | Playthrough utuh: marker `QA:LOOP:*` untuk tiap tahap loop; screenshot tiap fase | `tools/godot/run_smoke.sh` pola + `capture.mjs --wait-for` |

- **Test runner:** `scenes/tests/test_runner.tscn` — menjalankan semua test,
  mencetak `TEST:PASS/FAIL <name> <detail>` ke console, exit code via marker
  `TESTS:DONE passed=X failed=Y`. Dijalankan di Chromium headless via capture
  tool; hasil terbaca dari consoleLogs.
- **Aturan pass:** `failed=0` + semua marker QA yang diwajibkan muncul dengan
  nilai yang di-assert (bukan hanya "tidak error").

## 9. Konvensi Kode (GDScript)

- `class_name` untuk semua tipe yang dipakai lintas file (Def, Result, Input).
- Nama file `snake_case` sesuai modul; tidak ada kode game di luar `scripts/`.
- Tidak ada nilai balance di kode — hanya baca dari `GameData`.
- Cross-module: panggil API pemilik state atau publish event; jangan pernah
  memegang referensi UI dari sistem gameplay.
- Komentar secukupnya pada kontrak (mengapa, bukan apa).
- Semua file baru: verifikasi dengan test yang relevan sebelum status naik
  (lihat `QA_PLAN.md`).

## 10. Keputusan Teknologi & Konstraints

- **Engine:** Godot 4.7.2, GDScript (tanpa GDExtension — build WASM tidak
  mendukungnya; cukup untuk scope kita).
- **Renderer:** `gl_compatibility` (WebGL2) untuk build web; `forward+`
  tersedia untuk desktop nanti.
- **Target verifikasi utama:** web build di Chromium headless (SwiftShader).
- **Single-player, tanpa backend** (scope gate — lihat `ROADMAP.md` keputusan
  terbuka; RISK_ANALYSIS bottleneck #8).
- **Performa:** diukur di build representatif (Milestone 2); budget numerik
  menyusul setelah device class diputuskan.

## 11. Checklist Implementasi Framework (urutan, dengan gate)

Setiap item naik status hanya lewat gate di `QA_PLAN.md` (NOT STARTED →
IMPLEMENTED → RUNNABLE → VERIFIED → INTEGRATED → REGRESSION PASS).

1. [ ] Struktur folder `res://` dibuat (kosong) — gate: struktur ada & konsisten dengan dokumen ini
2. [ ] `core/`: EventBus, TimeSystem, SeededRNG, QaMarkers — unit test determinism
3. [ ] `core/`: Economy + `data/economy.tres` — unit test transaksi/caps
4. [ ] `core/`: GameData loader + `data/buildings/*.tres` (2–3 bangunan pertama) — data test
5. [ ] `building/`: BuildingSystem + Building + placement — integration test
6. [ ] `production/` + `fleet/`: produksi → kapal — integration test
7. [ ] `combat/`: CombatSimulator (pure) — unit test fixed seed; WaveDirector; CombatVisualizer — e2e marker + screenshot
8. [ ] `progression/` + reward 1× — integration test
9. [ ] `core/`: SaveSystem — round-trip test
10. [ ] `ui/`: HUD + build menu + battle HUD — e2e screenshot
11. [ ] `tests/`: test runner + e2e playthrough loop lengkap — VERIFIED end-to-end

## 12. Dokumen Terkait

- `DATA_CONTRACTS.md` — kontrak data & skema lengkap
- `QA_PLAN.md` — verification gates & QA per phase
- `RISK_ANALYSIS.md` — analisis risiko (dasar arsitektur ini)
- `ASSET_PIPELINE.md` / `ASSET_ACCEPTANCE_CRITERIA.md` — pipeline aset
- `TOOLCHAIN.md` — tools & cara verifikasi
- `ROADMAP.md` / `DEV_PLAN.md` — milestone & rencana
