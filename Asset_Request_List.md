Kalau daftar ini tidak dibuat sejak awal, ada risiko kita menghasilkan banyak aset yang terlihat bagus tetapi tidak mendukung gameplay, atau justru baru menyadari bahwa kita belum mempunyai aset penting ketika development sudah berjalan.

1. Visual Direction: Seperti Apa Game yang Kita Bangun?

Sebelum menyusun inventaris, kita perlu menetapkan satu prinsip visual.

Game ini menggabungkan tiga lapisan visual yang berbeda:

1. Base-Building Strategy: Pemain membangun benteng luar angkasa, mengelola produksi, melakukan riset, dan memperkuat pertahanan.


2. Fleet & Territory Management: Pemain memproduksi pesawat, mengatur armada, menyerang wilayah, dan menjelajahi sektor galaksi.


3. Cinematic Space Combat: Pesawat bergerak, laser ditembakkan, rudal mengejar target, kapal induk alien muncul, dan benteng mengalami kerusakan.



Artinya, tidak semua objek perlu dibuat dengan tingkat detail yang sama.

Kita membutuhkan kombinasi aset 3D, ilustrasi 2D, ikon, animasi, material, dan efek visual.

Pembagian visual yang direkomendasikan

Area	Pendekatan visual	Alasan

Benteng utama	Full 3D	Bangunan harus terlihat berkembang dan bisa mengalami kerusakan.
Bangunan produksi	Full 3D	Pemain harus dapat membedakan fungsi dan level bangunan.
Pesawat pemain	Full 3D	Pesawat harus bisa bergerak, bermanuver, menembak, dan dihancurkan.
Kapal perang besar	Full 3D	Dibutuhkan untuk pertarungan berskala besar dan boss battle.
Kapal alien	Full 3D	Menjadi ancaman yang dapat dikenali secara visual.
Asteroid dan planet	Full 3D	Dibutuhkan untuk eksplorasi, penguasaan wilayah, dan latar pertempuran.
Laser, ledakan, perisai	Efek 3D/VFX	Harus mengikuti posisi objek dan arah serangan.
Peta galaksi	2D atau 3D sederhana	Tidak membutuhkan detail seperti arena pertempuran.
Ikon sumber daya	2D statis	Harus mudah dibaca pada layar ponsel.
Ikon teknologi	2D statis	Lebih efisien daripada membuat objek 3D untuk setiap teknologi.
Potret komandan	2D statis	Cocok untuk UI, profil, dialog, dan misi.
Tombol, panel, HUD	2D/UI	Informasi harus terbaca jelas tanpa mengganggu gameplay.
Background menu	3D atau gambar 2D	Bisa menggunakan render benteng atau armada untuk menghemat produksi aset khusus.


Catatan penting: Full 3D bukan berarti semua objek harus memiliki model terpisah dengan ribuan polygon. Aset 3D bisa menggunakan model sederhana, LOD, material bersama, dan sistem instancing. Kualitas visual ditentukan oleh desain, pencahayaan, komposisi, material, serta animasi, bukan jumlah polygon semata.


---

2. Master Asset Inventory

Saya membagi kebutuhan menjadi 15 kelompok.

Untuk setiap aset, kita perlu mencatat:

ID: Identitas aset yang konsisten.

Nama: Aset yang harus dibuat.

Format visual: 3D, 2D statis, UI, atau VFX.

Fungsi: Kegunaan dalam gameplay.

Prioritas: Urutan kebutuhan produksi.

Varian: Versi atau kondisi aset yang diperlukan.


Arti prioritas

P0 — Vertical Slice: Harus tersedia agar prototype utama bisa dimainkan.

P1 — Core Game: Dibutuhkan untuk melengkapi sistem gameplay inti.

P2 — Expansion: Dibutuhkan untuk memperluas konten setelah core game berfungsi.

P3 — Polish: Untuk meningkatkan kualitas presentasi, variasi, dan cinematic.


Prioritas tersebut bukan klaim tentang jumlah aset final. Jumlah akhirnya bergantung pada desain sistem, jumlah unit, dan cara implementasi.


---

3. Kelompok A — Player Space Fortress

Benteng adalah pusat seluruh gameplay. Pemain membangun fasilitas, menghasilkan sumber daya, memproduksi armada, dan mempertahankan wilayah dari serangan alien.

Karena itu, benteng membutuhkan aset yang lebih lengkap daripada sekadar satu model stasiun luar angkasa.

ID	Aset	Format	Varian atau kebutuhan	Prioritas

FRT-001	Benteng utama	3D	Model inti benteng	P0
FRT-002	Command Core	3D	Level dasar dan level upgrade	P0
FRT-003	Struktur platform	3D modular	Platform kecil, sedang, besar	P0
FRT-004	Modul konektor	3D modular	Penghubung antarbangunan	P1
FRT-005	Docking port	3D	Tempat kapal berlabuh	P0
FRT-006	Landing pad	3D	Area pendaratan pesawat	P1
FRT-007	Koridor penghubung	3D	Modular	P1
FRT-008	Menara komunikasi	3D	Model dasar dan upgrade	P1
FRT-009	Antena radar	3D	Model yang dapat beranimasi	P0
FRT-010	Kubah pelindung	3D/VFX	Model dasar dan efek perisai aktif	P0
FRT-011	Menara observasi	3D	Dekoratif dan fungsional	P2
FRT-012	Lampu navigasi	3D + material	Beberapa konfigurasi	P1
FRT-013	Pipa energi	3D modular	Segmen lurus dan belokan	P1
FRT-014	Kabel dan conduit	3D modular	Beberapa ukuran	P2
FRT-015	Panel luar benteng	3D modular	Panel utuh dan rusak	P1
FRT-016	Mesin pendorong benteng	3D	Efek mesin menyala	P2
FRT-017	Dek observasi	3D	Modul tambahan	P2
FRT-018	Puing benteng	3D	Pecahan kecil dan besar	P1
FRT-019	Model benteng rusak	3D atau sistem material	Kerusakan ringan, sedang, berat	P1
FRT-020	Model benteng hancur	3D	Kondisi kritis atau kehancuran	P2


Keputusan desain yang penting

Jangan membuat seluruh benteng sebagai satu model statis jika pemain akan membangun dan meningkatkan fasilitas secara individual.

Sebaliknya, benteng sebaiknya menggunakan modular construction system.

Sebagai contoh:

Command Core menempati satu area.

Hangar berada pada platform lain.

Turret ditempatkan pada titik pertahanan.

Bangunan riset ditempatkan pada slot konstruksi.

Modul baru muncul ketika level benteng meningkat.


Dengan sistem modular, kita bisa menggunakan kembali komponen yang sama untuk berbagai konfigurasi benteng.

Namun, model benteng untuk cinematic juga boleh dibuat sebagai satu aset teroptimasi jika dibutuhkan. Model modular gameplay dan model cinematic tidak harus identik secara teknis, selama tampilan dan identitasnya konsisten.


---

4. Kelompok B — Bangunan Ekonomi dan Produksi

Bangunan ini membentuk progression loop: menghasilkan sumber daya, mengubahnya menjadi armada, lalu menggunakan armada untuk memperluas wilayah.

ID	Aset	Format	Fungsi	Prioritas

