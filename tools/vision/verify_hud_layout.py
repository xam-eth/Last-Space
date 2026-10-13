#!/usr/bin/env python3
"""verify_hud_layout.py — verifikasi HUD TIDAK BERTUMPUK (data build nyata).

Membaca JSON hasil capture Chromium (tools/vision/out atau docs/…) dan
mengambil marker dari log game:
  QA:HUD:LAYOUT  — rect semua zona (device px)
  QA:HUD:OVERLAP — pasangan zona yang bertumpuk (dari perhitungan in-engine)
  QA:HUD:FIT     — panel vs ukuran minimum konten

Aturan (kriteria lulus):
  1. count=0 tumpang-tindih pada SETIAP device class.
  2. semua panel fit=true (konten tidak melimpah keluar panel).
  3. ukuran komponen dalam dp: tombol aksi 48dp, top bar 56dp, margin 16dp.
  4. zona dalam batas layar (tidak keluar viewport).

Usage: python3 verify_hud_layout.py <json...> [--out out.json]
"""
import json
import re
import sys

RED, GRN, RST = "\033[31m", "\033[32m", "\033[0m"
results = []


def check(name, ok, evidence):
    results.append({"name": name, "ok": bool(ok), "evidence": evidence})
    print(f"{GRN if ok else RED}{'PASS' if ok else 'FAIL'}{RST} {name} — {evidence}")


def zone_rects(dump):
    out = {}
    for m in re.finditer(r"([A-Za-z]+)\[(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?) (\d+)x(\d+)\]", dump):
        name = m.group(1)
        if name in ("viewport", "dpr", "jsDpr", "scale", "cell0"):
            continue
        out[name] = (float(m.group(2)), float(m.group(3)), float(m.group(4)), float(m.group(5)))
    return out


def main():
    argv = sys.argv[1:]
    out_path = None
    if "--out" in argv:
        i = argv.index("--out")
        out_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]  # buang --out + nilainya dari daftar input
    files = [(a, None) for a in argv if a.endswith(".json")]
    for f, _ in files:
        try:
            report = json.load(open(f))
        except Exception as e:
            check(f"parse_{f}", False, f"gagal baca: {e}")
            continue
        logs = report.get("consoleLogs", [])
        dump = overlap = fit = None
        for line in logs:
            if "QA:HUD:LAYOUT" in line and dump is None:
                dump = line.split("QA:HUD:LAYOUT", 1)[1]
            if "QA:HUD:OVERLAP" in line and overlap is None:
                overlap = line.split("QA:HUD:OVERLAP", 1)[1]
            if "QA:HUD:FIT" in line and fit is None:
                fit = line.split("QA:HUD:FIT", 1)[1]
        tag = f.split("/")[-1].replace(".png.json", "").replace(".json", "")
        if dump is None:
            check(f"{tag}_dump", False, "tidak ada QA:HUD:LAYOUT di log")
            continue

        vp = re.search(r"viewport\[(\d+)x(\d+)\]", dump)
        dpr = re.search(r"dpr\[([\d.]+)\]", dump)
        vpw, vph = (int(vp.group(1)), int(vp.group(2))) if vp else (0, 0)
        dpr_f = float(dpr.group(1)) if dpr else 0.0
        zones = zone_rects(dump)

        # 1. anti-tumpuk (dari engine)
        n_overlap = None
        if overlap is not None:
            m = re.search(r"count=(\d+)", overlap)
            n_overlap = int(m.group(1)) if m else -1
            check(f"{tag}_tidak_bertumpuk", n_overlap == 0,
                  f"count={n_overlap} {overlap.replace('count=%d' % n_overlap, '').strip()[:80]}")

        # 2. fit konten
        if fit is not None:
            oks = re.findall(r"(\w+):(ok|MELIMPAH)\(", fit)
            bad = [n for n, st in oks if st == "MELIMPAH"]
            check(f"{tag}_konten_muat", len(oks) >= 2 and not bad,
                  f"{len(oks)} panel, melimpah: {bad if bad else 'tidak ada'} | {fit.strip()[:90]}")

        # 3. ukuran komponen dalam dp
        if dpr_f > 0:
            if "TopBar" in zones:
                _, _, _, th = zones["TopBar"]
                check(f"{tag}_topbar_56dp", abs(th / dpr_f - 56) <= 1.5,
                      f"{th:.0f}px / {dpr_f} = {th/dpr_f:.1f}dp (target 56)")
            if "cell0" in dump:
                m = re.search(r"cell0\[[\d.,]+ (\d+)x(\d+)\]", dump)
                if m:
                    cw, ch = float(m.group(1)), float(m.group(2))
                    ok = cw / dpr_f >= 47.0 and ch / dpr_f >= 47.0
                    check(f"{tag}_card_aksi_min_48dp", ok,
                          f"card aksi {cw:.0f}x{ch:.0f}px = {cw/dpr_f:.1f}x{ch/dpr_f:.1f}dp (minimum 48)")
            if "TopBar" in zones:
                x, y, _, _ = zones["TopBar"]
                check(f"{tag}_margin_16dp", abs(x / dpr_f - 16) <= 1.5 and abs(y / dpr_f - 16) <= 1.5,
                      f"({x/dpr_f:.1f},{y/dpr_f:.1f})dp (target 16)")

        # 3b. semua kontrol interaktif punya label teks (kriteria user 2026-10-12)
        labels = None
        for line in logs:
            if "QA:HUD:LABELS" in line and labels is None:
                labels = line.split("QA:HUD:LABELS", 1)[1]
        if labels is not None:
            mm = re.search(r"total=(\d+) labeled=(\d+) unlabeled=\[([^\]]*)\]", labels)
            if mm:
                total, labeled, unlab = int(mm.group(1)), int(mm.group(2)), mm.group(3).strip()
                check(f"{tag}_semua_kontrol_berlabel", labeled == total and unlab == "",
                      f"{labeled}/{total} berlabel, unlabeled=[{unlab}]")

        # 4. zona di dalam layar
        if vpw and vph:
            out_of = []
            for name, (x, y, w, h) in zones.items():
                if x < -1 or y < -1 or x + w > vpw + 1 or y + h > vph + 1:
                    out_of.append(f"{name}[{x:.0f},{y:.0f} {w:.0f}x{h:.0f}]")
            check(f"{tag}_zona_dalam_layar", not out_of,
                  f"viewport {vpw}x{vph}, keluar: {out_of if out_of else 'tidak ada'}")

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    payload = {"suite": "HUD layout anti-tumpuk (M3.7)", "passed": passed, "failed": failed, "checks": results}
    if out_path:
        json.dump(payload, open(out_path, "w"), indent=2)
    print(f"{GRN if failed == 0 else RED}REPORT: {passed} PASS / {failed} FAIL{RST}" + (f" -> {out_path}" if out_path else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
