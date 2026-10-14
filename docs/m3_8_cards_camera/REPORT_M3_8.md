# M3 #8 — Kamera v2 dinamis + kartu 56dp + audit tumpukan otomatis (kritik #5 lanjutan)

Milestone: **M3 #8** (kelanjutan perbaikan kritik #5 pemain)
Status keseluruhan: **VERIFIED**
Tanggal: 2026-10-14 · Branch: `arena/d80e2902-last-space`

---

## §20 Ringkasan (format AI_GOVERNANCE.md)

| Item | Isi |
|---|---|
| **Milestone** | M3 #8 — AC1 (kamera dinamis v2) + AC4 (kartu lebih kecil) + perluasan AC5 (klik) |
| **Capability** | Kamera Command Mode: pan bebas dengan klamp **fokus di dalam plataran**, zoom 0,45×–4,00× dengan `zoom_far` geometris (fit-all), drag kiri = pan, HUD resize-aware. Kartu katalog **56dp** (turun dari 68dp) tanpa label teks, gap 8dp. Audit tumpukan/keseragaman kartu otomatis di 2 menu × 4 device class. |
| **Status** | VERIFIED (semua gate hijau, verifier independen 29/29) |
| **Evidence** | `docs/m3_8_cards_camera/` — 7 foto (1280×720 @dpr2, 2340×1080 @dpr3, tablet 2048×1536 @dpr2, portrait 1080×2340 @dpr3, kamera close/pan, input flow) + `verify_m3_8.json` (29/29) |
| **Changes** | `camera_rig.gd` (v3), `base_scene.gd` (arena 80×80 + resize hook), `catalog_tile.gd` (TILE 112px + `audit_layout`), `build_menu.gd`/`ship_menu.gd` (modal responsif + audit deferred), `ui_showcase.gd`/`camera_showcase.gd`/`input_showcase.gd`, `run_game_check.sh` |
| **Verification** | gate `tests` 445/0 · gate `ui` 10 cek + 6 cek portrait · gate `camera` 12/12 · gate `input` 34/34 · `verify_m3_8.py` 29/29 |
| **Blockers** | Tidak ada |
| **Next action** | Ekspos tombol "fit" (`zoom_to_fit()` sudah ada di rig) & lanjut item DEV_PLAN berikutnya |
| **Scope change** | Klamp pan **radius arbitrer dibatalkan** → klamp "fokus di dalam plataran" (alasan teknis di §3). Tidak ada perubahan lingkup fitur. |

---

## 1. Yang dikerjakan (dan mengapa)

Kritik #5 pemain punya 5 acceptance criteria; M3 #7 menutup AC2 (SVG), AC3 (PNG
arena), dan sebagian AC4/AC5. M3 #8 menutup sisanya:

| # | Acceptance | Status sebelum | Status sekarang | Bukti |
|---|---|---|---|---|
| AC1 | Kamera **dinamis + bisa digerakkan** | zoom/pan jalan tapi klamp pan = radius arbitrer 16 unit (membatasi gerak tanpa dasar geometris) | **VERIFIED** — pan bebas, klamp **fokus tetap di dalam plataran**, `zoom_far` = fit-all geometris (≤4,00×) | gate `camera` **12/12**; `verify_m3_8.py` cek span **2,08×** |
| AC4 | **Ukuran card** | 136px = 68dp | **VERIFIED — 112px = 56dp** (turun 18%), ikon 80% sisi, tab 48dp | piksel: kotak 112×112 @dpr2 & 168×168 @dpr3 = **56dp**; marker `tile_dp=56` |
| AC5 | **"bangun dll tidak bisa diklik"** | 29 cek | **VERIFIED — 34 cek**: semua tab + kartu tiap tab + drag kiri pan + tap setelah drag | `QA:INPUT:DONE passed=34 failed=0` |

**Temuan nyata selama M3 #8** (bukan asumsi — berasal dari audit/foto, semua sudah diperbaiki):

1. **Kartu keluar panel di portrait 360dp** — `QA:CARD:LAYOUT … inside_panel=false ok=false`.
   Akar: modal 1024px (512dp) lebih lebar dari layar portrait (design 720px). Perbaikan:
   modal **responsif** (`_fit_modal()` + mode body WIDE/NARROW, `_set_body_mode()`).
2. **Dua cek QA hilang senyap** — `ui_showcase.gd` memakai `hud.get_node("QuestPanel")`
   padahal node itu anak `LeftColumn`/`BottomBand` → Godot mencetak `ERROR: Node not found`
   dan kedua cek tidak pernah tercetak PASS/FAIL. Perbaikan: `find_child()` + gate baru
   "TIDAK ada error 'Node not found'" agar tidak terulang.