ECO-001	Energy Reactor	3D	Menghasilkan energi	P0
ECO-002	Reactor Upgrade	3D atau varian modular	Menampilkan perkembangan level	P1
ECO-003	Solar Array	3D	Sumber energi tambahan	P1
ECO-004	Mineral Extractor	3D	Menghasilkan mineral	P0
ECO-005	Mining Drill	3D	Ekstraksi mineral asteroid	P1
ECO-006	Mining Platform	3D	Infrastruktur pertambangan	P1
ECO-007	Mineral Storage	3D	Penyimpanan mineral	P1
ECO-008	Energy Storage	3D	Penyimpanan energi	P1
ECO-009	Shipyard	3D	Produksi kapal perang	P0
ECO-010	Fighter Hangar	3D	Produksi pesawat tempur	P0
ECO-011	Capital Ship Dock	3D	Produksi kapal besar	P2
ECO-012	Drone Factory	3D	Produksi drone	P1
ECO-013	Repair Bay	3D	Perbaikan armada	P1
ECO-014	Research Laboratory	3D	Riset teknologi	P0
ECO-015	Logistics Center	3D	Peningkatan kapasitas logistik	P1
ECO-016	Cargo Terminal	3D	Transfer barang dan sumber daya	P1
ECO-017	Refinery	3D	Pemrosesan bahan mentah	P1
ECO-018	Trade Hub	3D	Perdagangan antarsektor	P2
ECO-019	Resource Conveyor	3D modular	Visualisasi alur produksi	P2
ECO-020	Industrial Smoke/Vent	3D + VFX	Menampilkan aktivitas industri	P2


Sistem level bangunan

Kita tidak perlu membuat model unik untuk setiap level setiap bangunan.

Sebagai contoh, Energy Reactor dapat memiliki:

Level 1: reaktor kecil dengan satu inti energi.

Level 2: inti lebih besar dan tambahan panel.

Level 3: dua modul energi tambahan.

Level 4: struktur yang lebih kompleks dengan emisi energi lebih kuat.


Secara teknis, ini bisa dibuat melalui kombinasi:

1. Satu model dasar.


2. Modul tambahan yang muncul pada level tertentu.


3. Material dan emissive lighting berbeda.


4. Animasi atau VFX tambahan.



Pendekatan ini mengurangi kebutuhan model unik sekaligus tetap memberikan kesan bahwa fasilitas berkembang.

Target awal: Untuk setiap bangunan P0, siapkan setidaknya satu model yang dapat dimainkan. Varian upgrade dapat ditambahkan secara modular setelah sistem pembangunan bekerja.


---

5. Kelompok C — Bangunan Pertahanan

Bangunan pertahanan harus mempunyai fungsi visual yang jelas. Pemain perlu bisa melihat bahwa benteng yang sudah diperkuat memiliki pertahanan yang lebih baik daripada benteng yang belum dikembangkan.

ID	Aset	Format	Fungsi	Prioritas

DEF-001	Basic Laser Turret	3D	Pertahanan awal	P0
DEF-002	Heavy Cannon Turret	3D	Kerusakan besar pada target berat	P1
DEF-003	Missile Launcher	3D	Serangan rudal	P0
DEF-004	Point Defense Turret	3D	Menghadapi pesawat atau rudal kecil	P1
DEF-005	Plasma Cannon	3D	Senjata energi berat	P2
DEF-006	Railgun Turret	3D	Senjata kinetik jarak jauh	P2
DEF-007	Anti-Capital Ship Cannon	3D	Senjata untuk kapal besar	P2
DEF-008	Shield Generator	3D	Menghasilkan perisai	P0
DEF-009	Shield Emitter	3D	Komponen tambahan perisai	P1
DEF-010	Mine Launcher	3D	Pertahanan area	P2
DEF-011	Defensive Drone Dock	3D	Tempat peluncuran drone	P1
DEF-012	Defense Control Tower	3D	Koordinasi pertahanan	P1
DEF-013	Turret Upgrade Modules	3D modular	Memperlihatkan peningkatan level	P1
DEF-014	Turret Destroyed State	3D atau material	Menampilkan turret hancur	P1


Animasi yang diperlukan

Model turret saja belum cukup.

Setiap turret yang aktif membutuhkan beberapa perilaku:

Idle atau standby.

Memindai target.

Mengunci target.

Mengarahkan laras.

Menembak.

Cooldown.

Menerima serangan.

Rusak.

Hancur.


Tidak semua perilaku memerlukan animasi skeletal. Gerakan turret bisa menggunakan rotasi node, sedangkan efek tembakan dan kehancuran menggunakan VFX.


---

6. Kelompok D — Armada Pemain

Ini adalah salah satu kelompok aset terpenting.

Kita memerlukan pesawat yang mudah dikenali, memiliki siluet berbeda, dan mempunyai fungsi yang dapat dipahami pemain tanpa membaca terlalu banyak informasi.

D1. Pesawat tempur kecil

ID	Aset	Format	Fungsi	Prioritas

SHP-001	Basic Interceptor	3D	Pesawat tempur awal	P0
SHP-002	Advanced Interceptor	3D	Pesawat cepat dan lincah	P1
SHP-003	Heavy Fighter	3D	Pesawat tempur dengan daya tahan tinggi	P1
SHP-004	Bomber	3D	Menyerang struktur dan kapal besar	P1
SHP-005	Missile Fighter	3D	Serangan berbasis rudal	P1
SHP-006	Recon Drone	3D	Pengintaian	P1
SHP-007	Combat Drone	3D	Pendukung armada	P1
SHP-008	Interceptor Destroyed	3D atau sistem fragmentasi	Kehancuran pesawat	P1


D2. Kapal perang menengah

ID	Aset	Format	Fungsi	Prioritas

SHP-009	Corvette	3D	Kapal perang ringan	P1
SHP-010	Frigate	3D	Kapal perang serbaguna	P1
SHP-011	Destroyer	3D	Kapal perang berat	P2
SHP-012	Missile Frigate	3D	Serangan jarak jauh	P2
SHP-013	Support Ship	3D	Dukungan armada	P2
SHP-014	Repair Ship	3D	Memperbaiki kapal sekutu	P2
SHP-015	Recon Ship	3D	Eksplorasi sektor	P2


D3. Kapal besar

ID	Aset	Format	Fungsi	Prioritas

SHP-016	Battleship	3D	Kapal perang utama	P2
SHP-017	Aircraft Carrier	3D	Membawa dan meluncurkan pesawat	P2
SHP-018	Dreadnought	3D	Kapal perang endgame	P3
SHP-019	Flagship	3D	Kapal komando	P2
SHP-020	Supercarrier	3D	Kapal besar untuk cinematic dan late game	P3


Apakah semua kapal harus dibuat sekarang?

Tidak.

Untuk vertical slice, saya merekomendasikan:

1. Basic Interceptor.


2. Satu kapal pendukung atau Corvette.


3. Satu kapal alien.


4. Satu kapal induk alien untuk menjadi ancaman besar pada tahap berikutnya.



Dengan empat kategori ini, kita sudah bisa menguji skala pertempuran, siluet unit, pergerakan, sistem target, efek senjata, dan keterbacaan visual.

Namun, model kapal induk alien tidak perlu langsung dibuat jika vertical slice pertama hanya membutuhkan serangan kecil. Kita dapat menggunakan aset yang sama untuk menguji sistem serangan terlebih dahulu.


