# UI/UX DESIGN — Last-Space

> **Alur & mekanisme gameplay (a–z, scene per frame, komponen & logika):**
> lihat **`GAMEPLAY_FLOW.md`** (dibuat 2026-10-11 setelah research reference
> UI/UX Doomsday: Last Survivors + pembacaan ulang `Game_Concept.md`).

Dokumen ini menetapkan **design system UI/UX game** — direvisi total
(2026-10-10) sesuai feedback human developer: **mobile-first landscape 16:9
full screen**, semua komponen layout design system berada **di atas gameplay
arena**, dengan referensi langsung ke design system game mobile landscape
(lihat §7 Referensi).

> **Catatan human developer (tercatat):** game ini **bukan game "asal jalan"** —
> UI/UX dan visualnya harus real game. Loading screen, menu, dan HUD harus
> terasa seperti game sungguhan, bukan placeholder.

---

## 1. Prinsip Desain (mobile-first landscape)

1. **Mobile-first, landscape, full screen — SEMUA aspek layar.** Game
   didesain untuk **ponsel dipegang landscape full screen**, bukan hanya
   16:9: mayoritas Android modern = **19.5:9 / 20:9** (bukan 16:9). Root
   viewport = window aktual (project.godot `viewport 0×0`) + stretch
   `canvas_items` + aspect **`expand`** → full screen **TANPA letterbox /
   black bars** di semua aspek (16:9, 19.5:9, 20:9, 21:9). HUD = **full-rect**
   (isi penuh window), zona di-anchor ke edge window (TopBar kiri/kanan,
   ActionGrid kanan-bawah, InfoPanel kiri-bawah) dengan ukuran fisik komponen
   tetap (scale match-height) — konsisten di semua device.
   *Koreksi fatal (2026-10-11, dari feedback human): sebelumnya "keep" +
   HUD di dalam kanvas 16:9 → black bars besar kiri-kanan + HUD tidak full
   width di 19.5:9/20:9. Diperbaiki + diverifikasi data nyata: HUD:LAYOUT di
   1280×720 / 1920×1080 / 2340×1080 / 2400×1080 / 2560×1440 (margin = 12dp
   fisik, komponen 48dp, zona di edge) + screenshot `res_before_*` vs
   `res_after_*` di `tools/godot/build/`.*
2. **Semua komponen = overlay di atas gameplay arena.** Arena (3D base +
   armada + battle) selalu di **center** dan bersih — tidak ada komponen yang
   menutupi center (center focus zone, referensi §7 [1]).
3. **Thumb zone ergonomics.** Aksi utama di **kanan-bawah** (thumb kanan,
   mayoritas pemain right-handed), info sekunder di **kiri-bawah**, info
   prioritas di **atas** (referensi §7 [2][3][5]).
4. **Tema: military command holographic** — panel taktis gelap translusen,
   garis tipis, aksen cyan hologram, indikator ancaman merah. Konsisten dengan
   `ART_DIRECTION.md`.
5. **Real values** — UI menampilkan nilai aktual dari sistem (read-only),
   tidak pernah mengarang angka (DATA_CONTRACTS.md §1).
6. **Satu design system** — token (warna, ukuran, spacing, komponen, ikon)
   yang sama di semua layar; diimplementasi di HUD in-game (`hud.gd`) dan
   dipakai ulang untuk layar berikutnya (menu, map, settings).

## 2. Layout Zone di atas Gameplay Arena

Kanvas **1280×720** (design resolution mobile-first, 16:9). Semua komponen
di-anchor ke sisi/pojok (bukan koordinat absolut), sehingga konsisten di
semua ukuran dalam frame 16:9.

```
┌──────────────────────────────────────────────────────┐  y=0
│ TOP BAR (h=96, margin 24)                            │
│ [⚡ ENERGY 450/1000 ▮] [⛏ MINERALS ▮] [🚀 FLEET 6]  │  y=12..108
│                          │  WAVE 1 — 120  │  [☰]      │
├──────────────────────────────────────────────────────┤
│  ┌─ TOAST (top-center, auto-hide 5s) — battle ─────┐  │  y=120..184
│                                                  │
│           GAMEPLAY ARENA — CENTER CLEAR          │
│           (base 3D + armada + battle view)       │
│                                                  │
│  ┌─ INFO PANEL ─┐                       ┌────────┐ │
│  │ status/log   │                       │ ACTION │ │  y=528..696
│  │ (kiri-bawah) │                       │ GRID   │ │
└──────────────────────────────────────────────────────┘  y=720
```

| Zone | Posisi (anchor) | Ukuran | Isi | Prioritas |
|---|---|---|---|---|
| **Top Bar** | top, full width − margin 24 | h=96 | Resource chips (Energy/Minerals/Fleet) kiri; indikator wave tengah; tombol menu kanan | Tinggi (sering dilihat) |
| **Toast** | top-center, y=120 | 640×64 | Hasil battle / territory unlocked — auto-hide 5s | Tinggi (event) |
| **Info Panel** | bottom-left, margin 24 | 460×168 | Status aksi berjalan + log (kiri = info sekunder, §7 [1]) | Medium |
| **Action Grid** | bottom-right, margin 24 | 4 kolom × 112px, gap 12 | Tombol ikon aksi: build bangunan + Interceptor (thumb zone kanan, §7 [2][3]) | **Utama (aksi)** |
| **Arena (center)** | — | sisa frame | Gameplay 3D — **CLEAR, tidak ada komponen** | Fokus utama |
| **Right edge (reserved)** | right, di atas action grid | TBD | Minimap (M2+ — placeholder zone, tidak diimplementasi) | — |

