#!/usr/bin/env python3
"""verify_m3_6_camera.py — verifikasi BUKTI PIKSEL kamera M3 #6 (zoom & pan Command Mode).

Semua angka berasal dari piksel nyata (docs/m3_6_camera/*.png) + log marker pada
.json hasil capture; tidak ada klaim yang tidak diuji (AI_GOVERNANCE §13).

Bukti yang diuji:
  A. Foto & runtime per file: dimensi, dpr, marker tunggu, tanpa pageError,
     tanpa TEST:FAIL, marker kamera ada, HUD tanpa tumpukan, label dunia tidak
     menembus panel HUD.
  B. ZOOM NYATA (piksel, bukan angka log):
     - luas piksel platform emas: close > default > far (rasio close ≥1,30,
       far ≤0,55);
     - jarak garis grid lantai (cyan): close ≥1,15× default, far ≤0,80× default;
     - close zoom: koridor label di atas HQ = 0 piksel teks terang, sedangkan
       default punya ≥100 → deklutter BENAR-BENAR menyembunyikan label yang
       akan menembus panel OBJEKTIF (temuan foto putaran pertama).
  C. PAN NYATA (piksel): centroid platform emas bergeser ≥60 px, tetapi jarak
     grid tidak berubah drastis (pan ≠ zoom; 0,85–1,15× default).
  D. Kontrol zoom HUD: ada tinta teks di klaster kanan-tengah (tombol + / chip /
     tombol −) di SEMUA foto termasuk portrait → kontrol tetap di tepi kanan.
  E. Marker zoom + chip sesuai langkah showcase: default 1,0/"x1,0",
     close 0,625/"x1,6", far 1,6/"x0,6".
  F. Marker deklutter per langkah: default & far label terlihat (visible=1),
     close label disembunyikan (hidden=1).

Output: docs/m3_6_camera/verify_m3_6_camera.json (+ ringkasan stdout).
Usage: python3 tools/vision/verify_m3_6_camera.py
"""
import json
import os
import re
import statistics
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "m3_6_camera")

EXPECT = {
    "00_zoom_default_1280x720.png": (1280, 720, 2),
    "01_zoom_close_1280x720.png": (1280, 720, 2),
    "02_zoom_far_1280x720.png": (1280, 720, 2),
    "03_pan_1280x720.png": (1280, 720, 2),
    "04_zoom_close_portrait_1080x2340.png": (1080, 2340, 3),
}

results = []


def check(name, ok, detail=""):
    results.append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (" — " + detail if detail else ""))


# ------------------------------------------------------------- ukur piksel ---
def gold_stats(img, hx=0.80, hy=0.78):
    """Platform markas (emas) di area arena; zona HUD kanan/bawah diabaikan."""
    w, h = img.size
    px = img.load()
    n = sx = sy = 0
    for y in range(int(h * 0.08), int(h * hy), 2):
        for x in range(int(w * 0.08), int(w * hx), 2):
            r, g, b = px[x, y][:3]
            if r > 120 and g > 90 and b < 0.62 * r and r - b > 45:
                n += 1
                sx += x
                sy += y
    if n == 0:
        return {"count": 0, "cx": 0.0, "cy": 0.0}
    return {"count": n, "cx": sx / n, "cy": sy / n}


def grid_spacing(img, y_fracs=(0.58, 0.63, 0.68)):
    """Jarak antar garis grid lantai (cyan) pada baris tetap → skala kamera."""
    w, h = img.size
    px = img.load()
    medians = []
    for yf in y_fracs:
        y = int(h * yf)
        xs = [x for x in range(int(w * 0.06), int(w * 0.98))
              if (lambda p: p[2] > p[0] + 18 and p[1] > p[0] + 8 and p[2] > 60
                  and p[0] < 120)(px[x, y][:3])]
        groups = []
        for x in xs:
            if groups and x - groups[-1][-1] <= 3:
                groups[-1].append(x)
            else:
                groups.append([x])
        centers = [sum(g) / len(g) for g in groups]
        if len(centers) >= 3:
            d = [centers[i + 1] - centers[i] for i in range(len(centers) - 1)]
            d = [v for v in d if 20 < v < w * 0.5]
            if d:
                medians.append(statistics.median(d))
    return round(statistics.median(medians), 1) if medians else 0.0