3. **Cek deklutter rapuh** (gate `camera` 11/12) — cek lama `hidden ≥ 1` bergantung
   kebetulan posisi label: base bawaan hanya **1 bangunan**, sehingga di zoom dekat
   `visible=1 hidden=0` → FAIL. Bukan bug deklutter, tapi ceknya tidak deterministik.
   Perbaikan: uji disemai 4 bangunan lebih dulu → `visible=2 hidden=2 overlap=0` **PASS**.

---

## 2. AC4 — Kartu 56dp (angka & bukti)

Perubahan: `CatalogTile.TILE 136 → 112` (= 56dp pada design px = 2×dp), `ICON_RATIO 0,78 → 0,80`
(ikon dibesarkan agar kartu kecil tetap "art-dominant" sesuai aturan kartu M3.7c).

```
QA:CARD:SUMMARY menu=build tab=all tiles=5 with_text=0 label_free_pct=100
                icon_ratio=80 tile_px=112 tile_dp=56 grid=496x240
QA:CARD:OVERLAP count=0 uniform=true inside_panel=true inside_screen=true
                gap_px=16.0..16.0 tile_px=[112.0, 112.0, 112.0, 112.0, 112.0] ok=true
```

**Diukur dari PIKSEL foto** (bukan dari kode — `verify_m3_8.py`, flood-fill border cyan):

| Foto | Kotak terdeteksi | ukuran px | = dp | gap minimum |
|---|---|---|---|---|
| 1280×720 @dpr2 | 5 | 112×112 | 56,0 | 16 px = 8dp |
| 2340×1080 @dpr3 | 5 | 168×168 | 56,0 | 24 px = 8dp |
| 2048×1536 @dpr2 (tablet 4:3) | 5 | 112×112 | 56,0 | 16 px = 8dp |
| rasio dpr3/dpr2 | — | **1,50** | tetap 56dp | — |

Rasio 1,50 membuktikan ukuran kartu **tetap dalam dp** dan tidak ikut membesar di layar besar
(aturan tetap pemain: "komponen wajib sesuai dp standar di semua device").
Gap minimum 8dp = kelipatan grid Material → tidak ada tumpukan (0 irisan).

## 3. AC1 — Kamera v2 (apa yang berubah & mengapa)

Perubahan teknis di `camera_rig.gd` + `base_scene.gd`:

- **Klamp pan = fokus di dalam plataran** (`pan_limits()` = batas arena − `_focus_base`,
  `inside_arena()` fokus ±0,05). Klamp radius arbitrer **dihapus** dan klamp "quad pandang ⊆ arena"
  **dibatalkan** karena terbukti mustahil: dengan kamera menunduk ~25°, unproject sudut atas
  viewport degenerate (test membuktikan S=(36,71, 0,000002)). Yang dijamin: pusat pandang tidak
  pernah keluar arena → kamera tetap "di depan base" tanpa bisa tersesat.
- **`zoom_far` geometris**: binary search `_fits_all()` (semua bangunan masuk frame) di-clamp
  1,90×–4,00× — jadi pemain selalu bisa zoom-out sampai seluruh base terlihat, tapi tidak
  sampai kotak tak berguna.
- **Drag kiri = pan** (`_left_down/_left_dragged/_left_hint`); pick dipindah ke **RELEASE**
  (`base_scene._unhandled_input`) sehingga drag tidak pernah salah-memilih bangunan
  ("mouse_drag_pan" vs "release_tap").
- **Resize-aware**: `get_viewport().size_changed → rig.on_viewport_resized()` + `_refresh_geometry()`
  → rotasi/aspect berubah tidak membuat pan/zoom meleset.
- Marker jujur: `set_zoom_raw` memakai `want := clampf(z, ZOOM_CLOSE, _zoom_far)` dan hanya
  mencetak `CAM:CLAMP` kalau batas **benar-benar** tersentuh (sebelumnya marker palsu).

```
QA:CAM:SPAN scale=1.0 px=244.6   →   scale=1.92 px=509.7 via=button   (rasio 2,08×)
QA:CAM:LABEL_CHECK step=close zoom=0.63 overlap=0 visible=2 hidden=2 zones=5
```

## 4. AC4b — Modal responsif (perbaikan temuan portrait)

