# UI M3 #1/#2 — Verifikasi Piksel (Build Menu / Ship Menu / Quest Panel / Selection)

Verifikasi berbasis data piksel nyata (Pillow) — koreksi human 2026-10-11.
File: `docs/ui_m3_build_menu/` (5 foto + report.json).

| # | Cek | Hasil | Detail |
|---|---|---|---|
| 1 | valid_00_baseline_1280x720.png | PASS | 1280 720 |
| 2 | valid_01_command_selected_1280x720.png | PASS | 1280 720 |
| 3 | valid_02_build_menu_1280x720.png | PASS | 1280 720 |
| 4 | valid_03_command_selected_2340x1080.png | PASS | 2340 1080 |
| 5 | valid_04_build_menu_2340x1080.png | PASS | 2340 1080 |
| 6 | valid_05_ship_menu_1280x720.png | PASS | 1280 720 |
| 7 | valid_06_ship_menu_2340x1080.png | PASS | 2340 1080 |
| 8 | valid_07_pause_menu_1280x720.png | PASS | 1280 720 |
| 9 | valid_08_pause_menu_2340x1080.png | PASS | 2340 1080 |
| 10 | menu_border_cyan_1280 | PASS | border modal x=96 y=360 (design, modal 1088×544) |
| 11 | menu_border_cyan_2340 | PASS | border modal x=354 y=540 (skala 1.5, modal 544dp) |
| 12 | ship_menu_border_cyan_1280 | PASS | border modal x=96 y=360 (design) |
| 13 | ship_menu_border_cyan_2340 | PASS | border modal x=354 y=540 (skala 1.5) |
| 14 | pause_menu_border_cyan_1280 | PASS | border modal x=400 y=360 (design, modal 480x360 center) |
| 15 | pause_menu_border_cyan_2340 | PASS | border modal x=810 y=540 (skala 1.5, design x=540) |
| 16 | quest_panel_border_1280 | PASS | QuestPanel x=32..44 y=180..380 (design, dari dump M3.7) |
| 17 | selection_panel_border_1280 | PASS | SelectionPanel x=448..470 y=496..670 (design, dari dump M3.7) |
| 18 | arrow_green_present | PASS | hijau=562 px (sampling) |
| 19 | arrow_green_absent_baseline | PASS | baseline hijau=0 px (arrow memang dari selection) |
| 20 | topbar_fullwidth_2340 | PASS | chip ENERGY border x=48 y=66 (skala 1.5 dari design x=32, margin 16dp) — sampai edge, tanpa black bar |

**Hasil: 20 PASS / 0 FAIL**

Catatan: panah hijau indikator = 562 px (sampling) saat selection, 0 px di baseline tanpa selection — indikator memang muncul karena klik bangunan.
