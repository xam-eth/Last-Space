#!/usr/bin/env python3
"""verify_m36.py — verifikasi M3.6 (resolusi & design system mobile-first).

Data nyata (bukan asumsi):
  1. Komposisi LOADING = landscape, satu baris horizontal (brand kiri,
     progress kanan) di 16:9 & 19.5:9 — diukur dari posisi piksel cyan.
  2. Rotate prompt tampil saat PORTRAIT (komposisi tengah, tanpa bar bawah).
  3. HUD skala dp: scale = devicePixelRatio / 2 dan ukuran komponen dalam dp
     (tombol aksi 48dp, margin tepi 16dp, top bar 48dp) — dibaca dari dump
     QA:HUD:LAYOUT milik build aktual (device class berbeda).

Usage: python3 verify_m36.py <img_dir> <out_json> [hud_json ...]
"""
import json
import os
import sys

from PIL import Image

RED, GRN, YEL, RST = "\033[31m", "\033[32m", "\033[33m", "\033[0m"
results = []


def check(name, ok, evidence):
    results.append({"name": name, "ok": bool(ok), "evidence": evidence})
    tag = f"{GRN}PASS{RST}" if ok else f"{RED}FAIL{RST}"
    print(f"{tag} {name} — {evidence}")


def cyan_pixels(path, step=2):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    pts = []
    for y in range(0, h, step):
        for x in range(0, w, step):
            r, g, b = px[x, y]
            if g > 200 and b > 210 and r < 190:  # accent #7df9ff (teks & bar)
                pts.append((x / w, y / h))
    return pts