---

7. Kelompok E — Armada Alien

Alien bukan sekadar musuh yang menggunakan model kapal pemain dengan warna berbeda. Mereka harus mempunyai identitas visual tersendiri.

Salah satu arah yang layak diuji adalah desain biomekanis atau struktur asing dengan bentuk asimetris, material gelap, inti energi bercahaya, dan geometri yang berbeda dari teknologi manusia.

Ini masih merupakan pilihan art direction, bukan keputusan final.

ID	Aset	Format	Fungsi	Prioritas

ALN-001	Alien Scout	3D	Pengintai	P0
ALN-002	Alien Interceptor	3D	Pesawat tempur kecil	P0
ALN-003	Alien Striker	3D	Penyerang cepat	P1
ALN-004	Alien Bomber	3D	Serangan berat	P1
ALN-005	Alien Corvette	3D	Kapal perang ringan	P1
ALN-006	Alien Cruiser	3D	Kapal perang menengah	P1
ALN-007	Alien Destroyer	3D	Kapal perang berat	P2
ALN-008	Alien Carrier	3D	Meluncurkan banyak pesawat	P1
ALN-009	Alien Mothership	3D	Boss besar	P2
ALN-010	Alien Siege Ship	3D	Menghancurkan struktur pertahanan	P2
ALN-011	Alien Drone Swarm	3D instanced	Serangan berkelompok	P1
ALN-012	Alien Outpost	3D	Basis musuh	P1
ALN-013	Alien Mining Structure	3D	Fasilitas ekstraksi alien	P2
ALN-014	Alien Fortress	3D	Benteng musuh	P2
ALN-015	Alien Nest/Core	3D	Target akhir sebuah wilayah	P1


Jangan membuat setiap alien sebagai desain terpisah tanpa alasan gameplay

Kita bisa mengembangkan variasi melalui:

Siluet.

Ukuran.

Jenis senjata.

Kecepatan.

Pola serangan.

Warna inti energi.

Material.

Modul tambahan.


Contohnya, Alien Interceptor dan Alien Striker bisa menggunakan basis desain yang sama, tetapi memiliki konfigurasi senjata dan bentuk sayap berbeda.

Namun, variasi yang hanya berupa perubahan warna tidak cukup untuk unit yang seharusnya mempunyai peran berbeda.


---

8. Kelompok F — Senjata, Projectile, dan Visual Effects

Kelompok ini sangat penting untuk membuat pertempuran terasa hidup.

Model pesawat yang bagus tanpa efek senjata, reaksi benturan, dan animasi pertempuran akan terlihat seperti miniatur yang hanya melayang.

ID	Aset	Format	Kegunaan	Prioritas

VFX-001	Laser Bolt	3D/VFX	Proyektil laser	P0
VFX-002	Heavy Laser Beam	3D/VFX	Tembakan laser berat	P1
VFX-003	Plasma Projectile	3D/VFX	Proyektil plasma	P1
VFX-004	Railgun Projectile	3D/VFX	Proyektil kinetik	P2
VFX-005	Missile Model	3D	Model rudal	P0
VFX-006	Missile Trail	VFX	Jejak asap atau energi	P0
VFX-007	Rocket Exhaust	VFX	Efek pendorong rudal	P1
VFX-008	Muzzle Flash	VFX	Efek saat senjata menembak	P0
VFX-009	Small Impact	VFX	Benturan proyektil kecil	P0
VFX-010	Heavy Impact	VFX	Benturan senjata berat	P1
VFX-011	Shield Hit	VFX	Dampak pada perisai	P0
VFX-012	Shield Collapse	VFX	Perisai gagal	P1
VFX-013	Small Explosion	VFX	Kehancuran drone/pesawat kecil	P0
VFX-014	Medium Explosion	VFX	Kehancuran kapal menengah	P1
VFX-015	Capital Ship Explosion	VFX	Kehancuran kapal besar	P2
VFX-016	Debris Field	3D/VFX	Puing pascapertempuran	P1
VFX-017	Energy Core Explosion	VFX	Kehancuran inti energi	P2
VFX-018	Engine Flame	VFX	Pendorong kapal	P0
VFX-019	Warp Effect	VFX	Kapal masuk atau keluar medan tempur	P1
VFX-020	Hyperspace Travel	VFX	Perjalanan antarsektor	P2
VFX-021	Asteroid Destruction	VFX	Asteroid pecah	P2
VFX-022	Structure Damage Smoke	VFX	Bangunan rusak	P1
VFX-023	Structure Fire	VFX	Kebakaran struktur	P1
VFX-024	Electric Sparks	VFX	Kerusakan elektronik	P1
VFX-025	Repair Effect	VFX	Perbaikan bangunan atau kapal	P1
VFX-026	Mining Beam	VFX	Ekstraksi mineral	P1
VFX-027	Energy Transfer Beam	VFX	Transfer energi	P2
VFX-028	Target Lock Indicator	UI/VFX	Menandai target	P0
VFX-029	Critical Hit	VFX	Serangan kritis	P1
VFX-030	Boss Warning Effect	UI/VFX	Peringatan kemunculan boss	P1


VFX mana yang benar-benar membutuhkan model 3D?

Tidak semuanya.

Laser Bolt dapat menggunakan mesh sederhana dengan material emissive.

Missile Trail dapat menggunakan particle system atau ribbon-like trail.

Ledakan dapat menggunakan kombinasi partikel, sprite flipbook, cahaya singkat, dan beberapa mesh.

Shield Hit dapat berupa shader atau efek transparan pada permukaan perisai.

Dengan kata lain, VFX adalah kategori produksi tersendiri, bukan sekadar daftar model 3D.

Satu aturan teknis

Setiap efek harus mempunyai batas durasi dan pengelolaan lifecycle.

Jika ada 200 pesawat yang menembak, efek laser dan ledakan dapat muncul dalam jumlah besar. Karena itu, VFX harus dirancang dengan pooling, pembatasan partikel, dan pengaturan kualitas untuk perangkat mobile.


---

9. Kelompok G — Planet, Asteroid, dan Lingkungan Luar Angkasa

Peta dan arena pertempuran memerlukan objek lingkungan yang membuat setiap wilayah terasa berbeda.

ID	Aset	Format	Fungsi	Prioritas

ENV-001	Small Asteroid	3D	Dekorasi dan variasi medan	P0
ENV-002	Medium Asteroid	3D	Hambatan visual	P0
ENV-003	Large Asteroid	3D	Landmark dan lokasi tambang	P0
ENV-004	Mineral Asteroid	3D	Sumber daya	P0
ENV-005	Rare Mineral Asteroid	3D	Sumber daya langka	P1
ENV-006	Asteroid Cluster	3D instanced	Area pertambangan	P0
ENV-007	Planet Background	3D	Latar arena	P0
ENV-008	Planet Surface Detail	3D atau material	Variasi planet	P2
ENV-009	Moon	3D	Latar atau landmark	P1
ENV-010	Nebula Background	2D/3D	Latar visual	P0
ENV-011	Starfield	Shader/2D/3D	Latar ruang angkasa	P0
ENV-012	Distant Galaxy	2D	Latar menu dan peta	P2
ENV-013	Space Debris	3D	Area bekas pertempuran	P1
ENV-014	Wrecked Spaceship	3D	Landmark atau objek misi	P1
ENV-015	Abandoned Station	3D	Area eksplorasi	P1
ENV-016	Space Gate	3D	Gerbang antarsektor	P1
ENV-017	Wormhole	3D/VFX	Transisi perjalanan	P2
ENV-018	Mining Buoy	3D	Penanda lokasi ekstraksi	P1
ENV-019	Cargo Container	3D	Loot atau objek logistik	P1
ENV-020	Space Anomaly	3D/VFX	Lokasi khusus	P2


