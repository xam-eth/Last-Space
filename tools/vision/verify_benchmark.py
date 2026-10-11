#!/usr/bin/env python3
"""verify_benchmark.py — verifikasi piksel foto visual benchmark (QA_PLAN.md
vision check): setiap foto valid PNG, dimensi benar, TIDAK blank, dan warna
khas aspeknya terlihat (HUD cyan/orange, base kuning, alien hijau/ungu).
Menulis report.json + VISUAL_BENCHMARK.md di folder benchmark.

Usage: python3 tools/vision/verify_benchmark.py <folder_benchmark>
"""
import json
import os
import sys

from PIL import Image

# warna khas (dari konstanta game: hud.gd C_BORDER/C_WARN, base kuning,
# ALN-001 MAT-021/022/023 hijau/ungu — lihat ART_DIRECTION.md §2)
COLORS = {
    "hud_cyan": (53, 208, 255),     # C_BORDER / C_ACCENT
    "energy_orange": (255, 184, 77),  # C_WARN
    "base_yellow": (255, 204, 51),  # command core kuning
    "engine_cyan": (38, 191, 255),  # SHP-001 MAT-007
    "alien_green": (38, 230, 89),   # ALN-001 MAT-021/022
    "alien_purple": (217, 64, 255),  # ALN-001 MAT-023
}
TOL = 45

# (file, dimensi, warna WAJIB, warna OPSIONAL (dicatat, tidak wajib — terlalu
# kecil di kamera jauh: weapon ungu r=0,07m & engine hijau di kamera stress),
# deskripsi)
EXPECT = [
    ("01_loading_screen.png", (1920, 1080), [], [],
     "Loading screen — root page (slideshow cinematic + progress bar)"),
    ("02_command_base.png", (1920, 1080), ["hud_cyan", "energy_orange", "base_yellow"], [],
     "Command base — game utama: HUD + 3D base (kamera gameplay)"),
    ("03_fleet_formation.png", (1920, 1080), ["hud_cyan", "engine_cyan"], [],
     "Armada — 6 interceptor SHP-001 formasi (engine glow cyan)"),
    ("04_battle_vs_alien.png", (1920, 1080), ["hud_cyan", "alien_green"], ["alien_purple"],
     "Battle — defender vs attacker ALN-001 (alien hijau; ungu opsional:"
     " weapon terlalu kecil di kamera)"),
    ("05_stress_42units.png", (1920, 1080), ["hud_cyan", "engine_cyan"], ["alien_green"],
     "Stress — 42 kapal (12 SHP-001 + 30 ALN-001) + 8 turret (alien hijau"
     " opsional: kamera jauh, kapal kecil)"),
    ("06_mobile_1920x1080_16x9.png", (1920, 1080), ["hud_cyan"], [],
     "Mobile landscape 16:9 (1920x1080) — full screen"),
    ("07_mobile_2340x1080_19.5x9.png", (2340, 1080), ["hud_cyan"], [],
     "Mobile landscape 19.5:9 (2340x1080) — full screen semua aspek"),
]


def count_color(img, rgb):
    """Hitung piksel yang mendekati warna target (tolerance)."""
    px = img.convert("RGB").load()
    w, h = img.size
    tr, tg, tb = rgb
    n = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            if abs(r - tr) <= TOL and abs(g - tg) <= TOL and abs(b - tb) <= TOL:
                n += 1
    return n


def hud_reaches_right_edge(img):
    """Cek HUD cyan ada di dekat edge kanan (x > w-100) → HUD full width."""
    px = img.convert("RGB").load()
    w, h = img.size
    tr, tg, tb = COLORS["hud_cyan"]
    for y in range(0, h, 2):
        for x in range(w - 100, w, 2):
            r, g, b = px[x, y]
            if abs(r - tr) <= TOL and abs(g - tg) <= TOL and abs(b - tb) <= TOL:
                return True
    return False


