# TOOLCHAIN — Last-Space

Tiga tools **wajib** yang harus disiapkan (dan sudah diverifikasi) untuk proyek
ini, plus catatan lengkap cara verifikasinya di sandbox ini.

> Semua perintah diverifikasi pada **2026-10-09**, branch
> `arena/d80e2902-last-space`, sandbox Debian 12 (x86_64, 2 core, 3.8 GB RAM).

## Ringkasan Status

| Tool | Versi | Status | Bukti verifikasi |
|---|---|---|---|
| Chromium (npm pack, vision) | HeadlessChrome **153.0.8010.0** via `@sparticuz/chromium` + `puppeteer-core` 25.13.0 | **VERIFIED** | Screenshot PNG valid 1280×720 + cek piksel (688 warna berbeda) — `tools/vision/out/smoke.png(.json)` |
| Blender | **4.5.14 LTS** (modul `bpy` — Blender sebagai Python module, headless) | **VERIFIED** | Mesh + material + export GLB + import balik GLB — semua lolos |
| Godot | **4.7.2.stable** (build web/WASM resmi, `custom_build.3d95ead8f`) | **VERIFIED** | Engine boot di Chromium headless, menjalankan project nyata, merender scene 3D, screenshot terverifikasi piksel — `tools/godot/build/godot_smoke.png(.json)` |

## 0. Environment bersama

```bash
source tools/env.sh   # set LD_LIBRARY_PATH ke stub libs + GODOT_WEB_DIR
```

## 1. Chromium — npm pack dengan vision (`tools/vision/`)

**Kenapa:** verifikasi visual ("vision") dari build game — screenshot otomatis
dari build web Godot di browser headless, lengkap dengan log console dan metadata.

- **Paket npm:** `@sparticuz/chromium` (mendistribusikan binary Chromium di dalam
  paket npm — semua dari `registry.npmjs.org`) + `puppeteer-core` (driver).
- **Kenapa bukan puppeteer/playwright biasa:** download browser-nya dari host
  yang tidak bisa diakses sandbox ini; `@sparticuz/chromium` mengemas Chromium
  di dalam tarball npm.
- **Isi:**
  - `capture.mjs` — capture screenshot + log console + metadata → PNG + `.json`
    - mendukung `--serve <dir>` (server HTTP lokal; build Godot web butuh HTTP,
      tidak bisa `file://` karena fetch/wasm)
    - mendukung `--wait-for <regex>` (tunggu marker log sebelum screenshot)
    - `--use-angle=swiftshader` aktif → WebGL2 via SwiftShader untuk render 3D
- **Verifikasi yang sudah dijalankan:**
  ```bash
  cd tools/vision && npm install
  node capture.mjs fixtures/smoke.html out/smoke.png 1280 720
  # → HeadlessChrome/153.0.8010.0, PNG valid 1280×720, title terbaca,
  #   cek piksel: 688 warna berbeda (render nyata, bukan blank)
  ```
- **Dipakai untuk:** setiap verifikasi visual game (Milestone 1+), misal
  `node capture.mjs /index.html out.png --serve tools/godot/build/smoke --wait-for MARKER`.

## 2. Blender (`bpy` — headless)

**Kenapa:** produksi aset 3D (pesawat, benteng, kapal, lingkungan) → export GLB
untuk Godot (lihat `ASSET_PIPELINE.md`).

- **Instalasi:** `pip3 install bpy==4.5.14` (Blender resmi sebagai modul Python,
  dari PyPI — versi 4.5 LTS, cocok dengan Python 3.11 sandbox).
- **Dipakai sebagai:** `python3` + `import bpy` (headless, tanpa GUI).
- **Verifikasi yang sudah dijalankan:**
  ```bash
  LD_LIBRARY_PATH=/home/user/tools/stublibs python3 -c "import bpy; print(bpy.app.version_string)"
  # → 4.5.14 LTS
  # smoke test: buat kubus + material metalik → export GLB → cek header GLB valid → import balik GLB → OK
  ```
- **Catatan sandbox:** binary Blender resmi butuh library X11/GL yang tidak ada
  di sandbox ini. Solusi: stub library (lihat §5). Untuk kerja GUI, pakai
  Blender resmi di komputer dev (apt/installer) — pipeline-nya sama persis.

## 3. Godot (4.7.2 — build web/WASM di Chromium headless)