Untuk tahap awal, kita tidak membutuhkan puluhan planet yang semuanya unik.

Kita bisa membuat satu lingkungan asteroid yang solid, kemudian memvariasikannya dengan:

Bentuk asteroid.

Ukuran.

Material.

Posisi planet di latar.

Kepadatan debris.

Pencahayaan.

Warna nebula.

Objek fasilitas yang mengorbit.


Ini memberikan variasi visual tanpa menambah biaya produksi secara berlebihan.


---

10. Kelompok H — Animasi dan Rigging

Bagian ini sering terlupakan ketika membuat asset list.

Model 3D bukan aset gameplay yang lengkap jika tidak mempunyai animasi atau perilaku yang dibutuhkan.

ID	Animasi	Jenis	Aset terkait	Prioritas

ANI-001	Fighter Idle Flight	Animasi/prosedural	Pesawat tempur	P0
ANI-002	Fighter Acceleration	Animasi/prosedural	Pesawat tempur	P0
ANI-003	Fighter Banking	Animasi/prosedural	Pesawat tempur	P0
ANI-004	Fighter Evasive Maneuver	Animasi/prosedural	Pesawat tempur	P1
ANI-005	Fighter Attack Pass	Animasi/prosedural	Pesawat tempur	P0
ANI-006	Fighter Destroyed	Animasi/VFX	Pesawat tempur	P0
ANI-007	Capital Ship Cruise	Animasi/prosedural	Kapal besar	P1
ANI-008	Capital Ship Weapon Fire	Animasi/prosedural	Kapal besar	P1
ANI-009	Hangar Door Open	Animasi	Hangar	P0
ANI-010	Hangar Door Close	Animasi	Hangar	P0
ANI-011	Ship Launch	Animasi/prosedural	Hangar dan pesawat	P0
ANI-012	Ship Docking	Animasi/prosedural	Pesawat dan docking port	P1
ANI-013	Turret Tracking	Animasi/prosedural	Turret	P0
ANI-014	Turret Recoil	Animasi	Turret	P0
ANI-015	Solar Panel Rotation	Animasi	Solar Array	P2
ANI-016	Mining Drill Operation	Animasi	Mining Drill	P1
ANI-017	Mining Beam Activation	Animasi/VFX	Mining Facility	P1
ANI-018	Reactor Pulse	Animasi/VFX	Energy Reactor	P1
ANI-019	Shield Activation	Animasi/VFX	Shield Generator	P0
ANI-020	Structure Collapse	Animasi/VFX	Bangunan	P1
ANI-021	Repair Animation	Animasi/VFX	Bangunan dan kapal	P1
ANI-022	Warp In/Out	Animasi/VFX	Semua kapal yang relevan	P1
ANI-023	Boss Entrance	Animasi/cinematic	Kapal induk alien	P2
ANI-024	Boss Destruction	Animasi/VFX	Kapal induk alien	P2


Tidak semua pesawat membutuhkan skeletal animation

Untuk pesawat ruang angkasa, banyak gerakan dapat dibuat secara prosedural:

Rotasi pitch, yaw, dan roll.

Perubahan posisi.

Akselerasi dan deselerasi.

Gerakan mengikuti lintasan.

Gerakan menghindar.

Rotasi turret.

Perubahan intensitas mesin.


Rigging skeletal lebih diperlukan jika model memiliki bagian mekanis kompleks yang harus bergerak secara independen.

Ini penting karena kita dapat mengurangi beban produksi animasi dengan memanfaatkan sistem gerakan di Godot.


---

11. Kelompok I — UI dan HUD

UI bukan bagian yang boleh ditunda sampai seluruh model 3D selesai.

Game strategi mobile membutuhkan banyak informasi, tetapi pemain harus tetap bisa melihat benteng dan armadanya.

Saya menyarankan visual UI bertema military command system: panel taktis, garis tipis, ikon teknologi, indikator ancaman, dan animasi holografis secukupnya.

I1. Komponen UI dasar

ID	Aset	Format	Prioritas

UI-001	UI Panel Background	2D	P0
UI-002	Main Button	2D/UI	P0
UI-003	Secondary Button	2D/UI	P0
UI-004	Disabled Button	2D/UI	P0
UI-005	Progress Bar	2D/UI	P0
UI-006	Health Bar	2D/UI	P0
UI-007	Shield Bar	2D/UI	P0
UI-008	Resource Counter	UI	P0
UI-009	Timer	UI	P0
UI-010	Tooltip Panel	UI	P1
UI-011	Modal Dialog	UI	P0
UI-012	Notification Toast	UI	P1
UI-013	Confirmation Dialog	UI	P0
UI-014	Loading Indicator	UI	P0
UI-015	Tab Navigation	UI	P0
UI-016	Dropdown/Selector	UI	P1
UI-017	Scroll Container Styling	UI	P0
UI-018	Building Level Badge	2D/UI	P0
UI-019	Upgrade Arrow	2D	P0
UI-020	Warning Indicator	2D/UI	P0


I2. HUD benteng

ID	Aset	Format	Prioritas

UI-021	Energy Icon	2D	P0
UI-022	Mineral Icon	2D	P0
UI-023	Premium Currency Icon	2D	P2
UI-024	Command Core Level	UI	P0
UI-025	Population/Capacity Indicator	UI	P1
UI-026	Fleet Capacity Indicator	UI	P0
UI-027	Threat Warning	UI	P0
UI-028	Base Health Indicator	UI	P0
UI-029	Building Menu Icon Set	2D	P0
UI-030	Build Placement Indicator	UI/VFX	P0
UI-031	Invalid Placement Indicator	UI/VFX	P0
UI-032	Upgrade Cost Panel	UI	P0
UI-033	Repair Cost Panel	UI	P0
UI-034	Production Queue	UI	P0
UI-035	Construction Timer	UI	P0


I3. HUD pertempuran

ID	Aset	Format	Prioritas

UI-036	Enemy Target Marker	UI/VFX	P0
UI-037	Target Health Bar	UI	P0
UI-038	Boss Health Bar	UI	P1
UI-039	Fleet Formation Icon	2D	P1
UI-040	Attack Command Button	UI	P0
UI-041	Retreat Command Button	UI	P1
UI-042	Tactical Pause Button	UI	P0
UI-043	Battle Speed Controls	UI	P1
UI-044	Damage Numbers	UI	P1
UI-045	Battle Result Panel	UI	P0
UI-046	Casualty Report	UI	P1
UI-047	Loot/Reward Panel	UI	P0
UI-048	Mission Objective Tracker	UI	P0
UI-049	Incoming Wave Warning	UI	P0
UI-050	Battle Timeline/Progress	UI	P2


