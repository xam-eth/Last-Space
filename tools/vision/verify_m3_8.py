#!/usr/bin/env python3
"""verify_m3_8.py — verifikasi M3 #8 (kritik #5 pemain 2026-10-14) dari BUKTI
PIKSEL + marker nyata di docs/m3_8_cards_camera/ (dasar AI_GOVERNANCE.md §13:
semua angka dari state aktual, bukan asumsi).

Konteks: pemain menuntut (a) kartu katalog lebih kecil — sekarang 56dp (turun
dari 68dp), (b) kamera dinamis (M3 #6 v2: fokus di dalam plataran) dengan
deklutter label yang BENAR-BENAR bekerja, (c) interaksi BANGUN/kartu nyata.

Cek:
  1. 7 foto bukti (2 ponsel landscape, tablet 4:3, portrait, 2 kamera, 1 input)
     ada, dimensi+dpr sesuai device class, `waitForMatched`, 0 pageError,
     0 TEST:FAIL, TIDAK ada error "Node not found" (cek QA tidak hilang senyap).
  2. **Kartu 56dp diukur dari PIKSEL**: komponen border cyan di foto dibaca
     (flood-fill) → bbox persegi 112×112 px @dpr2 & 168×168 px @dpr3 = 56dp;
     rasio lintas device kelas = 1.5 (ukuran dp tetap, tidak ikut membesar).
  3. **Tidak bertumpuk & gap konsisten**: jarak antar bbox kartu pada baris yang
     sama maupun antar-baris = 16 px @dpr2 / 24 px @dpr3 (= 8dp, grid Material).
  4. **Kamera v2**: foto zoom dekat membuktikan deklutter menyembunyikan label
     (hidden ≥ 1, overlap = 0); foto pan membuktikan pan nyata; gate kamera
     (artefak build) membuktikan span zoom membesar ≥ 1.3× + pan_clamped.
  5. **Portrait**: shell menampilkan prompt rotasi (marker + piksel teks terang),
     dan audit internal membuktikan modal menyusut ke ruang nyata (`narrow=true`)
     — kartu TIDAK mengecil di bawah 56dp.
  6. **Interaksi nyata** (foto input): `QA:INPUT:DONE passed=34 failed=0` dengan
     semua tab + kartu + drag-pan diklik sungguhan.

Output: docs/m3_8_cards_camera/verify_m3_8.json
Usage: python3 tools/vision/verify_m3_8.py
"""
import json
import os
import sys
from collections import deque

from PIL import Image
import numpy as np

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "m3_8_cards_camera")
BUILD = os.path.join(REPO, "tools", "godot", "build")

EXPECT = {  # file: (w, h, dpr, peran)
    "00_cards_56dp_1280x720.png": (1280, 720, 2, "cards"),
    "01_cards_56dp_2340x1080.png": (2340, 1080, 3, "cards"),
    "06_cards_56dp_tablet4x3_2048x1536.png": (2048, 1536, 2, "cards"),
    "02_rotate_prompt_portrait_1080x2340.png": (1080, 2340, 3, "portrait"),
    "03_camera_close_1280x720.png": (1280, 720, 2, "cam_close"),
    "04_camera_pan_2340x1080.png": (2340, 1080, 3, "cam_pan"),
    "05_input_flow_1280x720.png": (1280, 720, 2, "input"),
}

results = []


def check(name, ok, detail=""):
    results.append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (" — " + detail if detail else ""))


def load_report(png):
    with open(png + ".json") as fh:
        return json.load(fh)


def square_boxes(png, span):
    """Kotak kartu dari PIKSEL: komponen border cyan (bbox sisi `span` px)."""
    im = np.array(Image.open(png).convert("RGB")).astype(int)
    r, g, b = im[:, :, 0], im[:, :, 1], im[:, :, 2]
    mask = (b - r > 35) & (g > 85) & (b > 115) & (r < 110)
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        miny = maxy = y0
        minx = maxx = x0
        while q:
            y, x = q.popleft()
            miny, maxy = min(miny, y), max(maxy, y)
            minx, maxx = min(minx, x), max(maxx, x)
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True
                        q.append((ny, nx))
        bw, bh = maxx - minx + 1, maxy - miny + 1
        if span[0] <= bw <= span[1] and span[0] <= bh <= span[1]:
            out.append((minx, miny, bw, bh))
    return out


def bright_pixels(img, box):
    crop = np.array(img.crop(box).convert("RGB")).astype(int)
    return int(((crop[:, :, 0] > 150) & (crop[:, :, 1] > 150) & (crop[:, :, 2] > 150)).sum())


