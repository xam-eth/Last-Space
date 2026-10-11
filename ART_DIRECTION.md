# ART DIRECTION — Last-Space

Standar visual untuk seluruh aset game. Dibuat berdasarkan `Asset_Request_List.md`
(§1 visual direction) dan `Game_Concept.md` (§3 diferensiasi, §7 identitas visual).
Dokumen ini adalah kontrak: aset yang tidak mengikuti standar ini tidak lolos
review (lihat `ASSET_ACCEPTANCE_CRITERIA.md`).

## 1. Tiga Lapisan Visual (wajib terbaca berbeda)

| Lapisan | Konteks | Standar visual |
|---|---|---|
| Base-Building Strategy | Command Mode — kamera strategis melihat benteng | Benteng monumental, berkembang secara visual, rusak terlihat jelas |
| Fleet & Territory | Peta galaksi + manajemen armada | Node/rute 2D bersih, marker jelas, tidak perlu detail tinggi |
| Cinematic Space Combat | Combat Mode — kamera dekat pertempuran | Aksi dramatis: laser, misil, ledakan, kapal induk, benteng terbakar |

**Aturan utama:** "Full 3D bukan berarti ribuan polygon." Kualitas ditentukan oleh
desain, pencahayaan, komposisi, material, dan animasi — bukan jumlah polygon.
Gunakan model sederhana + LOD + material bersama + instancing.

## 2. Identitas Faksi

### Manusia (pemain)
- **Siluet:** teknologi industrial-militer yang rapi — hull metal dengan panel,
  garis tegas, modul jelas (hanggar, kubah, antena).
- **Material standar:** `MAT-001` Human Hull Metal (abu-テゴ, metalik), `MAT-003`
  Industrial Metal, `MAT-004` Dark Metal.
- **Aksen energi:** biru/cyan (`MAT-006` Energy Core, `MAT-007` Blue Engine
  Emission) untuk reaktor, mesin, dan inti energi.
- **Aksen senjata:** merah/orange (`MAT-008` Red/Orange Weapon Emission) untuk
  titik senjata energi — penanda "panas" yang mudah dibaca.

### Alien (musuh)
- **Siluet:** biomekanis — bentuk asimetris, material gelap (`MAT-002` Alien
  Hull), inti energi bercahaya sebagai focal point.
- **Aksen energi:** warna berbeda dari manusia — **diputuskan saat pilot
  ALN-001 (2026-10-11): hijau** untuk mesin + inti energi (`MAT-021`/
  `MAT-022`), **ungu menyala** untuk senjata energi (`MAT-023`) — harus
  konsisten untuk semua aset alien berikutnya.
- **Aturan variasi:** variasi antar unit alien dilakukan lewat siluet, ukuran,
  jenis senjata, kecepatan, pola serangan, warna inti, material, dan modul
  tambahan. **Perubahan warna saja tidak cukup** untuk peran yang berbeda.

## 3. Benteng Pemain (objek utama — monumental)

- Command Fortress sebesar kota futuristik; berkembang dari benteng kecil
  menjadi kompleks industri besar.
- **Pembangunan modular:** Command Core di satu area, hanggar di platform lain,
  turret di titik pertahanan, bangunan riset di slot konstruksi. Modul baru
  muncul saat level benteng meningkat.
- **Progresi harus terlihat:** contoh dari `Game_Concept.md` §7 — Hanggar L1:
  2 pesawat kecil; L5: 6 pesawat + jalur peluncuran tambahan; L10: fasilitas
  bertingkat dengan beberapa skuadron. Peningkatan = bukti visual, bukan angka.
- **Kerusakan terlihat:** 4 kondisi (Normal / Damaged / Critical / Destroyed)
  dengan material + VFX (asap, api, percikan, puing) — lihat
  `MASTER_ASSET_INVENTORY.md` Kelompok P.
- Hanggar terbuka memperlihatkan pesawat keluar-masuk; kapal induk bisa
  mengorbit di atas pangkalan; perisai energi muncul saat diserang.

