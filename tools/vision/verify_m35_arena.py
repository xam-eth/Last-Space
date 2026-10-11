#!/usr/bin/env python3
"""M3.5 verifier Tahap A — arena space visual (base_scene environment).

Cek berbasis piksel (data nyata, bukan asumsi):
  1. langit: bintang putih/terang di region langit (atas, tengah, tanpa HUD)
  2. planet: piksel biru dominan di region kanan-atas (planet besar)
  3. bulan: piksel coklat/abu terang di dekat planet
  4. platform: garis grid cyan emissive di region bawah (platform)
  5. battle: engine glow cyan di belakang kapal (region tengah bawah)

Pemakaian:
  python3 tools/vision/verify_m35_arena.py <foto_arena.png> <foto_battle.png>
"""
import json
import sys

from PIL import Image

RESULTS = []


def check(name, ok, detail):
    RESULTS.append({"check": name, "ok": bool(ok), "detail": detail})
    print(("PASS" if ok else "FAIL"), name, "-", detail)


def region_stats(img, x0, y0, x1, y1):
    px = img.crop((x0, y0, x1, y1)).convert("RGB")
    w, h = px.size
    data = list(px.getdata())
    n = len(data)
    bright = sum(1 for r, g, b in data if r > 200 and g > 200 and b > 210)
    ## dikalibrasi dari warna aktual planet (avg RGB 44,73,130 @ SwiftShader)
    blue = sum(1 for r, g, b in data if b > 100 and b > r + 25 and b > g + 10)
    cyan = sum(1 for r, g, b in data if g > 70 and b > 90 and r < 70 and b > g + 15)
    ## bulan: abu/coklat terang (avg RGB 153,144,132), bukan biru
    warm = sum(1 for r, g, b in data if r > 100 and r > b + 15 and g > 90)
    return {"n": n, "bright": bright, "blue": blue, "cyan": cyan, "warm": warm, "w": w, "h": h}


def main():
    arena_path, battle_path = sys.argv[1], sys.argv[2]
    arena = Image.open(arena_path)
    battle = Image.open(battle_path)
    W, H = arena.size
    print(f"arena {arena_path} {W}x{H}, battle {battle_path} {battle.size[0]}x{battle.size[1]}")

    # 1. bintang di langit: region atas tengah (y 8%..45%, x 30%..75%) — di atas
    #    horizon platform, di luar panel HUD kiri & planet kanan.
    sky = region_stats(arena, int(W * 0.30), int(H * 0.06), int(W * 0.72), int(H * 0.45))
    check("sky_stars", sky["bright"] >= 40,
          f"piksel terang(putih) di langit = {sky['bright']} (min 40, region {sky['w']}x{sky['h']})")

    # 2. planet biru: region kanan atas (x 60%..95%, y 0%..40%)
    planet = region_stats(arena, int(W * 0.60), 0, int(W * 0.97), int(H * 0.42))
    check("planet_blue", planet["blue"] >= 5000,
          f"piksel biru planet = {planet['blue']} (min 5000)")

    # 3. bulan: piksel warm (coklat/abu terang) dekat planet — region kanan atas
    #    lebih luas, bulan coklat (r>g>b hangat).
    moon = region_stats(arena, int(W * 0.55), int(H * 0.0), int(W * 0.90), int(H * 0.35))
    check("moon_warm", moon["warm"] >= 400,
          f"piksel warm bulan = {moon['warm']} (min 400)")

    # 4. grid cyan platform: region bawah tengah (y 55%..95%, x 35%..85%)
    grid = region_stats(arena, int(W * 0.35), int(H * 0.55), int(W * 0.85), int(H * 0.95))
    check("platform_grid_cyan", grid["cyan"] >= 3000,
          f"piksel cyan grid = {grid['cyan']} (min 3000)")

    # 5. engine glow saat battle: cyan terang di region tengah (kapal berkumpul)
    bw, bh = battle.size
    glow = region_stats(battle, int(bw * 0.35), int(bh * 0.45), int(bw * 0.70), int(bh * 0.85))
    check("battle_engine_glow_cyan", glow["cyan"] >= 150,
          f"piksel cyan engine glow = {glow['cyan']} (min 150)")

    passed = sum(1 for r in RESULTS if r["ok"])
    print(f"\nHASIL: {passed}/{len(RESULTS)} PASS")
    out = {"arena": arena_path, "battle": battle_path, "results": RESULTS,
           "passed": passed, "total": len(RESULTS)}
    with open(arena_path + ".verify_m35.json", "w") as f:
        json.dump(out, f, indent=2)
    sys.exit(0 if passed == len(RESULTS) else 1)


if __name__ == "__main__":
    main()