def bright_ink(img, box, thresh=190):
    """Piksel teks terang (semua kanal > thresh) di dalam kotak."""
    return sum(1 for p in img.crop(box).getdata()
               if p[0] > thresh and p[1] > thresh and p[2] > thresh)


def chip_ink(img):
    """Tinta di klaster kontrol zoom (kanan-tengah, tempat tombol +/chip/−)."""
    w, h = img.size
    return bright_ink(img, (int(w * 0.88), int(h * 0.26), int(w * 0.99),
                            int(h * 0.62)), thresh=150)


# ------------------------------------------------------------------ utama ----
def main():
    stats = {}
    for fname, (ew, eh, dpr) in EXPECT.items():
        path = os.path.join(DOC, fname)
        jpath = path + ".json"
        if not (os.path.exists(path) and os.path.exists(jpath)):
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
              str(report.get("pageErrors"))[:60])
        check("tanpa TEST:FAIL %s" % fname, "TEST:FAIL" not in joined)
        check("marker QA:CAM:STEP_READY %s" % fname,
              "QA:CAM:STEP_READY" in joined)
        check("HUD tanpa tumpukan %s" % fname, "QA:HUD:OVERLAP count=0" in joined)
        check("label dunia tidak menembus panel %s" % fname,
              "QA:SCENE:LABEL_HUD_OVERLAP count=0" in joined)
        g = gold_stats(img)
        stats[fname] = {"gold": g, "grid": grid_spacing(img), "img": img}
        check("markas terlihat di foto %s" % fname, g["count"] > 400,
              "piksel emas=%d centroid=(%.0f,%.0f)" % (g["count"], g["cx"], g["cy"]))
        ink = chip_ink(img)
        check("kontrol zoom HUD terlihat di tepi kanan %s" % fname, ink > 300,
              "%d px tinta di klaster kanan-tengah" % ink)

    have = set(stats)
    if not {"00_zoom_default_1280x720.png", "01_zoom_close_1280x720.png",
            "02_zoom_far_1280x720.png", "03_pan_1280x720.png"} <= have:
        print("VERIFY_M3_6_CAMERA: foto inti tidak lengkap — berhenti")
        return 1

    d = stats["00_zoom_default_1280x720.png"]
    c = stats["01_zoom_close_1280x720.png"]
    f = stats["02_zoom_far_1280x720.png"]
    p = stats["03_pan_1280x720.png"]

    # --- B. ZOOM NYATA (piksel) ---
    r_gold_cd = c["gold"]["count"] / d["gold"]["count"]
    r_gold_fd = f["gold"]["count"] / d["gold"]["count"]
    r_grid_cd = c["grid"] / d["grid"] if d["grid"] else 0.0
    r_grid_fd = f["grid"] / d["grid"] if d["grid"] else 0.0
    check("piksel platform: close > default > far", c["gold"]["count"] > d["gold"]["count"] > f["gold"]["count"],
          "close=%d default=%d far=%d" % (c["gold"]["count"], d["gold"]["count"], f["gold"]["count"]))
    check("rasio platform close/default ≥1,30 (dolly nyata)", r_gold_cd >= 1.30,
          "rasio=%.2f" % r_gold_cd)
    check("rasio platform far/default ≤0,55", r_gold_fd <= 0.55, "rasio=%.2f" % r_gold_fd)
    check("jarak grid close/default ≥1,15 (skala naik)", r_grid_cd >= 1.15,
          "grid close=%.1f default=%.1f (%.2f×)" % (c["grid"], d["grid"], r_grid_cd))
    check("jarak grid far/default ≤0,80 (skala turun)", r_grid_fd <= 0.80,
          "grid far=%.1f (%.2f×)" % (f["grid"], r_grid_fd))

    # --- B2. Deklutter label diuji di PIKsel: koridor label di atas HQ kosong ---
    def corridor(img):
        w, h = img.size
        return bright_ink(img, (int(w * 0.33), int(h * 0.26), int(w * 0.76),
                                int(h * 0.47)))

    ink_close = corridor(c["img"])
    ink_default = corridor(d["img"])
    check("close zoom: koridor label = 0 px teks (label disembunyikan)",
          ink_close == 0, "%d px teks terang" % ink_close)
    check("default zoom: koridor label berisi teks (kontrol positif)",
          ink_default >= 100, "%d px teks terang" % ink_default)

    # --- C. PAN NYATA ---
    dx = abs(p["gold"]["cx"] - d["gold"]["cx"])
    dy = abs(p["gold"]["cy"] - d["gold"]["cy"])
    check("centroid platform bergeser saat pan (≥60 px)", max(dx, dy) >= 60.0,
          "Δ=(%.0f, %.0f) px" % (dx, dy))
    rg = p["grid"] / d["grid"] if d["grid"] else 0.0
    check("pan tidak mengubah skala (grid 0,85–1,15× default)", 0.85 <= rg <= 1.15,
          "grid pan=%.1f (%.2f× default)" % (p["grid"], rg))

    # --- E. Marker zoom + chip sesuai langkah showcase ---
    for fname, want, chip in [("00_zoom_default_1280x720.png", 1.0, "chip=x1,0"),
                              ("01_zoom_close_1280x720.png", 0.625, "chip=x1,6"),
                              ("02_zoom_far_1280x720.png", 1.6, "chip=x0,6")]:
        report = json.load(open(os.path.join(DOC, fname + ".json")))
        steps = [l for l in report.get("consoleLogs", []) if "QA:CAM:STEP " in l]
        ok = False
        detail = "tidak ada marker QA:CAM:STEP"
        if steps:
            m = re.search(r'"zoom": ([0-9.]+)', steps[-1])
            if m:
                ok = abs(float(m.group(1)) - want) <= 0.02 and chip in steps[-1]
                detail = "zoom=%s (harap %.3f), %s" % (m.group(1), want, chip)
        check("marker zoom + chip sesuai tombol %s" % fname, ok, detail)

    # --- F. Marker deklutter per langkah ---
    for fname, vis, hid in [("00_zoom_default_1280x720.png", 1, 0),
                            ("01_zoom_close_1280x720.png", 0, 1),
                            ("02_zoom_far_1280x720.png", 1, 0),
                            ("03_pan_1280x720.png", 1, 0)]:
        report = json.load(open(os.path.join(DOC, fname + ".json")))
        line = [l for l in report.get("consoleLogs", []) if "LABEL_CHECK" in l]
        ok = False
        detail = "tidak ada marker LABEL_CHECK"
        if line:
            m = re.search(r"overlap=(\d+) visible=(\d+) hidden=(\d+)", line[-1])
            if m:
                ok = (int(m.group(1)) == 0 and int(m.group(2)) == vis
                      and int(m.group(3)) == hid)
                detail = "overlap=%s visible=%s hidden=%s (harap 0/%d/%d)" % (
                    m.group(1), m.group(2), m.group(3), vis, hid)
        check("deklutter label %s" % fname, ok, detail)

    passed = sum(1 for r in results if r["pass"])
    failed = len(results) - passed
    with open(os.path.join(DOC, "verify_m3_6_camera.json"), "w", encoding="utf-8") as fh:
        json.dump({"passed": passed, "failed": failed, "total": len(results),
                   "measured": {k: {"gold": v["gold"]["count"],
                                    "grid_px": v["grid"]} for k, v in stats.items()},
                   "results": results}, fh, indent=1, ensure_ascii=False)
    print("VERIFY_M3_6_CAMERA: %d/%d PASS, %d FAIL → docs/m3_6_camera/verify_m3_6_camera.json"
          % (passed, len(results), failed))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
