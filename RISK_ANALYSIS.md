# RISK ANALYSIS — Last-Space (Analisis Risiko Proyek)

> **Sumber:** catatan dari human developer, 2026-10-10. Disimpan ke repo agar
> tidak hilang dan menjadi dasar pengambilan keputusan. Format dirapikan;
> isi disampaikan apa adanya.
>
> Dokumen ini menjadi dasar untuk: `QA_PLAN.md` (verification gates & QA),
> fase di `ROADMAP.md`, kontrak data di `DATA_CONTRACTS.md`, dan arsitektur di
> `TECH_ARCHITECTURE.md`.
>
> **Catatan:** ini adalah analisis risiko proyek, bukan hasil pengukuran dari
> prototipe kita. Belum ada data yang cukup untuk menghitung probabilitas
> setiap masalah.

Saya memisahkan tiga hal:

- **FAKTA:** karakteristik teknis atau konsekuensi yang dapat dijelaskan
  secara konkret.
- **RISIKO TINGGI:** masalah yang sangat mungkin muncul berdasarkan cakupan
  proyek.
- **BELUM DIKETAHUI:** hal yang baru bisa dipastikan setelah implementasi dan
  pengujian.

---

## 1. Peta bottleneck utama

Skor tersebut adalah prioritas kerja yang saya usulkan, bukan persentase
kemungkinan kegagalan.

Menurut saya, ada tiga risiko yang harus kita kendalikan sejak awal:
**kompleksitas integrasi**, **kualitas core gameplay**, dan **keandalan proses
development berbantuan AI**.

Mari kita uraikan satu per satu.

---

## 2. Bottleneck #1 — Integrasi sistem

**Prioritas: Sangat tinggi**

Ini salah satu risiko terbesar untuk proyek yang dibangun dengan bantuan AI.

Game kita bukan sekadar kumpulan bangunan dan pesawat. Sistem-sistemnya harus
saling memengaruhi.

Misalnya, pemain:

1. Membangun Energy Reactor.
2. Reactor menghasilkan energi.
3. Energi digunakan untuk mengoperasikan fasilitas.
4. Fasilitas memproduksi material.
5. Material digunakan untuk membangun kapal.
6. Kapal membentuk armada.
7. Armada menyerang wilayah alien.
8. Pertempuran menghasilkan sumber daya.
9. Sumber daya digunakan untuk meningkatkan benteng.

Setiap tahap bergantung pada tahap sebelumnya.

**Apa yang bisa salah?**

Kita berhasil membuat semua fitur secara terpisah, tetapi ketika digabungkan:

- Bangunan tidak memperbarui produksi dengan benar.
- Upgrade tidak memengaruhi statistik yang seharusnya.
- Kapal tidak menggunakan data armada yang benar.
- Hasil pertempuran tidak konsisten dengan kerusakan yang divisualisasikan.
- Save dan load menghasilkan keadaan permainan yang berbeda.
- UI menampilkan jumlah sumber daya yang tidak sesuai dengan sistem ekonomi.

Masing-masing fitur mungkin tampak selesai, tetapi keseluruhan permainan tidak
bekerja secara konsisten.

**Mengapa AI dapat memperbesar masalah ini?**

AI dapat menghasilkan kode untuk berbagai subsistem dengan cepat. Namun,
kecepatan menghasilkan kode tidak menjamin konsistensi antarsubsistem.

Jika setiap tugas dikerjakan dengan asumsi berbeda, kita berpotensi memperoleh
banyak implementasi yang secara lokal terlihat benar, tetapi tidak kompatibel.

**Strategi pencegahan**

Sebelum memperbanyak fitur, kita perlu menetapkan kontrak data untuk sistem
inti.

Contohnya:

