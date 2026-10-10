# UI/UX DESIGN — Last-Space

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

1. **Mobile-first, landscape, full screen.** Game didesain untuk **ponsel
   dipegang landscape (16:9) full screen** — bukan desktop-first. Kanvas
   desain = 1920×1080 (16:9); Godot stretch `canvas_items` + aspect `keep`
   → full screen dengan letterbox gelap di device yang lebih lebar (mis.
   19.5:9). HUD hidup **di dalam** kanvas 16:9 sehingga konsisten di semua
   device (tidak tergantung ukuran fisik layar).
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
- Base grid **8px**; semua spacing = kelipatan 8 (8, 16, 24, 32, 48, 64)
  (referensi §7 [4] 8pt grid).
- `MARGIN = 24` — safe edge margin (semua sisi, dalam kanvas 16:9).
- `GAP = 12` — antar komponen/tombol.

### 3.2 Touch targets (mobile-first)
- Tombol aksi: **112×112** canvas px (ikon penuh) — setara **~11mm ≈ 84pt
  fisik** di ponsel 6.1" landscape (kanvas 720 = 71.6mm) — jauh di atas minimum
  44pt iOS / 48dp Android (referensi §7 [4][6]).
- Tombol sekunder (menu): 80×80. Chip resource: 220×80 (read-only, tidak
  untuk disentuh — tapi tetap nyaman dilihat).
- Jarak antar target ≥ 12 (gap grid) — melebihi minimum 8 (referensi §7 [4][6]).

### 3.3 Ukuran komponen
| Token | Nilai | Komponen |
|---|---|---|
| `TOP_BAR_H` | 96 | Top bar |
| `CHIP_W × CHIP_H` | 220 × 80 | Resource chip |
| `BTN` | 112 | Tombol aksi (ikon) |
| `GRID_COLS` | 4 | Action grid (2 baris untuk 7 aksi) |
| `INFO_W × INFO_H` | 460 × 168 | Info panel |
| `TOAST` | 640 × 64, y=120 | Toast (auto-hide 5s) |
| Progress bar | h=8, radius 4 | Di dalam chip |

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
- **HUD/angka:** font bawaan Godot via `LabelSettings` — ukuran: chip value
  30, chip label 20, action label 20, status 26, toast 30, wave 26. (Di kanvas
  720p, ukuran-ukuran ini secara fisik ~1.5× lebih besar daripada di 1080p —
  memang disengaja untuk mobile.)
- Semua label punya **shadow + outline** (kontras di atas arena apa pun).
- Judul (loading/menu): sans-serif bold, letter-spacing lebar (military).

## 4. Komponen Standar

| Komponen | Spesifikasi | Dipakai di |
|---|---|---|
| **Resource Chip** | Panel 300×96, radius 16, border cyan; [ikon 56 | label 22 muted + value 34] + progress bar 10 (warna resource); nilai = aktual/cap dari `Economy` | Top bar (Energy, Minerals, Fleet) |
| **Action Button** | TextureButton 112×112 (ikon penuh, icon design system §5) + label 22 di bawah; affordable = penuh, **unaffordable = modulate redup** (data: `Economy.can_afford`); tooltip = nama + biaya | Action grid (build + Interceptor) |
| **Info Panel** | Panel 720×224, radius 16; status (30) + result (34, accent); `mouse_filter = IGNORE` (tidak blok arena) | Kiri-bawah |
| **Toast** | Panel 840×76 top-center (y=160), border accent/ok/danger sesuai event; auto-hide 5s (token waktu, tidak tumpang tindih) | Battle result, territory |
| **Top Bar** | h=128, margin 32; HBox: chips kiri, wave label tengah (danger saat ada wave), menu button kanan | Atas |
| **Panel (umum)** | `panel` bg 78%, border 2px, radius 16, content margin 16 | Semua panel |
| **Progress Bar** | h=10, radius 5, bg hitam 45%, fill = warna resource/aksi | Chip |

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

## 6. Screen Consistency & Safe Area

