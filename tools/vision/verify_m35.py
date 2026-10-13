#!/usr/bin/env python3
"""verify_m35.py — verifikasi BUKTI (piksel + log marker) panel PENGATURAN M3 #5
di docs/m35_settings/. Dasar: AI_GOVERNANCE.md §13 — nilai dari state aktual.

Yang diuji (semua dihitung dari data nyata, bukan asumsi):
  1. 5 PNG ada dengan dimensi & dpr sesuai device class, plus log pasangannya;
     tidak ada pageError, tidak ada TEST:FAIL, marker tunggu cocok.
  2. Marker runtime `QA:SET:PANEL rect=WxH at=XxY … w_dp=… on_screen=ya`
     ada dan konsisten: lebar 320–560dp (batas dialog Material 560dp),
     `on_screen=ya` (dialog tidak terpotong layar).
  3. Bukti piksel MENGUJI klaim marker: pada keempat sisi rect yang diklaim
     harus benar-benar ada piksel border cyan UiTheme (≥60% titik uji) — jadi
     rect itu bukan angka hampa; di dalam rect ada tinta terang (label/kontrol)
     ≥ 2000 px; rect berada di dalam gambar.
  4. Geometri: pusat rect ≈ pusat layar (≤24 px) — dialog benar-benar center
     di 16:9, 19,5:9 dan portrait.
  5. Konsistensi antar device: lebar dp dpr2 == dpr3 (tidak ikut membesar),
     portrait menyusut ≤360dp (kolom tunggal), suite tanpa gagal
     (`QA:SETTINGS:DONE failed=0`, `QA:UI:DONE failed=0`).

Catatan jujur: kotak dialog TIDAK dideteksi ulang dari warna isi, karena warna
latar 3D (0B1020) identik dengan warna modal `UiTheme.C_MODAL` — deteksi warna
akan menandai seluruh langit. Karena itu klaim marker diuji langsung pada piksel
(border + tinta) supaya dua sumber bukti tetap saling menguatkan.

Output: docs/m35_settings/verify_m35.json.
Usage: python3 tools/vision/verify_m35.py
"""
import json
import os
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "m35_settings")

EXPECT = {
    "00_menu_settings_1280x720.png": (1280, 720, 2, "menu"),
    "01_settings_panel_1280x720.png": (1280, 720, 2, "settings"),
    "02_settings_panel_2340x1080.png": (2340, 1080, 3, "settings"),
    "03_menu_settings_portrait_1080x2340.png": (1080, 2340, 3, "menu"),
    "04_pause_settings_1280x720.png": (1280, 720, 2, "pause"),
}

results = []


def check(name, ok, detail=""):
    results.append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (" — " + detail if detail else ""))


def is_border(px, x, y, w, h):
    if x < 0 or y < 0 or x >= w or y >= h:
        return False
    r, g, b = px[x, y][:3]
    return g > 80 and b > 100 and g >= r


