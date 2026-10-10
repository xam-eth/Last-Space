# MASTER ASSET INVENTORY — Last-Space

Dokumen produksi utama untuk seluruh aset game. Dibuat dari `Asset_Request_List.md`
(master inventory 15 kelompok) dan harus menjadi sumber tunggal status produksi aset.

**Aturan pakai dokumen ini:**

- Setiap aset punya **ID unik** (contoh: `SHP-001`). ID dipakai di nama file, data konfigurasi,
  scene, dan laporan pekerjaan. Klaim "SHP-001 VERIFIED" harus bisa dibuktikan dengan file,
  scene, dan hasil pengujian — bukan sekadar nama yang terdaftar.
- Kolom **Status** wajib diisi. Status aset: `PLANNED` → `GENERATED` → `REVIEWED` → `OPTIMIZED`
  → `INTEGRATED` → `VERIFIED`. Jangan tandai selesai hanya karena file GLB berhasil dibuat.
- Jangan bulk-generate aset sebelum pipeline divalidasi dengan **satu aset pilot**
  (lihat `ASSET_PIPELINE.md` dan `ASSET_ACCEPTANCE_CRITERIA.md`, serta aturan Tripo di `AI_GOVERNANCE.md` §11).
- Angka prioritas: **P0** vertical slice (wajib ada agar prototype bisa dimainkan), **P1** core game,
  **P2** expansion, **P3** polish.

## Ringkasan per kelompok

| Kelompok | ID | Total | P0 | P1 | P2 | P3 |
|---|---|---|---|---|---|---|
| Kelompok A — Player Space Fortress | `FRT-` | 20 | 6 | 9 | 5 | 0 |
| Kelompok B — Bangunan Ekonomi dan Produksi | `ECO-` | 20 | 5 | 11 | 4 | 0 |
| Kelompok C — Bangunan Pertahanan | `DEF-` | 14 | 3 | 7 | 4 | 0 |
| Kelompok D — Armada Pemain | `SHP-` | 20 | 1 | 9 | 8 | 2 |
| Kelompok E — Armada Alien | `ALN-` | 15 | 2 | 8 | 5 | 0 |
| Kelompok F — Senjata, Projectile, dan VFX | `VFX-` | 30 | 9 | 15 | 6 | 0 |
| Kelompok G — Planet, Asteroid, dan Lingkungan | `ENV-` | 20 | 8 | 8 | 4 | 0 |
| Kelompok H — Animasi dan Rigging | `ANI-` | 24 | 11 | 10 | 3 | 0 |
| Kelompok I — UI dan HUD | `UI-` | 50 | 38 | 10 | 2 | 0 |
| Kelompok J — Ikon, Resource, dan Teknologi | `ICO-` | 30 | 10 | 15 | 5 | 0 |
| Kelompok K — Peta Galaksi dan Territory Management | `MAP-` | 18 | 11 | 6 | 1 | 0 |
| Kelompok L — Komandan, Karakter, dan Potret | `CMD-` | 10 | 0 | 0 | 7 | 3 |
| Kelompok M — Audio | `AUD-` | 27 | 14 | 10 | 3 | 0 |
| Kelompok N — Menu, Loading, dan Presentation | `PRE-` | 18 | 8 | 5 | 4 | 1 |
| Kelompok O — Material, Shader, dan Texture Library | `MAT-` | 20 | 10 | 7 | 3 | 0 |
| **Total** | | **336** | | | | |

> Catatan: daftar ini adalah inventaris kandidat, bukan perintah produksi sekaligus.
> Urutan produksi mengikuti `ROADMAP.md` (vertical slice dulu) dan tahapan di `Asset_Request_List.md` §24.

---

## Kelompok A — Player Space Fortress

*Benteng pemain (struktur utama, platform, kerusakan)*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `FRT-001` | Benteng utama | 3D | Model inti benteng | P0 | PLANNED |
| `FRT-002` | Command Core | 3D | Level dasar dan level upgrade | P0 | PLANNED |
| `FRT-003` | Struktur platform | 3D modular | Platform kecil, sedang, besar | P0 | PLANNED |
| `FRT-004` | Modul konektor | 3D modular | Penghubung antarbangunan | P1 | PLANNED |
| `FRT-005` | Docking port | 3D | Tempat kapal berlabuh | P0 | PLANNED |
| `FRT-006` | Landing pad | 3D | Area pendaratan pesawat | P1 | PLANNED |
| `FRT-007` | Koridor penghubung | 3D | Modular | P1 | PLANNED |
| `FRT-008` | Menara komunikasi | 3D | Model dasar dan upgrade | P1 | PLANNED |
| `FRT-009` | Antena radar | 3D | Model yang dapat beranimasi | P0 | PLANNED |
| `FRT-010` | Kubah pelindung | 3D/VFX | Model dasar dan efek perisai aktif | P0 | PLANNED |
| `FRT-011` | Menara observasi | 3D | Dekoratif dan fungsional | P2 | PLANNED |
| `FRT-012` | Lampu navigasi | 3D + material | Beberapa konfigurasi | P1 | PLANNED |
| `FRT-013` | Pipa energi | 3D modular | Segmen lurus dan belokan | P1 | PLANNED |
| `FRT-014` | Kabel dan conduit | 3D modular | Beberapa ukuran | P2 | PLANNED |
| `FRT-015` | Panel luar benteng | 3D modular | Panel utuh dan rusak | P1 | PLANNED |
| `FRT-016` | Mesin pendorong benteng | 3D | Efek mesin menyala | P2 | PLANNED |
| `FRT-017` | Dek observasi | 3D | Modul tambahan | P2 | PLANNED |
| `FRT-018` | Puing benteng | 3D | Pecahan kecil dan besar | P1 | PLANNED |
| `FRT-019` | Model benteng rusak | 3D atau sistem material | Kerusakan ringan, sedang, berat | P1 | PLANNED |
| `FRT-020` | Model benteng hancur | 3D | Kondisi kritis atau kehancuran | P2 | PLANNED |

