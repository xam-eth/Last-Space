# M3.6 — Resolusi & Design System (mobile-first ANDROID, berbasis standar)

Tanggal: 2026-10-12. Branch: `arena/d80e2902-last-space`.
Status: **VERIFIED** — gate 8/8 suite PASS exit 0; `verify_m36.py` **30/30 PASS**
(6 device class); `verify_ui_m3.py` tetap **20/20 PASS**; record per frame PASS.

## Kritik user (diterima, jujur)

"Resolusi masih salah, component design system kurang tepat dan size
komposisinya tidak sesuai, terlalu besar; loading design masih vertikal harusnya
landscape; cari tahu mobile-first Android size dan standar resolusi, bukan
asumsi."

Klarifikasi jujur yang dilaporkan: komposisi loading sesungguhnya **sudah
landscape** (bottom bar satu baris) sejak revisi 2026-10-11 — foto lama
(`ui_full.png`) sempat menampilkan loading mid-fade di atas game. Tapi kritik
lainnya **benar dan terukur** (lihat temuan di bawah). Metode: riset standar
resmi dulu (Android/Material/Godot), ukur build nyata, baru perbaiki.

## Standar yang dipakai (riset — dikutip, bukan asumsi)

| # | Sumber | Angka yang dipakai |
|---|---|---|
| 19 | Material Spacing/Metrics | 8dp grid (dan 4dp micro), **edge margin 16dp**, touch target 48dp, jarak 8dp, app bar 56dp |
| 20 | Android Screen support | dp density-independent (mdpi 160dpi = 1dp:1px), bucket ldpi 0,75× → xxxhdpi 4×, layout fleksibel |
| 21 | Material 3 touch targets | tombol min **48dp** (label 14–16pt), jarak ≥8dp |
| 22 | Material 3 type scale | labelSmall 11 / bodySmall+labelLarge 12 / bodyMedium 14 / bodyLarge+title 16 / titleLarge 22 / headline 22–32 |
| 23 | Material dialogs | max-width dialog 560dp |
| 24 | Android games large screens | landscape wajib ≥16:9, dianjurkan 21:9/16:10/3:2 |

Source Godot 4.7.2 (VERIFIED, bukan tebakan):
`platform/web/js/libs/library_godot_display.js:238` →
`godot_js_display_pixel_ratio_get()` mengembalikan `window.devicePixelRatio`;
`screen_get_dpi()` = `devicePixelRatio × 96` (baris 354). Dipakai untuk formula
skala HUD.

## Temuan audit (dari build nyata, terukur)

1. **Skala HUD tidak sesuai standar dp.** Sebelumnya `scale = tinggi_window /
   720` ("match-height"). Di device dengan dp tinggi ≠ 360 (tablet/desktop/
   foldable/landscape rendah) komponen membesar/melebar melebihi standar dp —
   inilah "size komposisi tidak sesuai, terlalu besar". Contoh nyata: capture
   CSS 640×360 @dpr2 (device 1280×720) → skala 0,6 → tombol 58 device px
   (29dp) di device 360dp; dan di desktop 1280×720 CSS → skala 1,0 → komponen
   2× dp seharusnya.
2. **Teks di bawah minimum.** HUD: chip label & quest % = 16–18 design px
   (8–9dp); modal: kategori/status 18 (9dp). Standar minimum Material 11dp.
3. **Tombol sekunder 40dp** (close modal build/ship/pause, tombol menu ☰) —
   di bawah minimum 48dp.