**Kenapa:** engine game. Build web/WASM dipilih karena bisa jalan di Chromium
headless (SwiftShader) tanpa X11 — ini jadi runtime verifikasi kita.

- **Versi:** 4.7.2.stable (build web resmi, single-threaded).
- **Sumber (hanya dari host yang bisa diakses):**
  - Engine WASM: npm package `@ringozz/godot-web-wasm32@4.7.2-643`
    (build Godot 4.7.2 web template resmi, di dalam tarball npm).
  - Shell JS (`Engine` class): source Godot 4.7.2 dari `codeload.github.com`
    (`platform/web/js/engine/*.js`).
- **Setup (otomatis, bisa diulang):** `bash tools/godot/setup_godot_web.sh`
  → hasil di `/home/user/tools/godot-web/` (`godot.js`, `game.wasm`, worklet audio).
- **Packing project tanpa editor:** `python3 tools/godot/make_pck.py <dir> <out.pck>`
  — menulis format PCK v4 yang sama persis dengan `core/io/pck_packer.cpp`
  (diverifikasi: engine berhasil load project hasil packing ini).
- **Smoke test end-to-end:** `bash tools/godot/run_smoke.sh`
  1. setup runtime → 2. pack `tools/godot/smoke_project/` → `game.pck`
  → 3. serve + capture screenshot via vision tool.
- **Hasil verifikasi (2026-10-09):**
  - Log: `Godot Engine v4.7.2.stable.custom_build.3d95ead8f`,
    `GODOT_ENGINE_VERSION: 4.7.2-stable (custom_build)`,
    marker `LAST_SPACE_TOOLCHAIN_SMOKE: READY` ter-match.
  - WebGL2 aktif: `ANGLE ... SwiftShader`.
  - Screenshot 1280×720 valid; cek piksel: kubus biru (5.406 piksel biru) di
    latar gelap (915.315 piksel) → **render 3D nyata terbukti**.
  - Tidak ada error console/page.
- **Catatan:** build ini **tanpa GDExtension** dan single-threaded — cukup untuk
  game GDScript kita. Build native (Linux editor) untuk dev machine: download
  dari godotengine.org (butuh X11/GL di mesin dev).

## 4. Alur Verifikasi Game (dipakai mulai Milestone 1) — SUDAH SIAP PAKAI

`tools/godot/run_game_check.sh` mengotomasi seluruh alur ini untuk project
`game/` (sudah terverifikasi, M1):

```bash
bash tools/godot/run_game_check.sh all    # tests + e2e + game smoke
bash tools/godot/run_game_check.sh tests  # test suite (data+unit+integration)
bash tools/godot/run_game_check.sh e2e    # playthrough end-to-end
bash tools/godot/run_game_check.sh game   # smoke build bisa dimainkan
```

Yang dilakukannya otomatis:
1. `make_script_class_cache.py` — generate `.godot/global_script_class_cache.cfg`
   (resolusi `class_name` tanpa editor — pengganti file yang dibuat editor)
2. `make_pck.py game/ → game.pck` (packing)
3. salin shell + runtime (godot.js, game.wasm, worklet) ke `tools/godot/build/game/`
4. `capture.mjs --serve --wait-for` → jalankan tiap mode di Chromium headless
   (tests: `TESTS:DONE`; e2e: `QA:LOOP:COMPLETE`; game: `QA:GAME:READY`)
5. cek report JSON: tidak ada `TEST:FAIL`, tidak ada pageErrors, marker match,
   dan `failed=0` — exit code = jumlah suite yang FAIL (gate CI)
6. screenshot + report tersimpan di `tools/godot/build/game_*.png(.json)`

Mode game dipilih via command line: shell meneruskan `?mode=tests|e2e|game`
sebagai argumen engine (`OS.get_cmdline_args()` di `game/scripts/main.gd`).

## 4c. Debug & Preview via web root repo (HTML/JS)

Sesuai kebutuhan human developer: debug & preview memakai halaman HTML/JS di
**root repo** (bukan UI Godot), di-serve dengan:

```bash
python3 -m http.server 8000 --bind 0.0.0.0   # dari root repo
```

- `index.html` (root) meng-import `debug/*.js`:
  - `debug/tres.js` — parser .tres; `debug/data.js` — load `game/data/*.tres`
  - `debug/logic.js` — port JS sistem inti (Economy, produksi, CombatSimulator, Progression)
  - `debug/checks.js` — check setup + data + logika (berbasis data nyata)
  - `debug/app.js` — render dashboard + preview game (iframe ke `tools/godot/build/game/`)