Catatan: Sebagian besar UI tidak perlu berupa gambar PNG terpisah. Panel, tombol, bar, dan indikator dapat dibangun menggunakan komponen UI Godot, StyleBox, SVG, font, dan material sederhana. Kita membutuhkan desain serta aset visual pendukung, bukan satu gambar unik untuk setiap elemen.


---

12. Kelompok J — Ikon, Resource, dan Teknologi

Ikon harus konsisten karena akan digunakan di banyak layar.

J1. Ikon sumber daya

ID	Ikon	Format	Prioritas

ICO-001	Energy	2D	P0
ICO-002	Mineral	2D	P0
ICO-003	Alloy	2D	P1
ICO-004	Rare Crystal	2D	P1
ICO-005	Research Data	2D	P1
ICO-006	Ship Parts	2D	P1
ICO-007	Fuel	2D	P1
ICO-008	Repair Materials	2D	P1
ICO-009	Premium Currency	2D	P2
ICO-010	Mission Token	2D	P2


J2. Ikon militer

ID	Ikon	Format	Prioritas

ICO-011	Fighter	2D	P0
ICO-012	Bomber	2D	P1
ICO-013	Corvette	2D	P1
ICO-014	Frigate	2D	P1
ICO-015	Battleship	2D	P2
ICO-016	Carrier	2D	P2
ICO-017	Scout	2D	P0
ICO-018	Defense Turret	2D	P0
ICO-019	Shield	2D	P0
ICO-020	Repair	2D	P1


J3. Ikon teknologi

ID	Ikon	Format	Prioritas

ICO-021	Weapon Technology	2D	P0
ICO-022	Armor Technology	2D	P0
ICO-023	Engine Technology	2D	P1
ICO-024	Energy Technology	2D	P0
ICO-025	Mining Technology	2D	P0
ICO-026	Logistics Technology	2D	P1
ICO-027	Shield Technology	2D	P1
ICO-028	Drone Technology	2D	P1
ICO-029	Fleet Command Technology	2D	P1
ICO-030	Alien Research	2D	P2


Sebaiknya kita memiliki satu icon design system yang mencakup ukuran, ketebalan garis, siluet, palet warna, dan aturan penggunaan.

Jangan membuat ikon dengan gaya berbeda-beda hanya karena dibuat oleh generator atau kreator yang berbeda.


---

13. Kelompok K — Peta Galaksi dan Territory Management

Peta galaksi memiliki kebutuhan yang berbeda dari arena pertempuran.

Pemain harus bisa melihat wilayah yang dikuasai, lokasi sumber daya, markas alien, rute perjalanan, dan target berikutnya.

Karena itu, peta bisa menggunakan pendekatan 2D atau 3D sederhana tanpa memerlukan kualitas model yang sama dengan cinematic battle.

ID	Aset	Format	Fungsi	Prioritas

MAP-001	Galaxy Map Background	2D	Latar peta	P0
MAP-002	Star Node	2D/UI	Titik sistem bintang	P0
MAP-003	Player Territory Marker	UI	Wilayah pemain	P0
MAP-004	Enemy Territory Marker	UI	Wilayah alien	P0
MAP-005	Neutral Territory Marker	UI	Wilayah belum dikuasai	P0
MAP-006	Resource Node Marker	UI	Lokasi sumber daya	P0
MAP-007	Fleet Marker	UI	Posisi armada	P0
MAP-008	Route Line	UI	Rute perjalanan	P0
MAP-009	Attack Route Animation	UI	Animasi perjalanan serangan	P1
MAP-010	Scanning Effect	UI/VFX	Menemukan sektor	P1
MAP-011	Fog of War	Shader/UI	Wilayah belum ditemukan	P1
MAP-012	Sector Border	UI	Batas wilayah	P0
MAP-013	Territory Capture Effect	UI/VFX	Wilayah berhasil dikuasai	P1
MAP-014	Planet Thumbnail	2D	Pratinjau sistem	P1
MAP-015	Sector Detail Panel	UI	Informasi wilayah	P0
MAP-016	Enemy Threat Indicator	UI	Tingkat ancaman	P0
MAP-017	Exploration Reward Marker	UI	Hadiah eksplorasi	P1
MAP-018	Boss Sector Marker	UI	Wilayah boss	P2


Apa yang harus dibuat dalam 3D?

Untuk vertical slice, peta tidak harus menjadi dunia 3D yang bisa dijelajahi bebas.

Kita dapat membuat sistem node dan rute menggunakan UI 2D, kemudian menampilkan model planet 3D saat pemain membuka detail wilayah.

Dengan demikian, aset 3D yang diperlukan untuk setiap node bisa digunakan ulang.


---

14. Kelompok L — Komandan, Karakter, dan Potret

Kita belum menetapkan apakah game ini akan memiliki hero system seperti game strategi mobile pada umumnya.

Karena itu, bagian ini sebaiknya dianggap sebagai sistem ekspansi, bukan syarat vertical slice.

Jika nantinya komandan menjadi bagian gameplay, kita membutuhkan:

ID	Aset	Format	Prioritas

CMD-001	Commander Portrait	2D	P2
CMD-002	Commander Profile Illustration	2D	P2
CMD-003	Commander Selection Card	UI	P2
CMD-004	Commander Skill Icon	2D	P2
CMD-005	Commander Rarity Frame	UI	P2
CMD-006	Commander Upgrade Effect	UI/VFX	P2
CMD-007	Commander Full Body	3D opsional	P3
CMD-008	Commander Idle Animation	3D opsional	P3
CMD-009	Commander Hologram	3D/VFX	P3
CMD-010	Dialogue Portrait Expressions	2D	P2


Rekomendasi

Jangan langsung membuat puluhan hero.

Sistem hero dapat meningkatkan kedalaman strategi, tetapi juga menambah pekerjaan untuk:

Desain karakter.

Skill.

Animasi.

Balance.

UI.

Progression.

Konten dan monetisasi.


Untuk pengujian core game, kita sebaiknya lebih dahulu membuktikan bahwa pembangunan benteng, produksi armada, ekspansi wilayah, dan pertahanan alien sudah menyenangkan tanpa bergantung pada hero collection.


---

15. Kelompok M — Audio

Meskipun pertanyaan utama kita tentang aset visual, inventaris produksi yang lengkap juga harus mencatat kebutuhan audio.

Audio bukan aset visual, tetapi sangat berpengaruh pada kualitas pertempuran.

ID	Aset	Format	Prioritas

AUD-001	UI Click	SFX	P0
AUD-002	UI Confirm	SFX	P0
AUD-003	UI Error	SFX	P0
AUD-004	Building Constructed	SFX	P0
AUD-005	Building Upgrade	SFX	P1
AUD-006	Reactor Hum	Loop SFX	P1
AUD-007	Hangar Ambience	Loop SFX	P1
AUD-008	Ship Engine	SFX/Loop	P0
AUD-009	Laser Fire	SFX	P0
AUD-010	Missile Launch	SFX	P0
AUD-011	Projectile Impact	SFX	P0
AUD-012	Shield Impact	SFX	P0
AUD-013	Small Explosion	SFX	P0
AUD-014	Large Explosion	SFX	P1
AUD-015	Capital Ship Explosion	SFX	P2
AUD-016	Warp	SFX	P1
AUD-017	Mining Operation	SFX	P1
AUD-018	Repair Operation	SFX	P1
AUD-019	Incoming Attack Alert	SFX	P0
AUD-020	Boss Arrival	SFX	P2
AUD-021	Victory Stinger	SFX	P0
AUD-022	Defeat Stinger	SFX	P0
AUD-023	Base Ambience	Loop SFX	P1
AUD-024	Space Exploration Music	Music	P1
AUD-025	Combat Music	Music	P0
AUD-026	Boss Music	Music	P2
AUD-027	Galaxy Map Music	Music	P1