## Kelompok B — Bangunan Ekonomi dan Produksi

*Produksi sumber daya, galangan, riset*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `ECO-001` | Energy Reactor | 3D | Menghasilkan energi | P0 | PLANNED |
| `ECO-002` | Reactor Upgrade | 3D atau varian modular | Menampilkan perkembangan level | P1 | PLANNED |
| `ECO-003` | Solar Array | 3D | Sumber energi tambahan | P1 | PLANNED |
| `ECO-004` | Mineral Extractor | 3D | Menghasilkan mineral | P0 | PLANNED |
| `ECO-005` | Mining Drill | 3D | Ekstraksi mineral asteroid | P1 | PLANNED |
| `ECO-006` | Mining Platform | 3D | Infrastruktur pertambangan | P1 | PLANNED |
| `ECO-007` | Mineral Storage | 3D | Penyimpanan mineral | P1 | PLANNED |
| `ECO-008` | Energy Storage | 3D | Penyimpanan energi | P1 | PLANNED |
| `ECO-009` | Shipyard | 3D | Produksi kapal perang | P0 | PLANNED |
| `ECO-010` | Fighter Hangar | 3D | Produksi pesawat tempur | P0 | PLANNED |
| `ECO-011` | Capital Ship Dock | 3D | Produksi kapal besar | P2 | PLANNED |
| `ECO-012` | Drone Factory | 3D | Produksi drone | P1 | PLANNED |
| `ECO-013` | Repair Bay | 3D | Perbaikan armada | P1 | PLANNED |
| `ECO-014` | Research Laboratory | 3D | Riset teknologi | P0 | PLANNED |
| `ECO-015` | Logistics Center | 3D | Peningkatan kapasitas logistik | P1 | PLANNED |
| `ECO-016` | Cargo Terminal | 3D | Transfer barang dan sumber daya | P1 | PLANNED |
| `ECO-017` | Refinery | 3D | Pemrosesan bahan mentah | P1 | PLANNED |
| `ECO-018` | Trade Hub | 3D | Perdagangan antarsektor | P2 | PLANNED |
| `ECO-019` | Resource Conveyor | 3D modular | Visualisasi alur produksi | P2 | PLANNED |
| `ECO-020` | Industrial Smoke/Vent | 3D + VFX | Menampilkan aktivitas industri | P2 | PLANNED |

## Kelompok C — Bangunan Pertahanan

*Turret, perisai, pertahanan area*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `DEF-001` | Basic Laser Turret | 3D | Pertahanan awal | P0 | PLANNED |
| `DEF-002` | Heavy Cannon Turret | 3D | Kerusakan besar pada target berat | P1 | PLANNED |
| `DEF-003` | Missile Launcher | 3D | Serangan rudal | P0 | PLANNED |
| `DEF-004` | Point Defense Turret | 3D | Menghadapi pesawat atau rudal kecil | P1 | PLANNED |
| `DEF-005` | Plasma Cannon | 3D | Senjata energi berat | P2 | PLANNED |
| `DEF-006` | Railgun Turret | 3D | Senjata kinetik jarak jauh | P2 | PLANNED |
| `DEF-007` | Anti-Capital Ship Cannon | 3D | Senjata untuk kapal besar | P2 | PLANNED |
| `DEF-008` | Shield Generator | 3D | Menghasilkan perisai | P0 | PLANNED |
| `DEF-009` | Shield Emitter | 3D | Komponen tambahan perisai | P1 | PLANNED |
| `DEF-010` | Mine Launcher | 3D | Pertahanan area | P2 | PLANNED |
| `DEF-011` | Defensive Drone Dock | 3D | Tempat peluncuran drone | P1 | PLANNED |
| `DEF-012` | Defense Control Tower | 3D | Koordinasi pertahanan | P1 | PLANNED |
| `DEF-013` | Turret Upgrade Modules | 3D modular | Memperlihatkan peningkatan level | P1 | PLANNED |
| `DEF-014` | Turret Destroyed State | 3D atau material | Menampilkan turret hancur | P1 | PLANNED |

## Kelompok D — Armada Pemain

