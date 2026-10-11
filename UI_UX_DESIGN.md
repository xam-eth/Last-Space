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

### 3.1 Spacing & grid
- Semua ukuran dalam **dp (Android density-independent pixel)**; design canvas
  1280×720 = **640×360dp** → **1 design px = 0,5dp** (px = dp × 2). Standar
  Android: screen referensi 360×640dp (16:9) — landscape = 640×360dp
  (referensi §7 [13]).
- Base grid **8dp** (= 16px); semua spacing = kelipatan 8dp (8, 16, 24, 32, 48,
  64dp) (referensi §7 [13] 8pt grid).
- `MARGIN = 24px` (12dp) — safe edge margin (semua sisi, dalam design canvas).
- `GRID_GAP = 16px` (8dp) — antar komponen/tombol (minimum Material 8dp,
  referensi §7 [13][14]).

### 3.2 Touch targets (mobile-first)
- Tombol aksi: **96×96** design px = **48dp** — touch target minimum/optimal
  Material (48–56dp optimal, referensi §7 [13][14]). Di ponsel xxhdpi (3×,
  tinggi fisik 1080px = 360dp): 96px × (1080/720) = 144px fisik = **48dp**
  persis — ukuran fisik sama di semua device (HUD di-scale match-height, §6).
- Tombol sekunder (menu): 80×80 (40dp). Chip resource: 220×72 (110×36dp,
  tinggi chip Material 32–40dp [14]) — read-only, tidak untuk disentuh.
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
| `QUEST_W × QUEST_H` | 440 × 232 (220×116dp) | Quest panel (kiri tengah, M3 #1) |
| `SEL_W × SEL_H` | 560 × 140 (280×70dp) | Selection panel (bawah tengah, M3 #1) |
| Modal | 1024 × 504 (512×252dp = 80%×70%) | Build menu (M3 #1), anchor center semua aspek |
| Card (grid modal) | 188 × 188 (94dp) | ikon 36dp + nama + biaya + count |
| Tombol besar modal | tinggi 96 (48dp), lebar penuh panel detail | BUILD/UPGRADE |

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

### 3.5 Tipografi
- **HUD/angka:** font bawaan Godot via `LabelSettings` — ukuran (design px =
  dp×2): chip value 28 (14dp), chip label 18 (9dp), status 24 (12dp), result 26
  (13dp), toast 26 (13dp), wave 24 (12dp). Tidak ada label pada tombol aksi
  (ikon-only — label terbukti meng-inflate tinggi cell); 14–16pt adalah standar
  label di dalam tombol Material 48dp (referensi §7 [13]) — dipakai di tooltip.
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
- **HUD = design frame 1280×720** (640×360dp) di-scale **uniform match-height**
  (`scale = window_height / 720`) lalu di-center horizontal (`hud.gd`
  `_apply_design_frame`, re-apply saat `size_changed`). Ukuran fisik komponen
  sama di semua device: di ponsel 1080px tinggi (3×, 360dp) → tombol 96px
  design = 144px fisik = **48dp** persis.
- **Margin aman 24px (12dp)** di semua sisi design canvas (action safe 95% /
  title safe 90%, referensi [1]) — aman untuk notch/rounded corner;
  `viewport-fit=cover` + full-screen CSS di root page.
- **Root page (`index.html`)**: viewport `width=device-width,
  initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover`;
  CSS full-screen (no scroll/bounce/zoom, `touch-action: none`); canvas
  `canvasResizePolicy: 2` (canvas isi window).
- **Orientasi: landscape saja** (dikunci di GDD — referensi [4]: "lock the
  orientation in the GDD"). Portrait = di luar scope (akan ditangani menu
  "rotate device" jika diperlukan — belum diimplementasi).
- **Verifikasi konsistensi:** capture di 2+ aspek (desktop 1280×720 16:9 &
  mobile landscape 896×414 ~19.5:9) — arena full screen di keduanya (tidak ada
  letterbox), HUD terlihat sama secara fisik (scale, bukan koordinat absolut)
  — lihat §9 acceptance. HUD:LAYOUT dump memuat `viewport[WxH]` + `scale`.

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

## 8. Inventaris Layar (Screen Inventory)

| # | Layar | Status | Keterangan |
|---|---|---|---|
| 1 | **Loading Screen** | ✅ implemented (website) | Slideshow cinematic full-bleed + **komposisi LANDSCAPE** (bottom bar: brand kiri, progress kanan) + ikon animasi |
| 2 | **Main Menu** | PLANNED (M2) | New Game / Continue / Settings — pakai design system §3–§5 |
| 3 | **Command Mode HUD** | ✅ **REVISI mobile-first (2026-10-10)** | Top bar chips, action grid ikon, info panel, toast — overlay di arena |
| 4 | **Build/Action Grid** | ✅ (bagian dari HUD) | Tombol ikon per aksi unlocked (biaya dari data, affordability real-time) |
| 5 | **Battle HUD** | ✅ (bagian dari HUD) | Wave indicator (top-center) + result toast |
| 6 | **Production Queue** | PLANNED (M2) | Antrian + progress — komponen §4 |
| 7 | **Galaxy Map** | PLANNED (M2) | Node sektor, territory, rute |
| 8 | **Settings** | PLANNED (M2) | Grafik, audio, bahasa |
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
2026-10-11):** slideshow 5 background full-bleed (crossfade tiap 4 detik,
`object-fit: cover`) + overlay gelap + **bottom bar horizontal** (satu baris,
searah landscape game): kiri = ikon loading berputar (72px) + judul
"LAST-SPACE" + teks status; kanan = persentase + progress bar. Tidak ada kolom
vertikal. Muncul saat halaman dimuat, hilang (fade out) setelah game siap
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

## 13. Terkait

- `ART_DIRECTION.md` — standar visual (ikon, UI, VFX)
- `ASSET_PIPELINE.md` / `ASSET_ACCEPTANCE_CRITERIA.md` — pipeline & acceptance aset
- `QA_PLAN.md` — gate verifikasi (setiap layar diverifikasi sebelum lanjut)
- `DEV_PLAN.md` — M2: implementasi layar menu/galaxy map/settings dari dokumen ini