| Sistem | Data yang menjadi sumber kebenaran |
|---|---|
| Ekonomi | Saldo sumber daya dan transaksi |
| Bangunan | Level, biaya, status, dan efek |
| Produksi | Input, output, kapasitas, dan waktu |
| Armada | Daftar unit, jumlah, statistik, dan kondisi |
| Pertempuran | Input pertempuran dan hasil simulasi |
| Progresi | Syarat unlock dan progres pemain |
| Save/load | Seluruh keadaan permainan yang harus dipertahankan |

Setiap sistem harus menggunakan sumber data yang konsisten.

Targetnya bukan membuat seluruh sistem sekaligus, melainkan membuktikan satu
rantai gameplay lengkap sebelum memperluasnya.

---

## 3. Bottleneck #2 — Core gameplay ternyata tidak cukup menarik

**Prioritas: Sangat tinggi**

Ini berbeda dari masalah teknis.

Game dapat berjalan tanpa bug yang berarti, tetapi pemain tetap tidak ingin
memainkannya.

Kita perlu menguji apakah aktivitas utama memberikan pengalaman yang menarik,
bukan hanya apakah tombolnya berfungsi.

**Risiko spesifik game kita**

Bayangkan pemain melakukan aktivitas berikut:

- Menekan tombol upgrade.
- Menunggu produksi selesai.
- Membuat kapal.
- Menekan tombol serang.
- Menonton pertempuran otomatis.
- Mengumpulkan hadiah.
- Mengulangi proses yang sama.

Semua fungsi tersebut bisa bekerja sempurna, tetapi permainan berpotensi
terasa repetitif.

Game strategi membutuhkan keputusan yang bermakna. Contohnya:

- Apakah pemain memprioritaskan produksi energi atau pembangunan armada?
- Apakah mereka menyerang wilayah yang lebih lemah untuk mendapatkan sumber
  daya atau mengambil risiko melawan alien yang lebih kuat?
- Apakah mereka membangun pertahanan atau mengalokasikan sumber daya untuk
  ekspansi?
- Apakah komposisi armada tertentu efektif melawan jenis musuh tertentu?

Pilihan tersebut harus menghasilkan konsekuensi yang dapat dipahami pemain.

**Cara mengatasinya**

Kita perlu membangun satu vertical slice yang mewakili pengalaman utama game.

Vertical slice ini setidaknya mencakup:

1. Satu benteng yang dapat dikembangkan.
2. Dua atau tiga fasilitas ekonomi.
3. Beberapa tipe kapal dengan fungsi berbeda.
4. Satu wilayah eksplorasi.
5. Satu pertempuran yang dapat diselesaikan.
6. Hadiah yang dapat digunakan untuk memperkuat benteng atau armada.
7. Musuh yang semakin menantang setelah pemain berkembang.

Tujuannya adalah membuktikan bahwa siklus permainan tersebut menarik sebelum
kita membuat puluhan fasilitas dan kapal.

Kita tidak harus langsung melakukan pengujian pasar. Pengujian internal dan
observasi terhadap pemain awal dapat dilakukan selama pengembangan.

Bottleneck ini tidak bisa diselesaikan hanya dengan menambah fitur atau
memperbagus grafis.

---

## 4. Bottleneck #3 — AI menghasilkan banyak kode, tetapi progres nyata lambat

**Prioritas: Sangat tinggi**

Ini penting karena kita mengandalkan AI dalam proses development.

Ada perbedaan antara:

1. Kode berhasil dibuat.
2. Kode berhasil dijalankan.
3. Fitur bekerja sesuai spesifikasi.
4. Fitur terintegrasi dengan sistem lain.
5. Fitur tetap bekerja setelah perubahan berikutnya.

Kelima kondisi itu tidak setara.

**Contoh kasus**

Kita meminta AI membuat sistem pertempuran antarkapal.

AI kemudian:

- Membuat model kapal.
- Membuat sistem target.
- Menambahkan efek laser.
- Membuat animasi ledakan.
- Membuat UI hasil pertempuran.

Dari tampilan visual, fitur tersebut mungkin terlihat selesai.

