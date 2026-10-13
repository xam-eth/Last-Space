# LAPORAN M3 #5 — Panel PENGATURAN (audio / tampilan / ukuran UI / bahasa)

Tanggal: 2026-10-13 · Branch: `arena/d80e2902-last-space` · Status: **VERIFIED**
(lihat §3 Verifikasi — angka gate nyata, bukan klaim).

Format §20 `AI_GOVERNANCE.md`.

---

## 1. Milestone / Capability advanced

**M3 #5 Settings** (DEV_PLAN milestone M3 setelah M3 #4 Main menu). Sebelumnya
tombol **PENGATURAN** di menu utama & pause menu hanya melaporkan status jujur
"segera hadir (M3 #5)". Sekarang tombol itu membuka **panel pengaturan nyata**
dan setiap nilainya **berlaku ke sistem nyata**, bukan kosmetik.

Capability: pemain bisa mengubah **volume (master/SFX/musik)**, **layar penuh**,
**ukuran UI (Kecil/Normal/Besar)**, dan **bahasa (Indonesia/English)**; semua
disimpan di `user://settings.json` dan dimuat ulang saat boot; ada
**Kembalikan default**.

## 2. Status per komponen (label governance §2)

| Komponen | Status | Bukti |
|---|---|---|
| `SettingsSystem` (autoload) — 6 kunci, persist `user://settings.json`, marker `QA:SET:*` | **VERIFIED** | gate `settings` (10/10), tests `set.*` 27 cek |
| `AudioSystem` (autoload) — bank 4 SFX prosedural → bus `SFX`, pool 6 pemutar | **VERIFIED** | `QA:AUDIO:READY streams=4 players=6 sfx_bus=SFX`; `set.sfx_bank`, `set.sfx_click_40_80ms` (55 ms) |
| `I18n` (autoload) — 37 pesan id→en runtime (`Translation.add_message`) | **VERIFIED** | `QA:I18N:READY messages=37 locales=id,en`; `tr("PENGATURAN")="SETTINGS"` saat locale=en |
| `SettingsPanel` (class_name) — dialog 520×320dp, seksi AUDIO/TAMPILAN/BAHASA | **VERIFIED** | foto 00–04 + `verify_m35.py` 82/82 |
| Integrasi menu utama & pause menu → HUD (`hud.open_settings()`) | **VERIFIED** | gate `menu` (`QA:MENU:ACTION action=settings available=true` + `QA:SET:PANEL_OPEN`), gate `ui` (`ui.settings_single_instance`) |
| SFX dapat DIDENGAR di sandbox headless | **UNKNOWN** | browser memblokir AudioContext tanpa gesture (`[warn] The AudioContext was not allowed to start`) — pemutaran nyata perlu uji manual pemain |
| Terjemahan HUD/katalog ke EN | **LIKELY (belum)** | hanya menu + panel pengaturan yang diterjemahkan; HUD/katalog masih ID — dicatat di panel |

## 3. Verifikasi (angka nyata)

- **Gate penuh `bash tools/godot/run_game_check.sh all` → `0 suite FAIL` (exit 0)**,
  dijalankan SETELAH semua kode final (tidak ada edit kode game selama/log setelah
  run ini): tests **368/0**, e2e **36/0**, game smoke + 9 cek menu **PASS**, menu
  **12/12** (`PENGATURAN membuka panel nyata M3 #5` + SAVE/LOAD ticks 600==600),
  **settings 10/10**, asset 17/0, sim 12/0, stress 8/0, ui **32 cek** + 4 cek M3 #5,
  perf throttle 1x/4x/6x 8/0 (fps_avg 2,25 / 1,75 / 2,33 — SwiftShader software GL,
  batas renderer), `pageErrors=0` di semua suite.
- **Gate `settings` (baru)**: **10/10 cek PASS** — bus audio nyata, slider →
  volume bus, ukuran UI → HUD scale, bahasa → locale, persistensi + reload,
  reset default, panel ≤560dp & di dalam layar, anti-tumpuk 0, bank SFX.