4. **Modal melebihi max-width dialog.** Build/ship menu 1024 = 512dp > 560dp?
   (masih di bawah, tapi M3.5 melebar 308-card → isi terpotong) — hasil foto
   menunjukkan **teks card terpotong** ("Ekstraktor Mineral", "Generator
   Perisai"), **detail panel terpotong** dan **tombol BANGUN meluber keluar
   modal** (isi detail lebih tinggi dari panel).
5. **Chip HUD tertutup dim modal** saat memilih bangunan (pemain kehilangan
   konteks biaya).
6. **Loading page**: komposisi sudah landscape, tetapi ukuran px tetap (ikon
   72px, judul 32px, bar 320px) → terlalu besar di ponsel landscape rendah
   (CSS tinggi 360 → ikon 72px = 20% tinggi layar) dan terlalu kecil relatif
   di layar besar; emoji (🚀🔧) tidak dirender di SwiftShader/beberapa platform;
   scrim kurang gelap di pita bawah → teks status tenggelam di slide terang.
7. **Tidak ada penanganan portrait** (kritis: mobile-first berarti ponsel bisa
   dibuka portrait dulu).

## Perbaikan (semua terverifikasi)

**A. Skala HUD = standar dp (bukan match-height).**
`hud.gd::_apply_design_frame`: `scale = dpr / 2` (design px = dp × 2), dengan
`dpr = DisplayServer.screen_get_scale()` (web = `window.devicePixelRatio`,
VERIFIED dari source Godot). clamp 0,5–3,0. Nilai dpr + viewport dicetak di
marker `QA:HUD:LAYOUT` (`dpr[...]`) untuk audit.

**B. Token & komponen sesuai standar.**
- Margin tepi 12dp → **16dp** (Material); top bar top offset 6dp → **16dp**
  (aman notch/status bar).
- Chip 110×36dp → **118×48dp** (tinggi = bar 48dp = touch target).
- Tombol sekunder 40dp → **48dp** (semua: close modal ×3, tombol ☰).
- Spacing non-grid (2/4/6/12px → 8/16px) dirapikan ke kelipatan 4/8dp.
- Quest panel 116dp → **144dp** (teks standar + 4 baris).

**C. Type scale standar (tidak ada teks < 11dp).**
HUD: chip label/level/quest % = 11dp; quest nama/efek/modal item = 12dp;
status/toast/wave/result = 14dp; nilai chip = 16dp; judul detail = 15–17dp.
Modal: nama card 12dp, biaya/jumlah 11dp, kategori 11dp, efek 12dp, biaya
detail 13dp, judul detail 15dp. Loading (CSS): ikon 40–64dp, judul 20–34dp,
status 12–16dp, persen 13–20dp, bar 160–360×6–10dp (semua `clamp()`).

**D. Layout modal diperbaiki dari hasil hitung (bukan asumsi).**
Modal 1088×544 (**544×272dp < max-width dialog Material 560dp** — terukur dari
foto: 1086 device px = 543dp @dpr2). Konten: grid 2 kolom 332 (166dp) + detail
360 (180dp); card 332×128 → area teks 204px, nama panjang **autowrap 2 baris**
(tidak terpotong lagi); detail panel spacing 4dp + ikon 32dp + tombol 44dp →
total konten 364px ≤ 392px panel (**tidak meluber** — temuan #4 diperbaiki);
status detail hanya tampil saat ada pesan.
**Strip resource di baris judul modal** ("ENERGI 300/1000 MINERAL 150/500") —
pemain tetap tahu sumber daya saat memilih (temuan #5).

**E. Loading page landscape + responsif dp.**
Bottom bar satu baris (brand kiri, bar+persen kanan) dengan ukuran `clamp()`
vh/vw dalam rentang dp; **scrim gradient bawah** (0,92 → 0,18 → 0,45) untuk
kontras; **safe-area** `env(safe-area-inset-*)` untuk notch; semua emoji
diganti teks/SVG.

**F. Rotate prompt portrait (baru).**
`#rotate-prompt` (CSS `@media (orientation: portrait)`) menutup layar:
ikon SVG ponsel portrait → panah → ponsel landscape, judul "Putar ke
LANDSCAPE", subteks "Last-Space didesain mobile-first landscape (16:9–21:9)."
(standar game landscape [24]).

**G. Harness QA = device class emulation.**
`capture.mjs`/`record.mjs` dapat `--dpr` (deviceScaleFactor); output PNG =
CSS × dpr; report memuat `cssViewport` + `devicePixelRatio`. `run_game_check.sh`
kini capture **CSS 640×360 @dpr2** (device class ponsel 16:9 360dp) — bukan
lagi 1280×720 CSS yang sebenarnya ≈ desktop 720dp. Handshake `QA:DPR:` di
shell/root page sebagai bukti device class per run.

## Verifikasi (data nyata)

- **Gate `run_game_check.sh all`: 8/8 suite PASS, exit 0** — tests 285/0,
  e2e 36/0, game, asset 17/0, sim 12/0, stress 8/0, ui, perf 3×8/0.
- **`tools/vision/verify_m36.py`: 30/30 PASS** → `docs/m36_visual/verify_m36.json`
  - loading landscape 16:9 & 19.5:9: ≥94% elemen cyan di pita bawah; ada di
    kiri (judul) & kanan (bar/persen)
  - rotate prompt portrait: cyan 5237 px, y rata-rata 0,49 (tengah), 0% bar
  - aset slide: 5 file, rasio 1,79 (landscape)
  - HUD **6 device class**: `scale = dpr/2` (2→1,000; 3→1,500; 1→0,500);
    margin 16,0dp; top bar 48,0dp; tombol aksi 48,0dp — semuanya persis.
- **`verify_ui_m3.py` (M3 #1–#3): 20/20 PASS** dengan evidence final
  (modal 544dp, border cyan di posisi baru @1280 & @2340, top bar full-width).
- **Record per frame** (`record_game/`): 20 frame @1,0 fps, **0 blank 0
  invalid**, motion rata-rata 2,00, scene `gameplay` → `command_hud` → PASS.
- **Foto** (`docs/m36_visual/`): loading landscape 16:9/19.5:9/21:9, portrait
  (rotate prompt), HUD 4 device class. `docs/ui_m3_build_menu/` 9 foto
  (M3 #1–#3) **di-capture ulang** dengan layout M3.6 (teks utuh, tombol di
  dalam modal, strip resource terlihat).

## Catatan jujur / blocker

- **dpr di headless Chromium**: `JavaScriptBridge.eval("window.LS_DPR")`
  mengembalikan `null` di build ini (terlihat di dump `jsDpr[<null>]`) — maka
  skala HUD memakai API resmi Godot (`screen_get_scale`), sedangkan `LS_DPR`
  tetap dicetak halaman sebagai bukti device class. Tidak ada workaround palsu.
- `devicePixelRatio` di Chromium headless = CSS device scale factor (bukan
  density fisik layar) — untuk QA device class ini justru yang diinginkan.
- Foto UI = SwiftShader software rendering; angka fps di folder record
  (1,0 fps @CSS 640×360) adalah batas renderer perangkat lunak, bukan device.

## Berikutnya

Roadmap lanjut: **M3 #4 Main menu** (Play/Pengaturan) atau M3 #6/#7.
Kandidat polish berikut: ikon SVG 2D untuk tombol aksi (saat ini PNG raster),
animasi transisi modal/dialog, dan UI_UX_DESIGN mockup §3 yang masih memakai
label lama (ENERGI/ARMADA sudah sesuai, teks mockup lama belum di-update).
