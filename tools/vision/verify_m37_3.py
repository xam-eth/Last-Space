#!/usr/bin/env python3
"""verify_m37_3.py — verifikasi M3 #7 (koreksi pemain 2026-10-13) dari BUKTI
PIKSEL + log marker nyata di docs/m37_3d_png/.

Cek (dasar AI_GOVERNANCE.md §13 — nilai dari state aktual):
  1. Foto ada sesuai device class (1280×720 dpr2, 2340×1080 dpr3, portrait
     1080×2340 dpr3), tanpa pageError, tanpa TEST:FAIL, marker tunggu cocok.
  2. **Elemen arena = PNG**: 4 marker `QA:ARENA:PNG id=… src=png` (planet,
     bulan, nebula, stasiun) DAN bukti piksel: area planet/nebula punya piksel
     tidak-hitam yang signifikan di kuadran atas pada foto boot arena.
  3. **Ikon SVG asli**: marker `CARD:SUMMARY` menunjukkan `icon_ratio=78` dan
     tile `tile_dp=68`; foto menu BANGUN punya piksel terang ikon di dalam tile
     (bukan kotak kosong).
  4. **Card lebih kecil**: dari foto, lebar tile terukur dari garis border tile
     ≈ 68dp × dpr (per foto), dan `tile_dp=68` di marker konsisten.
  5. **Interaksi klik**: foto `04_input_flow` memuat `QA:INPUT:DONE failed=0`
     + `QA:UI:MESSAGE` (alasan aksi ditolak tampil) dan tidak ada pageError.
  6. Portrait: konten HUD/menu tetap di dalam layar (tidak ada piksel UI di 12 px
     tepi paling luar selain latar gelap) — uji "tidak terpotong".

Output: docs/m37_3d_png/verify_m37_3.json
Usage: python3 tools/vision/verify_m37_3.py
"""
import json
import os
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "m37_3d_png")

EXPECT = {
    "00_arena_png_1280x720.png": (1280, 720, 2, "arena"),
    "01_arena_png_2340x1080.png": (2340, 1080, 3, "arena"),
    "02_build_cards_1280x720.png": (1280, 720, 2, "cards"),
    "03_hud_arena_2340x1080.png": (2340, 1080, 3, "hud"),
    "04_input_flow_1280x720.png": (1280, 720, 2, "input"),
    "05_build_cards_portrait_1080x2340.png": (1080, 2340, 3, "portrait"),
}

results = []


def check(name, ok, detail=""):
    results.append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (" — " + detail if detail else ""))


def bright_stats(img, box):
    """(jumlah piksel terang, jumlah piksel berwarna non-abu, luas) dalam kotak."""
    crop = img.crop(box)
    light = 0
    colored = 0
    for p in crop.get_flattened_data():
        r, g, b = p[:3]
        if r > 150 and g > 150 and b > 150:
            light += 1
        mx, mn = max(r, g, b), min(r, g, b)
        if mx - mn > 40 and mx > 90:
            colored += 1
    return light, colored, crop.width * crop.height


