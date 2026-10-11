# RECORD QA — UI M3 (selection -> build menu -> ship menu) (frame-by-frame, SwiftShader headless)

Rekam layar per frame via CDP `Page.startScreencast` (headless Chromium,
SwiftShader software GL — sama dengan semua suite QA). Analisis piksel
per frame (Pillow) — data nyata, bukan asumsi.

- **Frames**: 51 (fps aktual 4.21 — SwiftShader + screencast overhead)
- **Blank/invalid**: 0 blank, 0 invalid
- **Motion** (rata-rata abs diff antar frame): avg=0.63 max=22.48 — animasi jalan
- **Scene terdeteksi**: command_hud, modal_menu
- **Verdict**: **PASS**

## Segmentasi scene (run-length per frame)

| # | Scene | Frame | Waktu (s) | Bukti piksel |
|---|---|---|---|---|
| 1 | command_hud | 0–14 | 0.00–3.32 | 15 frame |
| 2 | modal_menu | 15–50 | 3.56–11.87 | 36 frame |

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