- **Gate `menu`**: 12/12 (termasuk cek baru "PENGATURAN membuka panel nyata M3 #5").
- **Gate `ui`**: showcase 32 cek `QA:UI:DONE passed=32 failed=0` + 4 cek M3 #5 baru
  (`ui.settings_open_from_pause`, `ui.settings_single_instance`, ditutup lagi,
  anti-tumpuk) — membuktikan **satu instance panel** dipakai menu utama & pause menu.
- **Tests**: `TESTS:DONE passed=368 failed=0` (+47 cek dari 321 sebelum M3 #5:
  `test_settings.gd` baru, `test_pause_menu.gd` +3, `test_main_menu.gd` disesuaikan).
- **`tools/vision/verify_m35.py`**: **82/82 PASS, 0 FAIL** atas 5 foto
  (`docs/m35_settings/verify_m35.json`): dimensi/dpr, `on_screen=ya`, lebar dp,
  **bukti piksel menguji klaim marker** (95% titik sisi rect benar-benar border
  cyan, 19 346 px tinta di dalam rect), **center 0 px offset** (horizontal &
  vertikal, portrait juga).
- **Konsistensi ukuran (standar, bukan asumsi)**: dialog **520dp** di 1280×720
  @dpr2 **dan** 2340×1080 @dpr3 (tidak ikut membesar saat dpr naik) — batas
  dialog Material **560dp**; portrait 1080×2340 menyusut ke **328dp** (mode kolom
  tunggal) dan tetap ≥320dp. Tinggi 320dp (layar 360dp → margin 20dp atas/bawah).

## 4. Changes (file)

**Baru**: `game/scripts/core/settings_system.gd`, `game/scripts/core/audio_system.gd`,
`game/scripts/core/i18n.gd`, `game/scripts/ui/settings_panel.gd`,
`game/tests/integration/test_settings.gd`, `game/tests/e2e/settings_showcase.gd`,
`tools/audio/make_sfx.py`, `assets/audio/{ui_click,ui_confirm,ui_cancel,wave_alarm}.wav`,
`game/assets/audio/sfx.json`, `tools/vision/capture_settings_evidence.sh`,
`tools/vision/verify_m35.py`, `docs/m35_settings/*`.

**Diubah**: `project.godot` (+3 autoload), `event_bus.gd` (+`settings_changed`),
`ui_theme.gd` (+`get_icon`), `hud.gd` (pemilik panel + `open_settings`, skala ×
`hud_scale`, re-apply saat pengaturan berubah), `main_menu.gd` & `pause_menu.gd`
(delegasi ke panel HUD + fallback), `main.gd` (+mode `settings`, `--settings`),
`shell/index.html`, `test_runner.gd` (+suite `settings`), `test_main_menu.gd`,
`test_pause_menu.gd`, `ui_showcase.gd` (+langkah D2), `run_game_check.sh`
(+suite `settings`, +4 cek `ui`, cek `menu` disesuaikan), `DEV_PLAN.md`,
`PROJECT_STATUS.md`, `UI_UX_DESIGN.md`.

## 5. Temuan jujur yang ditemukan & diperbaiki di turn ini

Semua ditemukan lewat **gate/foto nyata**, bukan dugaan:

1. **`load_settings()` tidak menerapkan nilai** yang dimuat — hanya mengubah
   memori, jadi bus audio/HUD tetap nilai lama sampai restart (bug nyata; test
   `set.loaded_applied_bus` menangkapnya).
2. **`set_anchors_preset` tanpa offsets** → root panel berukuran **0×0** di dalam
   menu, sehingga dialog melimpah **1104×1147 px** (lebar 552dp palsu, keluar
   layar). Diperbaiki → `set_anchors_and_offsets_preset` (+`grow` dari pusat).
3. **`custom_minimum_size` PanelContainer dihitung di luar margin stylebox** →
   lebar 552dp (target 520dp); target sekarang dikurangi `2×MARGIN`.
