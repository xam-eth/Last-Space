# Laporan M3.7c — Card katalog tanpa label teks (tiruan referensi game strategi)

**Tanggal:** 2026-10-13 · **Branch:** `arena/d80e2902-last-space` · **Mode:** koreksi + implementasi + verifikasi

## §20 Format Laporan (wajib, `AI_GOVERNANCE.md`)

### 1. Milestone
M3.7c — answer for the user's latest note: *"cek lagi dan search lagi reference ui ux card
layout game strategi lain, tata letak component nya dll, tiru itu. Satu catatan yg paling utama:
semua card itu 70% tidak ada teks label; yang pakai label cuma menu, itu pun tidak semua."*

### 2. Capability advanced

| Sebelum (M3.7, `066e8c9`) | Sesudah (M3.7c) |
|---|---|
| Card katalog berisi nama + `BIAYA …` + `DIBANGUN n` (setiap card penuh teks) | **Tile katalog tanpa label kata**: ikon 70% + badge **angka** `x2`; nama/biaya/kategori hanya di panel detail |
| Modal build/ship: 2 kolom card 332×128, **konten meluber** (grid 416 > area 320) | Grid 4 kolom tile 152 (76dp) di `ScrollContainer`; anggaran tinggi 320 terverifikasi |
| Tab kategori belum ada | `CategoryTabs` — 4 tab **ikon saja** 48dp (pola Clash of Clans) |
| `Panel` modal (content margin stylebox diabaikan → konten menempel tepi frame) | `PanelContainer` (margin dalam 16px benar-benar berlaku) |
| Subtitle panel seleksi `Lv 1 · command_core` (id internal bocor ke pemain) | `Lv 1` — id internal tidak ditampilkan |
| Detail panel tanpa penangan overflow (foto `05` pra-fix: tombol PRODUKSI keluar modal) | Blok teks di `ScrollContainer` → tombol aksi **selalu** di dalam panel |
| Audit label "semua kontrol wajib berlabel" (salah tafsir catatan user) | Audit dipecah: **chrome** berlabel (`QA:HUD:LABELS … catalog_tiles=16`), **tile** tanpa label (`QA:CARD:*`) |

### 3. Status
- **VERIFIED (runtime):** gate `run_game_check.sh all` → **8/8 suite PASS, exit 0**
  (tests 285/285 · e2e 36/36 · asset 17/17 · sim 12/12 · stress 8/8 · perf t1/t4/t6 8/8 ·
  ui 29/29 · play smoke PASS; semua `pageErrors=0`).
- **VERIFIED (script, dari JSON & foto):** `verify_ui_m3.py` 20/20,
  `verify_hud_layout.py` 63/63 (9 foto UI baru), `verify_m37.py` (lihat 4).
- **LIKELY (belum di device fisik):** nuansa visual tile/badge di layar nyata (semua bukti
  berasal dari Chromium SwiftShader headless, ≈1 fps).

### 4. Evidence

**Marker (nilai dari state nyata, bukan konstanta):**

| Marker | Nilai |
|---|---|
| `QA:CARD:SUMMARY` (build) | `menu=build tab=all tiles=5 with_text=0 label_free_pct=100 icon_ratio=70` |
| `QA:CARD:SUMMARY` (ship) | `menu=ship tab=all tiles=1 with_text=0 label_free_pct=100 icon_ratio=70` |
| `QA:CARD:TILE` | 6 tile (5 build + 1 ship) `text_nodes=0`, `labels=[]`; `qty=2` untuk `laser_turret` |
| `QA:HUD:LABELS` | `total=10 labeled=10 unlabeled=[] catalog_tiles=16` |
| `QA:HUD:OVERLAP` | `count=0` (state info & state seleksi) |
| `QA:HUD:FIT` | `QuestPanel ok(177x202<=440x234)`, `InfoPanel ok(1x86<=400x208)`, `SelectionPanel ok(199x152<=416x208)` |
| `QA:SCENE:LABEL_OVERLAP` | `count=0 visible=2 hidden=0 total=2` (setelah 2 turret ditambahkan showcase) |
| `QA:SCENE:ENV` | `stars=300 planet=1 asteroids=7 rim=4 pylons=4 pads=2` (koreksi: marker lama menulis 350 padahal nyata 300) |

**Test yang menentukan (gate `ui`, 29/0):** `ui.cards_no_label` (with_text=0),
`ui.cards_label_free_70` (100% ≥ 70%), `ui.cards_icon_ratio` (70%), `ui.cards_tabs_icon_only`,
`ui.menu_fit_build` / `ui.menu_fit_ship` (kosong = tidak ada anak modal keluar rect),
`ui.card_badge_qty` (=2 setelah 2 turret), `ui.card_badge_hidden_at_zero` (=0),
`ui.labels_all` (10/10 chrome berlabel), `ui.ships/no_label`, plus regresi HUD/3D
(`QA:HUD:OVERLAP count=0`).

**Foto (semua di-recapture dari build M3.7c, `docs/ui_m3_build_menu/`):**
`00_baseline_1280x720` · `01_command_selected_1280x720` · `02_build_menu_1280x720`
(katalog tile + badge `x2`) · `03/04_command_selected/build_menu_2340x1080` (19.5:9) ·
`05/06_ship_menu` · `07/08_pause_menu`. Bukti cacat pra-fix disimpan sebagai
`docs/m37c_visual/before_fix_ship_menu_overflow_1280x720.png` (+ JSON log-nya) — pada foto itu
tombol PRODUKSI tergambar **di luar** frame modal.