Untuk menghemat produksi, satu suara bisa digunakan oleh beberapa senjata sejenis dengan variasi pitch, volume, dan lapisan suara.


---

16. Kelompok N — Menu, Loading, dan Presentation Assets

Aset ini diperlukan agar game terlihat sebagai produk yang utuh, bukan hanya prototype arena pertempuran.

ID	Aset	Format	Prioritas

PRE-001	Main Menu Background	3D render atau 2D	P0
PRE-002	Logo Game	2D/SVG	P0
PRE-003	Loading Screen Background	2D	P0
PRE-004	Loading Indicator	UI	P0
PRE-005	Login Screen Background	2D/3D render	P2
PRE-006	Mission Briefing Background	2D/3D render	P1
PRE-007	Victory Screen Background	2D/3D render	P0
PRE-008	Defeat Screen Background	2D/3D render	P0
PRE-009	Boss Introduction Frame	UI	P2
PRE-010	Cinematic Letterbox	UI	P2
PRE-011	Screen Transition Effect	UI/VFX	P1
PRE-012	Event Banner	2D	P3
PRE-013	Achievement Badge	2D	P2
PRE-014	Tutorial Highlight	UI/VFX	P0
PRE-015	Tutorial Hand Indicator	2D/UI	P0
PRE-016	Reward Reveal Effect	UI/VFX	P1
PRE-017	New Building Unlocked	UI/VFX	P1
PRE-018	New Sector Unlocked	UI/VFX	P1


Strategi penghematan: Background menu dapat diambil dari scene 3D yang sama dengan benteng, lalu menggunakan kamera, pencahayaan, dan komposisi berbeda. Kita tidak perlu membuat satu environment baru khusus untuk setiap layar.


---

17. Kelompok O — Material, Shader, dan Texture Library

Ini adalah kelompok yang sering tidak terlihat dalam daftar aset, padahal dibutuhkan untuk membuat model terlihat konsisten.

Model 3D tanpa material yang baik sering terlihat seperti objek abu-abu biasa.

ID	Aset	Jenis	Penggunaan	Prioritas

MAT-001	Human Hull Metal	Material	Kapal dan bangunan manusia	P0
MAT-002	Alien Hull Material	Material	Armada alien	P0
MAT-003	Industrial Metal	Material	Fasilitas produksi	P0
MAT-004	Dark Metal	Material	Struktur militer	P0
MAT-005	Ceramic Armor	Material	Pelat pelindung	P1
MAT-006	Energy Core	Emissive material	Reaktor dan inti energi	P0
MAT-007	Blue Engine Emission	Emissive material	Pendorong kapal	P0
MAT-008	Red/Orange Weapon Emission	Emissive material	Senjata energi	P0
MAT-009	Shield Material	Shader/material	Perisai	P0
MAT-010	Damaged Metal	Material	Bangunan rusak	P1
MAT-011	Scorched Metal	Material	Bekas ledakan	P1
MAT-012	Asteroid Rock	Material	Asteroid	P0
MAT-013	Mineral Surface	Material	Asteroid kaya mineral	P0
MAT-014	Ice Surface	Material	Asteroid es	P2
MAT-015	Planet Surface	Material	Planet	P1
MAT-016	Hologram Material	Shader	UI 3D dan proyeksi	P1
MAT-017	Warp Distortion	Shader	Perjalanan antarsektor	P2
MAT-018	Dissolve/Destruction	Shader	Kehancuran unit	P2
MAT-019	Scanning Effect	Shader/VFX	Radar dan eksplorasi	P1
MAT-020	Shield Hit Distortion	Shader	Benturan perisai	P1


Kita tidak harus membuat semua material dari nol. Sebagian dapat menggunakan material dasar yang dimodifikasi.

Yang penting adalah menetapkan standar material sejak awal agar model dari sumber yang berbeda tidak terlihat seperti berasal dari tiga game berbeda.


---

18. Kelompok P — Efek Kerusakan dan Kondisi Bangunan

Karena serangan alien dapat merusak benteng, sistem kerusakan harus memiliki aset dan state visual tersendiri.

Jika bangunan hanya mempunyai kondisi normal dan tiba-tiba menghilang saat HP mencapai nol, konsekuensi gameplay akan terasa kurang kuat.

Saya merekomendasikan empat tingkat kondisi:

Kondisi	Visual	Implementasi

Normal	Struktur utuh, lampu aktif	Model normal
Damaged	Panel rusak, percikan kecil	Material atau modul kerusakan
Critical	Asap, api, lampu berkedip	Material + VFX
Destroyed	Struktur hancur atau tidak berfungsi	Model rusak, puing, atau state kehancuran


Contoh kebutuhan per bangunan:

Command Core: normal, damaged, critical.

Hangar: normal, damaged, critical, hangar tidak berfungsi.

Reactor: normal, damaged, critical, ledakan energi.

Turret: normal, damaged, disabled, destroyed.

Mining Facility: normal, damaged, production stopped.

Shield Generator: normal, damaged, shield weakened, shield offline.


Kita tidak perlu membuat empat model lengkap untuk setiap bangunan. Banyak state bisa dihasilkan melalui material, modul tambahan, partikel, lampu, dan perubahan perilaku.

Aturan gameplay: Kehancuran bangunan harus mengikuti keputusan desain ekonomi dan progression. Bangunan yang hancur tidak boleh otomatis menghapus seluruh progres pemain. Harus ada sistem perbaikan dan pemulihan yang jelas.


---

19. Berapa Banyak Aset yang Benar-Benar Dibutuhkan?

Daftar di atas merupakan inventaris kandidat, bukan perintah untuk memproduksi seluruhnya sekaligus.

Jika semua aset dibuat sebelum gameplay diuji, kita berisiko menghabiskan waktu pada konten yang akhirnya tidak digunakan.

Untuk itu, kita perlu membedakan jumlah entri inventaris dari jumlah file model atau texture yang harus diproduksi.

Satu aset dapat menghasilkan banyak varian. Sebaliknya, satu entri seperti Fighter bisa membutuhkan model, material, thumbnail, animasi, VFX, dan ikon UI.

Target awal yang realistis untuk vertical slice

Kelompok	Target awal	Keterangan

Benteng	1 inti + 3–5 modul	Menampilkan pembangunan dasar
Bangunan ekonomi	3–4	Reactor, extractor, hangar, research lab
Bangunan pertahanan	2	Laser turret dan shield generator
Armada pemain	1–2 unit	Interceptor dan satu kapal pendukung opsional
Armada alien	1–2 tipe	Scout dan interceptor alien
Lingkungan	1 set	Asteroid, mineral asteroid, planet, starfield
VFX	8–12 efek dasar	Laser, mesin, impact, shield, ledakan, kerusakan
Animasi/perilaku	8–12 perilaku	Terbang, menembak, tracking, launch, repair
UI	1 set dasar	Resource HUD, build menu, upgrade, battle HUD
Ikon	10–20 ikon inti	Sumber daya, bangunan, dan unit
Audio	8–12 SFX	Tembakan, mesin, ledakan, UI, alarm
Material	6–10 material dasar	Metal, energy, alien, asteroid, emissive