*Pesawat tempur, kapal perang, kapal besar*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `SHP-001` | Basic Interceptor | 3D | Pesawat tempur awal | P0 | PLANNED |
| `SHP-002` | Advanced Interceptor | 3D | Pesawat cepat dan lincah | P1 | PLANNED |
| `SHP-003` | Heavy Fighter | 3D | Pesawat tempur dengan daya tahan tinggi | P1 | PLANNED |
| `SHP-004` | Bomber | 3D | Menyerang struktur dan kapal besar | P1 | PLANNED |
| `SHP-005` | Missile Fighter | 3D | Serangan berbasis rudal | P1 | PLANNED |
| `SHP-006` | Recon Drone | 3D | Pengintaian | P1 | PLANNED |
| `SHP-007` | Combat Drone | 3D | Pendukung armada | P1 | PLANNED |
| `SHP-008` | Interceptor Destroyed | 3D atau sistem fragmentasi | Kehancuran pesawat | P1 | PLANNED |
| `SHP-009` | Corvette | 3D | Kapal perang ringan | P1 | PLANNED |
| `SHP-010` | Frigate | 3D | Kapal perang serbaguna | P1 | PLANNED |
| `SHP-011` | Destroyer | 3D | Kapal perang berat | P2 | PLANNED |
| `SHP-012` | Missile Frigate | 3D | Serangan jarak jauh | P2 | PLANNED |
| `SHP-013` | Support Ship | 3D | Dukungan armada | P2 | PLANNED |
| `SHP-014` | Repair Ship | 3D | Memperbaiki kapal sekutu | P2 | PLANNED |
| `SHP-015` | Recon Ship | 3D | Eksplorasi sektor | P2 | PLANNED |
| `SHP-016` | Battleship | 3D | Kapal perang utama | P2 | PLANNED |
| `SHP-017` | Aircraft Carrier | 3D | Membawa dan meluncurkan pesawat | P2 | PLANNED |
| `SHP-018` | Dreadnought | 3D | Kapal perang endgame | P3 | PLANNED |
| `SHP-019` | Flagship | 3D | Kapal komando | P2 | PLANNED |
| `SHP-020` | Supercarrier | 3D | Kapal besar untuk cinematic dan late game | P3 | PLANNED |

## Kelompok E — Armada Alien

*Unit alien dengan identitas visual biomekanis*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `ALN-001` | Alien Scout | 3D | Pengintai | P0 | PLANNED |
| `ALN-002` | Alien Interceptor | 3D | Pesawat tempur kecil | P0 | PLANNED |
| `ALN-003` | Alien Striker | 3D | Penyerang cepat | P1 | PLANNED |
| `ALN-004` | Alien Bomber | 3D | Serangan berat | P1 | PLANNED |
| `ALN-005` | Alien Corvette | 3D | Kapal perang ringan | P1 | PLANNED |
| `ALN-006` | Alien Cruiser | 3D | Kapal perang menengah | P1 | PLANNED |
| `ALN-007` | Alien Destroyer | 3D | Kapal perang berat | P2 | PLANNED |
| `ALN-008` | Alien Carrier | 3D | Meluncurkan banyak pesawat | P1 | PLANNED |
| `ALN-009` | Alien Mothership | 3D | Boss besar | P2 | PLANNED |
| `ALN-010` | Alien Siege Ship | 3D | Menghancurkan struktur pertahanan | P2 | PLANNED |
| `ALN-011` | Alien Drone Swarm | 3D instanced | Serangan berkelompok | P1 | PLANNED |
| `ALN-012` | Alien Outpost | 3D | Basis musuh | P1 | PLANNED |
| `ALN-013` | Alien Mining Structure | 3D | Fasilitas ekstraksi alien | P2 | PLANNED |
| `ALN-014` | Alien Fortress | 3D | Benteng musuh | P2 | PLANNED |
| `ALN-015` | Alien Nest/Core | 3D | Target akhir sebuah wilayah | P1 | PLANNED |

## Kelompok F — Senjata, Projectile, dan VFX

*Efek senjata, ledakan, perisai, kerusakan*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `VFX-001` | Laser Bolt | 3D/VFX | Proyektil laser | P0 | PLANNED |
| `VFX-002` | Heavy Laser Beam | 3D/VFX | Tembakan laser berat | P1 | PLANNED |
| `VFX-003` | Plasma Projectile | 3D/VFX | Proyektil plasma | P1 | PLANNED |
| `VFX-004` | Railgun Projectile | 3D/VFX | Proyektil kinetik | P2 | PLANNED |
| `VFX-005` | Missile Model | 3D | Model rudal | P0 | PLANNED |
| `VFX-006` | Missile Trail | VFX | Jejak asap atau energi | P0 | PLANNED |
| `VFX-007` | Rocket Exhaust | VFX | Efek pendorong rudal | P1 | PLANNED |
| `VFX-008` | Muzzle Flash | VFX | Efek saat senjata menembak | P0 | PLANNED |
| `VFX-009` | Small Impact | VFX | Benturan proyektil kecil | P0 | PLANNED |
| `VFX-010` | Heavy Impact | VFX | Benturan senjata berat | P1 | PLANNED |
| `VFX-011` | Shield Hit | VFX | Dampak pada perisai | P0 | PLANNED |
| `VFX-012` | Shield Collapse | VFX | Perisai gagal | P1 | PLANNED |
| `VFX-013` | Small Explosion | VFX | Kehancuran drone/pesawat kecil | P0 | PLANNED |
| `VFX-014` | Medium Explosion | VFX | Kehancuran kapal menengah | P1 | PLANNED |
| `VFX-015` | Capital Ship Explosion | VFX | Kehancuran kapal besar | P2 | PLANNED |
| `VFX-016` | Debris Field | 3D/VFX | Puing pascapertempuran | P1 | PLANNED |
| `VFX-017` | Energy Core Explosion | VFX | Kehancuran inti energi | P2 | PLANNED |
| `VFX-018` | Engine Flame | VFX | Pendorong kapal | P0 | PLANNED |
| `VFX-019` | Warp Effect | VFX | Kapal masuk atau keluar medan tempur | P1 | PLANNED |
| `VFX-020` | Hyperspace Travel | VFX | Perjalanan antarsektor | P2 | PLANNED |
| `VFX-021` | Asteroid Destruction | VFX | Asteroid pecah | P2 | PLANNED |
| `VFX-022` | Structure Damage Smoke | VFX | Bangunan rusak | P1 | PLANNED |
| `VFX-023` | Structure Fire | VFX | Kebakaran struktur | P1 | PLANNED |
| `VFX-024` | Electric Sparks | VFX | Kerusakan elektronik | P1 | PLANNED |
| `VFX-025` | Repair Effect | VFX | Perbaikan bangunan atau kapal | P1 | PLANNED |
| `VFX-026` | Mining Beam | VFX | Ekstraksi mineral | P1 | PLANNED |
| `VFX-027` | Energy Transfer Beam | VFX | Transfer energi | P2 | PLANNED |
| `VFX-028` | Target Lock Indicator | UI/VFX | Menandai target | P0 | PLANNED |
| `VFX-029` | Critical Hit | VFX | Serangan kritis | P1 | PLANNED |
| `VFX-030` | Boss Warning Effect | UI/VFX | Peringatan kemunculan boss | P1 | PLANNED |