**Kesalahan yang ditemukan & diperbaiki di turn ini (jujur, termasuk yang saya buat sendiri):**
1. Klaim awal saya "modal build meluber 3072px" **salah** — pengukuran ulang menunjukkan modal
   1088×544 berada di dalam canvas (dihitung dari capture 2340×1080: display px = design px).
2. Subtitle seleksi yang saya perpanjang jadi `Lv 1 · PUSAT KOMANDO` melebarkan panel 48px →
   gate menangkap `QA:HUD:OVERLAP count=1 ActionGrid-SelectionPanel:8x152`; diperbaiki menjadi `Lv 1`.
3. `ui.menu_fit_*` sempat **lolos palsu** karena mengukur sebelum container menyusun anak →
   sekarang menunggu 2 `process_frame` sebelum mengukur; setelah itu cacat nyata (tombol
   PRODUKSI keluar modal, terlihat di foto `05` pra-fix) tertangkap dan diperbaiki dengan
   `ScrollContainer` pada blok teks detail.
4. Marker `QA:SCENE:ENV stars=350` tidak sama dengan `multi.instance_count=300` → disamakan ke 300.

### 5. Changes (file)
- **baru** `game/scripts/ui/catalog_tile.gd` (`class_name CatalogTile`) — komponen bersama:
  `make_tile()` (ikon 70% + badge angka + overlay gembok), `make_tab()` (tab ikon 48dp),
  `set_qty()`, `qty_of()`, `label_nodes()`, `audit()`, `label_free_ratio()`.
- `game/scripts/ui/build_menu.gd` — `CategoryTabs`, `CardGrid` 4 kolom di `CardScroll`,
  `PanelContainer` modal, detail ber-`DetailScroll`, `audit_cards()`/`qty_of()`,
  marker `QA:CARD:TILE`/`QA:CARD:SUMMARY`, konstanta `CARD_*` lama dihapus.
- `game/scripts/ui/ship_menu.gd` — sama seperti build_menu + `select()` ramah `ButtonGroup`
  (unpress tile lain, pindah tab otomatis), `_icon_tip()`, baris tab disembunyikan bila 1 kategori.
- `game/scripts/ui/hud.gd` — `audit_labels()` di-scope ke chrome (subtree `BuildMenu`/`ShipMenu`
  dikecualikan, dihitung `catalog_tiles`), subtitle seleksi `Lv N`.
- `game/scripts/base_scene.gd` — marker `QA:SCENE:ENV stars=300`.
- `game/tests/e2e/ui_showcase.gd` — 7 check baru (card/fit/badge) + helper `_modal_overflow()`
  (walk anak modal, lewati `ScrollContainer`, tunggu layout settle).
- `tools/vision/verify_m37.py` — check `chrome_berlabel` (rename + scope chrome), tambahan
  `card_katalog_tanpa_label`, `card_tanpa_label_min_70pct`, `card_ikon_dominan`.
- Dokumentasi: `docs/REFERENCES_CARD_LAYOUT.md` (baru), `UI_UX_DESIGN.md` §14,
  `PROJECT_STATUS.md`, `docs/ui_m3_build_menu/UI_M3_REPORT.md` (regenerasi verifier).

### 6. Verification
- `run_game_check.sh all` → **8/8 PASS, exit 0**: tests 285/0, e2e 36/0, asset 17/0, sim 12/0,
  stress 8/0, perf throttle 1×/4×/6× 8/0 (fps_avg 4.00 / 3.25 / 2.33 — SwiftShader software GL,
  bukan device fisik), ui 29/0, play smoke PASS; `pageErrors=0` di semua suite.
- `python3 tools/vision/verify_m37.py docs/m37_visual tools/godot/build/*.png.json` →
  **12 PASS / 0 FAIL** (`docs/m37c_visual/verify_m37.json`), termasuk `chrome_berlabel` 10/10,
  `card_katalog_tanpa_label` (6 tile, `with_text=0`), `card_tanpa_label_min_70pct` 100%/100%,
  `card_ikon_dominan` 70%, `arena_props stars=300`, `label_3d_tidak_bertumpuk` overlap 0.
- `python3 tools/vision/verify_ui_m3.py` → **20 PASS / 0 FAIL** (foto M3.7c).
- `python3 tools/vision/verify_hud_layout.py docs/ui_m3_build_menu/0*.png.json` →
  **63 PASS / 0 FAIL**; hasil: `docs/m37c_visual/verify_hud_layout_ui.json`.
- `python3 tools/vision/verify_m37.py docs/m37_visual …` →
  hasil: `docs/m37c_visual/verify_m37.json`.

### 7. Blockers
- Tidak ada blocker teknis. Catatan jujur: pengukuran performa tetap dari SwiftShader
  (software renderer ≈1 fps) — bukan angka device fisik; `BuildingModel.simple_mode` hanya
  aktif di scene benchmark stress.

### 8. Next action
- M3.7c ditutup; berikutnya menunggu keputusan human: lanjut ke konten M3 #4/#5
  (mis. perluasan data bangunan/kapal sehingga grid katalog > 4 kolom → uji `CardScroll`)
  atau polish lanjutan (mis. `pause_menu` disamakan ke `PanelContainer`).

### 9. Scope change
- Interpretasi kriteria #4 **dikoreksi**: yang semula dibaca "semua card wajib berlabel"
  (`066e8c9`) kini mengikuti catatan terbaru user — **tile katalog tanpa label kata**,
  label hanya di chrome menu dan tidak semua elemen menu berlabel. Audit & verifier
  disesuaikan; dokumentasi lama (`UI_UX_DESIGN.md` §14, `PROJECT_STATUS.md`) diperbarui
  agar tidak ada dua kebenaran.