Angka tersebut adalah target perencanaan awal, bukan hasil benchmark produksi. Kebutuhan aktual akan berubah setelah ukuran scene, kamera, jumlah unit simultan, dan kualitas visual ditetapkan.

Dengan inventaris minimum ini, kita sudah bisa membangun dan menguji:

1. Pemain memulai dengan benteng dasar.


2. Pemain membangun fasilitas produksi.


3. Pemain menambang sumber daya.


4. Pemain memproduksi interceptor.


5. Pemain membangun pertahanan.


6. Armada alien menyerang.


7. Pertahanan menembak secara otomatis.


8. Bangunan dan kapal dapat mengalami kerusakan.


9. Pemain memperbaiki benteng.


10. Pemain menyerang satu wilayah untuk mendapatkan sumber daya tambahan.



Itulah vertical slice yang cukup untuk menguji apakah gameplay utamanya menarik.


---

20. Format File: Standar yang Sebaiknya Kita Tetapkan

Karena kita menggunakan Godot dan Blender sebagai arah teknologi, format aset sebaiknya ditentukan sebelum produksi dimulai.

Aset 3D

Jenis file	Penggunaan	Keputusan

.blend	Source project Blender	Simpan untuk aset yang dibuat atau diedit di Blender
.glb	Model, material, dan animasi untuk diimpor ke Godot	Format pertukaran utama yang direkomendasikan
.gltf	Format scene 3D berbasis JSON dengan resource pendukung	Alternatif jika workflow membutuhkan file terpisah
.png	Texture, sprite, icon, dan flipbook	Format utama gambar raster
.webp	Gambar UI atau background tertentu	Opsional setelah kompatibilitas pipeline diperiksa
.exr / .hdr	HDR environment atau lighting tertentu	Hanya jika dibutuhkan
.tres / .res	Resource native Godot	Material, konfigurasi, dan resource internal
.tscn	Scene Godot	Prefab bangunan, kapal, VFX, dan UI
.gd	Script Godot	Logic, animasi prosedural, dan integrasi gameplay


Rekomendasi format model

Gunakan .glb sebagai format pertukaran standar untuk model 3D.

Keuntungannya:

Dapat menyimpan mesh.

Mendukung material.

Mendukung hierarchy.

Dapat menyimpan animasi.

Mudah diorganisasi sebagai file tunggal.

Cocok untuk workflow Blender ke Godot.


Simpan .blend sebagai source file yang dapat diedit. Tidak semua model perlu dipecah menjadi banyak file jika satu model beserta material dan animasinya dapat disimpan dalam satu .glb.

Namun, jika sebuah kapal memiliki modul senjata yang harus diganti saat upgrade, modul tersebut sebaiknya mempunyai struktur dan titik attachment yang jelas.

Aset 2D

Jenis file	Penggunaan

.png	Texture, ikon raster, sprite, flipbook, transparansi
.svg	Ikon dan elemen UI vektor yang perlu diskalakan
.ttf / .otf	Font
.wav	Audio efek dan audio pendek
.ogg	Musik dan audio terkompresi yang didukung pipeline


Untuk sprite VFX, gunakan texture atlas atau sprite sheet bila sesuai. Untuk ikon yang dominan berbentuk geometris, SVG dapat membantu menjaga ketajaman pada berbagai ukuran layar.


---

21. Struktur Folder Asset yang Saya Rekomendasikan

Kita sebaiknya tidak menyimpan semua aset dalam satu folder bernama Assets.

Gunakan struktur yang memisahkan source file, aset impor, scene Godot, UI, VFX, dan audio.

res://
│
├── assets/
│   │
│   ├── 3d/
│   │   ├── fortress/
│   │   ├── buildings/
│   │   │   ├── economy/
│   │   │   ├── defense/
│   │   │   └── research/
│   │   ├── player_ships/
│   │   │   ├── fighters/
│   │   │   ├── corvettes/
│   │   │   ├── frigates/
│   │   │   └── capital_ships/
│   │   ├── alien_ships/
│   │   ├── environment/
│   │   │   ├── asteroids/
│   │   │   ├── planets/
│   │   │   └── stations/
│   │   ├── props/
│   │   └── debris/
│   │
│   ├── 2d/
│   │   ├── icons/
│   │   │   ├── resources/
│   │   │   ├── buildings/
│   │   │   ├── ships/
│   │   │   ├── technology/
│   │   │   └── status/
│   │   ├── ui/
│   │   ├── portraits/
│   │   ├── backgrounds/
│   │   ├── galaxy_map/
│   │   └── spritesheets/
│   │
│   ├── vfx/
│   │   ├── weapons/
│   │   ├── explosions/
│   │   ├── shields/
│   │   ├── engines/
│   │   ├── damage/
│   │   ├── repair/
│   │   └── transitions/
│   │
│   ├── materials/
│   ├── textures/
│   ├── audio/
│   │   ├── sfx/
│   │   ├── ambience/
│   │   └── music/
│   └── fonts/
│
├── scenes/
│   ├── base/
│   ├── buildings/
│   ├── ships/
│   ├── combat/
│   ├── galaxy_map/
│   ├── menus/
│   └── ui/
│
├── scripts/
│   ├── building/
│   ├── fleet/
│   ├── combat/
│   ├── economy/
│   ├── research/
│   └── ui/
│
├── data/
│   ├── buildings/
│   ├── ships/
│   ├── weapons/
│   ├── technologies/
│   └── sectors/
│
└── shaders/
    ├── shield/
    ├── hologram/
    ├── damage/
    └── environment/

Source .blend dapat disimpan di repository art source yang terpisah jika ukuran proyek menjadi besar. Jangan menyimpan cache hasil render, backup otomatis Blender, atau salinan duplikat aset tanpa alasan.


---

22. Standar Produksi: Setiap Aset Harus Memiliki Kontrak

Agar kita tidak kembali menghadapi masalah aset yang tampak bagus tetapi tidak dapat digunakan, setiap aset 3D harus mempunyai spesifikasi.

Contoh kontrak untuk SHP-001 Basic Interceptor:

Properti	Standar

Asset ID	SHP-001
Nama	Basic Interceptor
Source	Blender
Format impor	GLB
Skala	Meter
Forward axis	Konsisten dengan kontrak proyek Godot
Origin	Ditentukan berdasarkan kebutuhan gerak
Hierarchy	Root, body, engine, weapon attachment
Material	Menggunakan standar material proyek
Collision	Sederhana, dibuat sesuai kebutuhan gameplay
LOD	Berdasarkan jarak dan kebutuhan performa
Thumbnail	Render atau screenshot untuk UI
Icon	Ikon 2D terpisah
Engine effect	Titik attachment yang jelas
Weapon attachment	Titik attachment yang jelas
Animation	Tidak wajib skeletal; gerakan bisa prosedural
Performance	Diuji pada target perangkat
Status	Placeholder / In Production / Integrated / Verified


