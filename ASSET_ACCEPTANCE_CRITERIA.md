# ASSET ACCEPTANCE CRITERIA — Last-Space

Kriteria agar sebuah aset dianggap **layak, terintegrasi, dan terverifikasi**.
Menggabungkan `Asset_Request_List.md` §22–23, `AI_GOVERNANCE.md` §4 (Definition
of Done) dan §11 (aturan produksi aset).

> **Aturan emas:** aset bertatus `VERIFIED` hanya jika sudah diuji sesuai fungsi
> dan persyaratannya di dalam game — bukan karena file GLB berhasil dibuat.

## 1. Status dan Definisi Kelulusan

| Status | Arti | Bukti yang dibutuhkan |
|---|---|---|
| `PLANNED` | Belum dibuat | Entri di `MASTER_ASSET_INVENTORY.md` |
| `GENERATED` | Ada hasil awal (file/konsep) | File source (`.blend`/gambar) atau link hasil generator |
| `REVIEWED` | Diperiksa visual sesuai art direction | Catatan review (mengacu `ART_DIRECTION.md`) |
| `OPTIMIZED` | Sudah dioptimasi (poly, tekstur, ukuran file) | Angka sebelum/sesudah (poly count, ukuran file, jumlah draw call) |
| `INTEGRATED` | Masuk proyek Godot | Scene `.tscn` + import tanpa error + tampil di editor/runtime |
| `VERIFIED` | Lolos semua kriteria di bawah | Hasil pengujian aktual (log/screenshot/angka) |

## 2. Checklist Wajib per Aset 3D

Centang semua sebelum status dinaikkan ke `VERIFIED`:

- [ ] **ID unik** terdaftar di `MASTER_ASSET_INVENTORY.md` dan dipakai di nama file
- [ ] **Skala benar** — 1 unit = 1 meter; ukuran objek sesuai kelasnya (kapal kecil 2–6 m, dst.)
- [ ] **Orientasi benar** — depan objek menunjuk -Z di Godot (diverifikasi di scene, bukan asumsi)
- [ ] **Origin benar** — di titik jangkar yang disepakati (lihat `ASSET_PIPELINE.md` §2)
- [ ] **Geometri bersih** — tidak ada n-gon berlebihan, face terbalik, atau mesh rusak; poly count dalam budget
- [ ] **Material standar** — memakai `MAT-xxx` dari library proyek; tekstur PNG power-of-two (1024/2048)
- [ ] **Collision** — ada dan sesuai kebutuhan gameplay (box/sphere/convex sederhana)
- [ ] **LOD** — ada untuk kapal besar/benteng (LOD0/1/2), atau pengecualian terdokumentasi
- [ ] **Attachment point** — titik mesin (`Engine_*`) dan senjata (`Weapon_*`) ada dan bernama konsisten
- [ ] **Thumbnail** — render/screenshot untuk UI (jika aset tampil di UI)
- [ ] **Ikon 2D** — terpisah untuk UI (jika relevan)
- [ ] **VFX terkait** — efek yang melekat (mesin, tembakan, ledakan) punya lifecycle jelas (durasi, pooling, batas)
- [ ] **Ukuran file wajar** — GLB dalam budget (target awal: kapal kecil < 500 KB, kapal besar < 3 MB — *provisional, divalidasi saat pilot*)
- [ ] **Performa** — diuji bersama banyak unit di stress scene (target jumlah unit berjalan mulus)

## 3. Checklist Tambahan per Kategori

- **Bangunan:** state visual Normal/Damaged/Critical/Destroyed tersedia (material
  atau modul), titik jangkar konstruksi jelas, animasi aktif saat beroperasi
  (pintu hanggar, radar berputar, reaktor pulse).
- **Kapal:** siap gerak prosedural (banking/akselerasi di Godot), titik api senjata
  jelas, efek mesin di attachment point, kondisi hancur (fragmentasi atau VFX).
- **Turret:** basis + laras terpisah untuk rotasi yaw/pitch, animasi recoil,
  state hancur.
- **VFX:** durasi terbatas, pooling, batas partikel, качество bisa diturunkan.
- **UI/Ikon:** terbaca di ukuran kecil, konsisten dengan icon design system.
- **Audio:** durasi wajar, tidak ada klik/looping yang mengganggu, volume relatif
  konsisten.

## 4. Pengujian Integrasi (wajib untuk VERIFIED)

1. Import GLB → tidak ada error/warning di output Godot.
2. Aset dimunculkan di **scene perwakilan** (bukan scene kosong) — misal: kapal
   di arena asteroid; bangunan di benteng.
3. **Tangkapan layar (vision evidence)** dari kamera gameplay aktual disimpan
   (via `tools/vision/capture.mjs`) dan dilampirkan/direferensikan di laporan.
4. **Log** — tidak ada error di console selama pengujian.
5. **Performa** — stress test dengan jumlah unit relevan; frame-time tercatat.
6. Untuk aset yang dipakai di gameplay: **terhubung ke sistem nyata** (bukan
   demo terpisah) — governance §4 butir 2.

## 5. Aturan Pelaporan

Setiap aset yang dinaikkan statusnya wajib lapor (format ringkas):

- ID aset + nama file
- Perubahan/pekerjaan yang dilakukan
- Pengujian yang benar-benar dijalankan + hasil aktual
- Status baru + bukti (path screenshot/log/angka)
- Limitasi yang masih ada (jika ada)

Label status per governance §3: **VERIFIED** (ada bukti runtime/test),
**IMPLEMENTED** (ada tapi belum teruji), **LIKELY**, **ASSUMPTION**, **UNKNOWN**,
**BLOCKED**. Jangan pernah mengklaim selesai tanpa bukti.

## 6. Anti-Pattern (jangan lakukan)

- Jangan bulk-generate aset untuk mengisi inventaris (governance §11).
- Jangan tandai `VERIFIED` hanya karena GLB berhasil dibuat.
- Jangan mengubah skala/origin/naming seenaknya di tengah pipeline.
- Jangan membuat varian baru tanpa alasan gameplay yang jelas (governance §14).
- Jangan menyimpan `.blend1`, cache render, atau duplikat aset di repo.
