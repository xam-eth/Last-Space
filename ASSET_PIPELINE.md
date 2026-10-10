# ASSET PIPELINE — Last-Space

Standar lengkap Blender → GLB → Godot. Dibuat berdasarkan `Asset_Request_List.md`
(§20 format file, §21 struktur folder, §22 kontrak aset, §23 aset AI) dan
`AI_GOVERNANCE.md` §11 (aturan produksi aset).

## 1. Prinsip Utama

1. **Satu aset pilot dulu.** Sebelum aset apa pun diproduksi massal, satu aset
   perwakilan (pilot — diusulkan `SHP-001` Basic Interceptor) harus melewati
   seluruh pipeline dan lolos `ASSET_ACCEPTANCE_CRITERIA.md`. Pilot membuktikan:
   skala, orientasi, material, kualitas tekstur, ukuran file, konsistensi visual,
   kebutuhan animasi, dan hasil di scene perwakilan.
2. **Kontrak diutamakan, bukan selera.** Skala, sumbu, origin, dan naming adalah
   kontrak pipeline — tidak diputuskan ulang oleh setiap pembuat aset.
3. **Jangan simpan sampah.** Jangan menyimpan cache render, backup otomatis
   Blender (`.blend1`...), atau salinan duplikat aset tanpa alasan.

## 2. Kontrak Teknis (WAJIB untuk semua aset 3D)

| Properti | Standar |
|---|---|
| Satuan | **1 unit Blender = 1 meter** (skala metrik, `unit_scale = 1.0`) |
| Forward axis | **-Z di Godot** (depan kapal/objek menunjuk -Z setelah import). Di Blender: buat bagian depan menghadap **-Y** (front view). *Status: ASSUMPTION — wajib diverifikasi oleh pilot asset SHP-001* |
| Up axis | +Y (Blender default; exporter `+Y Up` → glTF) |
| Origin | di titik tumpu logis: kapal → pusat badan; bangunan → titik jangkar konstruksi (tengah footprint, di permukaan platform) |
| Skala setelah import | diverifikasi di Godot: kapal kecil ~2–6 m, kapal besar 30–200 m (angka awal, bisa berubah setelah kamera diputuskan) |
| Naming file | `snake_case` dengan ID: `shp_001_basic_interceptor.glb` (ID dari `MASTER_ASSET_INVENTORY.md`) |
| Naming node/objek | `SHP001_Body`, `SHP001_Engine_L`, `SHP001_Weapon_T` — prefix ID + bagian |
| Material | material standar proyek (`MAT-xxx` dari `MASTER_ASSET_INVENTORY.md` Kelompok O), berbasis Principled BSDF |
| Tekstur | PNG, 1024×1024 atau 2048×2048 (pilih satu per aset, konsisten), power-of-two |
| Collision | sederhana: kapal kecil = box/sphere hull; kapal besar = convex decomposition atau beberapa box; bangunan = box sesuai footprint |
| LOD | wajib untuk kapal besar & benteng: LOD0 (dekat) / LOD1 (menengah) / LOD2 (jauh, atau hilang) |
| Animasi | tidak wajib skeletal — gerakan kapal (banking, akselerasi, lintasan) dibuat **prosedural di Godot** (lihat Kelompok ANI) |
| Attachment | titik mesin (engine) dan senjata (weapon) wajib ada sebagai empty/node bernama konsisten |

## 3. Format File (standar yang ditetapkan)

| Format | Penggunaan |
|---|---|
| `.blend` | source project Blender — simpan untuk aset yang dibuat/diedit di Blender |
| `.glb` | **format pertukaran utama** model 3D ke Godot (mesh + material + hierarchy + animasi dalam satu file) |
| `.gltf` | alternatif jika workflow butuh file terpisah |
| `.png` | tekstur, sprite, ikon, flipbook (format utama gambar raster) |
| `.webp` | gambar UI/background tertentu — opsional setelah kompatibilitas pipeline diperiksa |
| `.exr` / `.hdr` | HDR environment/lighting — hanya jika dibutuhkan |
| `.svg` | ikon dan elemen UI vektor |
| `.ttf` / `.otf` | font |
| `.wav` | SFX pendek; `.ogg` | musik & audio terkompresi |
| `.tres` / `.res` | resource native Godot (material, konfigurasi, data) |
| `.tscn` | scene Godot (prefab bangunan, kapal, VFX, UI) |
| `.gd` | script Godot |

**Kenapa GLB:** menyimpan mesh, material, hierarchy, animasi, mudah diorganisasi
sebagai satu file, cocok untuk workflow Blender → Godot.

## 4. Struktur Folder (res://)

```
res://
├── assets/
│   ├── 3d/
│   │   ├── fortress/           # FRT-xxx
│   │   ├── buildings/
│   │   │   ├── economy/        # ECO-xxx
│   │   │   ├── defense/        # DEF-xxx
│   │   │   └── research/
│   │   ├── player_ships/       # SHP-xxx (fighters/, corvettes/, frigates/, capital_ships/)
│   │   ├── alien_ships/        # ALN-xxx
│   │   ├── environment/        # ENV-xxx (asteroids/, planets/, stations/)
│   │   ├── props/
│   │   └── debris/
│   ├── 2d/
│   │   ├── icons/              # ICO-xxx (resources/, buildings/, ships/, technology/, status/)
│   │   ├── ui/                 # UI-xxx
│   │   ├── portraits/          # CMD-xxx
│   │   ├── backgrounds/        # PRE-xxx
│   │   ├── galaxy_map/         # MAP-xxx
│   │   └── spritesheets/
│   ├── vfx/                    # VFX-xxx (weapons/, explosions/, shields/, engines/, damage/, repair/, transitions/)
│   ├── materials/              # MAT-xxx (.tres)
│   ├── textures/
│   ├── audio/                  # AUD-xxx (sfx/, ambience/, music/)
│   └── fonts/
├── scenes/                     # base/, buildings/, ships/, combat/, galaxy_map/, menus/, ui/
├── scripts/                    # building/, fleet/, combat/, economy/, research/, ui/
├── data/                       # buildings/, ships/, weapons/, technologies/, sectors/ (.tres)
└── shaders/                    # shield/, hologram/, damage/, environment/
```