Namun, kita belum tahu:

- Apakah statistik kapal benar-benar menentukan hasil?
- Apakah sistem target bekerja konsisten?
- Apakah pertempuran dapat diselesaikan dalam berbagai kondisi?
- Apakah kapal yang kalah benar-benar kehilangan HP?
- Apakah hasil pertempuran memengaruhi sumber daya pemain?
- Apakah simulasi tetap benar ketika jumlah kapal meningkat?

Jika hal-hal tersebut belum diuji, kita baru memiliki implementasi visual dan
sebagian logika, bukan sistem pertempuran yang sudah tervalidasi.

**Strategi yang saya rekomendasikan**

Gunakan gerbang verifikasi untuk setiap milestone.

| Status | Arti |
|---|---|
| NOT STARTED | Belum dikerjakan |
| IMPLEMENTED | Kode atau aset telah dibuat |
| RUNNABLE | Berhasil dijalankan |
| VERIFIED | Lulus pengujian yang ditentukan |
| INTEGRATED | Berhasil bekerja dengan sistem terkait |
| REGRESSION PASS | Perubahan tidak merusak fungsi yang sudah ada |

AI tidak boleh menyatakan milestone selesai hanya karena kode berhasil ditulis.

Kita juga perlu menyimpan bukti berupa hasil pengujian, log, dan rekaman visual
ketika relevan.

Ini akan membantu mencegah pola yang sering merugikan proyek berbantuan AI:
banyak perubahan, banyak dokumentasi, banyak aktivitas, tetapi fitur inti
tidak benar-benar bertambah matang.

---

## 5. Bottleneck #4 — Aset 3D dari Tripo tidak langsung siap dipakai

**Prioritas: Tinggi**

Kita sebelumnya membahas sekitar 82–117 model 3D unik sebagai estimasi awal
untuk kebutuhan aset.

Angka itu belum tentu menjadi jumlah final. Kebutuhan aktual baru dapat
diketahui setelah pipeline dan desain visual ditetapkan.

Masalahnya, satu model yang dihasilkan AI belum tentu siap masuk ke game.

**Masalah yang berpotensi muncul**

**A. Konsistensi desain**

Kapal pertama mungkin memiliki gaya visual tertentu, sedangkan kapal
berikutnya terlihat berasal dari game yang berbeda.

Akibatnya, keseluruhan armada tidak memiliki identitas visual yang kuat.

**B. Topologi dan geometri**

Model dapat memiliki:

- Geometri yang tidak efisien.
- Permukaan yang rusak atau tidak rapi.
- Detail berlebihan yang tidak terlihat dari kamera permainan.
- Bentuk yang sulit diperbaiki atau dianimasikan.

**C. Material dan tekstur**

Model mungkin memiliki tekstur yang bagus saat ditampilkan sendiri, tetapi
tidak konsisten dengan pencahayaan dan material aset lainnya.

**D. Rigging dan animasi**

Model statis tidak otomatis siap digunakan sebagai kapal yang memiliki bagian
bergerak, senjata berputar, mesin, atau animasi kerusakan.

**E. Optimasi**

Model dengan detail tinggi dapat menambah beban rendering, terutama jika
banyak kapal, proyektil, efek ledakan, dan objek lingkungan tampil bersamaan.

**Strategi yang tepat**

Jangan langsung menghasilkan 100 model.

Mulailah dengan satu set aset representatif:

- Satu Command Core.
- Satu bangunan produksi.
- Satu turret.
- Satu kapal pemain.
- Satu kapal alien.
- Satu asteroid.

Uji keenam aset tersebut di dalam Godot.

Validasi:

1. Skala dan proporsi.
2. Material.
3. Performa rendering.
4. Konsistensi gaya visual.
5. Kemudahan integrasi.
6. Ukuran file.
7. Kebutuhan perbaikan manual.