Satu hal penting: forward axis, skala, dan origin harus menjadi kontrak pipeline, bukan diputuskan ulang oleh setiap pembuat aset.

Hal ini sangat penting untuk model pesawat. Jika arah depan model berbeda-beda, kita akan mengalami masalah ketika mengatur gerakan, target, kamera, dan efek mesin.

Untuk Godot, orientasi node dan konvensi impor harus diuji menggunakan satu model pilot sebelum seluruh armada diproduksi.


---

23. Bagaimana dengan Aset yang Dibuat Menggunakan AI?

Kita bisa menggunakan AI untuk mempercepat pembuatan concept art, variasi desain, texture, dan model 3D awal.

Namun, jangan menganggap semua model hasil generator siap langsung digunakan.

Setiap aset perlu melewati proses:

1. Concept Validation: Apakah bentuknya sesuai dengan art direction?


2. Geometry Inspection: Apakah mesh memiliki masalah geometri?


3. Scale and Origin: Apakah skala dan orientasinya benar?


4. Material Inspection: Apakah material dan texture dapat diimpor dengan benar?


5. Optimization: Apakah model cukup ringan untuk target perangkat?


6. Collision Setup: Apakah collision sesuai kebutuhan gameplay?


7. Integration Test: Apakah model bekerja di scene Godot?


8. Visual Review: Apakah model terlihat benar dari kamera gameplay?


9. Performance Test: Apakah aset tetap layak ketika digunakan bersama banyak unit?


10. Acceptance: Apakah aset sudah benar-benar terintegrasi dan terverifikasi?



Status aset harus dibedakan:

PLANNED: Belum dibuat.

GENERATED: Sudah ada hasil awal.

REVIEWED: Sudah diperiksa secara visual.

OPTIMIZED: Sudah melalui proses optimasi.

INTEGRATED: Sudah masuk ke proyek.

VERIFIED: Sudah diuji sesuai fungsi dan persyaratannya.


Jangan menandai aset sebagai selesai hanya karena file GLB berhasil dibuat.


---

24. Apa yang Harus Dibuat Terlebih Dahulu?

Walaupun kita sudah memiliki master inventory yang besar, saya tidak menyarankan langsung membuat semua aset.

Urutan yang lebih aman adalah:

Tahap 1 — Visual Foundation

Buat:

Satu benteng utama.

Satu Command Core.

Satu Energy Reactor.

Satu Mineral Extractor.

Satu Fighter Hangar.

Satu Laser Turret.

Satu Basic Interceptor.

Satu Alien Interceptor.

Satu asteroid biasa.

Satu asteroid mineral.

Satu planet latar.

Satu set material dasar.


Tujuannya memastikan bahwa semua aset memiliki kualitas visual yang konsisten.

Tahap 2 — Core Gameplay Assets

Tambahkan:

Shield Generator.

Research Laboratory.

Shipyard.

Missile Launcher.

Model pesawat pendukung.

Alien Scout.

Sistem kerusakan bangunan.

Efek laser dan rudal.

Efek ledakan dan perisai.

UI pembangunan dan upgrade.

Resource icons.

Battle HUD.


Tujuannya memastikan gameplay utama dapat dimainkan dari pembangunan sampai pertempuran.

Tahap 3 — Combat Presentation

Tambahkan:

Variasi gerakan pesawat.

Pola serangan alien.

Efek senjata berat.

Puing.

Efek kerusakan kritis.

Animasi peluncuran kapal.

Animasi perbaikan.

Kamera cinematic.

Musik dan audio pertempuran.


Tujuannya meningkatkan kualitas presentasi tanpa mengorbankan performa.

Tahap 4 — Expansion Content

Setelah core game terbukti berfungsi, barulah tambahkan:

Corvette, Frigate, Destroyer, dan Battleship.

Alien Carrier.

Alien Mothership.

Lebih banyak fasilitas.

Planet dan sektor tambahan.

Teknologi tingkat lanjut.

Komandan dan skill.

Variasi senjata.

Efek boss battle.


Ini akan mengurangi risiko menghasilkan puluhan aset untuk sistem yang ternyata perlu didesain ulang.


---

25. Hal yang Belum Boleh Kita Anggap Sudah Diputuskan

Ada beberapa keputusan yang akan memengaruhi jumlah dan bentuk aset secara signifikan.

Keputusan	Dampak terhadap produksi

Kamera isometrik atau top-down	Menentukan siluet bangunan, detail yang terlihat, dan layout
Kamera dapat diputar atau tidak	Memengaruhi kebutuhan detail pada seluruh sisi model
Arena combat terpisah atau satu dunia	Memengaruhi kebutuhan scene, environment, dan transisi
Ukuran armada pada layar	Memengaruhi kompleksitas model, LOD, dan VFX
Combat otomatis atau kontrol langsung	Memengaruhi animasi, HUD, serta kebutuhan kontrol
Benteng modular atau satu model besar	Memengaruhi konstruksi, upgrade, dan sistem kerusakan
Upgrade kosmetik atau model berbeda	Memengaruhi jumlah varian bangunan
Sistem komandan atau tanpa komandan	Memengaruhi karakter, potret, skill, dan UI
Jumlah sektor dan planet	Memengaruhi kebutuhan environment
Gaya visual realistis atau stylized-realistic	Memengaruhi material, polygon budget, dan pencahayaan


Saya tidak akan menetapkan angka final untuk seluruh aset sebelum keputusan tersebut dibuat.

Jika kita memproduksi model sebelum mengetahui kamera, misalnya, kita mungkin menghabiskan waktu membuat detail bagian bawah kapal yang tidak pernah terlihat. Sebaliknya, jika kamera dapat berputar bebas, bagian tersebut mungkin penting.


---

26. Rekomendasi Akhir: Kita Membutuhkan Asset Registry, Bukan Hanya Daftar di Chat

Daftar ini sebaiknya menjadi dokumen produksi yang bisa digunakan terus-menerus oleh developer, AI coding agent, AI asset generator, dan artist.

Saya merekomendasikan empat dokumen inti:

1. MASTER_ASSET_INVENTORY.md

Daftar semua aset, fungsi, prioritas, format, dependensi, dan status produksi.

2. ART_DIRECTION.md

Standar visual untuk manusia, alien, benteng, pesawat, lingkungan, material, pencahayaan, dan VFX.

3. ASSET_PIPELINE.md

Standar Blender → GLB → Godot, skala, orientasi, naming convention, material, LOD, collision, dan pengujian.

4. ASSET_ACCEPTANCE_CRITERIA.md

Kriteria agar aset dianggap layak, terintegrasi, dan terverifikasi.

Setiap aset harus mempunyai ID unik. Contohnya:

FRT-001  Main Fortress
ECO-001  Energy Reactor
DEF-001  Basic Laser Turret
SHP-001  Basic Interceptor
ALN-001  Alien Scout
VFX-001  Laser Bolt
ENV-001  Small Asteroid
UI-001   Main UI Panel
ICO-001  Energy Icon
AUD-001  UI Click

ID tersebut digunakan pada dokumen, nama file, data konfigurasi, dan laporan pekerjaan. Dengan begitu, ketika AI agent mengatakan SHP-001 VERIFIED, kita bisa memeriksa model, scene Godot, thumbnail, material, serta hasil pengujiannya—bukan hanya mempercayai klaim bahwa pesawat sudah selesai.