## Kelompok G — Planet, Asteroid, dan Lingkungan

*Lingkungan luar angkasa dan arena pertempuran*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `ENV-001` | Small Asteroid | 3D | Dekorasi dan variasi medan | P0 | PLANNED |
| `ENV-002` | Medium Asteroid | 3D | Hambatan visual | P0 | PLANNED |
| `ENV-003` | Large Asteroid | 3D | Landmark dan lokasi tambang | P0 | PLANNED |
| `ENV-004` | Mineral Asteroid | 3D | Sumber daya | P0 | PLANNED |
| `ENV-005` | Rare Mineral Asteroid | 3D | Sumber daya langka | P1 | PLANNED |
| `ENV-006` | Asteroid Cluster | 3D instanced | Area pertambangan | P0 | PLANNED |
| `ENV-007` | Planet Background | 3D | Latar arena | P0 | PLANNED |
| `ENV-008` | Planet Surface Detail | 3D atau material | Variasi planet | P2 | PLANNED |
| `ENV-009` | Moon | 3D | Latar atau landmark | P1 | PLANNED |
| `ENV-010` | Nebula Background | 2D/3D | Latar visual | P0 | PLANNED |
| `ENV-011` | Starfield | Shader/2D/3D | Latar ruang angkasa | P0 | PLANNED |
| `ENV-012` | Distant Galaxy | 2D | Latar menu dan peta | P2 | PLANNED |
| `ENV-013` | Space Debris | 3D | Area bekas pertempuran | P1 | PLANNED |
| `ENV-014` | Wrecked Spaceship | 3D | Landmark atau objek misi | P1 | PLANNED |
| `ENV-015` | Abandoned Station | 3D | Area eksplorasi | P1 | PLANNED |
| `ENV-016` | Space Gate | 3D | Gerbang antarsektor | P1 | PLANNED |
| `ENV-017` | Wormhole | 3D/VFX | Transisi perjalanan | P2 | PLANNED |
| `ENV-018` | Mining Buoy | 3D | Penanda lokasi ekstraksi | P1 | PLANNED |
| `ENV-019` | Cargo Container | 3D | Loot atau objek logistik | P1 | PLANNED |
| `ENV-020` | Space Anomaly | 3D/VFX | Lokasi khusus | P2 | PLANNED |

## Kelompok H — Animasi dan Rigging