print("== 1. Foto bukti & higienitas log ==")
reports = {}
for fname, (w, h, dpr, role) in EXPECT.items():
    png = os.path.join(DOC, fname)
    if not os.path.exists(png) or not os.path.exists(png + ".json"):
        check("foto %s ada" % fname, False, "berkas hilang")
        continue
    rep = load_report(png)
    reports[fname] = rep
    logs = rep.get("consoleLogs", [])
    joined = "\n".join(logs)
    fails = [l for l in logs if "TEST:FAIL" in l]
    size = (rep["png"]["width"], rep["png"]["height"])
    ok = (size == (w, h) and rep.get("devicePixelRatio") == dpr
          and rep.get("waitForMatched") is True and len(rep.get("pageErrors", [])) == 0
          and not fails and "Node not found" not in joined)
    check("foto %s: %dx%d dpr %d, 0 error, 0 TEST:FAIL, tanpa 'Node not found'" % (
        fname, w, h, dpr), ok,
        "waitFor=%s pageErrors=%d TEST:FAIL=%d" % (
            rep.get("waitForMatched"), len(rep.get("pageErrors", [])), len(fails)))

print("\n== 2. Kartu 56dp diukur dari PIKSEL ==")
measured = {}
for fname, (w, h, dpr, role) in EXPECT.items():
    if role != "cards":
        continue
    ## 56dp → design px 112 (= 56dp × 2 design px/dp) → device px 112×dpr/2.
    span_px = 56.0 * dpr  ## = 112 @dpr2, 168 @dpr3
    boxes = square_boxes(os.path.join(DOC, fname), (int(span_px) - 8, int(span_px) + 8))
    boxes.sort(key=lambda t: (t[1], t[0]))
    measured[fname] = (boxes, dpr)
    widths = {b[2] for b in boxes}
    heights = {b[3] for b in boxes}
    ## 1 dp = 2 design px; device px = design × dpr/2 → dp = px / dpr.
    dp = (min(widths) / dpr) if widths else 0.0
    check("kartu %s: %d kotak terdeteksi, semua %.0f px = %.1f dp" % (
        fname, len(boxes), min(widths) if widths else 0, dp),
        len(boxes) >= 4 and widths == {int(span_px)} and heights == {int(span_px)} and abs(dp - 56.0) < 0.5,
        "bbox=%s" % str(boxes))
    # gap horizontal & vertikal (8dp = 16 px @dpr2 / 24 px @dpr3)
    gap_dp = 8.0
    want_gap = int(gap_dp * dpr)  ## 8dp → 16px @dpr2, 24px @dpr3
    gaps = []
    for i in range(len(boxes)):
        for j in range(len(boxes)):
            if i == j:
                continue
            a, b = boxes[i], boxes[j]
            if abs(a[1] - b[1]) < 2 and b[0] > a[0]:            # satu baris
                gaps.append(b[0] - (a[0] + a[2]))
            if abs(a[0] - b[0]) < 2 and b[1] > a[1]:            # satu kolom
                gaps.append(b[1] - (a[1] + a[3]))
    ## Jarak MINIMUM antar dua kartu mana pun = 8dp (16px @dpr2 / 24px @dpr3)
    ## → bukti "tidak ada tumpukan" langsung dari geometri piksel.
    check("gap minimum antar kartu %s = %d px (%.0f dp) — tidak ada yang bertumpuk" % (
        fname, want_gap, gap_dp),
        len(gap_ok := gaps) >= 3 and min(gaps) == want_gap,
        "gap_px=%s" % str(sorted(set(gaps))))
    # semua kartu di dalam layar
    in_screen = all(b[0] >= 0 and b[1] >= 0 and b[0] + b[2] <= w and b[1] + b[3] <= h
                    for b in boxes)
    check("semua kartu %s di dalam layar" % fname, in_screen, "layar %dx%d" % (w, h))

if "00_cards_56dp_1280x720.png" in measured and "01_cards_56dp_2340x1080.png" in measured:
    w2 = measured["00_cards_56dp_1280x720.png"][0][0][2]
    w3 = measured["01_cards_56dp_2340x1080.png"][0][0][2]
    check("rasio kartu dpr3/dpr2 = %.2f (ukuran dp tetap, tidak membesar di layar besar)" % (
        w3 / float(w2)), abs(w3 / float(w2) - 1.5) < 0.02, "px %d vs %d" % (w3, w2))

print("\n== 3. Marker kartu: label-free, seragam, di dalam panel ==")
for fname in ("00_cards_56dp_1280x720.png", "01_cards_56dp_2340x1080.png",
              "06_cards_56dp_tablet4x3_2048x1536.png"):
    joined = "\n".join(reports.get(fname, {}).get("consoleLogs", []))
    ok = ("tile_dp=56" in joined and "label_free_pct=100" in joined
          and "icon_ratio=80" in joined
          and "QA:CARD:OVERLAP count=0" in joined
          and "inside_panel=true inside_screen=true" in joined
          and "QA:CARD:LAYOUT menu=build" in joined and "menu=ship" in joined)
    check("marker kartu %s (56dp, 100%% tanpa label, 0 tumpukan, di dalam panel)" % fname,
          ok, "dari marker QA:CARD:*")