**Aturan penempatan (dari referensi §7):** action safe 95% dari tepi, title
safe 90% — semua komponen dalam margin 32px canvas; aksi primer di thumb zone
kanan-bawah; informasi yang sering dilihat di atas dan kiri; center = gameplay
([1] gameuxmasterguide 9-zone grid; [2] Boostroom MLBB thumb zones;
[3] Medium MLBB thumb zone; [5] PR quranic-strategy safe-area + rail landscape).

## 3. Design Tokens (konsistensi ukuran)

Semua nilai di bawah = **token** (konstan), dipakai bersama oleh HUD
(`game/scripts/ui/hud.gd`) dan komponen lain. Tidak ada angka "asal".
**M3 #4:** token warna/radius/ukuran/type-style dipusatkan di
`game/scripts/ui/ui_theme.gd` (`class_name UiTheme` — `panel_box`, `button_box`,
`style_button`, `ls` (LabelSettings), `apply_design_frame`) supaya layar baru
tidak menyalin konstanta; layar M3 #4 (main menu) memakai token ini, layar
M3 #1–#3 memakai nilai identik (migrasi menyusul di DEV_PLAN).

### 3.1 Spacing & grid
- Semua ukuran dalam **dp (Android density-independent pixel)**; design canvas
  1280×720 = **640×360dp** → **1 design px = 0,5dp** (px = dp × 2). Standar
  Android: screen referensi 360×640dp (16:9) — landscape = 640×360dp
  (referensi §7 [13]).
- Base grid **8dp**; semua spacing = kelipatan 8dp kecuali micro-gap 4dp
  (Material: padding dalam kelipatan 8dp atau 4dp [22]). `MARGIN = 32px` (16dp)
  — standar mobile edge margin Material [19]; aman untuk notch/status bar.
- **Formula skala dp (M3.6, standar bukan asumsi)**: di Android/browser modern
  **1 CSS px = 1 dp** (spec density-independent [20]); device px = CSS px ×
  `devicePixelRatio` (dpr). Design px = dp × 2 (canvas 1280×720 = 640×360dp,
  referensi xhdpi). Maka **scale = dpr / 2** — komponen berukuran TETAP dalam
  dp di semua device (implementasi: `hud.gd::_apply_design_frame`; dpr dibaca
  dari `DisplayServer.screen_get_scale()` = `window.devicePixelRatio`, VERIFIED
  dari source Godot 4.7.2 `platform/web/js/libs/library_godot_display.js:238`).
  Koreksi M3.6: sebelumnya skala = tinggi_window/720 → di tablet/desktop besar
  komponen ikut membesar melebihi standar dp ("terlalu besar").
- **Device class yang diverifikasi** (QA + foto, `docs/m36_visual/`):

| Device class | CSS px (= dp) | dpr | Device px | scale | Tombol aksi |
|---|---|---|---|---|---|
| Ponsel 16:9 xhdpi | 640×360 | 2 | 1280×720 | 1,000 | 48dp |
| Ponsel 19.5:9 xxhdpi | 780×360 | 3 | 2340×1080 | 1,500 | 48dp |
| Ponsel 21:9 xxhdpi | 840×360 | 3 | 2520×1080 | 1,500 | 48dp |
| Desktop 16:9 1x | 1280×720 | 1 | 1280×720 | 0,500 | 48dp |

- `GRID_GAP = 16px` (8dp) — antar komponen/tombol (minimum Material 8dp,
  referensi §7 [13][14]).

### 3.2 Touch targets (mobile-first)
- Tombol aksi: **96×96** design px = **48dp** — touch target minimum/optimal
  Material (48–56dp optimal, referensi §7 [13][14]). Di ponsel xxhdpi (3×,
  tinggi fisik 1080px = 360dp): 96px × (1080/720) = 144px fisik = **48dp**
  persis — ukuran fisik sama di semua device (HUD di-scale match-height, §6).
- Semua tombol (aksi, tutup modal, chip ikon) = **96×96 (48dp)** — M3.6:
  tombol sekunder 40dp dinaikkan ke minimum 48dp (temuan audit vs [21]).
- Chip resource: **236×96 (118×48dp)** — read-only; tingginya disamakan dengan
  top bar & touch target supaya top bar = satu baris 48dp penuh (rapi).
- Jarak antar target = 16px (8dp) — sama dengan minimum Material (referensi
  §7 [13][14]).