def main():
    img_dir = sys.argv[1] if len(sys.argv) > 1 else "out/m36"
    out_json = sys.argv[2] if len(sys.argv) > 2 else os.path.join(img_dir, "verify_m36.json")
    hud_jsons = sys.argv[3:]
    if not hud_jsons:
        cand = [os.path.join(img_dir, f) for f in sorted(os.listdir(img_dir)) if f.startswith("hud_") and f.endswith(".png.json")]
        prefix = os.path.join(img_dir, "..", "..", "tools", "godot", "build")
        for f in ("game_play.png.json", "game_ui.png.json"):
            p = os.path.normpath(os.path.join(prefix, f))
            if os.path.exists(p):
                cand.append(p)
        hud_jsons = cand

    # --- 1. Loading landscape (16:9 & 19.5:9) ---
    for label, fname, min_cyan in [("16x9", "load_land_16x9.png", 400), ("19_5x9", "load_land_19_5x9.png", 800)]:
        path = os.path.join(img_dir, fname)
        if not os.path.exists(path):
            check(f"loading_landscape_{label}", False, f"file tidak ada: {path}")
            continue
        pts = cyan_pixels(path)
        n = len(pts)
        bottom = sum(1 for _, y in pts if y > 0.7) / n if n else 0.0
        left = sum(1 for x, _ in pts if x < 0.34)
        right = sum(1 for x, _ in pts if x > 0.66)
        check(f"loading_landscape_{label}_bottom_bar", n >= min_cyan and bottom >= 0.85,
              f"cyan={n}px, {100*bottom:.0f}% di pita bawah (>0.7H) — komposisi 1 baris")
        check(f"loading_landscape_{label}_brand_left_progress_right", left >= 60 and right >= 60,
              f"cyan kiri(x<0.34)={left} (judul), kanan(x>0.66)={right} (bar+persen)")

    # --- 2. Rotate prompt saat portrait ---
    path = os.path.join(img_dir, "load_portrait.png")
    if os.path.exists(path):
        pts = cyan_pixels(path)
        n = len(pts)
        if n:
            ys = [y for _, y in pts]
            ymean = sum(ys) / n
            bottom = sum(1 for _, y in pts if y > 0.7) / n
        else:
            ymean, bottom = -1.0, 1.0
        check("rotate_prompt_portrait_center", n >= 300 and 0.30 <= ymean <= 0.70 and bottom <= 0.05,
              f"cyan={n}px, y rata-rata={ymean:.2f} (tengah), pita bawah={100*bottom:.0f}% (tidak ada bar loading)")
    else:
        check("rotate_prompt_portrait_center", False, f"file tidak ada: {path}")

    # --- 3. Aset slide loading = landscape (bukan portrait) ---
    assets = "assets/ui/loading"
    if os.path.isdir(assets):
        ratios = []
        for f in sorted(os.listdir(assets)):
            if f.endswith(".jpg"):
                w, h = Image.open(os.path.join(assets, f)).size
                ratios.append((f, w, h, w / h))
        bad = [r for r in ratios if r[3] < 1.5]
        check("loading_assets_landscape", len(ratios) >= 5 and not bad,
              f"{len(ratios)} slide, rasio {min(r[3] for r in ratios):.2f}–{max(r[3] for r in ratios):.2f} (semua > 1.5 = landscape)")

    # --- 4. HUD: skala dp & ukuran komponen dari dump build nyata ---
    seen = set()
    for hj in hud_jsons:
        hj = os.path.normpath(hj)
        if not os.path.exists(hj) or hj in seen:
            continue
        seen.add(hj)
        report = json.load(open(hj))
        dump = None
        for line in report.get("consoleLogs", []):
            if "QA:HUD:LAYOUT" in line:
                dump = line.split("QA:HUD:LAYOUT", 1)[1].strip()
        if not dump:
            continue
        tag = os.path.basename(hj).replace(".png.json", "")

        def grab(pat):
            import re
            m = re.search(pat, dump)
            return m.group(1) if m else None

        dpr = float(grab(r"dpr\[([\d.]+)\]"))
        scale = float(grab(r"scale\[([\d.]+)\]"))
        topbar = grab(r"TopBar\[([\d.,]+) ([\dx]+)\]")
        # TopBar[posx,posy WxH]
        import re
        m = re.search(r"TopBar\[([\d.]+),([\d.]+) (\d+)x(\d+)\]", dump)
        cell = re.search(r"cells:c0\[([\d.]+),([\d.]+) (\d+)x(\d+)\]", dump)
        card0 = re.search(r"cell0\[([\d.,]+) (\d+)x(\d+)\]", dump)  ## M3.7: ActionGrid
        expect_scale = dpr / 2.0
        check(f"hud_{tag}_scale_dp", abs(scale - expect_scale) <= 0.001,
              f"dpr={dpr} → scale={scale:.3f} (harus dpr/2={expect_scale:.3f})")
        if m:
            posx, posy, tw, th = (float(m.group(1)), float(m.group(2)), float(m.group(3)), float(m.group(4)))
            check(f"hud_{tag}_margin_16dp", abs(posx / dpr - 16) <= 1.5 and abs(posy / dpr - 16) <= 1.5,
                  f"TopBar pos ({posx:.0f},{posy:.0f}) device px = ({posx/dpr:.1f},{posy/dpr:.1f}) dp (target 16)")
            ## M3.7: TopBar dinaikkan ke 56dp = tinggi app bar standar Material
            ## (m3.material.io app bar 56dp) — menggantikan target lama 48dp.
            check(f"hud_{tag}_topbar_56dp_app_bar", abs(th / dpr - 56) <= 1.5,
                  f"tinggi {th:.0f} device px = {th/dpr:.1f} dp (target 56 = app bar Material)")
        if cell:
            cw = float(cell.group(3))
            check(f"hud_{tag}_button_48dp", abs(cw / dpr - 48) <= 1.5,
                  f"TombolKirim sisa: {cw:.0f} device px = {cw/dpr:.1f} dp (target 48, minimum Material)")
        if card0:
            cw, ch = float(card0.group(2)), float(card0.group(3))
            check(f"hud_{tag}_card_aksi_48dp", cw / dpr >= 47.0 and ch / dpr >= 47.0,
                  f"card aksi (ActionGrid) {cw:.0f}x{ch:.0f} device px = {cw/dpr:.1f}x{ch/dpr:.1f} dp (minimum 48)")
        if not m:
            check(f"hud_{tag}_dump_parse", False, f"TopBar tidak ditemukan di dump: {dump[:80]}")

    check("hud_device_classes_covered", len(seen) >= 3,
          f"{len(seen)} device class dianalisis: {[os.path.basename(x) for x in sorted(seen)]}")

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    payload = {
        "suite": "M3.6 — resolusi & design system mobile-first (loading landscape, rotate prompt, HUD dp)",
        "passed": passed,
        "failed": failed,
        "checks": results,
    }
    with open(out_json, "w") as f:
        json.dump(payload, f, indent=2)
    color = GRN if failed == 0 else RED
    print(f"{color}REPORT: {passed} PASS / {failed} FAIL{RST} -> {out_json}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