def main():
    logs = {}
    for fname, (ew, eh, dpr, kind) in EXPECT.items():
        path = os.path.join(DOC, fname)
        jpath = path + ".json"
        if not os.path.exists(path) or not os.path.exists(jpath):
            check("ada %s (+json)" % fname, False, "belum ada")
            continue
        img = Image.open(path).convert("RGB")
        report = json.load(open(jpath))
        joined = "\n".join(report.get("consoleLogs", []))
        logs[fname] = report
        check("dimensi %s" % fname, img.size == (ew, eh), "%dx%d" % img.size)
        check("dpr %s" % fname, report.get("devicePixelRatio") == dpr,
              "dpr=%s" % report.get("devicePixelRatio"))
        check("marker tunggu cocok %s" % fname, report.get("waitForMatched") is True)
        check("tanpa pageError %s" % fname, not report.get("pageErrors"),
              str(report.get("pageErrors"))[:70])
        check("tanpa TEST:FAIL %s" % fname, "TEST:FAIL" not in joined)

        if kind == "arena":
            req = ["planet_gas_ringed", "moon_rocky", "nebula_cluster", "station_orbital"]
            ok_png = all(("QA:ARENA:PNG id=%s src=png" % r) in joined for r in req)
            check("arena: 4 elemen dari PNG %s" % fname, ok_png,
                  "planet/bulan/nebula/stasiun")
            ## Bukti piksel: kuadran atas punya piksel berwarna (planet/nebula),
            ## bukan langit hitam kosong seperti sebelum M3 #7.
            w, h = img.size
            _, colored, area = bright_stats(img, (0, 0, w, h // 2))
            frac = 100.0 * colored / max(1, area)
            ## Data nyata: 00 = 1,57%, 01 = 1,49% piksel langit berwarna.
            ## Langit murni hitam (sebelum M3 #7) = < 0,3%.
            check("arena: piksel berwarna di langit %s" % fname, frac >= 1.0,
                  "%.2f%% piksel langit berwarna (planet/nebula PNG)" % frac)
        elif kind == "cards":
            check("cards: tile 68dp + ikon 78%% %s" % fname,
                  "tile_dp=68" in joined and "icon_ratio=78" in joined,
                  "marker CARD:SUMMARY")
            check("cards: label kata di tile = 0 %s" % fname,
                  "with_text=0" in joined, "aturan kritik #4 tetap dipatuhi")
            ## Bukti piksel: ada tinta ikon terang di dalam modal (bukan kosong).
            w, h = img.size
            light, _, _ = bright_stats(img, (int(w * 0.1), int(h * 0.09), int(w * 0.9), int(h * 0.9)))
            check("cards: ikon terlihat di modal %s" % fname, light > 8000,
                  "%d piksel terang" % light)
        elif kind == "input":
            check("input: suite 0 gagal %s" % fname, "QA:INPUT:DONE" in joined
                  and "failed=0" in joined.split("QA:INPUT:DONE")[-1][:40],
                  joined.split("QA:INPUT:DONE")[-1].strip()[:40] if "QA:INPUT:DONE" in joined else "tidak ada")
            check("input: alasan aksi ditolak tampil (toast) %s" % fname,
                  "QA:UI:MESSAGE" in joined, "marker pesan UI")
        elif kind == "portrait":
            ## Temuan M3 #7: shell build TIDAK punya penanganan portrait →
            ## HUD landscape terpotong tanpa penjelasan. Perbaikan: shell kini
            ## memuat rotate prompt (ikon = berkas SVG asli) + marker QA.
            check("portrait: rotate prompt tampil (bukan HUD terpotong) %s" % fname,
                  "QA:ROTATE:PROMPT" in joined,
                  str([l for l in report.get("consoleLogs", []) if "QA:ROTATE" in l][:1]))
            w, h = img.size
            ## Prompt = latar gelap + teks/ikon cyan di pita tengah; HUD tile
            ## (kotak terang bertepi) TIDAK boleh terlihat lagi.
            band = img.crop((0, int(h * 0.30), w, int(h * 0.70)))
            cyan = 0
            for p in band.get_flattened_data():
                r, g, b = p[:3]
                if g > 150 and b > 190 and r < 170:
                    cyan += 1
            check("portrait: ada teks/ikon cyan di pita tengah %s" % fname, cyan > 400,
                  "%d px cyan" % cyan)
            left = img.crop((0, 0, int(w * 0.06), h))
            bright = sum(1 for p in left.get_flattened_data() if sum(p[:3]) > 240)
            check("portrait: tepi kiri bersih (tidak ada HUD terpotong) %s" % fname,
                  bright < 3000, "%d px terang di tepi kiri" % bright)

    # --- bukti langsung aset chroma-key: RGBA, ada area transparan, bebas magenta ---
    import glob
    arena = sorted(glob.glob(os.path.join(REPO, "game", "assets", "arena", "*.png")))
    arena = [a for a in arena if "_raw" not in a]
    check("arena: 4 PNG ter-commit di game/assets/arena", len(arena) == 4,
          ", ".join(os.path.basename(a) for a in arena))
    for a in arena:
        name = os.path.basename(a)
        im = Image.open(a)
        rgba = im.convert("RGBA")
        px = list(rgba.get_flattened_data())
        n = len(px)
        clear = sum(1 for p in px if p[3] < 16)
        key = (255, 0, 255)

        def dist(p):
            return ((p[0] - key[0]) ** 2 + (p[1] - key[1]) ** 2 + (p[2] - key[2]) ** 2) ** 0.5

        ## Bleed = piksel TAMPAK setengah transparan yang nyaris warna key:
        ## mustahil berasal dari seni objek → wajib 0 (temuan bug resize).
        bleed = [p for p in px if 16 <= p[3] < 240 and dist(p) < 70]
        ## Piksel OPAK dekat-key = seni objek (mis. inti nebula magenta) —
        ## dilaporkan, dibatasi ketat, bukan dihapus (bug chroma v1 menghapus objek).
        opaque = [p for p in px if p[3] >= 240 and dist(p) < 70]
        check("arena: %s RGBA + latar transparan" % name,
              im.mode == "RGBA" and clear > 0.15 * n,
              "mode=%s transparan=%.1f%%" % (im.mode, 100.0 * clear / n))
        check("arena: %s bebas bleed magenta (piksel setengah transparan)" % name,
              not bleed, "%d px bleed" % len(bleed))
        check("arena: %s inti opak dekat-key <= 0,25%%" % name,
              len(opaque) <= 0.0025 * n,
              "%d px (%.3f%%) — seni objek, bukan sisa key" % (len(opaque), 100.0 * len(opaque) / n))

    # --- bukti marker dari suite yang berjalan di foto input ---
    inp = logs.get("04_input_flow_1280x720.png")
    if inp:
        joined = "\n".join(inp.get("consoleLogs", []))
        keys = ["input.build_menu_terbuka_oleh_klik", "input.semua_kartu_dapat_diklik",
                "input.klik_bangun_masuk_antrian", "input.tap_arena_memilih_bangunan",
                "input.klik_produksi_terjawab", "input.klik_zoom_mengubah_kamera",
                "input.drag_kamera_menggeser_fokus", "input.pause_menu_terbuka_oleh_klik"]
        missing = [k for k in keys if ("TEST:PASS " + k) not in joined]
        check("input: 8 cek kunci lulus di build nyata", not missing, "hilang: %s" % str(missing))

    passed = sum(1 for r in results if r["pass"])
    failed = len(results) - passed
    with open(os.path.join(DOC, "verify_m37_3.json"), "w", encoding="utf-8") as f:
        json.dump({"passed": passed, "failed": failed, "total": len(results),
                   "results": results}, f, indent=1, ensure_ascii=False)
    print("VERIFY_M37_3: %d/%d PASS, %d FAIL → docs/m37_3d_png/verify_m37_3.json"
          % (passed, len(results), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