*Perilaku gerak (sebagian besar prosedural)*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `ANI-001` | Fighter Idle Flight | Animasi/prosedural | Pesawat tempur | P0 | PLANNED |
| `ANI-002` | Fighter Acceleration | Animasi/prosedural | Pesawat tempur | P0 | PLANNED |
| `ANI-003` | Fighter Banking | Animasi/prosedural | Pesawat tempur | P0 | PLANNED |
| `ANI-004` | Fighter Evasive Maneuver | Animasi/prosedural | Pesawat tempur | P1 | PLANNED |
| `ANI-005` | Fighter Attack Pass | Animasi/prosedural | Pesawat tempur | P0 | PLANNED |
| `ANI-006` | Fighter Destroyed | Animasi/VFX | Pesawat tempur | P0 | PLANNED |
| `ANI-007` | Capital Ship Cruise | Animasi/prosedural | Kapal besar | P1 | PLANNED |
| `ANI-008` | Capital Ship Weapon Fire | Animasi/prosedural | Kapal besar | P1 | PLANNED |
| `ANI-009` | Hangar Door Open | Animasi | Hangar | P0 | PLANNED |
| `ANI-010` | Hangar Door Close | Animasi | Hangar | P0 | PLANNED |
| `ANI-011` | Ship Launch | Animasi/prosedural | Hangar dan pesawat | P0 | PLANNED |
| `ANI-012` | Ship Docking | Animasi/prosedural | Pesawat dan docking port | P1 | PLANNED |
| `ANI-013` | Turret Tracking | Animasi/prosedural | Turret | P0 | PLANNED |
| `ANI-014` | Turret Recoil | Animasi | Turret | P0 | PLANNED |
| `ANI-015` | Solar Panel Rotation | Animasi | Solar Array | P2 | PLANNED |
| `ANI-016` | Mining Drill Operation | Animasi | Mining Drill | P1 | PLANNED |
| `ANI-017` | Mining Beam Activation | Animasi/VFX | Mining Facility | P1 | PLANNED |
| `ANI-018` | Reactor Pulse | Animasi/VFX | Energy Reactor | P1 | PLANNED |
| `ANI-019` | Shield Activation | Animasi/VFX | Shield Generator | P0 | PLANNED |
| `ANI-020` | Structure Collapse | Animasi/VFX | Bangunan | P1 | PLANNED |
| `ANI-021` | Repair Animation | Animasi/VFX | Bangunan dan kapal | P1 | PLANNED |
| `ANI-022` | Warp In/Out | Animasi/VFX | Semua kapal yang relevan | P1 | PLANNED |
| `ANI-023` | Boss Entrance | Animasi/cinematic | Kapal induk alien | P2 | PLANNED |
| `ANI-024` | Boss Destruction | Animasi/VFX | Kapal induk alien | P2 | PLANNED |

## Kelompok I — UI dan HUD

*Panel, tombol, bar, indikator, HUD benteng & pertempuran*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `UI-001` | UI Panel Background | 2D |  | P0 | PLANNED |
| `UI-002` | Main Button | 2D/UI |  | P0 | PLANNED |
| `UI-003` | Secondary Button | 2D/UI |  | P0 | PLANNED |
| `UI-004` | Disabled Button | 2D/UI |  | P0 | PLANNED |
| `UI-005` | Progress Bar | 2D/UI |  | P0 | PLANNED |
| `UI-006` | Health Bar | 2D/UI |  | P0 | PLANNED |
| `UI-007` | Shield Bar | 2D/UI |  | P0 | PLANNED |
| `UI-008` | Resource Counter | UI |  | P0 | PLANNED |
| `UI-009` | Timer | UI |  | P0 | PLANNED |
| `UI-010` | Tooltip Panel | UI |  | P1 | PLANNED |
| `UI-011` | Modal Dialog | UI |  | P0 | PLANNED |
| `UI-012` | Notification Toast | UI |  | P1 | PLANNED |
| `UI-013` | Confirmation Dialog | UI |  | P0 | PLANNED |
| `UI-014` | Loading Indicator | UI |  | P0 | PLANNED |
| `UI-015` | Tab Navigation | UI |  | P0 | PLANNED |
| `UI-016` | Dropdown/Selector | UI |  | P1 | PLANNED |
| `UI-017` | Scroll Container Styling | UI |  | P0 | PLANNED |
| `UI-018` | Building Level Badge | 2D/UI |  | P0 | PLANNED |
| `UI-019` | Upgrade Arrow | 2D |  | P0 | PLANNED |
| `UI-020` | Warning Indicator | 2D/UI |  | P0 | PLANNED |
| `UI-021` | Energy Icon | 2D |  | P0 | PLANNED |
| `UI-022` | Mineral Icon | 2D |  | P0 | PLANNED |
| `UI-023` | Premium Currency Icon | 2D |  | P2 | PLANNED |
| `UI-024` | Command Core Level | UI |  | P0 | PLANNED |
| `UI-025` | Population/Capacity Indicator | UI |  | P1 | PLANNED |
| `UI-026` | Fleet Capacity Indicator | UI |  | P0 | PLANNED |
| `UI-027` | Threat Warning | UI |  | P0 | PLANNED |
| `UI-028` | Base Health Indicator | UI |  | P0 | PLANNED |
| `UI-029` | Building Menu Icon Set | 2D |  | P0 | PLANNED |
| `UI-030` | Build Placement Indicator | UI/VFX |  | P0 | PLANNED |
| `UI-031` | Invalid Placement Indicator | UI/VFX |  | P0 | PLANNED |
| `UI-032` | Upgrade Cost Panel | UI |  | P0 | PLANNED |
| `UI-033` | Repair Cost Panel | UI |  | P0 | PLANNED |
| `UI-034` | Production Queue | UI |  | P0 | PLANNED |
| `UI-035` | Construction Timer | UI |  | P0 | PLANNED |
| `UI-036` | Enemy Target Marker | UI/VFX |  | P0 | PLANNED |
| `UI-037` | Target Health Bar | UI |  | P0 | PLANNED |
| `UI-038` | Boss Health Bar | UI |  | P1 | PLANNED |
| `UI-039` | Fleet Formation Icon | 2D |  | P1 | PLANNED |
| `UI-040` | Attack Command Button | UI |  | P0 | PLANNED |
| `UI-041` | Retreat Command Button | UI |  | P1 | PLANNED |
| `UI-042` | Tactical Pause Button | UI |  | P0 | PLANNED |
| `UI-043` | Battle Speed Controls | UI |  | P1 | PLANNED |
| `UI-044` | Damage Numbers | UI |  | P1 | PLANNED |
| `UI-045` | Battle Result Panel | UI |  | P0 | PLANNED |
| `UI-046` | Casualty Report | UI |  | P1 | PLANNED |
| `UI-047` | Loot/Reward Panel | UI |  | P0 | PLANNED |
| `UI-048` | Mission Objective Tracker | UI |  | P0 | PLANNED |
| `UI-049` | Incoming Wave Warning | UI |  | P0 | PLANNED |
| `UI-050` | Battle Timeline/Progress | UI |  | P2 | PLANNED |

