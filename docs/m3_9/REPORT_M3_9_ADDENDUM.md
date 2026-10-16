# M3 #9 — ADDENDUM: aset 3D bangunan/benteng dari Blender + rekonsiliasi branch

Milestone: **M3 #9** (lanjutan) · Status: **VERIFIED** · Tanggal: 2026-10-16
Branch: `arena/d80e2902-last-space`

Laporan ini adalah **tambahan** untuk `docs/m3_9/REPORT_M3_9.md` (pekerjaan M3 #9
yang sudah ada di branch ini) dan `docs/m3_8_cards_camera/REPORT_M3_8.md`.

---

## 1. Yang terjadi di sesi ini (jujur, termasuk kesalahan saya)

Kritik pemain terbaru (verbatim): *"masih tidak jelas card nya masih bertumpuk dan
size nya masih tidak tepat, semua compenet layout dan icon nya masih memakai html5
code bukan asset svg or png begitu juga arena component, di sesi ini kamu bisa
generate foto atau svg, game arena nya itu harus nya di buat seperti di dalam markas
luar angkasa punya benteng, kamu harus cari dan pahami knownledge bagaimana logika
game building strategi disini build nya kamu buat asal asalan, doc concept dn
bottleneck itu tidak di taati"*.

**Kesalahan saya yang harus dicatat:** saya mengerjakan sesi ini dari memori chat
tanpa memeriksa repo lebih dulu. Ternyata sandbox sudah pernah reset **dan** branch
ini sudah dikerjakan agent lain sampai commit `fd598db` — dua hal yang melanggar
`AGENTS.md` ("inspect the actual repository before every development task"):

1. Saya sempat mulai menulis `can_place`/`snap_to_grid`/mode penempatan di
   `building_system.gd` + `base_scene.gd` — padahal **agent lain sudah
   mengimplementasikannya lebih lengkap** (ghost 2 langkah, validasi area, bilah
   LETAKKAN, tata letak basis). Pekerjaan duplikat itu saya **buang**.
2. Saya sempat memodifikasi 40 berkas versi lama (basis `41d8730`) sehingga terlihat
   seperti menghapus kerjaan mereka. Setelah `git fetch` saya melihat `fd598db`,
   lalu **me-rebase pekerjaan saya di atasnya**: semua berkas mereka dipulihkan
   (`git checkout fd598db -- …`), dan hanya **selisih komplementer** milik saya
   yang dipertahankan.