Setelah pipeline ini berhasil, kita dapat memperkirakan biaya token dan waktu
pengerjaan berdasarkan hasil nyata, bukan sekadar harga generasi model.

---

## 6. Bottleneck #5 — Performa pada perangkat mobile

**Prioritas: Tinggi**

Ini merupakan risiko teknis yang harus diukur langsung.

Kita merencanakan benteng, bangunan, kapal, efek senjata, ledakan, dan
pertempuran dalam ruang 3D.

Jumlah objek bukan satu-satunya faktor. Beban GPU, material, transparansi,
jumlah draw call, kompleksitas shader, animasi, dan resolusi juga memengaruhi
performa.

**Skenario yang perlu kita antisipasi**

Misalnya, satu pertempuran menampilkan:

- Puluhan kapal.
- Banyak proyektil.
- Beberapa ledakan.
- Efek perisai.
- Laser dan efek energi.
- Partikel serta objek puing.

Adegan tersebut bisa berjalan dengan baik di PC pengembangan, tetapi mengalami
penurunan frame rate pada ponsel.

Kita tidak boleh menyimpulkan performanya hanya berdasarkan preview di
desktop.

**Solusi arsitektural**

1. **Pisahkan simulasi pertempuran dari visualisasi.**

   Logika pertempuran menentukan:

   - Target.
   - Kerusakan.
   - HP.
   - Cooldown.
   - Efek kemampuan.
   - Kondisi kemenangan.

   Lapisan visual menampilkan hasilnya melalui gerakan kapal, laser, ledakan,
   dan animasi.

   Dengan pemisahan ini, kita dapat menguji simulasi tanpa harus merender
   semua efek 3D.

2. **Gunakan object pooling.**

   Proyektil dan efek yang sering muncul dapat digunakan kembali daripada terus
   dibuat dan dihancurkan.

3. **Gunakan instancing untuk objek berulang.**

   Asteroid, objek dekoratif, dan elemen tertentu dapat menggunakan teknik
   instancing jika sesuai dengan karakteristik objeknya.

4. **Tetapkan batas kualitas grafis.**

   Kita perlu memiliki target perangkat, batas jumlah objek aktif, dan profil
   grafis yang jelas.

5. **Ukur performa pada perangkat target.**

   Catat frame time, penggunaan memori, dan waktu pemuatan. FPS rata-rata saja
   tidak selalu cukup untuk mengungkap stutter.

Target angka performa baru sebaiknya ditentukan setelah kelas perangkat dan
kompleksitas adegan disepakati.

---

## 7. Bottleneck #6 — Ekonomi dan progresi tidak seimbang

**Prioritas: Tinggi**

Game strategi dengan sistem pembangunan membutuhkan ekonomi yang konsisten.

Jika progresi terlalu cepat, pemain kehabisan tujuan.

Jika progresi terlalu lambat, pemain dapat merasa bahwa permainan sengaja
memperlambat mereka untuk mendorong pembelian.

Kita perlu menyeimbangkan keduanya.

**Contoh masalah**

Pemain membutuhkan mineral untuk membangun kapal.

Namun:

- Produksi mineral terlalu lambat.
- Upgrade fasilitas terlalu mahal.
- Kapal membutuhkan terlalu banyak mineral.
- Hadiah pertempuran terlalu kecil.

Akibatnya, pemain harus menunggu terlalu lama sebelum bisa kembali melakukan
aktivitas yang menarik.

Masalah sebaliknya juga mungkin terjadi. Jika hadiah terlalu besar, pemain bisa
menyelesaikan progresi terlalu cepat dan kehilangan alasan untuk melanjutkan
permainan.

**Solusi**

Buat ekonomi berbasis data, bukan angka yang tersebar di banyak skrip.

Contohnya:

