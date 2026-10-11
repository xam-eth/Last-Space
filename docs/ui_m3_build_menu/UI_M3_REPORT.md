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
| 8 | menu_border_cyan_1280 | PASS | border modal x=128 y=360 (design) |
| 9 | menu_border_cyan_2340 | PASS | border modal x=402 y=540 (skala 1.5) |
| 10 | ship_menu_border_cyan_1280 | PASS | border modal x=128 y=360 (design) |
| 11 | ship_menu_border_cyan_2340 | PASS | border modal x=402 y=540 (skala 1.5) |
| 12 | quest_panel_border_1280 | PASS | QuestPanel x=24 y=424 (design) |
| 13 | selection_panel_border_1280 | PASS | SelectionPanel x=360 y=626 (design) |
| 14 | arrow_green_present | PASS | hijau=674 px (sampling) |
| 15 | arrow_green_absent_baseline | PASS | baseline hijau=0 px (arrow memang dari selection) |
| 16 | topbar_fullwidth_2340 | PASS | chip ENERGY border x=36 y=66 (skala 1.5) — sampai edge, tanpa black bar |

**Hasil: 16 PASS / 0 FAIL**

Catatan: panah hijau indikator = 674 px (sampling) saat selection, 0 px di baseline tanpa selection — indikator memang muncul karena klik bangunan.
