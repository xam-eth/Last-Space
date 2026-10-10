# Last-Space

Game strategi 3D base-building + pertempuran armada luar angkasa: bangun benteng
antariksa, produksi sumber daya, bangun armada pesawat, kuasai wilayah, dan
bertahan dari invasi alien dalam pertempuran 3D real-time.

- **Engine:** Godot 4.7.2 (GDScript) — diverifikasi via build web/WASM di Chromium headless
- **Art:** Blender 4.5 LTS → `.glb` → Godot
- **Verifikasi visual:** Chromium headless (`@sparticuz/chromium` + `puppeteer-core`)
- **Bahasa dokumen:** dokumen proyek/game dalam Bahasa Indonesia; dokumen
  governance (`AGENTS.md`, `AI_GOVERNANCE.md`, `PROJECT_STATUS.md`,
  `ROADMAP.md`, `DEV_PLAN.md`) dalam Bahasa Inggris (mengikuti paket governance).

## Dokumen

| Dokumen | Isi |
|---|---|
| `Game_Concept.md` | Konsep lengkap game (sudah ada) |
| `Asset_Request_List.md` | Master list kebutuhan aset (sudah ada) |
| `RISK_ANALYSIS.md` | Analisis risiko & urutan kerja 10 phase (catatan developer) |
| `ROADMAP.md` | Roadmap milestone 0–4 + 3 standing limits + keputusan terbuka |
| `DEV_PLAN.md` | Plan Milestone 1 per-phase dengan verification gate |
| `TECH_ARCHITECTURE.md` | Arsitektur tech + framework module (core autoloads, event bus, save format, test harness) |
| `DATA_CONTRACTS.md` | Kontrak data & skema (`res://data/*.tres`), ownership, validasi data |
| `QA_PLAN.md` | Verification gates (NOT STARTED→…→REGRESSION PASS) + QA matrix per phase |
| `MASTER_ASSET_INVENTORY.md` | Inventaris 336 aset + status produksi |
| `ART_DIRECTION.md` | Standar visual (faksi, benteng, VFX, UI, ikon) |
| `ASSET_PIPELINE.md` | Standar Blender → GLB → Godot |
| `ASSET_ACCEPTANCE_CRITERIA.md` | Kriteria aset lolos/terverifikasi |
| `TOOLCHAIN.md` | 3 tools wajib + bukti verifikasi + kendala sandbox |
| `PROJECT_STATUS.md` | Status aktual proyek (per `AI_GOVERNANCE.md`) |
| `AGENTS.md` / `AI_GOVERNANCE.md` | Aturan wajib kerja (anti-bottleneck governance) |

## Website (root repo) — GAME utama (TANPA SETUP APA PUN)

```bash
python3 -m http.server 8000 --bind 0.0.0.0   # dari root repo
# lalu buka http://localhost:8000/  (atau LIVE PREVIEW yang muncul)
```

**Game jalan di WebGL (browser) — preview TIDAK butuh install tools apa pun.**
Build WebGL sudah di-commit di `web/` (godot.js + game.wasm + game.pck +
worklet), jadi cukup serve repo-nya.

- **`index.html` (root) = GAME** — tampil **loading screen** (slideshow
  background cinematic `assets/ui/loading/bg_*.jpg` + icon loading + animasi)
  lalu **game playable fullscreen 16:9 full landscape** (viewport 1280×720 —
  design resolution mobile-first, stretch `canvas_items` + aspect `keep` —
  letterbox gelap di rasio lain).
- **`debug.html`** — dashboard debug: menjalankan **check setup & logika**
  (berbasis data nyata `game/data/*.tres`, port JS dari sistem inti) +
  preview game (iframe). Workflow UI/UX: `UI_UX_DESIGN.md`.
- **Tools (`tools/`, `setup_all.sh`) hanya untuk DEVELOPMENT & VERIFIKASI**
  (build game, test, screenshot) — bukan untuk preview. Rebuild & sync ke
  `web/`: `bash tools/godot/run_game_check.sh all`.

## Game (sudah bisa jalan & terverifikasi — Milestone 1 selesai)

Project game ada di `game/` (Godot 4.7.2, GDScript, semua balance di
`game/data/*.tres`). Verifikasi otomatis di Chromium headless:

```bash
bash tools/godot/run_game_check.sh all    # tests (167) + e2e (36) + game smoke
bash tools/godot/run_game_check.sh tests  # hanya test suite
bash tools/godot/run_game_check.sh e2e    # hanya playthrough end-to-end
```

Hasil: screenshot + report JSON di `tools/godot/build/` (gitignored).
Lihat `DEV_PLAN.md` (apa yang sudah dibangun) dan `PROJECT_STATUS.md` (bukti).

## Tools (wajib, sudah terverifikasi)

```bash
bash tools/setup_all.sh             # SETUP SEMUA SEKALIGUS (mesin apa pun)
# atau manual:
source tools/env.sh                 # environment bersama (path portable)
pip3 install bpy==4.5.14            # Blender (headless, via PyPI)
(cd tools/vision && npm install)    # Chromium vision tool
bash tools/setup_stublibs.sh         # stub libs (opsional; hanya sandbox tanpa X11/GL/NSS)
bash tools/godot/run_smoke.sh       # Godot web runtime + smoke test end-to-end
```

Lihat `TOOLCHAIN.md` untuk detail, bukti verifikasi, dan cara verifikasi game.

## Aturan kerja

Semua pekerjaan mengikuti `AI_GOVERNANCE.md` (wajib dibaca sebelum mulai) dan
`QA_PLAN.md` (verification gate di setiap phase):
progress terverifikasi, bukan sekadar aktivitas; setiap phase diverifikasi
berulang lalu QA berdasarkan **data nyata** (bukan asumsi, bukan "asal jalan");
laporan akhir dengan label VERIFIED/IMPLEMENTED/BLOCKED; human developer adalah
pengambil keputusan akhir.