## Kelompok J — Ikon, Resource, dan Teknologi

*Ikon sumber daya, militer, teknologi*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `ICO-001` | Energy | 2D |  | P0 | PLANNED |
| `ICO-002` | Mineral | 2D |  | P0 | PLANNED |
| `ICO-003` | Alloy | 2D |  | P1 | PLANNED |
| `ICO-004` | Rare Crystal | 2D |  | P1 | PLANNED |
| `ICO-005` | Research Data | 2D |  | P1 | PLANNED |
| `ICO-006` | Ship Parts | 2D |  | P1 | PLANNED |
| `ICO-007` | Fuel | 2D |  | P1 | PLANNED |
| `ICO-008` | Repair Materials | 2D |  | P1 | PLANNED |
| `ICO-009` | Premium Currency | 2D |  | P2 | PLANNED |
| `ICO-010` | Mission Token | 2D |  | P2 | PLANNED |
| `ICO-011` | Fighter | 2D |  | P0 | PLANNED |
| `ICO-012` | Bomber | 2D |  | P1 | PLANNED |
| `ICO-013` | Corvette | 2D |  | P1 | PLANNED |
| `ICO-014` | Frigate | 2D |  | P1 | PLANNED |
| `ICO-015` | Battleship | 2D |  | P2 | PLANNED |
| `ICO-016` | Carrier | 2D |  | P2 | PLANNED |
| `ICO-017` | Scout | 2D |  | P0 | PLANNED |
| `ICO-018` | Defense Turret | 2D |  | P0 | PLANNED |
| `ICO-019` | Shield | 2D |  | P0 | PLANNED |
| `ICO-020` | Repair | 2D |  | P1 | PLANNED |
| `ICO-021` | Weapon Technology | 2D |  | P0 | PLANNED |
| `ICO-022` | Armor Technology | 2D |  | P0 | PLANNED |
| `ICO-023` | Engine Technology | 2D |  | P1 | PLANNED |
| `ICO-024` | Energy Technology | 2D |  | P0 | PLANNED |
| `ICO-025` | Mining Technology | 2D |  | P0 | PLANNED |
| `ICO-026` | Logistics Technology | 2D |  | P1 | PLANNED |
| `ICO-027` | Shield Technology | 2D |  | P1 | PLANNED |
| `ICO-028` | Drone Technology | 2D |  | P1 | PLANNED |
| `ICO-029` | Fleet Command Technology | 2D |  | P1 | PLANNED |
| `ICO-030` | Alien Research | 2D |  | P2 | PLANNED |

## Kelompok K — Peta Galaksi dan Territory Management

*Peta galaksi 2D/UI, node, rute, wilayah*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `MAP-001` | Galaxy Map Background | 2D | Latar peta | P0 | PLANNED |
| `MAP-002` | Star Node | 2D/UI | Titik sistem bintang | P0 | PLANNED |
| `MAP-003` | Player Territory Marker | UI | Wilayah pemain | P0 | PLANNED |
| `MAP-004` | Enemy Territory Marker | UI | Wilayah alien | P0 | PLANNED |
| `MAP-005` | Neutral Territory Marker | UI | Wilayah belum dikuasai | P0 | PLANNED |
| `MAP-006` | Resource Node Marker | UI | Lokasi sumber daya | P0 | PLANNED |
| `MAP-007` | Fleet Marker | UI | Posisi armada | P0 | PLANNED |
| `MAP-008` | Route Line | UI | Rute perjalanan | P0 | PLANNED |
| `MAP-009` | Attack Route Animation | UI | Animasi perjalanan serangan | P1 | PLANNED |
| `MAP-010` | Scanning Effect | UI/VFX | Menemukan sektor | P1 | PLANNED |
| `MAP-011` | Fog of War | Shader/UI | Wilayah belum ditemukan | P1 | PLANNED |
| `MAP-012` | Sector Border | UI | Batas wilayah | P0 | PLANNED |
| `MAP-013` | Territory Capture Effect | UI/VFX | Wilayah berhasil dikuasai | P1 | PLANNED |
| `MAP-014` | Planet Thumbnail | 2D | Pratinjau sistem | P1 | PLANNED |
| `MAP-015` | Sector Detail Panel | UI | Informasi wilayah | P0 | PLANNED |
| `MAP-016` | Enemy Threat Indicator | UI | Tingkat ancaman | P0 | PLANNED |
| `MAP-017` | Exploration Reward Marker | UI | Hadiah eksplorasi | P1 | PLANNED |
| `MAP-018` | Boss Sector Marker | UI | Wilayah boss | P2 | PLANNED |

## Kelompok L — Komandan, Karakter, dan Potret