4. **Konten 573dp tidak muat di layar 360dp** → header/footer tetap + isi seksi di
   `ScrollContainer` (`SettingsScroll`), tinggi dialog dibatasi layar.
5. **Audit anti-tumpuk menghitung isi yang ter-clip** ScrollContainer sebagai
   "tumpukan" → 3 tumpukan **palsu** (`ResetButton-Section_TAMPILAN`, …). Audit
   kini memakai rect **terlihat** (dipotong leluhur yang meng-clip) → 0 tumpukan
   nyata di semua state.
6. **Panel sebagai anak menu terpotong rect panel menu di portrait** (footer
   keluar bingkai — terlihat di foto) → panel dipindah jadi **milik HUD**
   (full layar), menu utama & pause menu hanya memanggil; satu instance.
7. **Mode kolom tunggal tidak berjalan** setelah restrukturisasi scroll (iterasi
   baris masih ke `_body`) → label tetap 240 sehingga panel 698 design px >
   batas 656. Diperbaiki → portrait 328dp.
8. **Pelaporan `on_screen` memakai skala asumsi dpr/2** → melaporkan "TIDAK"
   palsu saat pemain memilih ukuran UI "Besar" (1,15). Kini memakai skala nyata
   panel; pada 1,15 dialog 598dp (**disengaja**: pengguna memang meminta UI
   lebih besar) dan tetap di dalam layar.
9. **`snappedf(1.725, 0.01)` vs float 1 ulp** → cek gagal palsu; toleransi 0,02.
10. **Suite test memakai `await`** → cek setelah titik await **hilang senyap**
    (354 → 346, tanpa FAIL). Pelajaran penting: runner test **sinkron**; asersi
    layout/frame dipindah ke showcase (`?mode=settings`).
11. **`ButtonGroup` dibuat per tombol** (bukan per baris) → eksklusivitas radio
    tidak dijamin kontrol; kini satu grup per baris (diuji `set.panel_radio_exclusive`).
12. **Fullscreen bisa ditolak platform** (browser butuh gesture) → nilai
    pengaturan disamakan dengan mode nyata + tombol di-sync ulang, supaya UI
    tidak berbohong (marker `QA:SET:FULLSCREEN_REFUSED`).

## 6. Bukti (path)

- Foto: `docs/m35_settings/00_menu_settings_1280x720.png` (dari menu utama),
  `01_settings_panel_1280x720.png`, `02_settings_panel_2340x1080.png`,
  `03_menu_settings_portrait_1080x2340.png` (rotasi), `04_pause_settings_1280x720.png`
  (dari pause menu) — masing-masing + `.json` (consoleLogs + metrics).
- Verifier: `docs/m35_settings/verify_m35.json` (**82/82 PASS**).
- Aset audio: `assets/audio/*.wav` + `game/assets/audio/sfx.json` (69 823 B).

## 7. Blockers / batasan yang dilaporkan terbuka

- **Audio tidak bisa diputar di sandbox headless** (autoplay policy). Bukti yang
  ada: bank PCM termuat (durasi terukur), bus ada, counter pemanggilan naik.
  Pendengaran nyata = uji manual pemain (belum dilakukan).
- Level volume linear→dB dipakai apa adanya (`db_to_linear` balik = nilai
  diminta ±0,001) — kurva loudness perceptual (perceived) belum diimplementasi.
- Terjemahan EN baru mencakup menu + panel pengaturan; HUD/katalog masih ID
  (ditulis jujur di dalam panel).
- Model suara prosedural (bukan aset audio final) — "final audio" masih di luar
  scope M1/M2.

## 8. Next action

Milestone M3 berikutnya (M3 #6/#7) sesuai DEV_PLAN; sebelum itu, **verifikasi
independen `git fetch` + gate** tetap wajib karena branch ini juga dikerjakan
agent lain (M3 #4 datang dari agent lain di commit `27ce547`).