| Parameter | Fungsi |
|---|---|
| Produksi per menit | Menentukan kecepatan perolehan sumber daya |
| Biaya upgrade | Menentukan investasi pemain |
| Waktu konstruksi | Menentukan tempo pembangunan |
| Biaya kapal | Menentukan investasi militer |
| Hadiah pertempuran | Menghubungkan pertempuran dengan progresi |
| Biaya riset | Mengatur pengembangan jangka panjang |

Semua parameter sebaiknya dapat diubah tanpa harus menulis ulang logika utama.

Kita juga perlu membuat simulasi ekonomi agar dapat mengetahui apakah pemain
berkembang terlalu cepat atau terlalu lambat.

---

## 8. Bottleneck #7 — Konten yang diperlukan ternyata jauh lebih banyak

**Prioritas: Tinggi**

Sistem dasar mungkin hanya membutuhkan beberapa bangunan dan kapal.

Namun, game yang terasa lengkap memerlukan variasi konten.

Contohnya:

- Banyak tipe kapal.
- Variasi senjata.
- Musuh dengan perilaku berbeda.
- Bangunan dengan fungsi berbeda.
- Teknologi dan jalur riset.
- Sektor galaksi.
- Misi.
- Boss.
- Hadiah.
- Upgrade.
- Tahapan progresi.

Masalahnya, jumlah konten bertambah jauh lebih cepat daripada jumlah sistem
dasarnya.

Misalnya, kita sudah memiliki sistem pertempuran yang berfungsi. Untuk membuat
permainan lebih menarik, kita kemudian membutuhkan tipe musuh baru, senjata
baru, kemampuan baru, dan mekanisme boss baru.

Jika setiap variasi harus dibuat dari awal, biaya produksi akan membengkak.

**Strategi**

Gunakan sistem yang dapat menghasilkan variasi dari komponen bersama.

Contohnya, beberapa kapal dapat menggunakan sistem dasar yang sama dengan
perbedaan pada:

- HP.
- Kecepatan.
- Jarak serang.
- Jenis senjata.
- Peran dalam formasi.
- Kemampuan khusus.

Namun, jangan menganggap perubahan statistik saja selalu cukup untuk
menciptakan variasi gameplay. Sebagian unit harus memiliki peran dan perilaku
yang benar-benar berbeda.

Tujuannya adalah memperbesar variasi permainan tanpa memperbesar kompleksitas
kode secara tidak terkendali.

---

## 9. Bottleneck #8 — Multiplayer dan backend

**Prioritas: Bergantung pada desain final**

Saya belum menganggap multiplayer sebagai kebutuhan wajib karena kita belum
memastikan seluruh spesifikasi online game ini.

Namun, jika kita ingin menghadirkan fitur seperti:

- Aliansi.
- PvP.
- Perebutan wilayah antarpemain.
- Peringkat global.
- Event bersama.
- Pertempuran armada secara kompetitif.

Maka backend akan menjadi salah satu risiko terbesar.

**Mengapa?**

Game yang berjalan sepenuhnya secara lokal dapat menyimpan keadaan permainan di
perangkat.

Sebaliknya, game online kompetitif membutuhkan aturan mengenai:

- Sumber data yang tepercaya.
- Validasi aksi pemain.
- Sinkronisasi keadaan permainan.
- Penyimpanan progres.
- Pencegahan manipulasi.
- Penanganan koneksi terputus.
- Konsistensi hasil pertempuran.

Jika pemain dapat mengubah saldo sumber daya atau hasil pertempuran melalui
modifikasi lokal, ekonomi dan kompetisi dapat dirusak.

**Keputusan penting**

Kita harus menetapkan sejak awal apakah game ini:

**A. Single-player atau offline-first**

Lebih sederhana untuk membangun prototipe, menguji gameplay, dan memvalidasi
progresi.

**B. Online dengan progresi pemain di server**

Membutuhkan backend, autentikasi, penyimpanan data, dan validasi server.

**C. Multiplayer kompetitif**

Membutuhkan arsitektur tambahan untuk sinkronisasi, keamanan, dan integritas
hasil pertandingan.

