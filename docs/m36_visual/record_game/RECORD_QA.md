# RECORD QA — M3.6 device 16:9 640x360 CSS @dpr2 (frame-by-frame, SwiftShader headless)

Rekam layar per frame via CDP `Page.startScreencast` (headless Chromium,
SwiftShader software GL — sama dengan semua suite QA). Analisis piksel
per frame (Pillow) — data nyata, bukan asumsi.

- **Frames**: 20 (fps aktual 0.97 — SwiftShader + screencast overhead)
- **Blank/invalid**: 0 blank, 0 invalid
- **Motion** (rata-rata abs diff antar frame): avg=2.00 max=25.39 — animasi jalan
- **Scene terdeteksi**: command_hud, gameplay
- **Verdict**: **PASS**

## Segmentasi scene (run-length per frame)

| # | Scene | Frame | Waktu (s) | Bukti piksel |
|---|---|---|---|---|
| 1 | gameplay | 0–11 | 0.00–11.29 | 12 frame |
| 2 | command_hud | 12–19 | 12.32–19.50 | 8 frame |

## Arti scene (deteksi piksel, skala HUD full-rect = tinggi/720)

- `modal_menu` — border cyan modal di x=128 design (build/ship menu terbuka)
- `battle` — piksel merah kapal alien (r>200, g<90, b<90) > 100 (sampling) —
  hanya saat wave battle; command core GOLD (g≈215) tidak masuk
- `command_hud` — border cyan quest panel di x=24 design (HUD aktif)
- `gameplay` — 3D arena tanpa penanda UI di atas
- `green_px` per frame = indikator panah hijau (C_OK) — juga bisa hangar
  (production GREEN) / quest bar; di record UI nilainya turun drastis saat
  modal terbuka (arrow tertutup modal) = bukti transisi selection→menu

Frame sampled (setiap 5 frame) tersimpan di `sampled/` sebagai evidence.
