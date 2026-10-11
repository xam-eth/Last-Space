#!/usr/bin/env python3
"""verify_ui_m3.py — verifikasi piksel evidence UI M3 #1/#2 (build menu, ship
menu, quest panel, building selection) di docs/ui_m3_build_menu/. Semua klaim
dari data piksel nyata (koreksi human 2026-10-11: jangan asumsikan dari visual).

Cek (design canvas 1280x720, HUD full-rect scale = tinggi/720):
  1. Semua PNG valid + dimensi benar.
  2. Build menu: border cyan modal di edge kiri modal (design x=128, y=360;
     skala 2340x1080 = 1.5 → x=402, y=540) — panel benar-benar muncul & center.
  3. Command selected: border cyan QuestPanel (x=24, y=424) & SelectionPanel
     (x=360, y=626); panah hijau indikator terdeteksi (piksel hijau) dan TIDAK
     ada di baseline (mode=game tanpa selection).
  4. Full screen semua aspek: top bar chip border cyan sampai edge kiri
     (x=36 @2340x1080, skala 1.5 dari x=24) — tanpa black bars.

Output: report.json + UI_M3_REPORT.md di docs/ui_m3_build_menu/.
Usage: python3 tools/vision/verify_ui_m3.py
"""
import json
import os
import sys

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "ui_m3_build_menu")

results = []


def check(name, ok, detail=""):
    results.append({"check": name, "ok": bool(ok), "detail": detail})
    print("%s %s %s" % ("PASS" if ok else "FAIL", name, detail))


def load(f):
    return Image.open(os.path.join(DOC, f)).convert("RGB")


def is_cyan_border(p):
    ## Border panel = cyan #35d0ff alpha 0.55 di atas bg gelap → redup
    ## (misal (36,124,156)); ikon solid lebih terang. Bedakan dari hijau/panel.
    r, g, b = p
    return g > 70 and b > 90 and r < 70 and b > g + 15


def has_cyan_in_region(img, x0, x1, y0, y1):
    px = img.load()
    for x in range(max(0, x0), min(img.width, x1)):
        for y in range(max(0, y0), min(img.height, y1)):
            if is_cyan_border(px[x, y]):
                return True
    return False


def green_count(img):
    """Jumlah piksel hijau indikator (panah): g tinggi, r & b rendah."""
    px = img.load()
    n = 0
    for x in range(0, img.width, 2):
        for y in range(0, img.height, 2):
            r, g, b = px[x, y]
            if g > 180 and r < 120 and b < 170:
                n += 1
    return n


def main():
    files = [
        ("00_baseline_1280x720.png", 1280, 720),
        ("01_command_selected_1280x720.png", 1280, 720),
        ("02_build_menu_1280x720.png", 1280, 720),
        ("03_command_selected_2340x1080.png", 2340, 1080),
        ("04_build_menu_2340x1080.png", 2340, 1080),
        ("05_ship_menu_1280x720.png", 1280, 720),
        ("06_ship_menu_2340x1080.png", 2340, 1080),
    ]
    imgs = {}
    for f, w, h in files:
        path = os.path.join(DOC, f)
        ok = os.path.exists(path)
        if ok:
            im = Image.open(path)
            ok = im.format == "PNG" and im.size == (w, h)
            imgs[f] = load(f)
        check("valid_%s" % f, ok, "%s %s" % (w, h))

    # --- 2. build menu: modal border cyan di edge kiri modal ---
    # design: modal x=128..1152, y=108..612 (1024x504 center). Skala 1 (1280x720).
    im = imgs["02_build_menu_1280x720.png"]
    check("menu_border_cyan_1280", has_cyan_in_region(im, 124, 134, 340, 380),
          "border modal x=128 y=360 (design)")
    # skala 1.5 (2340x1080): modal x=402..1938, y=162..918
    im = imgs["04_build_menu_2340x1080.png"]
    check("menu_border_cyan_2340", has_cyan_in_region(im, 398, 410, 520, 560),
          "border modal x=402 y=540 (skala 1.5)")

    # --- 2b. ship menu: modal border cyan di edge kiri modal (posisi sama) ---
    im = imgs["05_ship_menu_1280x720.png"]
    check("ship_menu_border_cyan_1280", has_cyan_in_region(im, 124, 134, 340, 380),
          "border modal x=128 y=360 (design)")
    im = imgs["06_ship_menu_2340x1080.png"]
    check("ship_menu_border_cyan_2340", has_cyan_in_region(im, 398, 410, 520, 560),
          "border modal x=402 y=540 (skala 1.5)")

    # --- 3. command selected: quest panel + selection panel + arrow hijau ---
    im = imgs["01_command_selected_1280x720.png"]
    check("quest_panel_border_1280", has_cyan_in_region(im, 20, 30, 410, 440),
          "QuestPanel x=24 y=424 (design)")
    check("selection_panel_border_1280", has_cyan_in_region(im, 356, 366, 610, 640),
          "SelectionPanel x=360 y=626 (design)")
    g_sel = green_count(im)
    g_base = green_count(imgs["00_baseline_1280x720.png"])
    check("arrow_green_present", g_sel > 50, "hijau=%d px (sampling)" % g_sel)
    check("arrow_green_absent_baseline", g_base < 10,
          "baseline hijau=%d px (arrow memang dari selection)" % g_base)

    # --- 4. full screen semua aspek: top bar sampai edge kiri @2340x1080 ---
    im = imgs["03_command_selected_2340x1080.png"]
    check("topbar_fullwidth_2340", has_cyan_in_region(im, 32, 44, 50, 90),
          "chip ENERGY border x=36 y=66 (skala 1.5) — sampai edge, tanpa black bar")

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    report = {
        "suite": "ui_m3_build_menu pixel verification (M3 #1 build menu + M3 #2 ship menu)",
        "passed": passed, "failed": failed,
        "results": results,
        "green_arrow_px_selected": g_sel,
        "green_arrow_px_baseline": g_base,
    }
    with open(os.path.join(DOC, "report.json"), "w") as f:
        json.dump(report, f, indent=1)

    lines = [
        "# UI M3 #1/#2 — Verifikasi Piksel (Build Menu / Ship Menu / Quest Panel / Selection)",
        "",
        "Verifikasi berbasis data piksel nyata (Pillow) — koreksi human 2026-10-11.",
        "File: `docs/ui_m3_build_menu/` (5 foto + report.json).",
        "",
        "| # | Cek | Hasil | Detail |",
        "|---|---|---|---|",
    ]
    for i, r in enumerate(results, 1):
        lines.append("| %d | %s | %s | %s |" % (
            i, r["check"], "PASS" if r["ok"] else "FAIL", r["detail"]))
    lines += [
        "",
        "**Hasil: %d PASS / %d FAIL**" % (passed, failed),
        "",
        "Catatan: panah hijau indikator = %d px (sampling) saat selection, %d px di "
        "baseline tanpa selection — indikator memang muncul karena klik bangunan." % (
            g_sel, g_base),
        "",
    ]
    with open(os.path.join(DOC, "UI_M3_REPORT.md"), "w") as f:
        f.write("\n".join(lines))
    print("REPORT: %d PASS / %d FAIL -> %s" % (passed, failed, os.path.join(DOC, "report.json")))
    sys.exit(0 if failed == 0 else 1)


if __name__ == "__main__":
    main()