## 4. Armada (siluet harus terbaca jelas)

- Setiap kelas kapal punya siluet yang berbeda dan terbaca dari kejauhan:
  interceptor kecil/cepat, pembom berat, kapal pendukung, kapal perang besar.
- **Kontrak teknis:** bagian depan kapal menunjuk **-Z di Godot** (lihat
  `ASSET_PIPELINE.md` §sumbu). Titik attachment mesin (engine) dan senjata
  (weapon) wajib ada dan dinamai konsisten.
- Kapal besar (Battleship ke atas) butuh LOD; detail yang tidak terlihat dari
  kamera gameplay tidak diprioritaskan.

## 5. Lingkungan Luar Angkasa

- Satu set lingkungan asteroid yang solid, divariasikan dengan: bentuk,
  ukuran, material, posisi planet di latar, kepadatan debris, pencahayaan,
  warna nebula, dan objek fasilitas yang mengorbit.
- Latar: starfield (shader), nebula (2D/3D), planet background (3D, low-detail).
- Asteroid adalah landmark sekaligus sumber daya (`MAT-012` Asteroid Rock,
  `MAT-013` Mineral Surface).

## 6. Pencahayaan

- Ruang angkasa: 1 key light (arah matahari/star) + emissive dari inti energi
  kapal/reaktor + rim light tipis untuk memisahkan objek dari latar gelap.
- Ledakan = cahaya singkat yang benar-benar menerangi sekitarnya (real-time
  light dengan radius kecil, dibatasi jumlahnya untuk performa).
- Hindari pencahayaan datar: objek di ruang angkasa tanpa kontras akan
  terlihat seperti stiker.

## 7. VFX

- Laser: mesh sederhana + material emissive. Misil: model + trail partikel/
  ribbon. Ledakan: kombinasi partikel + cahaya singkat + sedikit mesh.
- Shield: efek transparan pada permukaan kubah (`MAT-009` Shield Material,
  `MAT-020` Shield Hit Distortion).
- **Setiap efek punya batas durasi + lifecycle yang jelas** (pooling, batas
  partikel, quality setting untuk mobile) — lihat `Asset_Request_List.md` §8.

## 8. UI / HUD

- Tema **military command system**: panel taktis, garis tipis, ikon teknologi,
  indikator ancaman, animasi holografis secukupnya (`MAT-016` Hologram).
- Informasi harus terbaca jelas tanpa mengganggu gameplay; HUD tidak menutupi
  benteng/armada.
- Sebagian besar UI dibangun dari komponen Godot (panel, tombol, StyleBox,
  font) — bukan gambar unik per elemen.

## 9. Sistem Ikon

- Satu icon design system: ukuran grid konsisten, ketebalan garis, siluet,
  palet warna, aturan penggunaan.
- Ikon sumber daya harus terbaca di layar ponsel (kontras tinggi, bentuk
  sederhana).
- Jangan membuat ikon dengan gaya berbeda-beda hanya karena dibuat oleh
  generator/kreator berbeda.

## 10. Gaya Keseluruhan

- **Stylized-realistic** (rekomendasi default, menunggu keputusan final di
  `MASTER_ASSET_INVENTORY.md` §Keputusan): bentuk dan proporsi bisa estil,
  material dan pencahayaan meyakinkan.
- Konsistensi antar aset lebih penting daripada kecanggihan satu aset:
  material dari sumber berbeda tidak boleh terlihat seperti dari game berbeda.

## 11. Keputusan Visual yang Masih Terbuka

Lihat `MASTER_ASSET_INVENTORY.md` §"Keputusan yang Belum Ditetapkan" — kamera
(isometrik/top-down, rotasi), arena combat terpisah vs satu dunia, ukuran
armada di layar, benteng modular vs satu model, gaya realistis vs stylized.
**Jangan produksi aset sebelum keputusan ini diambil.**