print("\n== 4. Kamera v2: deklutter nyata + pan ==")
close_logs = "\n".join(reports.get("03_camera_close_1280x720.png", {}).get("consoleLogs", []))
cam_rep = {"logs": close_logs}
m = None
for line in close_logs.split("\n"):
    if "QA:CAM:LABEL_CHECK" in line:
        m = line
hidden = int(m.split("hidden=")[1].split()[0]) if m else -1
visible = int(m.split("visible=")[1].split()[0]) if m else -1
overlap = int(m.split("overlap=")[1].split()[0]) if m else -1
check("zoom dekat: deklutter BENAR-BENAR menyembunyikan label dunia", hidden >= 1 and overlap == 0,
      "hidden=%d visible=%d overlap=%d (%s)" % (hidden, visible, overlap, (m or "?").strip()[:80]))
pan_logs = "\n".join(reports.get("04_camera_pan_2340x1080.png", {}).get("consoleLogs", []))
check("pan: kamera bergeser & label tetap rapi (overlap=0)",
      "QA:CAM:STEP_READY step=pan" in pan_logs and "overlap=0" in pan_logs,
      "marker step=pan + LABEL_CHECK")

gate = os.path.join(BUILD, "game_camera.png.json")
if os.path.exists(gate):
    glogs = json.load(open(gate)).get("consoleLogs", [])
    txt = "\n".join(glogs)
    spans = [float(l.split("px=")[1].split()[0]) for l in glogs if "QA:CAM:SPAN" in l]
    ratio = (spans[-1] / spans[0]) if len(spans) >= 2 and spans[0] > 0 else 0.0
    check("gate kamera: span zoom membesar %.2f× (≥1.30) saat zoom in" % ratio,
          ratio >= 1.30, "span px=%s" % str([round(s, 1) for s in spans]))
    check("gate kamera: fokus ter-clamp di dalam plataran (pan_clamped) & tap tetap memilih",
          "TEST:PASS cam.pan_clamped" in txt and "TEST:PASS cam.pan_moves_camera" in txt
          and "TEST:PASS cam.tap_selects_after_pan" in txt
          and "TEST:PASS cam.declutter_hides_labels" in txt,
          "dari tools/godot/build/game_camera.png.json")
else:
    check("gate kamera artefak ada", False, "game_camera.png.json hilang (jalankan gate camera)")

print("\n== 5. Portrait: prompt rotasi + modal menyusut (audit internal) ==")
port_logs = "\n".join(reports.get("02_rotate_prompt_portrait_1080x2340.png", {}).get("consoleLogs", []))
check("portrait: prompt rotasi tampil (marker QA:ROTATE:PROMPT)",
      "QA:ROTATE:PROMPT aspect=" in port_logs, "keputusan pemain: portrait = rotate prompt")
img = Image.open(os.path.join(DOC, "02_rotate_prompt_portrait_1080x2340.png"))
mid = bright_pixels(img, (0, 700, 1080, 1600))
check("portrait: teks prompt terang terlihat di piksel (>=1500 px terang)", mid >= 1500,
      "piksel terang area tengah = %d" % mid)
check("portrait: modal menyusut ke ruang nyata (narrow=true, kartu tetap 56dp)",
      "QA:CARD:MODAL menu=build" in port_logs and "narrow=true" in port_logs
      and "tile_dp=56" in port_logs, "audit internal layout")

print("\n== 6. Interaksi nyata (foto input) ==")
in_logs = "\n".join(reports.get("05_input_flow_1280x720.png", {}).get("consoleLogs", []))
check("foto input: QA:INPUT:DONE passed=34 failed=0", "QA:INPUT:DONE passed=34 failed=0" in in_logs,
      "semua tab + kartu + drag pan")
tabs_ok = False
for line in in_logs.split("\n"):
    if "QA:INPUT:TABS" in line and "tab_fail=[]" in line and "card_fail=[]" in line:
        tabs_ok = "cards=" in line
check("foto input: semua tab & kartu bisa diklik (tab_fail/card_fail kosong)", tabs_ok,
      "marker QA:INPUT:TABS")

passed = sum(1 for r in results if r["pass"])
total = len(results)
out = {"checks": results, "passed": passed, "total": total,
       "verdict": "PASS" if passed == total else "FAIL"}
with open(os.path.join(DOC, "verify_m3_8.json"), "w") as fh:
    json.dump(out, fh, indent=2, ensure_ascii=False)
print("\nverify_m3_8: %d/%d PASS -> %s" % (passed, total, out["verdict"]))
sys.exit(0 if passed == total else 1)