### 3.3 Ukuran komponen
| Token | Nilai (px = dp×2) | Komponen |
|---|---|---|
| `TOP_BAR_H` | 96 (48dp) | Top bar |
| `CHIP_W × CHIP_H` | 220 × 72 (110×36dp) | Resource chip |
| `BTN` | 96 (48dp) | Tombol aksi (ikon-only; nama+biaya di tooltip) |
| `GRID_GAP` | 16 (8dp) | Gap action grid |
| `GRID_COLS` | 4 | Action grid (2 baris untuk 7 aksi; tinggi grid 208px = 29% tinggi canvas) |
| `INFO_W × INFO_H` | 420 × 140 (210×70dp) | Info panel |
| `TOAST` | 560 × 56 (280×28dp), y=120 | Toast (auto-hide 5s) |
| Progress bar | h=6, radius 3 | Di dalam chip |
| `QUEST_W × QUEST_H` | 440 × 288 (220×144dp) | Quest panel (kiri tengah) |
| `SEL_W × SEL_H` | 560 × 140 (280×70dp) | Selection panel (bawah tengah, M3 #1) |
| Modal | 1088 × 544 (544×272dp) | Build + Ship menu, anchor center semua aspek; **544dp < max-width dialog Material 560dp** [23]; terukur dari foto |
| Card (grid modal, M3.6) | 332 × 128 (166×64dp) | ikon 48dp kiri + nama 12dp 2-baris + biaya 11dp + jumlah 11dp |
| Detail panel (M3.6) | 360 (180dp) | ikon 32dp + nama 15dp + kategori/efek 11–12dp + biaya 13dp + tombol 44dp — konten dihitung agar TIDAK meluber (temuan foto) |
| Tombol besar modal | tinggi 96 (48dp), lebar penuh panel detail | BUILD/UPGRADE |
| Modal pause | 480 × 360 (240×180dp), anchor center | Pause menu (M3 #3): RESUME 56dp / SETTINGS 48dp / MAIN MENU 48dp |

### 3.4 Palet warna
| Token | Warna | Penggunaan |
|---|---|---|
| `bg` | `#05070f` | Latar belakang utama (deep space) |
| `panel` | `#0b1020` @ 78% | Panel/kartu (translusen — arena terlihat) |
| `border` | `#35d0ff` @ 55% | Garis tepi panel (cyan hologram) |
| `text` | `#eaf6ff` | Teks utama |
| `muted` | `#9fb3cc` | Teks sekunder / unaffordable |
| `accent` | `#35d0ff` | Aksen cyan (fokus, toast territory) |
| `danger` | `#ff5c5c` | Ancaman / battle kalah / wave incoming |
| `warn` | `#ffb84d` | Energy / peringatan |
| `ok` | `#4dff88` | Sukses / battle menang |
| `energy` | `#ffb84d` | Resource energy |
| `minerals` | `#c7b58a` | Resource minerals |

### 3.5 Tipografi — type scale standar (M3.6: tidak ada teks < 11dp)
Material 3 type scale [22] dipetakan ke design px (dp × 2). **Semua teks ≥ 11dp**
(temuan audit M3.6: sebelumnya ada teks 8–9dp — di bawah minimum terbaca):

| Peran | Material | dp | design px | Dipakai di |
|---|---|---|---|---|
| labelSmall | 11sp | 11 | 22 | chip label, progress %, level, kategori, biaya kecil |
| bodySmall | 12sp | 12 | 24 | nama quest, efek, stats, item modal |
| labelLarge | 12sp | 12 | 24 | nama card |
| bodyMedium | 14sp | 14 | 28 | status, result, toast, wave |
| bodyLarge | 16sp | 16 | 32 | nilai chip (value) |
| titleMedium | 16–17sp | 16–17 | 32–34 | judul detail, nama selection |
| titleLarge | 22sp | 22 | 44 | judul modal (BANGUN/ARMADA/DIJEDA) |
| headline | 22–24sp | 22–24 | 44–48 | tombol utama modal |

- **HUD/angka:** font bawaan Godot via `LabelSettings`, semua dengan shadow +
  outline (kontras di atas arena). Tidak ada label pada tombol aksi (ikon-only —
  label terbukti meng-inflate tinggi cell); nama + biaya ada di tooltip.
- **Loading page (CSS):** ukuran responsif `clamp()` dalam rentang dp standar —
  ikon 40–64dp, judul 20–34dp, status 12–16dp, persen 13–20dp, bar 6–10dp.
- Semua label punya **shadow + outline** (kontras di atas arena apa pun).
- Judul (loading/menu): sans-serif bold, letter-spacing lebar (military).

## 4. Komponen Standar

| Komponen | Spesifikasi | Dipakai di |
|---|---|---|
| **Resource Chip** | Panel 220×72 (36dp), radius 16, border cyan; [ikon 40 | label 18 muted + value 28] + progress bar 6 (warna resource); nilai = aktual/cap dari `Economy` | Top bar (Energy, Minerals, Fleet) |
| **Action Button** | TextureButton **ikon-only 96×96 (48dp)**, icon design system §5, label sengaja tidak ada (label di dalam/atas tombol terbukti meng-inflate tinggi cell — evidence `QA:HUD:LAYOUT` cells 96×126/157 sebelum fix); nama + biaya ada di **tooltip** (hover/long-press); affordable = penuh, **unaffordable = modulate redup** (data: `Economy.can_afford`) | Action grid (build + Interceptor) |
| **Info Panel** | Panel 420×140 (70dp), radius 16; status (24) + result (26, accent); `mouse_filter = IGNORE` (tidak blok arena) | Kiri-bawah |
| **Toast** | Panel 560×56 top-center (y=120), border accent/ok/danger sesuai event; auto-hide 5s (token waktu, tidak tumpang tindih) | Battle result, territory |
| **Top Bar** | h=96 (48dp), margin 24 (12dp); HBox: chips kiri, wave label tengah (danger saat ada wave), menu button kanan (80 = 40dp) | Atas |
| **Panel (umum)** | `panel` bg 78%, border 2px, radius 16, content margin 16 | Semua panel |
| **Progress Bar** | h=6, radius 3, bg hitam 45%, fill = warna resource/aksi | Chip |

Semua komponen: **read-only terhadap state** (nilai dari sistem), interaksi
memanggil API sistem yang sama dengan gameplay (`ProductionSystem.enqueue_*`).

## 5. Icon Design System

Referensi: satu simbol + fokus jelas + kontras tinggi + **terbaca di 32px**
([7] Retrostyle; [8] CrazyOyster); gaya badge rounded-square glossy untuk
tombol UI game mobile ([9] iStock); taksonomi gaya (line/flat/glyph/rounded)
([10] Iconscout) — kita pilih **glyph flat di atas badge rounded-square**.

**Spesifikasi:**
- Kanvas 1024×1024 → export **256×256 PNG** (power-of-two).
- **Badge:** rounded-square (radius ~18%), gradient vertikal navy
  (#1e3052 → #090e1e), outline ganda (dark 26px luar + cyan 8px dalam),
  gloss highlight atas (blur).
- **Glyph:** satu simbol, warna near-white #eaf6ff + shadow offset (kontras).
- **Generator:** `tools/ui/make_icons.py` (PIL, reproducible). Source PNG ke
  `assets/ui/icons/`; runtime `game/assets/ui/icons.json` (semua ikon embedded
  base64 — build wasm tidak punya loader .png saat runtime; decode via
  `Image.load_png_from_buffer`, pola sama dengan pilot asset SHP-001).

**Daftar ikon (12):** `energy` (bolt), `minerals` (crystal), `fleet` (ship),
`command` (star), `reactor` (atom), `extractor` (pickaxe), `hangar` (hangar),
`turret` (cannon), `shield` (shield), `interceptor` (jet), `menu` (gear),
`warning` (triangle).

**Naming:** `snake_case`, 1:1, dipakai di HUD via `_icon_map` (id bangunan →
ikon). Ikon baru: tambah glyph di generator + entry di `_icon_map`.

## 6. Screen Consistency & Safe Area (mobile-first ANDROID — berbasis riset, bukan asumsi)

**Standar yang dipakai (referensi §7 [13]–[18]):**
- **Screen referensi Android: 360×640dp (16:9)** — screen paling umum di
  Android 16:9; landscape = **640×360dp** [13].
- **Design canvas = 1280×720 px = 640×360dp @2x** (1px = 0,5dp) — design
  resolution untuk game vector/3D: "1280×720 for vector art project" [16];
  "design once for the lowest (logical) resolution, scale up" [18].
- **Touch target 48dp** minimum (48–56dp optimal) [13][14]; **8dp grid** [13];
  **chip 32–40dp** [14]; label tombol 48dp = 14–16pt [13].
- **Full screen di semua aspek**: "adapt resolution at runtime + anchor UI
  objects" [16]; untuk 3D, adaptasi aspek = matriks perspektif kamera (otomatis
  di Godot) [17].

**Implementasi (VERIFIED dari source Godot 4.7.2 `scene/main/window.cpp:1328`
— `content_scale_size == 0` → root viewport = window size):**
- `project.godot`: `viewport_width=0`, `viewport_height=0` → **root viewport
  ADAPTIF = ukuran window aktual** — game **full screen tanpa letterbox** di
  semua device (16:9 desktop, 18:9–21:9 Android). Kamera 3D mengikuti aspek
  window (lebih lebar = lebih banyak arena terlihat).
- **HUD = design frame 1280×720** (640×360dp) di-scale **uniform by device
  density** (M3.6): `scale = dpr / 2` (`hud.gd::_apply_design_frame`, re-apply
  saat `size_changed`; dpr = `DisplayServer.screen_get_scale()`). Semua device
  → komponen TETAP dalam dp: ponsel 1080p xxhdpi (dpr 3) tombol 96 design px =
  144 device px = **48dp**; desktop dpr 1 = 48 device px = 48dp (tidak
  membesar). Verifikasi: `tools/vision/verify_m36.py` (22 cek) membandingkan
  dump `QA:HUD:LAYOUT` build nyata di 4 device class — lihat `docs/m36_visual/`.
- **Margin aman 24px (12dp)** di semua sisi design canvas (action safe 95% /
  title safe 90%, referensi [1]) — aman untuk notch/rounded corner;
  `viewport-fit=cover` + full-screen CSS di root page.
- **Root page (`index.html`)**: viewport `width=device-width,
  initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover`;
  CSS full-screen (no scroll/bounce/zoom, `touch-action: none`); canvas
  `canvasResizePolicy: 2` (canvas isi window).
- **Orientasi: landscape saja** (dikunci di GDD — referensi [4]: "lock the
  orientation in the GDD"). **Rotate prompt (M3.6, diimplementasi)**: saat
  perangkat PORTRAIT, overlay `#rotate-prompt` (ikon SVG ponsel portrait →
  landscape + "Putar ke LANDSCAPE" + subteks Indonesia) menutup layar sampai
  perangkat diputar (standar game mobile landscape [24]); diverifikasi via foto
  portrait 360×640 CSS @dpr3 (`docs/m36_visual/load_portrait.png`) + piksel
  (komposisi tengah, tanpa bar loading).
- **Loading page = komposisi LANDSCAPE satu baris** (M3.6): brand (ikon + judul
  + status) kiri, progress (bar + persen) kanan dalam pita bawah; ukuran dp
  responsif (`clamp()`), scrim gradient bawah untuk kontras, safe-area
  `env(safe-area-inset-*)`. Diverifikasi piksel di 16:9 & 19.5:9
  (`verify_m36.py`: ≥85% elemen cyan di pita bawah, ada di kiri & kanan).
- **Verifikasi konsistensi (M3.6, data nyata):** capture di **4 device class**
  (16:9 xhdpi, 19.5:9 xxhdpi, 21:9 xxhdpi, desktop dpr 1) — arena full screen
  (tanpa letterbox), komponen sama dalam dp (dump `QA:HUD:LAYOUT` memuat
  `viewport[WxH]`, `dpr[...]`, `scale[...]`). Checker: `tools/vision/verify_m36.py`
  (layout loading landscape, rotate prompt, skala dp & ukuran komponen dari
  build) → `docs/m36_visual/verify_m36.json`. Evidence foto: `docs/m36_visual/`.

## 7. Referensi (dikutip langsung — game mobile landscape layout & icon design system)

0. **Doomsday: Last Survivors (IGG, 2021)** — reference utama pola UI/UX
   base-building 3D mobile (dipilih human developer 2026-10-11): top bar
   resource chips + nama pemain; gameplay = canvas 3D full screen dengan HUD
   minimal di pojok; modal menu = panel tengah + title + close + sidebar tabs
   + **grid of cards** (ikon + quantity) + detail panel + tombol besar;
   dialog bubble bawah; countdown wave. Screenshot: `docs/references/doomsday/`.
   Pola yang diadopsi & mapping ke Last-Space: `GAMEPLAY_FLOW.md` §0.
   https://play.google.com/store/apps/details?id=com.igg.android.doomsdaylastsurvivors
1. **gameuxmasterguide — "Layout of the HUD"** (9-zone grid, action safe 95%,
   title safe 90%, center focus = gameplay, top-left = info primer, bottom-left
   = tombol/minimap, bottom-right = sekunder).
   https://gameuxmasterguide.com/2019-05-07-HUDLayout/
2. **Boostroom — "MLBB HUD Layout Tips: Set Controls Like a Pro"** (thumb
   zones: kiri = joystick/gerak, kanan = skill/aksi; priority placement; skill
   cluster geometry; phone vs tablet).
   https://boostroom.com/blog/hud-layout-tips-set-your-controls-like-a-pro
3. **Medium (sglyc2) — "5 Facets… why Mobile Legends is so popular"** (Thumb
   Zone dari *Designing Mobile Interfaces* — Steve Hoober; sektor ML: kiri =
   arah/map, atas-tengah = skor, kanan = kontrol karena mayoritas right-handed).
   https://medium.com/@sglyc2/game-design-5-facets-that-every-game-should-leverage-and-5-reasons-why-mobile-legends-is-so-1d015347fec8
4. **Game-Ace — "Mobile game design: practices, workflow, and toolchain"**
   (44pt iOS / 48dp Android touch target; thumb arc → aksi primer di pojok
   bawah; safe area via inset; lock orientation di GDD).
   https://game-ace.com/blog/mobile-game-design/
5. **PR quranic-strategy-3d #11 — "Mobile HUD redesign: thumb-zone ergonomics,
   safe areas"** (status bar ≤ 6% tinggi; dock aksi ≥ 48×48, gap 8px; landscape
   = side rail; map ≥ 70%; sebelum/sesudah terukur).
   https://github.com/abolfazlghasemi2001/quranic-strategy-3d/pull/11
6. **UXPin — "Responsive Design for Touch Devices"** (target 48px, spacing
   8px, tabel standar Apple/Google/NN/g/WCAG).
   https://www.uxpin.com/studio/blog/responsive-design-touch-devices-key-considerations/
7. **Retrostyle Games — "How to Design a Cool App Icon for Your Game?"**
   (simplify, satu simbol, kontras tinggi, terbaca di 32px).
   https://retrostylegames.com/blog/how-to-design-a-cool-app-icon-for-your-games/
8. **CrazyOyster — "How to design a great icon for a mobile game?"** (satu
   simbol, satu fokus, warna kontras, 1024²).
   https://crazyoystergames.com/blog/how-to-design-a-great-icon-for-a-mobile-game/
9. **iStock — "Buttons and Icons Set for Mobile App and Game UI"** (gaya badge
   rounded-square glossy untuk tombol UI game mobile).
   https://www.istockphoto.com/illustrations/buttons-and-icons-set-for-mobile-app-and-game-ui
10. **Iconscout — "Mobile Game Icons"** (taksonomi gaya: line, flat, glyph,
    colored outline, gradient, dual tone, rounded, isometric).
    https://iconscout.com/icons/mobile-game
11. **cursa — "Mobile Screen Resolution, Aspect Ratios, and Safe Areas"**
    (adaptive layout via anchor, SafeAreaRoot, acceptance: tidak ada clipping,
    target ≥ 44–48dp).
    https://cursa.app/en/page/mobile-screen-resolution-aspect-ratios-and-safe-areas
12. **humanstandards.org — "Touch Targets & Spacing"** (design tokens: target
    44/48/56/64px, gap 8/12/16/24, ikon 16/24/32).
    https://www.humanstandards.org/code-design-tokens/touch-targets-spacing/
13. **Medium (intelligentmachines) — "The Basics of Android UI Design: Know Your
    Dimensions"** (screen paling umum Android = **360×640dp (16:9)** → landscape
    **640×360dp**; tombol **48dp** tinggi; **8pt grid**; gap 16dp antar tombol;
    primary action 40–56dp; label 14–16pt di dalam tombol 48dp).
    https://medium.com/intelligentmachines/the-basics-of-android-ui-design-know-your-dimensions-935982e00216
14. **Mobileviewer — "Touch Target Size: How Big Should It Be?"** (touch target
    **48–56dp optimal**, **8dp** spacing antar target; Material 3: FAB 56dp,
    chip **32–40dp**).
    https://www.mobileviewer.io/blog/touch-target-size
15. **charlesjean — "Android Game Loading Screen Design"** (loading screen game
    Android: **full-screen background image + progress bar + teks status**
    di atasnya; window fullscreen — komposisi landscape, bukan kolom tengah).
    https://charlesjean.github.io/2013/07/21/2013-07-21-android-game-loading-screen-design/
16. **GDevelop Forum — "Fit android game in most mobile screens"** (daftar
    resolusi umum: 3840×2160 … **1280×720**, 854×480, 640×360; "**1280×720 for
    vector art project**"; full screen = **adapt resolution at runtime** +
    anchor UI objects + background lebih besar dari base resolution).
    https://forum.gdevelop.io/t/fit-android-game-in-most-mobile-screens/37154
17. **GameDev StackExchange — "Is it a good idea to make a game for one aspect
    ratio and arbitrary screen resolution?"** (kualitas tinggi = support semua
    aspek; untuk game 3D, adaptasi aspek = perubahan matriks perspektif kamera).
    https://gamedev.stackexchange.com/questions/30461/is-it-a-good-idea-to-make-a-game-for-one-aspect-ratio-and-arbitrary-screen-res
