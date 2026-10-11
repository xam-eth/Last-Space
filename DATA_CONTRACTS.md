# DATA CONTRACTS — Last-Space

Kontrak data untuk semua sistem inti. Mengikat `AI_GOVERNANCE.md` §8
(integration & authoritative data), §13 (economy rules), dan bottleneck #1 di
`RISK_ANALYSIS.md`.

> **Aturan utama:** UI tidak pernah menjadi sumber kebenaran. Visual pertempuran
> menampilkan hasil simulasi aktual. Reward diberikan tepat satu kali. Save/load
> tidak menduplikasi atau menghilangkan state.

**Status: IMPLEMENTED & VERIFIED (M1, 2026-10-10)** — skema di bawah adalah
yang benar-benar dipakai sistem game di `game/`. Amendment dari versi awal
ditandai **[amended]**.

## 1. Kepemilikan State (Source of Truth)

| Sistem | Pemilik state (satu-satunya) | Data yang menjadi sumber kebenaran |
|---|---|---|
| Ekonomi | `Economy` (autoload) | Saldo sumber daya dan transaksi |
| Bangunan | `BuildingSystem` + node `Building` | Level, biaya, status, dan efek |
| Produksi | `ProductionSystem` | Input, output, kapasitas, dan waktu |
| Armada | `FleetSystem` + node `Ship` | Daftar unit, jumlah, statistik, dan kondisi |
| Pertempuran | `CombatSimulator` → `BattleResult` | Input pertempuran dan hasil simulasi |
| Progresi | `ProgressionSystem` | Syarat unlock dan progres pemain |
| Quest | `QuestTracker` (M3 #1) | Progress objektif + reward-once |
| Save/load | `SaveSystem` | Seluruh keadaan permainan yang harus dipertahankan |
| UI | HUD/menus (read-only) | Tidak ada — hanya menampilkan |

**Aturan:** sistem lain mengakses state lewat API pemilik atau via `EventBus`.
Tidak ada variabel yang menyimpan saldo/HP/unit di luar pemiliknya.

## 2. Skema Data (game/data/)

Semua file adalah resource Godot (`.tres`) dengan `class_name` di
`game/scripts/**/*_def.gd`. **Tidak ada nilai balance di kode.**

### 2.1 EconomyConfig (`data/economy.tres`) ✅ implemented

```gdscript
class_name EconomyConfig
extends Resource

@export var starting_resources: Dictionary = {"energy": 300, "minerals": 150}
@export var storage_caps: Dictionary = {"energy": 1000, "minerals": 500}
```

### 2.2 BuildingDef (`data/buildings/*.tres`) ✅ implemented

```gdscript
class_name BuildingDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var category: String          # hq | economy | production | defense | research
@export var max_level: int = 10
@export var base_cost: Dictionary     # biaya level 1
@export var cost_growth: float = 1.6  # biaya level n = base_cost * growth^(n-1)
@export var build_time_ticks: int
@export var max_hp: int
@export var produces: StringName      # resource yang diproduksi, &"" jika tidak ada
@export var production_per_minute: int
@export var storage_bonus: Dictionary # tambahan storage cap (sekali saat placement)
@export var repair_cost_per_hp: Dictionary
@export var weapon_id: StringName = &""   # [amended] bangunan defense yang menembak
@export var shield_pool: int = 0          # [amended] pool serap damage (shield generator)
@export var footprint: Vector2i
@export var scene_path: String = ""       # [amended] kosong = visual placeholder (sampai aset masuk)
```

Skala level (implemented & tested):
- `effective_max_hp = max_hp * level`
- `production = production_per_minute * level`
- `cost(level n) = base_cost * cost_growth^(n-1)` (dibulatkan ke int)

**Repair:** memperbaiki bangunan rusak AND hancur (repair = rebuild wreck),
biaya = `repair_cost_per_hp × HP yang dipulihkan`. [amended — diverifikasi di M1]

### 2.3 ShipDef (`data/ships/*.tres`) ✅ implemented

```gdscript
class_name ShipDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var ship_class: String        # fighter | corvette | frigate | capital
@export var role: String
@export var max_hp: int
@export var speed: float
@export var turn_rate: float
@export var weapon_id: StringName     # referensi WeaponDef (wajib resolve)
@export var weapon_count: int = 1
@export var armor: int
@export var cost: Dictionary
@export var build_time_ticks: int
@export var repair_cost_per_hp: Dictionary
@export var fleet_supply: int
@export var model_path: String = ""   # kosong = visual placeholder
```

### 2.4 WeaponDef (`data/weapons/*.tres`) ✅ implemented

```gdscript
class_name WeaponDef
extends Resource

@export var id: StringName
@export var weapon_type: String       # laser | missile | cannon
@export var damage: int
@export var range: float
@export var cooldown_ticks: int
@export var projectile_speed: float
@export var tracking: bool
@export var vs_structure_multiplier: float = 1.0
@export var vs_shield_multiplier: float = 1.0
```

### 2.5 WaveDef (`data/waves/*.tres`) ✅ implemented

```gdscript
class_name WaveDef
extends Resource

@export var id: StringName
@export var composition: Dictionary   # {ship_id: count}
@export var telegraph_ticks: int
@export var spawn_interval_ticks: int
@export var threat: int
```

### 2.6 SectorDef (`data/sectors/*.tres`) ✅ implemented

```gdscript
class_name SectorDef
extends Resource

@export var id: StringName
@export var display_name: String
@export var unlock_condition: String  # "start" atau "defend_home_base_N"
@export var rewards: Dictionary
@export var threat: int
@export var waves: Array[StringName]
```

### 2.7 BattleInput / BattleResult (runtime) ✅ implemented

```gdscript
class_name BattleInput
extends Resource

@export var attacker: Array[StringName]
@export var defender_ships: Array[StringName]
@export var defender_turrets: Array[Dictionary]    # {weapon_id, count, hp}
@export var defender_buildings: Array[Dictionary]  # [amended] {instance_id, hp, max_hp}
@export var shield_hp: int
@export var seed: int

class_name BattleResult
extends Resource

@export var attacker_losses: Dictionary   # {ship_id: count}
@export var defender_ship_losses: Dictionary
@export var turret_damage: Dictionary     # {turret_index: damage}
@export var shield_damage: int
@export var building_damage: Dictionary   # {building_instance: damage}
@export var duration_ticks: int
@export var winner: String                # "attacker" | "defender" | "draw"
@export var seed: int
```

Model simulasi (deterministic, tick-based, diverifikasi di M1):
prioritas target attacker = kapal defender → turret → bangunan (shield
menyerap damage ke bangunan lebih dulu); damage = `max(1, weapon.damage -
armor) × multiplier` (`vs_structure` untuk turret/bangunan).

### 2.8 Save Data (v1) ✅ implemented

`SaveSystem` menyimpan JSON versi (schema_version=1): `game_time_ticks`,
`rng_seed`, `phase`, `economy`, `buildings[]`, `production`, `fleet[]`,
`progression`, `wave_director`, `quests`, `settings`. Round-trip diverifikasi: state
setelah load sama persis; reward tidak ganda.

### 2.9 ProgressionConfig (`data/progression.tres`) ✅ implemented [amended — baru]

```gdscript
class_name ProgressionConfig
extends Resource

@export var starting_unlocks: Array[StringName] = []
@export var starting_territories: Array[StringName] = []
```

## 3. Aturan Validasi Data (diuji otomatis — `tests/unit/test_data_validation.gd`) ✅

Data game diverifikasi berdasarkan data itu sendiri, bukan asumsi:

1. **ID unik** — tidak ada dua def dengan id sama dalam satu kategori.
2. **Referensi resolve** — `ShipDef.weapon_id` → WeaponDef; `WaveDef.composition`
   → ShipDef; `SectorDef.waves` → WaveDef; `SectorDef.rewards` → resource yang
   ada di `storage_caps`; `ProgressionConfig.starting_unlocks` → def yang ada;
   bangunan defense (dengan weapon) → WeaponDef.
3. **Nilai valid** — biaya ≥ 0; `max_hp` > 0; `build_time_ticks` ≥ 0;
   `cooldown_ticks` > 0; `range` > 0; wave non-empty & telegraph > 0.
4. **Produser valid** — `produces` menunjuk resource yang ada di `storage_caps`
   dan `production_per_minute` > 0.
5. **Ekonomi awal** — dengan `starting_resources`, pemain bisa membangun
   minimal 1 fasilitas ekonomi pertama (loop bisa dimulai).

Pelanggaran = test FAIL dengan pesan yang menunjuk file & field spesifik.

## 4. Kebijakan Nilai (governance §13)

- Semua nilai di `data/*.tres` ditandai **PROVISIONAL** (komentar) sampai
  diuji simulasi ekonomi + playtest.
- Simulasi ekonomi (headless, ratusan hari game) untuk cek tempo progresi —
  dijadwalkan di Milestone 2.
- Perubahan nilai balance = perubahan data file + re-run test suite (regresi
  tidak boleh rusak) + catat di `PROJECT_STATUS.md`.

## 5. Aturan Perubahan Kontrak

Mengubah kontrak data (menambah/mengubah field, mengubah kepemilikan state)
= perubahan arsitektur: wajib analisis dampak, update dokumen ini +
`TECH_ARCHITECTURE.md` + skema save (migration), dan persetujuan human
developer (governance §7).