Pilihan C memiliki kompleksitas yang jauh lebih tinggi daripada sekadar
menambahkan fitur login.

Kita tidak perlu membangun seluruh infrastruktur multiplayer sebelum terbukti
bahwa gameplay intinya layak dikembangkan.

---

## 10. Urutan penanganan yang saya rekomendasikan

Berikut urutan kerja yang menurut saya paling masuk akal.

| Tahap | Fokus | Kriteria kelulusan |
|---|---|---|
| 1 | Fondasi proyek Godot | Proyek berjalan pada perangkat target awal |
| 2 | Ekonomi dan pembangunan | Bangunan, produksi, biaya, dan upgrade bekerja konsisten |
| 3 | Armada dan pertempuran | Statistik unit menentukan hasil pertempuran secara benar |
| 4 | Integrasi progresi | Hadiah pertempuran dapat digunakan untuk mengembangkan basis |
| 5 | Save/load | Progres tidak hilang atau berubah secara tidak sengaja |
| 6 | Pipeline aset | Aset Tripo dapat diimpor dan digunakan dengan konsisten |
| 7 | Performa mobile | Adegan representatif memenuhi target performa |
| 8 | Variasi konten | Unit, musuh, teknologi, dan misi memperluas gameplay |
| 9 | Balancing | Tempo ekonomi dan progresi telah diuji |
| 10 | Validasi pemain | Terdapat bukti bahwa pemain memahami dan ingin melanjutkan permainan |

Urutan ini bukan berarti seluruh pekerjaan harus berlangsung secara linear.
Beberapa bagian dapat dikerjakan paralel setelah antarmuka sistemnya jelas.

Yang penting adalah tidak memperluas produksi sebelum fondasi yang menjadi
dependensi fitur berikutnya terbukti bekerja.

---

## 11. Bottleneck yang paling berbahaya bagi proyek kita

Jika harus memilih tiga, saya akan memilih:

1. **Sistem terlihat selesai, tetapi tidak benar-benar terintegrasi**

   Ini dapat menghasilkan prototipe yang tampak mengesankan, tetapi banyak
   mekanismenya tidak memiliki konsekuensi gameplay yang nyata.

   Pencegahan: verifikasi rantai gameplay lengkap, bukan hanya fitur
   individual.

2. **Terlalu banyak aset diproduksi sebelum pipeline terbukti**

   Kita berpotensi menghabiskan token untuk model yang akhirnya harus dibuat
   ulang karena gaya visual, skala, atau kualitas teknisnya tidak sesuai.

   Pencegahan: validasi sampel kecil sebelum produksi massal.

3. **Terlalu banyak fitur tanpa bukti bahwa core gameplay menarik**

   Ini yang paling berbahaya dari sudut pandang bisnis.

   Kita dapat menghabiskan waktu membuat puluhan bangunan, ratusan ikon, dan
   banyak kapal tanpa mengetahui apakah pemain menyukai siklus permainan
   utamanya.

   Pencegahan: bangun dan validasi satu siklus permainan yang lengkap sebelum
   memperluas konten.

---

## Kesimpulan

Menurut saya, masalah terbesar kita kemungkinan bukan kemampuan AI untuk membuat
kode atau menghasilkan model 3D. Masalah yang lebih penting adalah mengendalikan
kompleksitas agar semua bagian menjadi satu game yang koheren, stabil, menarik,
dan cukup efisien untuk perangkat mobile.

Karena itu, saya menyarankan kita menetapkan tiga batas sebelum memasuki
produksi besar:

1. **Batas teknis:** setiap sistem inti harus memiliki kriteria kelulusan yang
   dapat diuji.
2. **Batas produksi:** jangan memperbanyak aset sebelum pipeline model 3D
   terbukti layak.
3. **Batas gameplay:** jangan menganggap banyaknya fitur sebagai bukti bahwa
   permainan sudah menarik.
