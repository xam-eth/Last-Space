# DEVICE_CLASS_BRIEF — Data untuk Keputusan "Minimum Device Class"

**Status:** 📊 DATA SIAP — keputusan tetap pada human developer (AI_GOVERNANCE.md:
human = decision-maker final). Dokumen ini **tidak memutuskan**, hanya menyajikan
hasil ukur nyata (M2 item 5, DEV_PLAN / ROADMAP unapproved decision).

## 1. Yang dibutuhkan

ROADMAP "Unapproved decisions": **Minimum device class: TBD — blocks mobile
performance budgets.** Tanpa kelas device minimum, tidak ada budget numerik
FPS/frame/memory yang bisa diverifikasi (M2 item 5 mobile performance test).

## 2. Metode (data nyata, bukan asumsi)

- **Scene:** stress scene — 42 kapal (12 defender SHP-001 + 30 attacker
  ALN-001) + 8 laser_turret (target unit PROVISIONAL, "fleet size on screen"
  belum diputuskan).
- **Build:** Godot 4.7.2 web/WASM yang di-commit di `web/`, diukur via
  headless Chromium (`tools/vision/capture.mjs` + suite `perf`
  `tools/godot/run_game_check.sh perf`).
- **Emulasi device class:** CDP `Emulation.setCPUThrottlingRate` —
  **1x** = baseline sandbox, **4x** ≈ mid-tier mobile (Snapdragon 6xx class),
  **6x** ≈ low-end budget (Helio G/A53 class).
- **Renderer:** `ANGLE (Vulkan 1.3.0, SwiftShader)` = **software GL** — angka
  berikut adalah indikasi sensitivitas CPU pada scene, **bukan** performa device
  fisik (device nyata dengan GPU hardware akan jauh lebih tinggi).
- **Hasil:** 3 run × 8/8 stress checks PASS, 0 pageErrors, exit 0.
  Report: `tools/godot/build/game_perf_t{1,4,6}.png.json`.

## 3. Hasil ukur (data nyata, 2026-10-11)

| Emulated class | CPU throttle | fps_avg | fps_min | frame_ms avg | frame_ms max | JS heap |
|---|---|---|---|---|---|---|
| Baseline sandbox | 1x | 12,2 | 11,0 | 81,3 | 147,9 | 7,8 MB |
| ~Mid-tier mobile | 4x | 8,8 | 7,0 | 112,7 | 150,0 | 8,4 MB |
| ~Low-end budget | 6x | 8,5 | 5,0 | 111,8 | 150,0 | 7,9 MB |

Catatan: draw calls 230 avg, render objects ~454, nodes 427 (sama semua class —
beban sama, yang berubah hanya kecepatan CPU). Memory stabil ~8 MB JS heap
(wasm memory tidak ter-expose di headless — diukur via `page.metrics`).

## 4. Interpretasi jujur (label evidence)

- **VERIFIED (data nyata):** scene 42 kapal + 8 turret berjalan tanpa freeze di
  semua class emulasi; frame time dan FPS tercatat; memory ~8 MB JS heap.
- **LIKELY:** pada device fisik low-end (GPU hardware, bukan SwiftShader),
  fps akan jauh di atas angka emulasi — software GL di sandbox adalah
  **worst-case kasar**, bukan representasi device nyata.
- **ASSUMPTION (belum terbukti):** korelasi throttle 4x/6x dengan device class
  tertentu (Snapdragon 6xx / Helio G) — hanya berdasarkan praktik umum
  industri, belum diukur di device fisik.
- **UNKNOWN:** performa di device fisik target — perlu device/kelas terpilih
  untuk diukur (atau cloud device farm).

## 5. Opsi keputusan (untuk human developer)

| Opsi | Minimum device class | Konsekuensi berdasarkan data |
|---|---|---|
| **A — Low-end budget** | Android 2019, ~4 GB RAM, Helio G35/A53 class (throttle 6x) | Game saat ini ~8 fps di emulasi software GL → **perlu optimasi** (kurangi unit on-screen, LOD, efek) sebelum bisa klaim jalan di class ini. Butuh device fisik untuk verifikasi akhir. |
| **B — Mid-tier** (rekomendasi data) | Android 2020+, ~6 GB RAM, Snapdragon 6xx class (throttle 4x) | ~9 fps di emulasi software GL; device fisik mid-tier dengan GPU hardware diprediksi (LIKELY) jauh melebihi 30 fps. Risiko rendah. |
| **C — High-end saja** | Snapdragon 8xx / flagship | Over-target untuk game strategi kasual; tidak efisien. |

**Rekomendasi berbasis data (bukan keputusan):** opsi **B (mid-tier)** —
memberi headroom optimasi yang wajar tanpa over-engineering; opsi A baru
layak setelah ada data device fisik (software GL terlalu pesimistis untuk
low-end).

## 6. Keputusan yang dibutuhkan (human developer)

1. **Minimum device class** (pilih A/B/C atau spesifikasi sendiri).
2. **Performance budget** setelah class diputuskan: target fps (misal 30),
   frame-time max (misal < 100 ms spike), memory cap (misal < 150 MB).
3. (Opsional) **Unit on-screen maksimum** — saat ini stress scene 42 kapal +
   8 turret adalah PROVISIONAL (menunggu art decision "fleet size on screen").

## 7. Setelah keputusan

Budget numerik akan di-set di `stress_scene.gd` (checks `stress.fps_avg_*`,
`stress.frame_ms_max_*`, `stress.memory_*`) dan suite `perf` jadi gate
verifikasi berulang — semua berbasis data nyata, sesuai QA_PLAN.md.