| Device class | design space | `QA:CARD:MODAL` | Hasil |
|---|---|---|---|
| 1280×720 @dpr2 (ponsel 16:9) | 1280×720 | `w=1024 h=560 cols=4 narrow=false` | seperti sebelumnya (tanpa regresi) |
| 2340×1080 @dpr3 (ponsel 19,5:9) | 1560×720 | `w=1024 h=560 cols=4 narrow=false` | kartu 168px = 56dp |
| 2048×1536 @dpr2 (tablet 4:3) | 1024×768 | `w=1024 h=560 cols=4 narrow=false` | kartu 112px = 56dp |
| 1080×2340 @dpr3 (portrait) | 720×1560 | `w=656 h=560 cols=4 narrow=true` | modal 328dp (≥ batas bawah dialog 280dp), kartu tetap 56dp |

Mode NARROW = grid di **atas** detail di dalam `ScrollContainer` vertikal (isi di-reparent, bukan
dibuat ulang) sehingga tidak ada elemen yang terpotong. `inside_panel` dan `inside_screen`
keduanya `true` di keempat device class (sebelumnya `inside_panel=false` di portrait).

## 5. Verifikasi (semua dari run nyata, log tersimpan)

```
bash tools/godot/run_game_check.sh tests   → TESTS:DONE passed=445 failed=0 skipped=0   (0 suite FAIL)
bash tools/godot/run_game_check.sh ui      → 10/10 UI CHECK + 6/6 UI PORTRAIT CHECK     (0 suite FAIL)
bash tools/godot/run_game_check.sh camera  → 12/12 CAMERA CHECK                        (0 suite FAIL)
bash tools/godot/run_game_check.sh input   → QA:INPUT:DONE passed=34 failed=0          (0 suite FAIL)
python3 tools/vision/verify_m3_8.py        → verify_m3_8: 29/29 PASS -> PASS
```

Gate `ui` sekarang menguji **dua orientasi** dan menolak regresi "cek hilang senyap":

```
UI CHECK: kartu katalog 56dp -> PASS
UI CHECK: kartu tidak bertumpuk + ukuran seragam -> PASS
UI CHECK: gap antar kartu konsisten (≥8px) -> PASS
UI CHECK: panel quest & seleksi benar-benar diuji -> PASS
UI CHECK: TIDAK ada error 'Node not found' di console (cek tidak hilang senyap) -> PASS
UI PORTRAIT CHECK: modal menyusut ke ruang nyata (narrow) -> PASS
UI PORTRAIT CHECK: kartu di dalam panel + di dalam layar (portrait) -> PASS
```

## 6. Foto bukti — `docs/m3_8_cards_camera/`

| Berkas | Device class | Isi |
|---|---|---|
| `00_cards_56dp_1280x720.png` | 640×360dp @dpr2 | menu BANGUN, 5 kartu 56dp, tanpa label teks |
| `01_cards_56dp_2340x1080.png` | 780×360dp @dpr3 | sama, kartu 168px = 56dp (dp tetap) |
| `06_cards_56dp_tablet4x3_2048x1536.png` | 1024×768dp @dpr2 | tablet 4:3, modal tidak melimpah |
| `02_rotate_prompt_portrait_1080x2340.png` | 360×780dp @dpr3 | **prompt rotasi** (keputusan pemain) + audit internal `narrow=true` |
| `03_camera_close_1280x720.png` | 640×360dp @dpr2 | zoom dekat: deklutter menyembunyikan **2** label, 0 tumpukan |
| `04_camera_pan_2340x1080.png` | 780×360dp @dpr3 | pan nyata, label tetap rapi |
| `05_input_flow_1280x720.png` | 640×360dp @dpr2 | 34/34 interaksi nyata (tab + kartu + drag pan) |

## 7. Catatan jujur / keterbatasan

- **Portrait menampilkan prompt rotasi**, bukan gameplay (keputusan pemain: landscape-first).
  Audit layout portrait tetap dijalankan mesin (marker `narrow=true`) sebagai jaring pengaman
  bila kelak overlay dimatikan atau dipakai di tablet sempit.
- Gate `ui`/`input` berjalan di SwiftShader (software GL) — fps rendah bukan indikator performa
  perangkat nyata; angka performa tetap dari gate `perf` (emulasi CPU throttle).
- `zoom_to_fit()` sudah ada di rig tetapi **belum diekspos** ke HUD sebagai tombol; itu langkah
  berikutnya (§ next action), bukan klaim selesai.
- Sisa 1 keterbatasan lama yang tidak berubah: sub-piksel label dunia pada zoom ekstrem tetap
  mungkin terlihat "rapat" — tetapi irisan label-vs-label dan label-vs-HUD diukur ulang tiap
  0,05 s dan sekarang **0** di semua foto/gate.