*Sistem komandan (ekspansi, bukan vertical slice)*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `CMD-001` | Commander Portrait | 2D |  | P2 | PLANNED |
| `CMD-002` | Commander Profile Illustration | 2D |  | P2 | PLANNED |
| `CMD-003` | Commander Selection Card | UI |  | P2 | PLANNED |
| `CMD-004` | Commander Skill Icon | 2D |  | P2 | PLANNED |
| `CMD-005` | Commander Rarity Frame | UI |  | P2 | PLANNED |
| `CMD-006` | Commander Upgrade Effect | UI/VFX |  | P2 | PLANNED |
| `CMD-007` | Commander Full Body | 3D opsional |  | P3 | PLANNED |
| `CMD-008` | Commander Idle Animation | 3D opsional |  | P3 | PLANNED |
| `CMD-009` | Commander Hologram | 3D/VFX |  | P3 | PLANNED |
| `CMD-010` | Dialogue Portrait Expressions | 2D |  | P2 | PLANNED |

## Kelompok M — Audio

*SFX dan musik*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `AUD-001` | UI Click | SFX |  | P0 | PLANNED |
| `AUD-002` | UI Confirm | SFX |  | P0 | PLANNED |
| `AUD-003` | UI Error | SFX |  | P0 | PLANNED |
| `AUD-004` | Building Constructed | SFX |  | P0 | PLANNED |
| `AUD-005` | Building Upgrade | SFX |  | P1 | PLANNED |
| `AUD-006` | Reactor Hum | Loop SFX |  | P1 | PLANNED |
| `AUD-007` | Hangar Ambience | Loop SFX |  | P1 | PLANNED |
| `AUD-008` | Ship Engine | SFX/Loop |  | P0 | PLANNED |
| `AUD-009` | Laser Fire | SFX |  | P0 | PLANNED |
| `AUD-010` | Missile Launch | SFX |  | P0 | PLANNED |
| `AUD-011` | Projectile Impact | SFX |  | P0 | PLANNED |
| `AUD-012` | Shield Impact | SFX |  | P0 | PLANNED |
| `AUD-013` | Small Explosion | SFX |  | P0 | PLANNED |
| `AUD-014` | Large Explosion | SFX |  | P1 | PLANNED |
| `AUD-015` | Capital Ship Explosion | SFX |  | P2 | PLANNED |
| `AUD-016` | Warp | SFX |  | P1 | PLANNED |
| `AUD-017` | Mining Operation | SFX |  | P1 | PLANNED |
| `AUD-018` | Repair Operation | SFX |  | P1 | PLANNED |
| `AUD-019` | Incoming Attack Alert | SFX |  | P0 | PLANNED |
| `AUD-020` | Boss Arrival | SFX |  | P2 | PLANNED |
| `AUD-021` | Victory Stinger | SFX |  | P0 | PLANNED |
| `AUD-022` | Defeat Stinger | SFX |  | P0 | PLANNED |
| `AUD-023` | Base Ambience | Loop SFX |  | P1 | PLANNED |
| `AUD-024` | Space Exploration Music | Music |  | P1 | PLANNED |
| `AUD-025` | Combat Music | Music |  | P0 | PLANNED |
| `AUD-026` | Boss Music | Music |  | P2 | PLANNED |
| `AUD-027` | Galaxy Map Music | Music |  | P1 | PLANNED |

## Kelompok N — Menu, Loading, dan Presentation

*Layar menu, loading, hasil pertempuran*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `PRE-001` | Main Menu Background | 3D render atau 2D |  | P0 | PLANNED |
| `PRE-002` | Logo Game | 2D/SVG |  | P0 | PLANNED |
| `PRE-003` | Loading Screen Background | 2D |  | P0 | PLANNED |
| `PRE-004` | Loading Indicator | UI |  | P0 | PLANNED |
| `PRE-005` | Login Screen Background | 2D/3D render |  | P2 | PLANNED |
| `PRE-006` | Mission Briefing Background | 2D/3D render |  | P1 | PLANNED |
| `PRE-007` | Victory Screen Background | 2D/3D render |  | P0 | PLANNED |
| `PRE-008` | Defeat Screen Background | 2D/3D render |  | P0 | PLANNED |
| `PRE-009` | Boss Introduction Frame | UI |  | P2 | PLANNED |
| `PRE-010` | Cinematic Letterbox | UI |  | P2 | PLANNED |
| `PRE-011` | Screen Transition Effect | UI/VFX |  | P1 | PLANNED |
| `PRE-012` | Event Banner | 2D |  | P3 | PLANNED |
| `PRE-013` | Achievement Badge | 2D |  | P2 | PLANNED |
| `PRE-014` | Tutorial Highlight | UI/VFX |  | P0 | PLANNED |
| `PRE-015` | Tutorial Hand Indicator | 2D/UI |  | P0 | PLANNED |
| `PRE-016` | Reward Reveal Effect | UI/VFX |  | P1 | PLANNED |
| `PRE-017` | New Building Unlocked | UI/VFX |  | P1 | PLANNED |
| `PRE-018` | New Sector Unlocked | UI/VFX |  | P1 | PLANNED |

## Kelompok O — Material, Shader, dan Texture Library

*Material & shader standar agar aset konsisten*