def main():
    folder = sys.argv[1] if len(sys.argv) > 1 else "docs/visual_benchmark"
    results = []
    all_ok = True
    for fname, (ew, eh), required, optional, desc in EXPECT:
        path = os.path.join(folder, fname)
        entry = {"file": fname, "desc": desc, "ok": False, "checks": {}}
        if not os.path.exists(path):
            entry["checks"]["exists"] = False
            results.append(entry)
            all_ok = False
            continue
        entry["checks"]["exists"] = True
        size = os.path.getsize(path)
        entry["size_bytes"] = size
        try:
            img = Image.open(path)
            img.verify()  # valid PNG
            img = Image.open(path).convert("RGB")
            w, h = img.size
            entry["checks"]["valid_png"] = True
            entry["checks"]["dimensions"] = (w == ew and h == eh)
            entry["dimensions"] = [w, h]
            # tidak blank: std harus cukup tinggi (ada konten bervariasi)
            gray = img.convert("L")
            hist = gray.histogram()
            total = sum(hist)
            mean = sum(i * c for i, c in enumerate(hist)) / total
            var = sum(c * (i - mean) ** 2 for i, c in enumerate(hist)) / total
            std = var ** 0.5
            entry["checks"]["not_blank"] = std > 10.0
            entry["pixel_std"] = round(std, 1)
            # warna khas wajib
            found = {}
            for cname in required:
                n = count_color(img, COLORS[cname])
                found[cname] = n
                entry["checks"]["color_" + cname] = n > 20
            # warna opsional: dicatat (data nyata), tidak wajib
            opt = {}
            for cname in optional:
                opt[cname] = count_color(img, COLORS[cname])
            entry["colors_found"] = found
            entry["colors_optional"] = opt
            # mobile: HUD harus sampai edge kanan (full width)
            if fname.startswith(("06_", "07_")):
                entry["checks"]["hud_full_width_right_edge"] = hud_reaches_right_edge(img)
            entry["ok"] = (
                entry["checks"]["valid_png"]
                and entry["checks"]["dimensions"]
                and entry["checks"]["not_blank"]
                and all(v for k, v in entry["checks"].items()
                        if k.startswith("color_"))
                and (entry["checks"].get("hud_full_width_right_edge", True))
            )
        except Exception as e:  # bukan PNG valid
            entry["checks"]["valid_png"] = False
            entry["error"] = str(e)
        results.append(entry)
        all_ok = all_ok and entry["ok"]
        print("%-34s %s" % (fname, "PASS" if entry["ok"] else "FAIL"))

    report = {"benchmark": "visual build Last-Space", "all_ok": all_ok,
              "results": results}
    with open(os.path.join(folder, "report.json"), "w") as f:
        json.dump(report, f, indent=2)

    # index markdown
    lines = [
        "# Visual Benchmark — Build Game Last-Space",
        "",
        "Foto hasil akhir game secara visual (data nyata dari web build,",
        "bukan ilustrasi). Diverifikasi piksel (QA_PLAN.md vision check):",
        "valid PNG, dimensi benar, tidak blank, warna khas aspek terlihat.",
        "",
        "| Foto | Aspek (ART_DIRECTION.md §1) | Resolusi | Verifikasi |",
        "|---|---|---|---|",
    ]
    for r in results:
        dims = "%dx%d" % tuple(r.get("dimensions", [0, 0]))
        lines.append("| `%s` | %s | %s | %s |" % (
            r["file"], r["desc"], dims, "PASS" if r["ok"] else "FAIL"))
    lines += [
        "",
        "**Hasil keseluruhan:** %s" % ("SEMUA PASS" if all_ok else "ADA FAIL"),
        "",
        "Detail per foto (cek piksel, warna ditemukan): `report.json`.",
        "",
        "Cara generate ulang: `bash tools/vision/visual_benchmark.sh`",
        "(butuh `source tools/env.sh`).",
    ]
    with open(os.path.join(folder, "VISUAL_BENCHMARK.md"), "w") as f:
        f.write("\n".join(lines) + "\n")

    print("==> visual benchmark: %s" % ("ALL PASS" if all_ok else "ADA FAIL"))
    print("report: %s/report.json + VISUAL_BENCHMARK.md" % folder)
    sys.exit(0 if all_ok else 1)


if __name__ == "__main__":
    main()
