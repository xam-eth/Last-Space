#!/usr/bin/env python3
"""verify_m37.py — verifikasi M3.7 (label teks di semua card + model 3D arena).

Kriteria (dari feedback user 2026-10-12: "card 70% tidak ada label" & "canvas 3D
masih prototype") — semua bukti dari build nyata:

  1. QA:MODEL:BUILD  — tiap tipe bangunan = model komposit (≥8 mesh, ≥3 mesh
     emissive) → bukan kotak polos.
  2. QA:SCENE:ENV    — arena punya rim/pylons/pads (bukan bidang kosong).
  3. QA:HUD:LABELS   — kontrol CHROME (HUD + modal) punya label teks (0 unlabeled);
     tile katalog dikecualikan (memang tanpa label kata) & dihitung terpisah.
  3b. QA:CARD:SUMMARY / QA:CARD:TILE — card KATALOG tanpa label kata
     (with_text=0, label_free_pct=100 ≥ 70 kriteria user, ikon ≥ 60% sisi tile).
  4. Piksel          — teks label benar-benar TERGAMBAR di card aksi & card
     upgrade (bukan hanya ada di kode): hitung piksel terang di pita label.

Usage: python3 verify_m37.py <img_dir> <game_json...> --out out.json
"""
import json
import os
import re
import sys

from PIL import Image

RED, GRN, RST = "\033[31m", "\033[32m", "\033[0m"
results = []


def check(name, ok, evidence):
    results.append({"name": name, "ok": bool(ok), "evidence": evidence})
    print(f"{GRN if ok else RED}{'PASS' if ok else 'FAIL'}{RST} {name} — {evidence}")


def logs_of(path):
    try:
        return json.load(open(path)).get("consoleLogs", [])
    except Exception as e:
        print(f"  (skip {path}: {e})")
        return []


def bright_pixels(path, x0, y0, x1, y1, thr=190):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    sx, sy = w / 1280.0, h / 720.0          # skala dari design px
    px = im.load()
    n = 0
    for y in range(int(y0 * sy), min(int(y1 * sy), h), 2):
        for x in range(int(x0 * sx), min(int(x1 * sx), w), 2):
            r, g, b = px[x, y]
            if r > thr and g > thr and b > thr:
                n += 1
    return n