18. **Felgo — "How to create mobile games for different screen sizes and
    resolutions"** (design di **logical resolution terendah** lalu scale up —
    contoh 480×320 landscape; 16:9 = 1280×720 & 1920×1080 sebagai contoh
    device; sisa letterbox bisa diisi background).
    https://felgo.com/doc/felgo-different-screen-sizes/

## 7b. Referensi standar resolusi & komponen (M3.6 — riset, bukan asumsi)

19. **Material Design — Spacing methods / Metrics & keylines**: "All components
    align to an 8dp square baseline grid"; padding kelipatan **8dp atau 4dp**;
    mobile **screen edge margin 16dp**; touch target **min 48×48dp** dengan
    jarak **8dp**. Toolbar/app bar **56dp**. https://m2.material.io/design/layout/spacing-methods.html
20. **Android — Screen compatibility overview**: dp/density independence
    (baseline mdpi 160dpi = 1dp:1px), density bucket ldpi 0,75× / mdpi 1× /
    hdpi 1,5× / xhdpi 2× / xxhdpi 3× / xxxhdpi 4×; layout harus fleksibel
    (jangan hardcode posisi/ukuran). https://developer.android.com/guide/practices/screens_support
21. **Material 3 touch targets (ringkasan praktik)**: tombol standar **48dp**
    (label 14–16pt, padding horizontal 16dp); FAB 56dp; ikon 24dp dalam target
    48dp; **min 8dp antar target**; indikator visual boleh lebih kecil bila
    target tetap 48dp. https://www.mobileviewer.io/blog/touch-target-size
