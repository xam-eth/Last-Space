# Visual Benchmark — Build Game Last-Space

Foto hasil akhir game secara visual (data nyata dari web build,
bukan ilustrasi). Diverifikasi piksel (QA_PLAN.md vision check):
valid PNG, dimensi benar, tidak blank, warna khas aspek terlihat.

| Foto | Aspek (ART_DIRECTION.md §1) | Resolusi | Verifikasi |
|---|---|---|---|
| `01_loading_screen.png` | Loading screen — root page (slideshow cinematic + progress bar) | 1920x1080 | PASS |
| `02_command_base.png` | Command base — game utama: HUD + 3D base (kamera gameplay) | 1920x1080 | PASS |
| `03_fleet_formation.png` | Armada — 6 interceptor SHP-001 formasi (engine glow cyan) | 1920x1080 | PASS |
| `04_battle_vs_alien.png` | Battle — defender vs attacker ALN-001 (alien hijau; ungu opsional: weapon terlalu kecil di kamera) | 1920x1080 | PASS |
| `05_stress_42units.png` | Stress — 42 kapal (12 SHP-001 + 30 ALN-001) + 8 turret (alien hijau opsional: kamera jauh, kapal kecil) | 1920x1080 | PASS |
| `06_mobile_1920x1080_16x9.png` | Mobile landscape 16:9 (1920x1080) — full screen | 1920x1080 | PASS |
| `07_mobile_2340x1080_19.5x9.png` | Mobile landscape 19.5:9 (2340x1080) — full screen semua aspek | 2340x1080 | PASS |

**Hasil keseluruhan:** SEMUA PASS

Detail per foto (cek piksel, warna ditemukan): `report.json`.

Cara generate ulang: `bash tools/vision/visual_benchmark.sh`
(butuh `source tools/env.sh`).