def main():
    argv = sys.argv[1:]
    out_path = None
    if "--out" in argv:
        i = argv.index("--out")
        out_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    img_dir = argv[0] if argv else "out/m37"
    jsons = [a for a in argv[1:] if a.endswith(".json")]

    # --- 1 & 2 & 3: marker dari build ---
    seen_models = {}
    env_ok = None
    labels_ok = None
    card_sum = {}
    card_tiles = {}

    for j in jsons:
        for line in logs_of(j):
            m = re.search(r"QA:MODEL:BUILD id=(\S+) meshes=(\d+) emissive=(\d+)", line)
            if m:
                seen_models[m.group(1)] = (int(m.group(2)), int(m.group(3)))
            m2 = re.search(r"QA:SCENE:ENV (.*)", line)
            if m2:
                env_ok = m2.group(1)
            m3 = re.search(r"QA:HUD:LABELS total=(\d+) labeled=(\d+) unlabeled=\[([^\]]*)\]", line)
            if m3:
                labels_ok = (int(m3.group(1)), int(m3.group(2)), m3.group(3).strip())
            m4 = re.search(r"QA:CARD:SUMMARY menu=(\S+) tab=(\S+) tiles=(\d+) with_text=(\d+) label_free_pct=(-?\d+) icon_ratio=(\d+)", line)
            if m4:
                card_sum[m4.group(1)] = {"tab": m4.group(2), "tiles": int(m4.group(3)),
                    "with_text": int(m4.group(4)), "label_free": int(m4.group(5)),
                    "icon_ratio": int(m4.group(6))}
            m5 = re.search(r"QA:CARD:TILE menu=(\S+) id=(\S+) text_nodes=(\d+)", line)
            if m5:
                card_tiles[(m5.group(1), m5.group(2))] = int(m5.group(3))

    if seen_models:
        bad = {k: v for k, v in seen_models.items() if v[0] < 8 or v[1] < 3}
        detail = ", ".join(f"{k}={v[0]}mesh/{v[1]}glow" for k, v in sorted(seen_models.items()))
        check("model_komposit_semua_tipe", len(seen_models) >= 5 and not bad,
              f"{len(seen_models)} tipe: {detail}" + (f" | kurang: {bad}" if bad else ""))
    else:
        check("model_komposit_semua_tipe", False, "marker QA:MODEL:BUILD tidak ditemukan")

    if env_ok:
        need = all(k in env_ok for k in ["rim=", "pylons=", "pads="])
        check("arena_props", need, f"QA:SCENE:ENV {env_ok}")
    else:
        check("arena_props", False, "marker QA:SCENE:ENV tidak ditemukan")

    if labels_ok:
        total, labeled, unlab = labels_ok
        check("chrome_berlabel", total >= 10 and labeled == total and unlab == "",
              f"{labeled}/{total} kontrol chrome berlabel, unlabeled=[{unlab}]")
    else:
        check("chrome_berlabel", False, "marker QA:HUD:LABELS tidak ditemukan")

    # --- 3c: card KATALOG tanpa label kata (kriteria utama user 2026-10-13) ---
    if card_sum:
        bad_tiles = {k: v for k, v in card_tiles.items() if v != 0}
        detail = ", ".join(
            f"{k}: tiles={v['tiles']} with_text={v['with_text']} tanpa_label={v['label_free']}% ikon={v['icon_ratio']}%"
            for k, v in sorted(card_sum.items()))
        check("card_katalog_tanpa_label",
              all(v["with_text"] == 0 for v in card_sum.values()) and not bad_tiles and len(card_tiles) > 0,
              f"{len(card_tiles)} tile diperiksa: {detail}" + (f" | tile berlabel: {bad_tiles}" if bad_tiles else ""))
        check("card_tanpa_label_min_70pct",
              all(v["label_free"] >= 70 for v in card_sum.values()),
              ", ".join(f"{k}={v['label_free']}%" for k, v in sorted(card_sum.items())) + " (kriteria: ≥70%)")
        check("card_ikon_dominan",
              all(v["icon_ratio"] >= 60 for v in card_sum.values()),
              ", ".join(f"{k}={v['icon_ratio']}% dari sisi tile" for k, v in sorted(card_sum.items())))
    else:
        check("card_katalog_tanpa_label", False, "marker QA:CARD:SUMMARY tidak ditemukan")
        check("card_tanpa_label_min_70pct", False, "marker QA:CARD:SUMMARY tidak ditemukan")
        check("card_ikon_dominan", False, "marker QA:CARD:SUMMARY tidak ditemukan")

    # --- 3b: label di canvas 3D tidak boleh bertumpuk (kritik #3 berlaku juga
    # untuk teks di dunia 3D, bukan hanya HUD) ---
    lbl_seen = []
    for j in jsons:
        for line in logs_of(j):
            m = re.search(r"QA:SCENE:LABEL_OVERLAP count=(\d+) visible=(\d+) hidden=(\d+) total=(\d+)", line)
            if m:
                lbl_seen.append(tuple(int(g) for g in m.groups()))
    if lbl_seen:
        worst = max(x[0] for x in lbl_seen)
        multi = [x for x in lbl_seen if x[3] >= 3]
        check("label_3d_tidak_bertumpuk", worst == 0,
              f"{len(lbl_seen)} sampel, overlap maks={worst}; dengan >=3 bangunan: "
              + ", ".join(f"vis={v} hid={h}/{t}" for _, v, h, t in multi[:3]))
    else:
        check("label_3d_tidak_bertumpuk", False, "marker QA:SCENE:LABEL_OVERLAP tidak ditemukan")

    # --- 4: label benar-benar tergambar (piksel terang di pita label) ---
    hud = os.path.join(img_dir, "hud_16x9.png")
    if os.path.exists(hud):
        # kartu aksi (design px): 3 kartu 112 lebar, gap 16, blok kanan-bawah
        cards = [(880, 1008), (1008, 1136), (1136, 1248)]
        counts = []
        for i, (x0, x1) in enumerate(cards):
            n = bright_pixels(hud, x0 + 8, 616, x1 - 8, 664)
            counts.append(n)
            check(f"label_card_aksi_{i+1}", n >= 40,
                  f"{n} px teks terang di pita label kartu {i+1} ({x0}..{x1}, y 616..664)")
        check("label_card_aksi_semua", all(c >= 40 for c in counts), f"counts={counts}")
    else:
        check("label_card_aksi_1", False, f"foto tidak ada: {hud}")

    sel = os.path.join(img_dir, "command_selected_16x9.png")
    if os.path.exists(sel):
        n = bright_pixels(sel, 1040, 600, 1280, 680)  # area card TINGKATKAN
        check("label_card_upgrade", n >= 60, f"{n} px teks di card upgrade (seleksi)")
    else:
        print(f"  (catatan: {sel} tidak ada — cek label card upgrade dilewati)")

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    if out_path:
        json.dump({"suite": "M3.7 label & model 3D", "passed": passed, "failed": failed,
                   "checks": results}, open(out_path, "w"), indent=2)
    print(f"{GRN if failed == 0 else RED}REPORT: {passed} PASS / {failed} FAIL{RST}" + (f" -> {out_path}" if out_path else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