22. **Material Design 3 type scale** — roles labelSmall 11 / bodySmall+labelLarge
    12 / bodyMedium 14 / bodyLarge+titleMedium 16 / titleLarge 22 / headline
    22–32 sp. Dipakai sebagai batas minimum teks UI. https://m3.material.io/styles/typography/type-scale-tokens
23. **Material dialogs** — lebar dialog dibatasi max-width (ponsel 560dp; layar
    lebih lebar tetap 560dp) + margin 24dp. Modal M3.6 = 544dp (terverifikasi).
    https://m3.material.io/components/dialogs/specs
24. **Android games — Support large screen resizability**: game landscape wajib
    mendukung ≥16:9 dan dianjurkan 21:9, 16:10, 3:2; window bebas di-resize.
    https://developer.android.com/games/develop/multiplatform/support-large-screen-resizability

## 8. Inventaris Layar (Screen Inventory)

| # | Layar | Status | Keterangan |
|---|---|---|---|
| 1 | **Loading Screen** | ✅ implemented (website) | Slideshow cinematic full-bleed + **komposisi LANDSCAPE** (bottom bar: brand kiri, progress kanan) + ikon animasi |
| 2a | **Dialog / modal (KREDIT)** | ✅ **DONE (M3 #4)** | Standar Material [23]: dialog = permukaan **sendiri** (opaque, `UiTheme.C_MODAL` α=0.995) di atas **scrim** penuh; tap di luar dialog menutupnya; maks 560dp. Temuan foto: panel α=0.92 membuat teks panel di belakang samar terbaca di atas dialog → diperbaiki + marker `QA:MENU:MODAL`. Label dunia 3D disembunyikan saat menu (`QA:SCENE:LABEL_MENU state=hidden`) supaya tidak ada teks 3D di atas panel. |
| 2 | **Main Menu** | ✅ **DONE (M3 #4)** | Panel 336dp (≤560dp) anchor tengah-bawah: judul + tombol utama **56dp** (MULAI / LANJUTKAN / LANJUTKAN PERMAINAN — dari state nyata save & sesi) + PENGATURAN 48dp (M3 #5) + MULAI BARU (kondisional) + KREDIT (modal ≤560dp). Latar = base 3D idle (kamera orbit halus, waktu beku). Boot: root tetap game → fase MENU (`main_menu.gd`, `ui_theme.gd`, `base_scene.show_main_menu`). |
| 3 | **Command Mode HUD** | ✅ **REVISI mobile-first (2026-10-10)** | Top bar chips, action grid ikon, info panel, toast — overlay di arena |
| 4 | **Build/Action Grid** | ✅ (bagian dari HUD) | Tombol ikon per aksi unlocked (biaya dari data, affordability real-time) |
| 5 | **Battle HUD** | ✅ (bagian dari HUD) | Wave indicator (top-center) + result toast |
| 6 | **Production Queue** | PLANNED (M2) | Antrian + progress — komponen §4 |
| 7 | **Galaxy Map** | PLANNED (M2) | Node sektor, territory, rute |
| 8 | **Settings** | ✅ **DONE (M3 #5)** | Panel `SettingsPanel` **520dp × 320dp** (≤560dp batas dialog Material [23]), **center**, header (judul + TUTUP 48dp) & footer (status + Kembalikan default 48dp) **tetap**, isi seksi AUDIO/TAMPILAN/BAHASA di `ScrollContainer` (layar landscape 360dp hanya muat ~4 baris 48dp). Kolom tunggal bila lebar <450dp → **portrait 328dp** (foto `docs/m35_settings/03_…portrait…`). Baris kontrol = **label kiri + kontrol kanan** (slider 48dp area sentuh + nilai persen). Satu instance **milik HUD** dipakai menu utama & pause menu (`hud.open_settings()`); semua nilai berlaku ke **AudioServer / DisplayServer / skala HUD / TranslationServer** dan tersimpan di `user://settings.json`. Verifikasi: `docs/m35_settings/REPORT_M35.md`, `verify_m35.json` 82/82. |

## Keputusan bahasa UI (M3.5, 2026-10-12 — sementara, bisa diubah di M3 #5)

Dokumen belum menetapkan bahasa UI. Keputusan sementara (dilaporkan ke user):
**label utama Bahasa Indonesia** (ENERGI/MINERAL/ARMADA/OBJEKTIF/BANGUN/
PRODUKSI/DIJEDA/LANJUT/PENGATURAN/MENU UTAMA; quest & nama bangunan/kapal/
sektor), **istilah teknis tetap Inggris** (WAVE/HP/ATK/ARMOR, biaya E=Energi/
M=Mineral, Lv). HUD mockup di §3 masih menampilkan label lama (ENERGY/MINERALS/
FLEET) — sudah tidak berlaku sejak M3.5 (lihat `docs/m35_visual/ui_full.png`).
Card build/ship: **2 kolom landscape** (ikon 48dp kiri, nama 24px, biaya 20px,
panel detail 170dp kanan) — menggantikan kotak 94dp 3 kolom (M3 #1/#2).
| 9 | **Pause Menu** | PLANNED (M2) | Resume / Save / Load — panel §4 |

## 9. Workflow: Desain → Aset → Implementasi → Verifikasi

```
1. DESAIN     — wireframe + spesifikasi komponen (dokumen ini, §2–§5)
2. ASET       — ikon via tools/ui/make_icons.py; background/foto → assets/ui/...
                (aturan AI-gen: AI_GOVERNANCE.md §11)
3. IMPLEMENTASI — Godot UI (game/scripts/ui/) pakai token §3; UI read-only
                dari sistem (EventBus/API)
4. VERIFIKASI — vision screenshot (capture.mjs) di 2 resolusi (1280×720 &
                896×414 mobile landscape) + acceptance check §10; tidak boleh
                "asal jalan" — cek terbaca, konsisten, nilai nyata, center clear
5. REVIEW     — human developer review visual (real game, bukan placeholder)
```

## 10. Acceptance Criteria UI/UX (checklist per layar — mobile-first)

- [ ] **Konsisten:** semua komponen pakai design token §3 (dalam dp, tidak ada
  ukuran "asal"); layout sama secara fisik di 1280×720 (16:9) dan 896×414
  (~19.5:9) — arena full screen di keduanya (adaptif, tanpa letterbox), HUD
  di-scale match-height (bukan koordinat absolut)
- [ ] **Mobile-first Android:** touch target aksi = 96px design = **48dp**
  (Material minimum/optimal); komposisi HUD ≤ ~30% tinggi layar; aksi primer di
  kanan-bawah (thumb zone); tidak ada kontrol di tengah-atas arena; **loading
  screen komposisi landscape** (bottom bar horizontal, bukan kolom vertikal)
- [ ] **Center arena clear** — tidak ada komponen menutupi gameplay center
- [ ] Semua teks/angka terbaca (kontras + shadow/outline, ukuran ≥ 22px)
- [ ] Nilai yang ditampilkan = nilai aktual sistem (bukan placeholder)
- [ ] Ikon semua pakai icon design system §5 (satu gaya, naming konsisten)
- [ ] Loading/menu/HUD terlihat seperti game sungguhan (real game)
- [ ] Verifikasi visual: screenshot via `capture.mjs` (2 resolusi) + review
  human developer
- [ ] Tidak ada error console saat layar tampil (termasuk decode ikon)

## 11. Aset 2D (Sprite & Foto) — Loading Screen ✅

Lokasi: `assets/ui/loading/`

| File | Jenis | Penggunaan |
|---|---|---|
| `bg_01_nebula_fleet.jpg` | foto cinematic | Slideshow loading background 1 |
| `bg_02_battle_station.jpg` | foto cinematic | Slideshow loading background 2 |
| `bg_03_alien_fleet.jpg` | foto cinematic | Slideshow loading background 3 |
| `bg_04_space_battle.jpg` | foto cinematic | Slideshow loading background 4 |
| `bg_05_asteroid_planet.jpg` | foto cinematic | Slideshow loading background 5 |
| `icon_loading.png` | ikon (transparan) | Icon loading + animasi (spin + pulse glow) |

**Loading screen (website, root `index.html` — komposisi LANDSCAPE, revisi
M3.6 2026-10-12):** slideshow 5 background full-bleed **landscape 1376×768
(rasio 1,79)** crossfade tiap 4 detik (`object-fit: cover`) + scrim gradient
bawah + **bottom bar horizontal satu baris** (searah landscape game): kiri =
ikon loading berputar (40–64dp) + judul "LAST-SPACE" (20–34dp) + teks status
(12–16dp); kanan = persentase (13–20dp) + progress bar (160–360dp × 6–10dp).
Semua ukuran `clamp()` vh/vw = rentang dp standar di semua device; safe-area
`env(safe-area-inset-*)`; portrait → rotate prompt (`#rotate-prompt`, §6).
Tidak ada kolom vertikal. Muncul saat halaman dimuat, hilang (fade out) setelah
game siap
(`QA:GAME:READY`). Background: 5 JPG **1376×768 (16:9)** — ukuran aktual
diverifikasi dengan PIL (2026-10-11).

**Aturan aset 2D ke depan (game):**
- Sprite/UI game masuk `game/assets/` (res://) — lihat `ASSET_PIPELINE.md` §4.
- Ikon: satu icon design system §5 (generator `tools/ui/make_icons.py`).
- Foto background game (menu/loading): format JPG/PNG, 16:9, epic cinematic,
  konsisten dengan palet §3.4.
- Aset hasil AI (foto/sprite) tetap melewati 10-step review
  (`ASSET_ACCEPTANCE_CRITERIA.md`) sebelum dipakai.

## 12. Loading Animation (spesifikasi)

- **Komposisi (landscape):** `.loading-bottom` — `position:absolute;
  left/right/bottom:0`, flex horizontal `space-between`, `align-items:flex-end`,
  padding 28px 36px. Kiri `.loading-brand` (ikon + teks), kanan
  `.loading-progress` (persen + bar). Perubahan kecil (ponsel landscape pendek,
  `max-height:480px`): ikon 44px, judul 20px, bar 200px, padding 14px 20px —
  tetap satu baris horizontal.
- **Icon:** `icon_loading.png` berputar 360° tiap 1.6s (linear, infinite) +
  pulse glow (drop-shadow cyan yang mengembang-empis tiap 1.6s).
- **Progress:** bar 320×6px + teks persentase (`#loading-pct`); pola
  indeterminate (CSS animation) sampai ada data real dari `onProgress` engine
  (Godot web), lalu determinate 0→100% + persen.
- **Slideshow:** 5 background, crossfade 1.2s, interval 4s per gambar,
  loop. Di belakang overlay gelap (rgba(5,7,15,0.55)) agar teks terbaca.

## 14. Layout card & label (M3.7 — hasil riset referensi game strategi)

**Aturan wajib (kritik user 2026-10-13, M3.7c — kutipan: "semua card itu 70%
tidak ada teks label; yang pakai label cuma menu, itu pun tidak semua"):**

| Area | Aturan | Verifikasi otomatis |
|---|---|---|
| **Tile katalog** (BANGUN/ARMADA) | **TANPA label kata**: art/ikon 70% + badge **angka** kuantitas saja | `QA:CARD:SUMMARY tiles=5 with_text=0 label_free_pct=100`; test `ui.cards_no_label`, `ui.cards_label_free_70` (≥70%), `ui.cards_icon_ratio` (≥60%) |
| **Chrome menu & HUD** (judul, chip, tombol aksi, field detail) | **Wajib berlabel teks** | `HUD.audit_labels()` → `QA:HUD:LABELS total=10 labeled=10 unlabeled=[]` (tile katalog dikecualikan, dihitung `catalog_tiles`) |
| **Tidak semua elemen menu berlabel** | Tab kategori = **ikon saja** (48dp persegi + tooltip desktop) | test `ui.cards_tabs_icon_only` (0 Label di `CategoryTabs`) |

Riset & pemetaan lengkap: `docs/REFERENCES_CARD_LAYOUT.md` (sumber + tabel
referensi → komponen). Ringkas: tab ikon + grid tile art-dominan + badge angka
(keluarga Clash of Clans) + panel detail berlabel terpisah (Rise of Kingdoms /
Evony), tombol aksi besar (Doomsday: Last Survivors).

**Riset referensi (2026-10-12/13) dan pola yang diadopsi:**

| Sumber | Temuan | Keputusan di Last-Space |
|---|---|---|
| Supercell, blog revamp UI Clash of Clans | core loop dibelah dua: **Battle kiri-bawah, Build kanan-bawah**; upgrade lewat satu rumah upgrade | ActionGrid 3 card besar (BANGUN/ARMADA/MENU) di **kanan-bawah**, InfoPanel/SelectionPanel di **kiri-bawah** |
| therookies.co (UX breakdown Clash Royale) | prinsip satu tangan: menu di bawah, bukan atas; popup tidak full screen | tombol MENU turun dari TopBar ke ActionGrid; modal 544dp < max 560dp Material |
| game-wisdom.com & gamedeveloper.com (RTS UI dos/don'ts) | bar bawah = perintah + info kontekstual, top bar = status; hindari perintah terpencar | TopBar hanya status (ENERGI/MINERAL/ARMADA + wave); semua perintah di bawah |
| ageofempires.fandom (command bar) | perintah kontekstual per seleksi | SelectionPanel = card upgrade "TINGKATKAN Lv N" + biaya (atau "LEVEL MAKS") |
| Clash of Clans shop/build (supercell.com, gameuidatabase.com, interfaceingame.com) | satu tombol build = 4 **tab ikon** + **grid tile** art-dominan + **badge angka**; nama/biaya di panel detail | `CatalogTile`: `CategoryTabs` ikon-saja 48dp + `CardGrid` 4 kolom tile 152 (76dp), ikon 70%, badge `x2`, detail berlabel di panel kanan |
| Doomsday: Last Survivors (foto lokal `docs/references/doomsday/`) | modal penuh + tombol aksi besar; counter angka (`x/y`) alih-alih teks panjang | tombol BANGUN/PRODUKSI 48dp; badge kuantitas angka pada tile |

**Struktur HUD terverifikasi (design px, viewport 1280×720, scale = dpr/2):**

| Zona | Posisi/ukuran | Isi |
|---|---|---|
| TopBar | `[32,32 1216×112]` (56dp app bar) | 3 chip resource berlabel + status wave |
| QuestPanel | `[32,160 440×234]` | OBJEKTIF + 4 baris quest + bar progres |
| InfoPanel / SelectionPanel | `[32,480 400×208]` / `[448,480 416×208]` | info konteks / detail seleksi + card upgrade |
| ActionGrid | `[880,536 368×152]` (anchor kanan-bawah) | 3 card 112×152 (56×76dp ≥ 48dp) berlabel |

**Aturan anti-tumpuk (kritik #3 — berlaku HUD *dan* teks di canvas 3D):**
- HUD: hanya container + margin, **tanpa offset absolut**; gate `QA:HUD:OVERLAP
  count=0` + `QA:HUD:FIT` (konten ≤ container) + `verify_hud_layout.py`.
- Label dunia: declutter 20 Hz — label yang kotaknya beririsan di ruang layar
  disembunyikan (prioritas: bangunan terpilih → terdekat kamera), dilaporkan
  sebagai `QA:SCENE:LABEL_OVERLAP count=0 visible=N hidden=M`.

## 13. Terkait

- `ART_DIRECTION.md` — standar visual (ikon, UI, VFX)
- `ASSET_PIPELINE.md` / `ASSET_ACCEPTANCE_CRITERIA.md` — pipeline & acceptance aset
- `QA_PLAN.md` — gate verifikasi (setiap layar diverifikasi sebelum lanjut)
- `DEV_PLAN.md` — M2: implementasi layar menu/galaxy map/settings dari dokumen ini