Setelah rekonsiliasi, struktur commit: `41d8730` → `2b0b74a` (M3 #8 saya) →
`2aede03` (M3 #9 agent lain) → `fd598db` (M3 #9 AC-6a agent lain) → **commit sesi ini**.

## 2. Gap yang saya tutup (dan gap yang masih terbuka)

`docs/m3_9/REPORT_M3_9.md` §5 sudah mencatat sendiri dua pekerjaan terbuka:

| Elemen | Sebelum | Sekarang |
|---|---|---|
| Model bangunan (markas, reaktor, ekstraktor, hanggar, turret, generator perisai) | mesh prosedural dari kode (`building_model.gd`) | **ASET Blender → GLB + mesh.json** (`assets/fortress/*.glb` + `game/assets/fortress/*.mesh.json`) |
| Dek benteng arena (FRT-001) | — (deck PNG + dinding PNG dari agent lain, sudah ada) | **opsional**: aset FRT-001 tersedia (platform heksagon 85 m, `assets/fortress/frt-001.glb`); dek PNG mereka tetap dipakai karena tampil lebih baik dari segi visual & bobot |
| Frame/panel HUD (border, sudut) | `StyleBoxFlat` dari kode | **masih `StyleBoxFlat`** — jujur: BELUM diganti nine-patch PNG |
| Kartu TINGKATKAN terpotong (tinggi 64dp > tinggi band) | teks meluber keluar kartu | **diperbaiki**: kartu 88×52dp + `clip_text` + audit `QA:HUD:TEXTFIT` |

## 3. Aset baru: kit benteng & bangunan (Blender headless)

Generator: `tools/blender/make_fortress.py` (mengikuti kontrak `ASSET_PIPELINE.md`
& pilot `make_shp_001.py`: 1 unit = 1 m, depan −Z Godot, material `MAT-xxx`,
tekstur PNG 512 power-of-two, geometri di-weld + triangulasi, tanpa n-gon).

| ID (inventaris) | Berkas runtime | Tris | Node (material) | Ukuran meter |
|---|---|---|---|---|
| `FRT-001` Fortress Platform | `frt-001.mesh.json` | 292 | 2 | 85,2 × 85,2 × 5,35 |
| `FRT-002` Command Core | `frt-002.mesh.json` | 528 | 3 (dek, lambung, **inti energi emissive**) | 8,48 × 8,48 × 12,1 |
| `ECO-001` Energy Reactor | `eco-001.mesh.json` | 656 | 3 | 4,88 × 4,88 × 5,05 |
| `ECO-004` Mineral Extractor | `eco-004.mesh.json` | 252 | 3 | 7,26 × 5,3 × 5,1 |
| `ECO-010` Fighter Hangar | `eco-010.mesh.json` | 236 | 3 | 7,1 × 6,75 × 4,8 |
| `DEF-001` Laser Turret | `def-001.mesh.json` | 192 | 3 (termasuk **ujung laras menyala**) | 2,97 × 4,38 × 1,81 |
| `DEF-008` Shield Generator | `def-008.mesh.json` | 476 | 3 (termasuk **kubah perisai**) | 6,0 × 6,0 × 4,16 |

Sumber: `assets/fortress/<id>.glb` + `.blend` per aset (satu scene per aset — satu
scene untuk 7 aset membuat GLB tiap aset memuat SEMUA model: temuan nyata yang
diperbaiki). Tekstur: `deck_plating_512.png` + `hull_panel_512.png` (hasil generate
foto, dibuat *seamless* secara matematis) + peta **emissive terpisah** (hanya garis
panel yang menyala). Laporan angka: `assets/fortress/make_fortress_report.json`.

## 4. Tiga bug nyata yang ditemukan & diperbaiki selama verifikasi

1. **Join multi-material kehilangan material** — semua bagian yang punya material
   kedua/ketiga (inti reaktor, ujung laras, kubah perisai) ikut material pertama.
   Bukti: `QA:ASSET:MAT` awal hanya melaporkan 1 node per aset. Perbaikan:
   `_extract_nodes()` mengekspor **satu node per material**.
2. **`mesh.material` selalu null** — material aset dipasang per-surface
   (`surface_set_material(0)`), jadi audit material dan pewarnaan state
   (`BuildingModel.tint`) tidak pernah melihatnya. Bukti: marker `QA:ASSET:MAT`
   mencetak kosong walau berkas memuat material. Perbaikan: baca lewat
   `surface_get_material(0)`.
3. **Metalik tanpa IBL = hitam** — foto pertama memperlihatkan model bangunan nyaris
   tak terlihat (hanya siluet). Perbaikan: metallic `0,65 → 0,10`, roughness naik,
   ambient 0,5 → 0,85, key light 0,85 → 1,35, plus **fill light** dari arah
   berlawanan (`QA:ASSET:MAT` melaporkan nilai material nyata tiap kali build).

## 5. Verifikasi (angka dari run nyata)

```
gate tests  → TESTS:DONE passed=466 failed=0        (0 suite FAIL)
gate input  → QA:INPUT:DONE passed=42 failed=0      (termasuk alur penempatan 2 langkah)
gate e2e    → QA:LOOP:COMPLETE                      (0 suite FAIL)
gate asset  → QA:MODEL:ASSET id=… src=assets/fortress/*.mesh.json ×6 (7 tipe, semua dari aset)
gate ui     → 0 suite FAIL; QA:HUD:TEXTFIT checked=12 overflow=0
              QA:CARD:OVERLAP count=0 … gap_px=16.0..16.0 tile_px=[112.0 …] ok=true
```

## 6. Limitasi yang masih ada (tidak diklaim selesai)

- **Frame/panel HUD** masih `StyleBoxFlat` dari kode (belum nine-patch PNG).
- **Terrain/asteroid/bulan** masih mesh bola dari kode (dekorasi 3D di luar dek).
- **LOD & collision** untuk aset baru belum dibuat (aset statis, gameplay pick
  memakai proyeksi 2D titik bangunan — tidak butuh collision mesh saat ini).
- **`assets/fortress/*.glb` ±1,2 MB per aset** karena mesin ekspor menanam tekstur
  512² + peta emissive ke GLB; runtime tidak memakainya (memakai `mesh.json`).
  Bila ukuran repo jadi masalah, langkah berikutnya: ekspor GLB tanpa tekstur
  (referensi eksternal) atau pindahkan `_raw`/`*.glb` ke penyimpanan luar.
- Verifikasi visual akhir (foto bukti baru untuk aset bangunan) **belum**
  ditambahkan ke `docs/`; yang ada di laporan ini adalah hasil tangkapan sesi
  (`/tmp/m39b.png`, 2560×1440) — bukan berkas yang di-commit.