- **Kanvas tetap 16:9 (1280×720 — design resolution mobile-first)**, stretch
  `canvas_items` + aspect `keep` — full screen di device landscape; letterbox
  gelap di device lebih lebar. HUD di-anchor dalam kanvas → **konsisten di
  semua device** (tidak ada "size layar tidak konsisten"). Mengapa bukan
  1920×1080: di 1080p semua teks/ikon terlalu kecil secara fisik di ponsel;
  1280×720 adalah design resolution standar mobile-first 16:9.
- **Margin aman 32px** di semua sisi kanvas (action safe 95% / title safe 90%,
  referensi [1]) — aman untuk notch/rounded corner (letterbox menjauhkan HUD
  dari tepi fisik device; `viewport-fit=cover` + full-screen CSS di root page).
- **Root page (`index.html`)**: viewport `width=device-width,
  initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover`;
  CSS full-screen (no scroll/bounce/zoom, `touch-action: none`).
- **Orientasi: landscape saja** (dikunci di GDD — referensi [4]: "lock the
  orientation in the GDD"). Portrait = di luar scope (akan ditangani menu
  "rotate device" jika diperlukan — belum diimplementasi).
- **Verifikasi konsistensi:** capture di 2 resolusi (desktop 1280×720 &
  mobile landscape 896×414) — HUD terlihat sama (anchor, bukan koordinat
  absolut) — lihat §9 acceptance.

## 7. Referensi (dikutip langsung — game mobile landscape layout & icon design system)

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

## 8. Inventaris Layar (Screen Inventory)

| # | Layar | Status | Keterangan |
|---|---|---|---|
| 1 | **Loading Screen** | ✅ implemented (website) | Slideshow cinematic + icon + animasi |
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

- [ ] **Konsisten:** semua komponen pakai design token §3 (tidak ada ukuran
  "asal"); layout sama di 1280×720 dan 896×414 (anchor, bukan koordinat)
- [ ] **Mobile-first:** touch target aksi ≥ 112px (≈ ≥44–48pt fisik); aksi
  primer di kanan-bawah (thumb zone); tidak ada kontrol di tengah-atas arena
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

**Loading screen (website, root `index.html`):** slideshow 5 background
(crossfade tiap 4 detik) + overlay gelap + icon loading berputar + judul
"LAST-SPACE" + teks loading + progress bar animasi. Muncul saat halaman dimuat,
hilang (fade out) setelah game siap (`QA:GAME:READY`).

**Aturan aset 2D ke depan (game):**
- Sprite/UI game masuk `game/assets/` (res://) — lihat `ASSET_PIPELINE.md` §4.
- Ikon: satu icon design system §5 (generator `tools/ui/make_icons.py`).
- Foto background game (menu/loading): format JPG/PNG, 16:9, epic cinematic,
  konsisten dengan palet §3.4.
- Aset hasil AI (foto/sprite) tetap melewati 10-step review
  (`ASSET_ACCEPTANCE_CRITERIA.md`) sebelum dipakai.

## 12. Loading Animation (spesifikasi)

- **Icon:** `icon_loading.png` berputar 360° tiap 1.6s (linear, infinite) +
  pulse glow (box-shadow cyan yang mengembang-empis tiap 1.6s).
- **Progress bar:** lebar 0→100% dengan pola indeterminate (CSS animation),
  warna aksen cyan di atas panel.
- **Slideshow:** 5 background, crossfade 1.2s, interval 4s per gambar,
  loop. Di belakang overlay gelap (rgba(5,7,15,0.55)) agar teks terbaca.

## 13. Terkait

- `ART_DIRECTION.md` — standar visual (ikon, UI, VFX)
- `ASSET_PIPELINE.md` / `ASSET_ACCEPTANCE_CRITERIA.md` — pipeline & acceptance aset
- `QA_PLAN.md` — gate verifikasi (setiap layar diverifikasi sebelum lanjut)
- `DEV_PLAN.md` — M2: implementasi layar menu/galaxy map/settings dari dokumen ini