Source `.blend` disimpan di repositori art source terpisah jika ukuran proyek
membesar (bisa juga `tools/art-source/`, di luar `res://`). `.glb` hasil export
masuk `assets/3d/...` dan di-commit; file hasil import Godot (`.import`,
`.godot/`) tidak di-commit (sudah di `.gitignore`).

## 5. Pengaturan Export Blender (glTF 2.0)

- Format: **GLB**, `+Y Up` aktif.
- **Apply Modifiers** aktif; **+Y Up**; kompresi Draco boleh aktif untuk aset
  besar (Godot 4.7 membacanya — sudah terbukti di smoke test toolchain).
- Materials: `EXPORT` (materialengan Principled BSDF → Godot StandardMaterial3D).
- Mesh: triangulated (Godot aman dengan apa pun, tapi konsisten itu lebih baik).
- Animasi: sertakan hanya jika memang ada (sebagian besar tidak — prosedural).
- Ekspor via script headless (bpy) agar bisa diulang di CI:

```python
# contoh: tools/art/export_glb.py (dijalankan dengan python3 yang punya bpy)
import bpy
bpy.ops.export_scene.gltf(
    filepath="assets/3d/player_ships/fighters/shp_001_basic_interceptor.glb",
    export_format="GLB",
    export_yup=True,
    export_apply=True,          # apply modifiers
    export_materials="EXPORT",
    export_draco_mesh_compression_enable=True,
)
```

## 6. Import & Penggunaan di Godot 4.7

- Import GLB via editor (dev machine) atau **runtime** dengan `GLTFDocument`
  untuk pengujian di CI tanpa editor:
  `GLTFDocument.new().append_from_buffer(packed_byte_array, "glb", state)`.
- Material hasil import di-override dengan material standar proyek (`MAT-xxx`)
  agar konsisten.
- Prefab per aset = `.tscn` yang membungkus mesh GLB + collision + titik
  attachment + (untuk bangunan) state visual kerusakan.
- **Verifikasi orientasi & skala di Godot dengan pilot asset sebelum produksi
  seluruh armada** — ini bagian dari acceptance criteria.

## 7. Material Standar (Kelompok O)

Semua aset memakai material dari library `assets/materials/` (lihat
`MASTER_ASSET_INVENTORY.md` Kelompok O: `MAT-001` Human Hull Metal, `MAT-002`
Alien Hull, `MAT-006` Energy Core, `MAT-007` Blue Engine Emission, `MAT-008`
Red/Orange Weapon Emission, `MAT-009` Shield, `MAT-012` Asteroid Rock,
`MAT-013` Mineral Surface, dst.). Material baru harus kompatibel dengan
standar ini dan diberi ID.

## 8. Aset yang Dibuat dengan AI (termasuk generator 3D)

Boleh dipakai untuk mempercepat concept art, variasi, tekstur, dan model awal.
**Tetap wajib melewati 10 proses** (`Asset_Request_List.md` §23):

1. Concept Validation — sesuai art direction?
2. Geometry Inspection — mesh bermasalah?
3. Scale and Origin — benar?
4. Material Inspection — impor dengan benar?
5. Optimization — cukup ringan untuk target perangkat?
6. Collision Setup — sesuai kebutuhan gameplay?
7. Integration Test — bekerja di scene Godot?
8. Visual Review — benar dari kamera gameplay?
9. Performance Test — layak saat dipakai banyak unit?
10. Acceptance — benar-benar terintegrasi dan terverifikasi?

Dan aturan governance §11: sebelum bulk generation — buat batch kecil, impor ke
Godot, verifikasi (skala, orientasi, material, tekstur, ukuran file, konsistensi,
kebutuhan animasi), uji di scene perwakilan, catat rework manual, baru estimasi
biaya/waktu dari hasil nyata.

## 9. Status Aset (wajib di `MASTER_ASSET_INVENTORY.md`)

`PLANNED` → `GENERATED` → `REVIEWED` → `OPTIMIZED` → `INTEGRATED` → `VERIFIED`

Definisi lengkap dan kriteria kelulusan tiap tahap: `ASSET_ACCEPTANCE_CRITERIA.md`.
**Jangan tandai aset selesai hanya karena file GLB berhasil dibuat.**

## 10. Checklist Sebelum Produksi Massal

- [ ] Pilot asset (SHP-001) lolos seluruh acceptance criteria
- [ ] Kontrak sumbu/skala/origen terbukti di Godot (scene uji)
- [ ] Material standar (6–10 material dasar) sudah ada dan konsisten
- [ ] Keputusan kamera & gaya visual sudah diambil (lihat `MASTER_ASSET_INVENTORY.md` §Keputusan)
- [ ] Struktur folder di atas sudah dibuat
- [ ] Smoke test import GLB di runtime (CI) hijau
