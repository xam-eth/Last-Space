# GAMEPLAY_FLOW.md — Alur & Mekanisme Gameplay Last-Space (Visualisasi a–z)

Dokumen ini menjembatani **konsep** (`Game_Concept.md`) → **visual/UI** →
**logika** yang akan diimplementasikan. Dibuat setelah research reference
UI/UX **Doomsday: Last Survivors** (IGG — base-building survival 3D,
`screenshots: docs/references/doomsday/`) dan standar mobile-first yang sudah
diverifikasi (`UI_UX_DESIGN.md`). Tujuannya: sebelum menulis logika, kita punya
gambaran utuh — setiap scene/frame, elemen & komponen yang harus ada, ukuran,
dan logikanya. **Bukan logika asal-asalan.**

---

## 0. Referensi yang diadopsi (dan yang tidak)

Dari Doomsday: Last Survivors (mobile base-building 3D). **Research lengkap
frame-by-frame (F0 splash → F13 settings, 30 screenshot):**
[`docs/references/doomsday/FRAME_BY_FRAME.md`](docs/references/doomsday/FRAME_BY_FRAME.md)
(screenshot: `docs/references/doomsday/`).

| Pola Doomsday | adopsi untuk Last-Space |
|---|---|
| Top bar: resource chips kiri (food/wood/steel/gem + tombol `+`), kanan: nama/level pemain | ✅ Top bar: ENERGY/MINERALS/FLEET chips kiri + wave indicator tengah + menu kanan (sudah ada, full-rect) |
| Gameplay = canvas 3D full screen (isometric/spherical), HUD minimal di pojok | ✅ Command Mode = canvas 3D full screen (sudah ada); HUD overlay minimal di edge |
| Tombol aksi besar pojok kanan bawah (circular) | ✅ Action grid kanan bawah (ikon-only 48dp) |
| Chat/mission panel kiri bawah | ✅ Info panel kiri bawah (log/toast) |
| Modal menu: panel tengah + title + close X + sidebar tabs + **grid of cards** + detail panel kanan + tombol besar bawah | ✅ Build menu & Ship menu (card = ikon + nama + level + biaya + progress + tombol) |
| Card = square ikon/portrait + bingkai tier + angka quantity | ✅ Card bangunan/kapal: ikon + nama + level + biaya/waktu |
| Dialog bubble bawah tengah (tutorial/guide) | ✅ Tutorial toast/dialog (sistem toast sudah ada) |
| Countdown timer pojok kanan bawah (wave/zombie attack) | ✅ Wave countdown di top bar (sudah ada: "WAVE wave_1 — N ticks") |
| Zoom in/out kamera (shelter ↔ world map) | 🔶 Future: kamera zoom/pan di Command Mode (belum) |
| **Quest/mission panel kiri tengah** (progress objektif aktif) | ➕ adopsi — extend info panel kiri (progress misi/wave objektif) |
| **Tombol Region (world map) kiri bawah** (ikon globe 48dp) | ➕ adopsi — pindah shelter ↔ peta sektor (ekspansi, M4) |
| **Indikator bangunan terpilih** (nama + level + panah hijau + aksi konteks bawah: Info/Level Up/Buff) | ➕ adopsi — klik bangunan di base 3D → panel info + upgrade (M3 #1) |
| **Event icons kanan atas** (VIP/mall/countdown) | 🔶 ganti jadi notifikasi/event game (tanpa IAP — keputusan ROADMAP: no monetisasi) |
| **Hamburger menu kanan bawah** | ➕ gabung ke pause/settings (M3 #3/#5) |
| Battle report (loot/kerusakan panel) | ➕ adopsi — panel hasil wave (M3) |

Yang **tidak** diadopsi: tema zombie, hero/gacha, PvP, energi/gacha currency.
Fokus Last-Space: **base-building + armada pesawat + defense vs alien**
(3 lapisan, `Game_Concept.md` §3).

---

## 1. Mekanisme Gameplay (a–z)

### 1.1 Game loop utama (Game_Concept.md §6)

```
BANGUN MARKAS → PRODUKSI SUMBER DAYA → BANGUN ARMADA PESAWAT →
SERANG/AMANKAN WILAYAH → KUASAI SUMBER DAYA → ALIEN MENYERANG →
BERTAHAN (COMBAT) → PERBAIKI & TINGKATKAN → BUKA TEKNOLOGI →
SERANG SARANG ALIEN → BUKA SEKTOR GALAKSI → (loop)
```

Tiga progresi yang saling bergantung (`Game_Concept.md` §6):
- **Ekonomi:** energi + mineral (produksi, kapsitas, konsumsi).
- **Militer:** armada pesawat + turret + perisai.
- **Teritorial:** sektor/wilayah yang dikuasai.

### 1.2 Dua mode kamera (Game_Concept.md §5)

| Mode | Kamera | Pemain lakukan | Logika |
|---|---|---|---|
| **Command Mode** | Strategis ( tinggi, lihat markas utuh) | bangun, upgrade, produksi, teknologi, ekspansi, formasi armada | Keputusan jangka panjang; ekonomi berjalan real-time |
| **Combat Mode** | Dekat (battle 3D) | lihat hasil pertempuran: skuadron vs alien, turret menembak, benteng diserang, ledakan, kerusakan | Hasil dihitung **simulasi statistik** (CombatSimulator, fixed seed → reproducible), lalu **divisualisasikan** 3D (CombatVisualizer) — bukan fisika per-peluru (`Game_Concept.md` §8) |

### 1.3 Sistem (yang sudah ada — diverifikasi test)

| Sistem | File | Fungsi |
|---|---|---|
| Economy | `core/economy.gd` | energi/mineral, produksi per menit, kapsitas, konsumsi |
| TimeSystem | `core/time_system.gd` | tick game (10 tick/detik), pause/resume |
| GameManager | `core/game_manager.gd` | state game, new game, mulai |
| BuildingSystem | `building/building_system.gd` | tempat/upgrade bangunan, footprint grid |
| ProductionSystem | `production/production_system.gd` | antrian produksi (hanggar → pesawat) |
| FleetSystem | `fleet/fleet_system.gd` | spawn armada, formasi parkir |
| CombatSimulator | `combat/combat_simulator.gd` | hasil battle dari statistik (fixed seed) |
| WaveDirector | `combat/wave_director.gd` | jadwal gelombang alien (1 slot pending) |
| CombatVisualizer | `combat/combat_visualizer.gd` | visualisasi 3D hasil battle (model SHP-001 & ALN-001) |
| ProgressionSystem | `progression/progression_system.gd` | sektor/territorial, reward-once |
| SaveSystem | `core/save_system.gd` | save/load round-trip |
| EventBus | `core/event_bus.gd` | sinyal antar sistem (resource_changed, fleet_changed, wave_incoming, combat_started/finished, territory_unlocked, building_placed, ...) |
| HUD | `ui/hud.gd` | top bar + action grid + info panel + toast (full-rect, 48dp) |

### 1.4 Kondisi kerusakan bangunan (Game_Concept.md §4)

`Normal → Damaged → Critical → Destroyed`. Dampak: produksi/efektivitas turun,
hanggar rusak tidak produksi sampai diperbaiki, Command Fortress hancur =
kekalahan besar (sebagian sumber daya hilang, wilayah berisiko — bukan
reset total).

---

## 2. State Machine (GameManager)

```
BOOT → LOADING → MAIN_MENU → COMMAND ⇄ BATTLE
                              ↓    ↑
                            PAUSE → MAIN_MENU
                              ↓
                         TERRITORY_UNLOCKED (toast, balik COMMAND)
                              ↓
                         GAME_OVER (base hancur) → MAIN_MENU
```

| State | Scene/canvas | HUD aktif | TimeSystem |
|---|---|---|---|
| BOOT/LOADING | loading screen | — | pause |
| MAIN_MENU | menu (bg 3D base idle) | — | pause |
| COMMAND | gameplay 3D (base) | penuh (top bar, action grid, info) | jalan |
| BATTLE | gameplay 3D (battle view) | wave label + hasil toast | jalan (simulasi) |
| PAUSE | modal tengah | beku | pause |
| GAME_OVER | modal | — | pause |

Event penting (EventBus): `resource_changed`, `fleet_changed`,
`wave_incoming`, `combat_started`, `combat_finished`, `territory_unlocked`,
`building_placed`, `building_upgraded`, `ship_spawned`, `ship_destroyed`.

---

## 3. Scene / Frame Inventory (tampilan frame 1 → dst)

> Ukuran dalam **dp** (design canvas 1280×720 = 640×360dp; 1 design px = 0,5dp;
> ikut `UI_UX_DESIGN.md` §3). Semua scene **landscape full screen** (semua
> aspek, tanpa letterbox — koreksi 2026-10-11).

### Frame 1 — Splash / Boot
- **Visual:** logo LAST-SPACE di tengah, background gelap. 1–2 detik.
- **Komponen:** logo (ikon 96dp), nama game.
- **Logika:** engine init, load data (`QA:DATA:LOADED`), masuk LOADING.

### Frame 2 — Loading Screen
- **Visual:** slideshow background cinematic (5 bg 16:9, crossfade 4s) + overlay gelap + bottom bar landscape: kiri = ikon + brand + teks status; kanan = progress bar + persentase. **Sudah ada & VERIFIED** (`index.html`, `docs/visual_benchmark/01_loading_screen.png`).
- **Komponen:** bg slideshow, icon loading (spin), progress bar (tinggi 8dp), teks status (14–16pt).
- **Logika:** progress = load engine + pck + data; setelah siap → MAIN_MENU (atau langsung COMMAND untuk build preview — default: langsung game sesuai requirement "halaman utama = GAME").

### Frame 3 — Main Menu
- **Visual:** background = 3D base (idle, kamera strategis, perlahan zoom/pan). Panel tengah: judul + tombol.
- **Komponen:** tombol utama **Play/Continue** (56dp tinggi, full-width card 320dp), tombol sekunder **Settings** (48dp), mungkin **Credits**. Card menu: panel 12dp radius, border cyan 1dp.
- **Logika:** Play → COMMAND (new game atau lanjut save). Settings → modal Frame 8b.
- **Status:** BELUM ADA (halaman utama langsung game sesuai requirement — menu ini untuk rilis, masuk backlog M3).

### Frame 4 — COMMAND MODE (gameplay utama) ⭐ inti
- **Visual:** canvas 3D full screen — benteng (command core + bangunan + turret + armada parkir di formasi). Kamera strategis. **Sudah ada & VERIFIED** (`02_command_base.png`, `03_fleet_formation.png`).
- **Komponen & posisi (9-zone grid, full-rect):**
  - **Top bar** (atas, full width, tinggi 48dp): kiri = 3 chip resource (ENERGY/MINERALS/FLEET, 110×36dp, ikon 20dp + label + nilai + progress bar 3dp); tengah = indikator wave ("ARENA CLEAR" / "WAVE wave_1 — N ticks" / countdown); kanan = tombol menu (40dp).
  - **Action grid** (kanan bawah, 2 baris × 4 kolom, tombol 48dp, gap 8dp): ikon-only — build, ship, fleet, research, radar, sector, dock, shield (8 aksi). **Sudah ada (7 tombol)**.
  - **Info panel** (kiri bawah, 210×70dp): log/toast pesan (bangun selesai, wave incoming, territory unlocked).
  - **Toast** (atas tengah bawah top bar): hasil battle / notifikasi.
  - **3D canvas:** klik bangunan → info/upgrade; klik kosong → build menu (Frame 5).
- **Logika:** ekonomi jalan real-time (tick); pemain bangun/upgrade/produksi lewat action grid; wave masuk sesuai jadwal (WaveDirector) → transisi BATTLE (Frame 7).

### Frame 5 — Build Menu (modal)
- **Visual:** modal panel tengah (max 80% lebar, 70% tinggi), background canvas tetap terlihat (blur/dim). **Pola Doomsday (BAG): title + close X + grid of cards.**
- **Komponen:**
  - Title bar: "BUILD" + close X (48dp touch).
  - Grid of **building cards** (3 kolom): tiap card = ikon bangunan (48dp) + nama + level + biaya (ikon resource + angka) + waktu + tombol "BUILD"/"UPGRADE" (48dp). Card ~ 200×160dp.
  - Detail saat pilih: panel kanan (ikon besar, nama, deskripsi, efek, biaya, tombol).
- **Logika:** pilih bangunan → cek resource cukup (atomik, tanpa partial spend — sudah di-test `test_economy_edge`) → antrian produksi (ProductionSystem) → toast saat selesai. Upgrade: level naik, efek naik, visual bangunan berubah (future: model per level).
- **Status:** BELUM ADA (action grid tombol build masih placeholder) — **prioritas M3 pertama**.

### Frame 6 — Ship Menu (modal)
- **Visual:** modal panel tengah. **Pola Doomsday (Hero): grid of cards + detail.**
- **Komponen:** grid of **ship cards**: portrait/ikon kapal (48dp) + nama + kelas + HP bar + stats (speed/attack/armor). Detail kanan: model besar + nama + stats + tombol "PRODUCE" (antrian hanggar).
- **Logika:** produce → biaya + waktu (hanggar) → masuk FleetSystem (formasi parkir). HP kapal dari battle (CombatSimulator) → repair (dock, biaya per HP — sudah di-test).
- **Status:** BELUM ADA — prioritas M3.

### Frame 7 — BATTLE MODE (combat view)
- **Visual:** kamera dekat ke battle: skuadron interceptor vs armada alien (model ALN-001 hijau/ungu), turret menembak (tracer), ledakan, benteng di tengah. **Sudah ada & VERIFIED** (`04_battle_vs_alien.png`): attacker bergerak ke base, defender formasi, explosion, toast hasil.
- **Komponen:** wave label atas tengah; toast hasil ("BATTLE: DEFENDER WON (32 TICKS)" / "ALIEN WON"); HUD minimal (resource tetap update).
- **Logika:** `wave_incoming` → CombatSimulator hitung hasil (fixed seed, reproducible) → CombatVisualizer mainkan animasi 2.5s → `combat_finished` → terapkan hasil: kapal hancur (fleet_changed), bangunan rusak (kondisi Normal/Damaged/Critical/Destroyed), base hancur → GAME_OVER. Kembali COMMAND.
- **Catatan:** hasil battle **tidak diarang** — jumlah & kehancuran persis dari BattleResult (`combat_visualizer.gd` komentar, AI_GOVERNANCE §8).

### Frame 8 — Pause Menu (modal)
- **Visual:** modal tengah: panel dengan tombol besar: **Resume** (56dp), **Settings** (48dp), **Main Menu** (48dp, konfirmasi).
- **Logika:** TimeSystem.pause; Resume → COMMAND; Main Menu → konfirmasi → save → MAIN_MENU.
- **Status:** tombol menu sudah ada (buka modal kosong?) — cek `_on_menu_pressed`; perlu isi.

### Frame 8b — Settings (modal)
- **Komponen:** slider volume (musik/SFX), toggle (fullscreen, notifikasi), bahasa, reset progress (konfirmasi), about.
- **Status:** BELUM ADA — backlog.

### Frame 9 — Territory Unlocked (event, bukan scene penuh)
- **Visual:** toast besar tengah-atas + highlight sektor baru di peta (future: world map).
- **Logika:** ProgressionSystem → reward-once (sudah di-test `test_progression`) → balik COMMAND.
- **Status:** toast sudah ada; highlight sektor future.

---

## 4. Komponen & Ukuran Standar (card/menu)

| Komponen | Ukuran (dp) | Catatan |
|---|---|---|
| Tombol aksi utama | 48×48 (ikon-only) | Material touch target; grid gap 8dp |
| Tombol sekunder (menu/close) | 40×40 | pojok, selalu terjangkau ibu jari |
| Tombol besar (Play/Build/Upgrade/USE) | tinggi 48–56, lebar ≥ 120 | di modal bawah |
| Chip resource | 110×36 | ikon 20dp + label + nilai + bar 3dp |
| Card bangunan/kapal (grid) | ~200×160 | ikon 48dp + nama + level + biaya + tombol |
| Modal panel | ≤ 80% lebar, ≤ 70% tinggi | radius 12dp, border 1dp, bg 78% opacity |
| Toast/dialog | tinggi 28–40 | atas tengah / bawah tengah (tutorial) |
| Progress bar | tinggi 3–6 | di chip/card |
| Margin edge | 12 | semua sisi (safe area) |
| Base grid | 8 | semua spacing kelipatan 8dp |

---

## 5. Mapping: sudah ada vs yang harus dibuat (prioritas)

| Fitur | Status | Prioritas |
|---|---|---|
| Loading screen | ✅ VERIFIED | — |
| Command Mode canvas 3D + HUD (top bar, action grid, info, toast) | ✅ VERIFIED | — |
| Battle Mode (simulasi + visualisasi, model SHP-001 & ALN-001) | ✅ VERIFIED | — |
| Full screen semua aspek (16:9/19.5:9/20:9) | ✅ VERIFIED (koreksi 2026-10-11) | — |
| Ekonomi/produksi/bangunan/armada/wave/progresi/save | ✅ VERIFIED (tests 230/0) | — |
| **Build menu (card bangunan + detail + build/upgrade)** | ❌ BELUM | **M3 #1** |
| **Ship menu (card kapal + detail + produce)** | ❌ BELUM | **M3 #2** |
| Pause menu isi (Resume/Settings/Main Menu) | ⚠️ tombol ada, modal kosong | M3 #3 |
| Main menu (Play/Settings) | ❌ BELUM (root langsung game) | M3 #4 |
| Settings (audio/fullscreen/bahasa) | ❌ BELUM | M3 #5 |
| Kamera zoom/pan Command Mode | ❌ BELUM | M3 #6 |
| Kerusakan visual bangunan (Normal/Damaged/Critical/Destroyed) | ⚠️ data ada, visual future | M3 #7 |
| World map / sektor ekspansi visual | ❌ BELUM | M4 |

---

## 6. Risiko (dari Game_Concept.md §9) & catatan implementasi

1. **Terlalu banyak sistem di versi pertama** → vertical slice dulu (sudah:
   1 markas + 1 sektor + 1 armada + 1 invasi — sesuai `Game_Concept.md` §10).
2. **Battle hanya tontonan** → keputusan pemain harus berpengaruh:
   bangun turret/hanggar/perisai sebelum wave = hasil beda (sudah: hasil
   simulasi dari statistik armada & pertahanan).
3. **Pembangunan hanya menu** → bangunan harus terlihat di 3D dan terkait
   battle (sudah: bangunan di base 3D, turret & hanggar di battle view).

**Aturan logika (wajib, sudah dipegang):** hasil battle dari simulasi
(fixed seed, reproducible) — visual tidak mengarang hasil; resource tidak
bisa minus (clamp, uji edge); konstruksi atomik (tanpa partial spend);
reward-once; save/load round-trip.