- Verifikasi dashboard (headless): `node capture.mjs http://127.0.0.1:8000/ out.png --wait-for "DEBUG:PAGE:COMPLETE" --wait-until domcontentloaded`
  - marker: `DEBUG:PAGE:DONE passed=X failed=Y` (saat ini **56/56 PASS**)
- Catatan: game **bukan "asal jalan"** — visual harus real game; placeholder
  hanya sementara sampai pilot asset (`DEV_PLAN.md` M2).

## 4b. Alur Manual (kalau perlu)

```
1. (dev) buat/edit project game di game/ (project.godot, scenes/, scripts/, data/)
2. bash tools/godot/run_game_check.sh all   (atau panggil langkah 1-5 di atas manual)
3. cek: consoleLogs (marker + tidak ada error), pageErrors kosong,
   PNG valid, cek piksel (via Pillow) untuk memastikan render bukan blank
4. arsipkan hasil + update PROJECT_STATUS.md (label VERIFIED + bukti)
```

## 5. Kendala Sandbox & Solusinya (transparan, terdokumentasi)

Sandbox hanya bisa akses: `github.com`, `codeload.github.com`,
`api.github.com`, `registry.npmjs.org`, `pypi.org`, `files.pythonhosted.org`.
Konsekuensinya:

1. **Download binary dari GitHub Releases tidak bisa** (redirect ke
   `objects.githubusercontent.com` — diblokir). Solusi: Godot web/WASM dari npm
   (`@ringozz/godot-web-wasm32`), Godot source dari `codeload.github.com`.
2. **Tidak ada apt / library X11, GL, NSS, dsb.** Solusi:
   - Editor Godot (GUI) tidak bisa jalan di sandbox → pakai build web/WASM di
     Chromium (sudah terbukti).
   - `bpy` dan Chromium butuh beberapa library GUI yang tidak dipanggil saat
     operasi headless → disediakan **stub library** di
     `/home/user/tools/stublibs/`, dibuat otomatis oleh
     `tools/setup_stublibs.sh` (deteksi library hilang via `ldd`, kumpulkan
     simbol via `ldd -r`, lalu self-verify: import bpy + launch Chromium).
     Lihat `tools/env.sh`. Ini trik khusus sandbox; **di komputer dev, tidak
     diperlukan** — instalasi normal sudah menyediakan library tersebut.
3. **WebGL di Chromium headless** → SwiftShader (`--use-angle=swiftshader
   --enable-unsafe-swiftshader`), sudah aktif di `capture.mjs`.

## 6. Tools Tambahan (terpasang)

- `pillow` (Pillow 12.3.0) — analisis piksel screenshot (cek bukan blank).
- `node` v22.22.3, `npm` 10.9.8, `python3` 3.11.2, `gcc` 12.2.0.

## 7. Reproduksi dari Awal (PORTABLE — jalan di mesin apa pun)

**Satu perintah (dev machine / CI / sandbox):**

```bash
bash tools/setup_all.sh
```

`setup_all.sh` menjalankan: Blender (bpy via pip) → vision tool (npm) →
stub libs (opsional; hanya untuk sandbox tanpa X11/GL/NSS) → Godot web
runtime → verifikasi penuh (tests + e2e).

**Path (portable, tidak hardcode):**
- Tools dir default: `$HOME/.last-space-tools` (override: `GODOT_TOOLS_DIR`).
- Godot web runtime: `$GODOT_WEB_DIR` = `$GODOT_TOOLS_DIR/godot-web`.
- Stub libs: `$GODOT_TOOLS_DIR/stublibs`.
- `source tools/env.sh` untuk environment (LD_LIBRARY_PATH stub — hanya
  berpengaruh di sandbox; di dev machine yang sudah punya libnss3/libXrender,
  stub tidak diperlukan).

**Langkah manual (kalau perlu):**
```bash
source tools/env.sh
pip3 install bpy==4.5.14                      # Blender (bpy)
(cd tools/vision && npm install)              # vision tool
bash tools/setup_stublibs.sh                   # opsional (sandbox saja)
bash tools/godot/setup_godot_web.sh           # Godot web runtime
bash tools/godot/run_game_check.sh all        # verifikasi penuh
```

Semua langkah di atas sudah dijalankan dan lolos (bukti di `PROJECT_STATUS.md`).