| ID | Aset | Format | Fungsi / Keterangan | Prioritas | Status |
|---|---|---|---|---|---|
| `MAT-001` | Human Hull Metal | Material | Kapal dan bangunan manusia | P0 | PLANNED |
| `MAT-002` | Alien Hull Material | Material | Armada alien | P0 | PLANNED |
| `MAT-003` | Industrial Metal | Material | Fasilitas produksi | P0 | PLANNED |
| `MAT-004` | Dark Metal | Material | Struktur militer | P0 | PLANNED |
| `MAT-005` | Ceramic Armor | Material | Pelat pelindung | P1 | PLANNED |
| `MAT-006` | Energy Core | Emissive material | Reaktor dan inti energi | P0 | PLANNED |
| `MAT-007` | Blue Engine Emission | Emissive material | Pendorong kapal | P0 | PLANNED |
| `MAT-008` | Red/Orange Weapon Emission | Emissive material | Senjata energi | P0 | PLANNED |
| `MAT-009` | Shield Material | Shader/material | Perisai | P0 | PLANNED |
| `MAT-010` | Damaged Metal | Material | Bangunan rusak | P1 | PLANNED |
| `MAT-011` | Scorched Metal | Material | Bekas ledakan | P1 | PLANNED |
| `MAT-012` | Asteroid Rock | Material | Asteroid | P0 | PLANNED |
| `MAT-013` | Mineral Surface | Material | Asteroid kaya mineral | P0 | PLANNED |
| `MAT-014` | Ice Surface | Material | Asteroid es | P2 | PLANNED |
| `MAT-015` | Planet Surface | Material | Planet | P1 | PLANNED |
| `MAT-016` | Hologram Material | Shader | UI 3D dan proyeksi | P1 | PLANNED |
| `MAT-017` | Warp Distortion | Shader | Perjalanan antarsektor | P2 | PLANNED |
| `MAT-018` | Dissolve/Destruction | Shader | Kehancuran unit | P2 | PLANNED |
| `MAT-019` | Scanning Effect | Shader/VFX | Radar dan eksplorasi | P1 | PLANNED |
| `MAT-020` | Shield Hit Distortion | Shader | Benturan perisai | P1 | PLANNED |

---

## Kelompok P — Efek Kerusakan dan Kondisi Bangunan (state visual, bukan aset berdiri sendiri)

Empat tingkat kondisi yang harus dimiliki bangunan (dari `Asset_Request_List.md` §18):

| Kondisi | Visual | Implementasi |
|---|---|---|
| Normal | Struktur utuh, lampu aktif | Model normal |
| Damaged | Panel rusak, percikan kecil | Material atau modul kerusakan |
| Critical | Asap, api, lampu berkedip | Material + VFX |
| Destroyed | Struktur hancur / tidak berfungsi | Model rusak, puing, atau state kehancuran |

Kebutuhan state per bangunan: Command Core (normal/damaged/critical), Hangar (normal/damaged/critical/
hanggar tidak berfungsi), Reaktor (normal/damaged/critical/ledakan energi), Turret (normal/damaged/disabled/
destroyed), Fasilitas tambang (normal/damaged/produksi berhenti), Shield Generator (normal/damaged/perisai melemah/
perisai offline).

Aturan gameplay: bangunan hancur tidak boleh menghapus seluruh progres pemain — harus ada sistem perbaikan
dan pemulihan yang jelas (lihat `Game_Concept.md` §4).

---

## Target Awal — Vertical Slice (P0)

| Kelompok | Target awal | Keterangan |
|---|---|---|
| Benteng | 1 inti + 3–5 modul | Menampilkan pembangunan dasar |
| Bangunan ekonomi | 3–4 | Reaktor, extractor, hangar, research lab |
| Bangunan pertahanan | 2 | Laser turret dan shield generator |
| Armada pemain | 1–2 unit | Interceptor dan satu kapal pendukung opsional |
| Armada alien | 1–2 tipe | Scout dan interceptor alien |
| Lingkungan | 1 set | Asteroid, mineral asteroid, planet, starfield |
| VFX | 8–12 efek dasar | Laser, mesin, impact, shield, ledakan, kerusakan |
| Animasi/perilaku | 8–12 perilaku | Terbang, menembak, tracking, launch, repair |
| UI | 1 set dasar | Resource HUD, build menu, upgrade, battle HUD |
| Ikon | 10–20 ikon inti | Sumber daya, bangunan, dan unit |
| Audio | 8–12 SFX | Tembakan, mesin, ledakan, UI, alarm |
| Material | 6–10 material dasar | Metal, energy, alien, asteroid, emissive |

## Keputusan yang Belum Ditetapkan (mempengaruhi jumlah aset)

Dari `Asset_Request_List.md` §25 — jangan produksi aset sebelum keputusan ini diambil:

- Kamera: isometrik atau top-down? dapat diputar atau tidak?
- Arena combat terpisah atau satu dunia utuh?
- Ukuran armada di layar (mempengaruhi LOD, VFX, kompleksitas model)
- Combat otomatis atau kontrol langsung?
- Benteng modular atau satu model besar?
- Upgrade kosmetik atau model berbeda per level?
- Sistem komandan atau tanpa komandan?
- Jumlah sektor dan planet
- Gaya visual: realistis atau stylized-realistic?

Lihat juga: `ART_DIRECTION.md`, `ASSET_PIPELINE.md`, `ASSET_ACCEPTANCE_CRITERIA.md`, `ROADMAP.md`.