def edge_border_fraction(img, rect):
    """Fraksi titik uji pada 4 sisi rect yang memiliki piksel border cyan di
    sekitarnya (offset -4..+4 px). Menguji klaim marker terhadap piksel nyata."""
    x0, y0, x1, y1 = rect
    px = img.load()
    w, h = img.size
    hits = 0
    total = 0
    step_x = max(1, (x1 - x0) // 40)
    step_y = max(1, (y1 - y0) // 40)
    for x in range(x0 + 4, x1 - 4, step_x):
        for yy in (y0, y1):
            total += 1
            if any(is_border(px, x, yy + d, w, h) for d in (-4, -2, 0, 2, 4)):
                hits += 1
    for y in range(y0 + 4, y1 - 4, step_y):
        for xx in (x0, x1):
            total += 1
            if any(is_border(px, xx + d, y, w, h) for d in (-4, -2, 0, 2, 4)):
                hits += 1
    return hits / max(1, total)


def light_ink(img, rect, thresh=150):
    x0, y0, x1, y1 = rect
    inner = img.crop((x0 + 10, y0 + 10, x1 - 10, y1 - 10))
    return sum(1 for p in inner.getdata() if p[0] > thresh and p[1] > thresh and p[2] > thresh)


def marker_rect(line):
    wh = line.split("rect=")[1].split()[0].split("x")
    at = line.split(" at=")[1].split()[0].split("x")
    return (int(at[0]), int(at[1]), int(at[0]) + int(wh[0]), int(at[1]) + int(wh[1]))


def main():
    dp = {}
    for fname, (ew, eh, dpr, mode) in EXPECT.items():
        path = os.path.join(DOC, fname)
        jpath = path + ".json"
        if not os.path.exists(path) or not os.path.exists(jpath):
            check("ada %s (+json)" % fname, False, "file hilang")
            continue
        img = Image.open(path).convert("RGB")
        report = json.load(open(jpath))
        joined = "\n".join(report.get("consoleLogs", []))
        check("dimensi %s" % fname, img.size == (ew, eh), "%dx%d" % img.size)
        check("dpr %s" % fname, report.get("devicePixelRatio") == dpr,
              "dpr=%s" % report.get("devicePixelRatio"))
        check("marker tunggu cocok %s" % fname, report.get("waitForMatched") is True)
        check("tanpa pageError %s" % fname, not report.get("pageErrors"),
              str(report.get("pageErrors"))[:80])
        check("tanpa TEST:FAIL %s" % fname, "TEST:FAIL" not in joined)

        pan = [l for l in report.get("consoleLogs", []) if "QA:SET:PANEL rect" in l]
        check("marker QA:SET:PANEL %s" % fname, bool(pan))
        if not pan:
            continue
        line = pan[-1]
        rect = marker_rect(line)
        w_dp = float(line.split("w_dp=")[1].split()[0])
        dp[fname] = w_dp
        check("on_screen=ya %s" % fname, "on_screen=ya" in line,
              line.split("on_screen=")[-1])
        check("lebar ≤560dp (batas dialog Material) %s" % fname, w_dp <= 560.0,
              "%.0f dp" % w_dp)
        check("lebar ≥320dp %s" % fname, w_dp >= 320.0, "%.0f dp" % w_dp)
        check("rect marker di dalam gambar %s" % fname,
              rect[0] >= 0 and rect[1] >= 0 and rect[2] < img.size[0] and rect[3] < img.size[1],
              str(rect))

        # --- bukti piksel menguji klaim marker ---
        frac = edge_border_fraction(img, rect)
        check("piksel: sisi rect = border cyan %s" % fname, frac >= 0.6,
              "%.0f%% titik sisi punya border di sekitarnya" % (frac * 100))
        ink = light_ink(img, rect)
        check("piksel: tinta label/kontrol di dalam rect %s" % fname, ink > 2000,
              "%d piksel terang" % ink)
        h_dp = (rect[3] - rect[1]) / dpr
        check("tinggi ≥240dp %s" % fname, h_dp >= 240.0, "%.0f dp" % h_dp)

        # --- geometri: dialog center di layar ---
        cx_off = abs((rect[0] + rect[2]) / 2 - img.size[0] / 2)
        cy_off = abs((rect[1] + rect[3]) / 2 - img.size[1] / 2)
        check("dialog center horizontal %s" % fname, cx_off <= 24, "offset %.0f px" % cx_off)
        check("dialog center vertikal %s" % fname, cy_off <= 24, "offset %.0f px" % cy_off)

        # --- marker suite sesuai jalur ---
        if mode == "settings":
            done = [l for l in report.get("consoleLogs", []) if "QA:SETTINGS:DONE" in l]
            check("suite settings 0 gagal %s" % fname,
                  bool(done) and "failed=0" in done[-1], done[-1] if done else "tidak ada")
        elif mode == "pause":
            done = [l for l in report.get("consoleLogs", []) if "QA:UI:DONE" in l]
            check("suite ui 0 gagal %s" % fname,
                  bool(done) and "failed=0" in done[-1], done[-1] if done else "tidak ada")
            check("panel dibuka dari pause menu %s" % fname,
                  "QA:UI:PAUSE_SETTINGS_OPEN" in joined and "open=true" in joined)

    a, b = "01_settings_panel_1280x720.png", "02_settings_panel_2340x1080.png"
    if a in dp and b in dp:
        check("lebar dp KONSISTEN dpr2 vs dpr3 (tidak ikut membesar)",
              abs(dp[a] - dp[b]) <= 1.0, "%.0f dp vs %.0f dp" % (dp[a], dp[b]))
    p = "03_menu_settings_portrait_1080x2340.png"
    if p in dp:
        check("portrait menyusut (kolom tunggal) ≤360dp", dp[p] <= 360.0, "%.0f dp" % dp[p])
        check("portrait masih ≥320dp (bukan mengecil berlebihan)", dp[p] >= 320.0,
              "%.0f dp" % dp[p])

    passed = sum(1 for r in results if r["pass"])
    failed = len(results) - passed
    with open(os.path.join(DOC, "verify_m35.json"), "w", encoding="utf-8") as f:
        json.dump({"passed": passed, "failed": failed, "total": len(results),
                   "w_dp_per_photo": dp, "results": results}, f, indent=1,
                  ensure_ascii=False)
    print("VERIFY_M35: %d/%d PASS, %d FAIL → docs/m35_settings/verify_m35.json"
          % (passed, len(results), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
