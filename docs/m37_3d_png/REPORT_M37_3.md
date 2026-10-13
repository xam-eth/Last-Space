# M3 #7 — Koreksi Pemain 2026-10-13 (ikon SVG, arena PNG chroma-key, card lebih kecil, bug klik)

Milestone: **M3 #7** (perbaikan atas kritik #5 pemain)
Status keseluruhan: **VERIFIED** (dengan satu catatan terbuka di §5)
Tanggal: 2026-10-13/14 · Branch: `arena/d80e2902-last-space` · Commit: `6d1d208`

---

## 1. Permintaan pemain (verbatim)

> "fix camera udah benar tapi perlu di buat dynamic dan bisa di gerakan da untuk
> element nya disini kamu masih pakai code semua icon harus nya pakai svg real
> bukan code html untuk arena itu elemt nya juga pakai png kamu generate foto
> dengan cromase seperti planet dll , disii juga ukuran card nya masi terlalu
> besar , untuk bangun dll itu fungsi nya masih banyak bug , tidak bisa diklik ,"

Dipecah menjadi 5 acceptance criteria (AC1–AC5) dan statusnya:

| # | Acceptance | Status | Bukti |
|---|---|---|---|
| AC1 | Kamera **dinamis & bisa digerakkan** | **VERIFIED** (dibuat di M3 #6 `4a4b752`, agent lain; saya verifikasi ulang) | gate `camera` 12/12; gate `input` cek zoom/chip/drag; `verify_m3_6_camera.py` 66/66 |
| AC2 | Ikon = **SVG ASLI**, bukan digambar lewat kode | **VERIFIED** | 33 berkas `.svg` di `game/assets/ui/icons/`; suite `icons` lulus di build WebGL (ThorVG); `icon_source() == "svg"` |
| AC3 | Elemen arena = **PNG hasil foto ber-chroma-key** | **VERIFIED** | 4 PNG RGBA di `assets/arena/` + marker `QA:ARENA:PNG … src=png` ×4 lulus gate `asset`; `verify_m37_3.py` 54/54 |
| AC4 | **Ukuran card dikecilkan** | **VERIFIED** | tile 68dp, kartu aksi HUD 52×64dp, modal 512dp; marker `CARD:SUMMARY tile_dp=68 icon_ratio=78` |
| AC5 | **"Bangun dll tidak bisa diklik"** diperbaiki & dibuktikan dengan uji klik nyata | **VERIFIED** | suite `input` baru (event mouse sintetis, bukan panggilan API) 29/29; akar bug terdokumentasi di §4 |

---

## 2. AC1 — Kamera dinamis & bisa digerakkan

Kamera sudah tuntas di M3 #6 (commit `4a4b752`): `CameraRig` dengan zoom
0,45×–1,90×, pan dibatasi radius 16, gesture pinch / wheel / drag / double-tap, plus
tombol HUD eksplisit (+ / ×x1,0 / − / reset). Pemain menyatakan kamera **"sudah
benar"**, jadi saya **tidak merombaknya**; saya hanya memverifikasi ulang bahwa
gerakan kamera tetap bekerja setelah semua perubahan M3 #7:

```
==> run_game_check.sh camera  → 12/12 cek PASS
  CAMERA CHECK: tombol HUD zoom (48dp) memindahkan kamera              -> PASS
  CAMERA CHECK: jarak piksel landmark membesar saat zoom in             -> PASS
  CAMERA CHECK: jarak piksel landmark mengecil saat tombol −            -> PASS
  CAMERA CHECK: chip zoom ikut state nyata + reset                      -> PASS
  CAMERA CHECK: gesture: wheel + double tap + pinch                     -> PASS
  CAMERA CHECK: pan menggeser kamera & dibatasi radius                  -> PASS
  CAMERA CHECK: tap pendek tetap memilih bangunan setelah pan            -> PASS
  SPAN landmark: 312,8 px → 1011,1 px (rasio 3,23)
```

Gate `input` (klik nyata) menambah bukti: `input.klik_chip_buka`, drag pan
`(0,0) → (6,72; 2,24)`, chip zoom `×1,0 → ×1,3`, chip reset → `×1,0`.

---

## 3. AC2 — Ikon SVG asli

**Sebelum** (kritik pemain): ikon digambar oleh kode Python (`tools/ui/make_icons.py`
→ PNG 256 px → base64 → `game/assets/ui/icons.json`), dan prompt rotasi halaman web
memakai `<svg>` inline (kode HTML di dalam `index.html`).

**Sesudah**: 33 berkas **SVG nyata** di `game/assets/ui/icons/*.svg` (disalin juga ke
`assets/ui/icons/` untuk halaman web), dibuat `tools/ui/make_svg_icons.py`. Tiap berkas
berisi elemen vektor sungguhan:

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="128" height="128">
  <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#16213f"/><stop offset="1" stop-color="#0a1020"/></linearGradient></defs>
  <rect x="3" y="3" width="58" height="58" rx="14" fill="url(#g)" stroke="#35d0ff" stroke-width="3"/>
  <g fill="none" stroke="#eaf6ff" stroke-width="4" stroke-linecap="round" stroke-linejoin="round">…glyph…</g>
</svg>
```

Daftar id (33): `build check close command crate crosshair energy extractor factory
fleet fort grid hangar home info interceptor lock menu minerals minus planet play
plus quest reactor reset rotate settings shield timer turret upgrade warning`.

Pemuatan runtime (`game/scripts/ui/ui_theme.gd`):

* `UiTheme.get_icon(id, px = 128)` membaca **teks berkas SVG** dari PCK
  (`FileAccess.get_file_as_string("res://assets/ui/icons/<id>.svg")`) lalu meraster
  dengan `Image.load_svg_from_string(text, float(px) / 64.0)` (ThorVG).
* `icons.json` (PNG base64) **tetap ada hanya sebagai fallback**, dan sumber yang
  benar-benar dipakai **dilaporkan**: `UiTheme.icon_source()` → `"svg"` / `"png"` / `""`.
* Uji `icons.source_is_svg` memastikan **tidak ada** ikon yang jatuh ke fallback.
* `game/shell/index.html` + `index.html` (halaman web) memakai berkas
  `assets/ui/icons/rotate.svg` lewat `<img src=…>`; SVG inline dihapus.

Bukti runtime: suite `icons` + `tests` **442/0** di build **WebGL/ThorVG** (bukan
sekadar editor), plus makro-foto `docs/m37_3d_png/02_build_cards_1280x720.png` yang
menampilkan glyph SVG terasterisasi (bukan kotak).

---

## 4. AC3 — Elemen arena = PNG foto hasil chroma-key

### 4.1 Proses produksi

1. **Generate foto** ber-latar **magenta murni #FF00FF** (perintah pemain: "kamu
   generate foto dengan chromase"): `assets/arena/_raw/*_raw.png` 1024×1024 —
   `planet_gas_ringed` (planet gas bercincin), `moon_rocky` (bulan berkawah),
   `nebula_cluster` (nebula), `station_orbital` (stasiun orbit).
2. **Chroma-key** oleh `tools/art/chroma_key.py`:
   * Jarak warna Euclidean ke key: `d(P,K)`; `d < 55` → latar pasti transparan.
     (Versi pertama saya memakai skor sumbu `(max(r,b) − g)` — **salah**: badan
     planet biru/ungu ikut terhapus. Bug itu nyata dan sudah dilaporkan; jangan
     diulang.)
   * Pita tepi 3 px diberi alpha gradien `(d − 55)/(115 − 55)` + *despill*
     (un-mix terhadap warna key) supaya tidak ada halo magenta.
   * **Cleanup pasca-resize (baru, wajib)**: `Image.LANCZOS` 1024 → 512 mencampur
     ulang piksel transparan ber-warna-key di tepi dengan piksel isi → muncul
     kembali piksel setengah-transparan bernuansa key (temuan nyata:
     `station_orbital.png` 201 px magenta kuat di x=50 baris 10–17, `moon_rocky`
     halo di x=3). Karena itu despill diulang **setelah** resize:
     `alpha < 240 && d < 70` → transparan; `alpha < 250 && d < 130` → un-mix +
     despill. Piksel **opak** tidak disentuh (nebula memang berwarna magenta
     sebagai seni — menghapusnya = menghapus objek).
3. Hasil: 4 PNG RGBA, tepi dibersihkan 134–621 px/aset, disimpan ke
   `assets/arena/` **dan** `game/assets/arena/` (dipakai build).

| Aset | Ukuran | Latar dipotong | Tepi dibersihkan | Transparan | Bleed magenta |
|---|---|---|---|---|---|
| moon_rocky.png | 512×512 | 36,6 % | 163 px | 23,5 % | **0 px** |
| nebula_cluster.png | 512×497 | 47,5 % | 134 px | 16,2 % | **0 px** |
| planet_gas_ringed.png | 512×379 | 59,3 % | 228 px | 36,7 % | **0 px** |
| station_orbital.png | 512×360 | 69,5 % | 621 px | 48,4 % | **0 px** |

("Bleed" = piksel **tampak** setengah-transparan yang nyaris warna key; mustahil
berasal dari seni objek, jadi wajib 0 — diukur `tools/vision/verify_m37_3.py`.)

### 4.2 Pemakaian di game (bukan sekadar file di repo)

`game/scripts/base_scene.gd` menambahkan `_add_arena_sprite(id, world_w, pos)`:

```gdscript
var tex := load("res://assets/arena/%s.png" % id)
sprite.texture = tex
sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED      # selalu menghadap kamera
sprite.pixel_size = world_w / float(tex.get_width())      # ukuran dunia konsisten
QaMarkers.marker("ARENA", "PNG", {"id": id, "src": "png", …})
```

Jika PNG gagal dimuat, jatuh ke mesh lama **dan melaporkan jujur**
(`QA:ARENA:PNG … src=none`) — tidak ada klaim palsu.

Bukti runtime (gate `asset`, suite `asset` 17/0, 0 pageError):

```
  ARENA PNG: planet_gas_ringed dari PNG -> PASS
  ARENA PNG: moon_rocky dari PNG        -> PASS
  ARENA PNG: nebula_cluster dari PNG    -> PASS
  ARENA PNG: station_orbital dari PNG   -> PASS
```

Foto: `docs/m37_3d_png/00_arena_png_1280x720.png` (640×360 CSS @dpr2) dan
`01_arena_png_2340x1080.png` (780×360 CSS @dpr3) — planet bercincin, bulan,
nebula, dan stasiun terlihat di latar arena.

---

## 5. AC4 — Ukuran card dikecilkan

Standar yang dipakai (bukan asumsi): 1 CSS px = 1 dp, design px = dp × 2,
touch target ≥ 48 dp (UI_UX_DESIGN.md §7b), Design System M3.

| Komponen | Sebelum | Sesudah | Alasan |
|---|---|---|---|
| Tile katalog (BANGUN/ARMADA) | 152 px = 76 dp | **136 px = 68 dp** | keluhan "card masih terlalu besar"; 68 dp masih ≥ 48 dp target |
| Ikon di dalam tile | 70 % tile (53 dp) | **78 % tile (53 dp dari 68)** | art lebih dominan, aturan kritik #4 (tanpa label teks) |
| Tab kategori | 48 dp | 48 dp (tetap) | touch target minimum |
| Modal katalog | 544 dp | **512 dp** | standar dialog ≤ 560 dp, tetap di tengah |
| Kartu aksi HUD | 56×76 dp | **52×64 dp** | ikon 44 dp + label 11 dp, tetap ≥ 48 dp tinggi target |

Bukti: marker `CARD:SUMMARY {tile_px=136 tile_dp=68 icon_ratio=78 with_text=0
grid=…}` pada gate `ui` (4 cek M3 #5 tetap lulus: 0 tumpukan, card 68 dp), dan
foto `02_build_cards_1280x720.png`.

Catatan jujur: 68 dp adalah **kompromi terendah** yang masih memenuhi touch target
48 dp sekaligus menampilkan 16 tile katalog dalam satu layar 360 dp. Bila pemain
masih menganggapnya besar, angka ini bisa diturunkan lagi ke 64 dp (ikon 50 dp)
tanpa melanggar standar — keputusan ada di tangan pemain.

---

## 6. AC5 — "Bangun dll tidak bisa diklik": akar & perbaikan

### 6.1 Cara menguji (dan cara TIDAK menguji)

Kesalahan lama: mengklaim UI "bisa diklik" setelah memanggil method `press_build()`
langsung. Itu **bukan** membuktikan pemain bisa menekan tombol. Maka dibuat suite
baru **`?mode=input`** (`game/tests/e2e/input_showcase.gd`) yang:

* mencari tombol lewat **nama node nyata** (`get_node_or_null`), melewati
  `Control.visible` + area layar, lalu mengirim **event mouse sintetis** ke
  `Input.parse_input_event` (`InputEventMouseMotion` → hover, `InputEventMouseButton`
  pressed → released) pada koordinat **transform nyata** (`get_global_transform()`),
* memverifikasi hasilnya lewat state game (antrian, level, zoom, posisi kamera,
  visible) — bukan lewat pemanggilan API,
* **null-guard wajib**: memanggil method pada `null` di build web = crash SELURUH
  WASM (`RuntimeError: null function`, sisa suite hilang). Karena itu `_tap()`
  mengembalikan FAIL jujur, bukan crash (pernah terjadi dan sudah diperbaiki).

### 6.2 Dua bug nyata yang ditemukan

**(a) `_refresh_affordability` salah tipe → error tiap 0,5 s.**
`hud.gd` menulis `var b := _cards[id] as TextureButton` padahal kartu aksi
dibangun sebagai `Button` → `b == null` → `b.disabled = …` error terus-menerus,
dan karena error terjadi di tengah fungsi, **`_refresh_selection()` di baris
berikutnya tidak pernah dijalankan** sehingga panel detail menampilkan data basi
(pemain melihat "harga/biaya" yang tidak nyambung dengan seleksi). Diperbaiki:
cast ke `Button` + null-guard untuk id tanpa definisi.

**(b) Tombol BANGUN/PRODUKSI `disabled` = akar keluhan "tidak bisa diklik".**
Saat syarat belum terpenuhi (mis. kapal butuh **Hangar Pesawat** + dana panjang),
tombol di-nonaktifkan. Akibatnya tap pemain **tidak menghasilkan apa pun** — tidak
ada dialog, tidak ada pesan, tombol hanya "mati". Inilah yang pemain rasakan
sebagai "fungsinya masih banyak bug, tidak bisa diklik".

Perbaikan (aturan UX baru, berlaku untuk semua tombol aksi):

1. Tombol aksi **tidak pernah** `disabled` — selalu bisa ditap.
2. Tap yang gagal **wajib dijawab**: baris **SYARAT** di panel detail
   (`DetailRequirement`) + status di panel (`DetailStatus`) + **toast**
   `EventBus.ui_message(text, level)` → HUD `_show_toast()` + marker
   `QA:UI:MESSAGE level=warning text=…`.
3. Pesan menuntun, bukan sekadar menolak: "Butuh **HANGAR PESAWAT** — bangun dulu
   lewat BANGUN", "Dana kurang: butuh E100 M50".

### 6.3 Hasil suite `input` (klik nyata)

```
QA:INPUT:DONE passed=29 failed=0
```

Cek kunci (semua lewat event mouse nyata):

| Cek | Hasil nyata |
|---|---|
| `input.build_menu_terbuka_oleh_klik` | modal BANGUN terbuka via tap tombol HUD |
| `input.semua_kartu_dapat_diklik` | 8 tile katalog ditap satu per satu → semua menjawab (status berubah) |
| `input.klik_bangun_masuk_antrian` | tap BANGUN → antrian konstruksi 0 → 1 |
| `input.hangar_masuk_antrian` | tap kartu Hangar + BANGUN → antrian 1 → 2 |
| `input.klik_produksi_terjawab` | tap PRODUKSI → antri **ATAU** alasan tampil di UI/toast |
| `input.toast_alasan_ditolak` | `QA:UI:MESSAGE level=warning` muncul saat syarat kurang |
| `input.tap_arena_memilih_bangunan` | tap bangunan di arena → seleksi `command_core_1` |
| `input.klik_upgrade_menaikkan_level` | tap UPGRADE → Lv 1 → 2 |
| `input.drag_kamera_menggeser_fokus` | drag → pan (0,0) → (6,72; 2,24) |
| `input.klik_zoom_mengubah_kamera` | tap + → zoom ×1,0 → ×1,3; chip reset → ×1,0 |
| `input.pause_menu_terbuka_oleh_klik` / `_tertutup` | tap MENU → pause; tap LANJUT → tutup |

Gate `run_game_check.sh input` menambahkan 10 baris `INPUT CHECK` (termasuk
"aksi ditolak SELALU dijawab toast") dan regresi unit: `bm.button_always_tappable`,
`bm.press_answered_without_funds`, `bm.reason_shown_in_ui`, `bm.reason_toast_emitted`,
`sm.*` (5 cek serupa) → tests **442/0**.

---

## 7. Ringkasan verifikasi (semua dijalankan ulang setelah perubahan terakhir)

| Gate | Hasil |
|---|---|
| `tests` (unit+integrasi, WebGL) | **442 / 0** PASS |
| `input` (klik nyata, suite e2e baru) | **29 / 0** di dalam suite; **10/10** cek gate |
| `camera` (M3 #6, regresi) | **12 / 12** PASS |
| `asset` (+4 cek ARENA PNG) | 17 / 0 suite, **4/4** PNG PASS |
| `ui` (M3 #5, regresi + card 68 dp) | PASS (0 suite FAIL) |
| `all` (seluruh suite sekaligus) | **0 suite FAIL** |
| `verify_m37_3.py` (piksel + marker dari 6 foto) | **56 / 56** PASS |

Foto bukti: `docs/m37_3d_png/00…05` (arena 1280×720@2, arena 2340×1080@3, kartu
BANGUN, HUD arena, alur klik, portrait 1080×2340@3).

---

## 7b. Temuan tambahan saat inspeksi foto portrait (dan perbaikannya)

Inspeksi foto `05_build_cards_portrait_1080x2340.png` menemukan **celah nyata yang
belum masuk daftar kritik**: rotate prompt (aturan pemain "portrait ditangani")
hanya ada di halaman depan `index.html`, sedangkan **shell build game**
(`game/shell/index.html` → `web/index.html`) tidak punya penanganan portrait
sama sekali. Akibatnya, siapa pun yang membuka build langsung (preview/embed)
dalam posisi portrait melihat **HUD landscape terpotong kiri-kanan tanpa
penjelasan** — bukan pesan "putar perangkat".

Perbaikan (kecil, aman, langsung diuji):

1. `game/shell/index.html` kini memuat rotate prompt yang sama, dengan ikon
   **berkas SVG asli** `assets/ui/icons/rotate.svg` (bukan SVG inline/kode HTML),
   muncul lewat CSS `@media (max-aspect-ratio: 1/1)`.
2. `run_game_check.sh` menyalin `rotate.svg` ke build dir **dan** `web/assets/ui/icons/`
   supaya berkasnya benar-benar ada di preview (bukan 404).
3. Shell mencatat bukti jujur `QA:ROTATE:PROMPT aspect=… viewport=…` hanya bila
   prompt memang tampil.
4. Verifier menambah 3 cek portrait: marker prompt ada, teks/ikon cyan muncul di
   pita tengah, dan **tepi kiri bersih** (tidak ada HUD terpotong).

Bukti setelah perbaikan:

```
05 portrait 1080×2340 @dpr3 → QA:ROTATE:PROMPT aspect=0.46 viewport=360x780
00 landscape 1280×720 @dpr2 → tidak ada marker prompt (tersembunyi), 4 marker PNG arena, 0 error
```

## 7c. Verifikasi margin HUD dari foto (dijalankan, bukan asumsi)

Kekhawatiran "chip atas terpotong" pada foto 1280×720 **tidak terbukti**: pengukuran
piksel pada `02_build_cards_1280x720.png` (dpr 2) menunjukkan chip kiri-atas mulai
pada **baris y = 32 px = 16 dp** dan panel kiri mulai **kolom x = 32 px = 16 dp** —
tepat margin standar 16 dp (UI_UX_DESIGN §7b). Jadi tata letak atas sudah benar;
yang tampak "terpotong" hanya efek visual karena modal katalog menutupinya.

## 8. Yang BELUM / jujur terbuka

1. **Keputusan ukuran card ada di pemain.** 68 dp = titik terendah yang masih
   memenuhi touch target 48 dp untuk grid 16 tile. Bila masih terasa besar, saya
   tunggu arahan (mis. 64 dp atau grid lebih rapat).
2. **Ikon SVG di-raster saat pertama diminta** (`Image.load_svg_from_string`)
   lalu di-cache. Biaya raster per ikon kecil (< 1 ms), tapi ini bukan vektor GPU —
   bila nanti butuh ikon skala mulus tanpa raster, jalur `Texture2D` SVG milik
   Godot 4.4+ perlu evaluasi ulang. **UNKNOWN**: saya belum mengukur biaya raster
   kumulatif untuk 33 ikon pada perangkat kelas bawah.
3. **Nebula menyisakan 434 piksel opak dekat warna key** (0,17 %) — itu bagian
   seni magenta nebula, bukan sisa chroma. Tidak dihapus dengan alasan di §4.1.
4. **Foto bukti memakai build WebGL + SwiftShader**, bukan GPU nyata: artefak
   kompresi/filter WebGL headless bisa berbeda dari perangkat nyata. Klaim visual
   valid untuk tata letak/ukuran, tidak untuk kualitas filter tekstur di perangkat.
