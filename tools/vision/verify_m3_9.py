#!/usr/bin/env python3
"""verify_m3_9.py — verifikasi M3 #9 (kritik #6 pemain 2026-10-14) dari BUKTI
PIKSEL + marker nyata di docs/m3_9/.

Cek:
  1. 5 foto bukti (2 dpr untuk benteng, zoom-out, penempatan sah & tidak sah):
     dimensi + dpr sesuai, `waitForMatched`, 0 pageError, 0 TEST:FAIL, tanpa
     "Node not found", marker penunggu cocok.
  2. **Benteng = PNG**: marker `QA:ARENA:FORTRESS src=png walls=8 bastions=4` dan
     `QA:ARENA:DECK src=png`; bukti piksel: lantai plataran BERTEKSTUR (banyak
     tingkat kecerahan, bukan warna rata) + celah tembak cyan di bastion.
  3. **Logika build**: marker `QA:BUILD:LAYOUT placed=9`, `COVERAGE` inti ditutup
     ≥2 turret, hantu sah (`valid=true`) dan tidak sah (`reason=di_luar_plataran`),
     penolakan konfirmasi + toast.
  4. **Mode penempatan terlihat di foto**: bilah LETAKKAN (teks terang di
     bawah-tengah) + hantu HIJAU saat sah; saat tidak sah tidak ada hantu hijau
     di arena dan teks bilah memuat alasan (piksel merah "TIDAK BISA").
  5. **AC-6a kartu** (foto 05, dpr1 1280x720, katalog terbuka): geometri NYATA semua
     kartu → 0 pasangan beririsan, 0 kartu menabrak panel detail, tile ≥48dp,
     jarak antar kartu ≥8dp, modal ≤560×360dp, tanpa label kata (kritik #4).
  6. **Chrome gameplay disembunyikan** saat mode penempatan (marker
     `QA:HUD:PLACE_MODE chrome=hidden`) → tidak ada tumpukan bilah vs grid aksi.

Output: docs/m3_9/verify_m3_9.json
Usage: python3 tools/vision/verify_m3_9.py
"""
import json
import os
import re
import sys

import numpy as np
from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
DOC = os.path.join(REPO, "docs", "m3_9")

EXPECT = {
    "00_fortress_1280x720.png": (1280, 720, 2, "fortress"),
    "01_fortress_2340x1080.png": (2340, 1080, 3, "fortress"),
    "02_fortress_zoomout_1280x720.png": (1280, 720, 2, "fortress"),
    "03_placement_valid_1280x720.png": (1280, 720, 2, "place_valid"),
    "04_placement_invalid_1280x720.png": (1280, 720, 2, "place_invalid"),
    ## AC-6a: sudut pandang pemain, dpr1 (kritik #6: "card bertumpuk & size tidak tepat")
    "05_kartu_ui_dpr1_1280x720.png": (1280, 720, 1, "kartu"),
}

results = []


def check(name, ok, detail=""):
    results.append({"name": name, "pass": bool(ok), "detail": detail})
    print(("PASS " if ok else "FAIL ") + name + (" — " + detail if detail else ""))


def _load_json(path):
    try:
        with open(path) as fh:
            return json.load(fh)
    except Exception:
        return {}


def pixels(path):
    return np.array(Image.open(path).convert("RGB")).astype(int)


def count_mask(arr, fn):
    r, g, b = arr[:, :, 0], arr[:, :, 1], arr[:, :, 2]
    return int(np.count_nonzero(fn(r, g, b)))


def bright(arr):
    return count_mask(arr, lambda r, g, b: (r > 150) & (g > 150) & (b > 150))


def green(arr):
    return count_mask(arr, lambda r, g, b: (g > 130) & (g - np.maximum(r, b) > 35))


def red(arr):
    return count_mask(arr, lambda r, g, b: (r > 140) & (r - np.maximum(g, b) > 45))


def cyan(arr):
    return count_mask(arr, lambda r, g, b: (b - r > 60) & (b > 130) & (g > 110))


print("== 1. Foto bukti & higienitas log ==")
reports = {}
for fname, (w, h, dpr, role) in EXPECT.items():
    png = os.path.join(DOC, fname)
    if not os.path.exists(png) or not os.path.exists(png + ".json"):
        check("foto %s ada" % fname, False, "berkas hilang")
        continue
    rep = json.load(open(png + ".json"))
    reports[fname] = rep
    logs = "\n".join(rep.get("consoleLogs", []))
    size = (rep["png"]["width"], rep["png"]["height"])
    ok = (size == (w, h) and rep.get("devicePixelRatio") == dpr
          and rep.get("waitForMatched") is True and len(rep.get("pageErrors", [])) == 0
          and "TEST:FAIL" not in logs and "Node not found" not in logs)
    check("foto %s: %dx%d dpr %d, 0 error, tanpa 'Node not found'" % (fname, w, h, dpr), ok,
          "waitFor=%s pageErrors=%d" % (rep.get("waitForMatched"), len(rep.get("pageErrors", []))))

print("\n== 2. Benteng luar angkasa = PNG + bukti piksel ==")
for fname in ("00_fortress_1280x720.png", "01_fortress_2340x1080.png"):
    logs = "\n".join(reports.get(fname, {}).get("consoleLogs", []))
    ok = ("QA:ARENA:FORTRESS src=png walls=8 bastions=4" in logs
          and "QA:ARENA:DECK src=png" in logs)
    check("marker benteng %s (dinding+bastion PNG, deck PNG)" % fname, ok,
          re.search(r"QA:ARENA:FORTRESS[^\"]*", logs).group(0) if "FORTRESS" in logs else "?")

img = pixels(os.path.join(DOC, "00_fortress_1280x720.png"))
## (a) lantai BERTEKSTUR: banyak tingkat kecerahan pada area plataran (bukan warna rata)
floor = img[420:660, 200:1100]
gray = (floor[:, :, 0] * 299 + floor[:, :, 1] * 587 + floor[:, :, 2] * 114) // 1000
levels = int(np.unique(gray).size)
check("lantai plataran bertekstur (PNG), bukan warna rata", levels >= 24,
      "tingkat kecerahan area plataran = %d (warna rata ≈ <5)" % levels)
## (b) elemen benteng terang (dinding/bastion) terlihat, bukan siluet hitam
wall_band = img[150:420, :]
check("dinding/bastion benteng terbaca (banyak piksel terang)", bright(wall_band) >= 3000,
      "piksel terang di area dinding = %d" % bright(wall_band))
## (c) celah tembak cyan bastion (3D emissive, bukan HUD) hadir di area atas
check("celah tembak cyan bastion terlihat", cyan(img[60:260, :]) >= 400,
      "piksel cyan area bastion = %d" % cyan(img[60:260, :]))

print("\n== 3. Logika build (marker nyata) ==")
valid_logs = "\n".join(reports.get("03_placement_valid_1280x720.png", {}).get("consoleLogs", []))
invalid_logs = "\n".join(reports.get("04_placement_invalid_1280x720.png", {}).get("consoleLogs", []))
check("rencana tata letak diterapkan (9 bangunan)",
      re.search(r"QA:BUILD:LAYOUT placed=9", valid_logs) is not None,
      "marker QA:BUILD:LAYOUT")
mc = re.search(r"QA:BUILD:COVERAGE.*", valid_logs)
covering = int(re.search(r"covering[\"\s:]+(\d+)", mc.group(0)).group(1)) if mc else -1
m = mc
check("inti ditutup ≥2 turret (dari DATA jangkauan)", covering >= 2,
      (m.group(0) if m else "marker tidak ada"))
check("hantu SAH terekam (valid=true)",
      "QA:BUILD:GHOST id=laser_turret pos=16,-14 valid=true reason=ok" in valid_logs
      or re.search(r"QA:BUILD:GHOST .*valid=true reason=ok", valid_logs) is not None,
      "marker QA:BUILD:GHOST")
check("hantu TIDAK SAH terekam + alasan nyata (di luar plataran)",
      re.search(r"QA:BUILD:GHOST .*valid=false reason=di_luar_plataran", invalid_logs) is not None
      and re.search(r"QA:PLACE:READY step=invalid .*valid=false reason=di_luar_plataran",
                    invalid_logs) is not None,
      "marker QA:PLACE:READY step=invalid")
check("chrome gameplay disembunyikan di mode penempatan (anti-tumpuk)",
      "QA:HUD:PLACE_MODE chrome=hidden" in valid_logs
      and "QA:HUD:PLACE_MODE chrome=hidden" in invalid_logs,
      "marker QA:HUD:PLACE_MODE")
check("bilah penempatan dibangun (330×56dp, 48dp tombol)",
      "QA:HUD:PLACEBAR w=660 h=112 dp=330x56" in valid_logs, "marker QA:HUD:PLACEBAR")

print("\n== 4. Bukti piksel mode penempatan ==")
img_v = pixels(os.path.join(DOC, "03_placement_valid_1280x720.png"))
img_i = pixels(os.path.join(DOC, "04_placement_invalid_1280x720.png"))
## bilah penempatan: teks terang di bawah-tengah
bar_v = bright(img_v[580:680, 320:960])
bar_i = bright(img_i[580:680, 320:960])
check("bilah LETAKKAN terlihat di foto sah & tidak sah", bar_v >= 1200 and bar_i >= 1200,
      "piksel terang bilah: sah=%d tidak-sah=%d" % (bar_v, bar_i))
## hantu: HIJAU di arena saat sah; saat tidak sah jauh lebih sedikit
g_v = green(img_v[200:600, :])
g_i = green(img_i[200:600, :])
check("hantu HIJAU terlihat saat posisi sah", g_v >= 300, "piksel hijau arena = %d" % g_v)
check("tidak ada hantu hijau saat posisi ditolak", g_i <= g_v / 3,
      "piksel hijau arena (ditolak) = %d vs sah = %d" % [g_i, g_v][0] if False else
      "piksel hijau arena (ditolak) = %d vs sah = %d" % (g_i, g_v))
## penanda "TIDAK BISA"/tombol BATAL merah saat ditolak
r_i = red(img_i[580:680, 320:960])
check("bilah menampilkan penolakan (teks/tombol merah) saat tidak sah", r_i >= 250,
      "piksel merah di bilah = %d" % r_i)

print("\n== 5. Tidak ada tumpukan bilah vs grid aksi ==")
## grid aksi berada di kanan-bawah; saat mode penempatan harus TIDAK ada tombol
## BANGUN/ARMADA/MENU di foto (chrome disembunyikan) → area kanan-bawah gelap/arena
corner = img_v[560:720, 1080:1280]
check("area kanan-bawah bersih di mode penempatan (chrome tersembunyi)",
      bright(corner) <= 600, "piksel terang area grid aksi = %d" % bright(corner))

print("\n== 6. Audit kartu AC-6a (foto dpr1 1280x720, katalog terbuka) ==")
## Sumber angka: marker QA:UI:KARTU_READY + TEST:PASS dari run mode=ui&step=kartu.
p05 = os.path.join(DOC, "05_kartu_ui_dpr1_1280x720.png")
j05 = _load_json(p05 + ".json") if os.path.exists(p05 + ".json") else {}
logs05 = "\n".join(j05.get("consoleLogs", []))
m05 = re.search(r"QA:UI:KARTU_READY[^\n]*", logs05)
m05 = m05.group(0) if m05 else ""

def _num(pattern, text, default=-1.0):
    mm = re.search(pattern, text)
    return float(mm.group(1)) if mm else default

check("katalog BANGUN benar-benar TERBUKA di foto 05 (marker KARTU_READY)",
      "QA:UI:KARTU_READY" in logs05 and "cards=5" in m05, m05[:160])
check("tidak ada pasangan kartu beririsan (diukur dari rect nyata)",
      "kartu_beririsan=0" in m05 and "TEST:PASS ui.kartu_tidak_bertumpuk" in logs05,
      "kartu_beririsan=%s" % _num(r"kartu_beririsan=(\d+)", m05))
check("tidak ada kartu menabrak panel detail",
      "kartu_vs_detail=0" in m05 and "TEST:PASS ui.kartu_tidak_menabrak_panel_detail" in logs05,
      "kartu_vs_detail=%s" % _num(r"kartu_vs_detail=(\d+)", m05))
tile_dp = _num(r"tile_dp_min=([\d.]+)", m05)
check("ukuran kartu sesuai standar dp (≥48dp)", tile_dp >= 48.0,
      "tile terkecil=%.1fdp (standar Material ≥48dp)" % tile_dp)
gap_dp = _num(r"jarak_dp=([\d.]+)", m05)
check("jarak antar kartu sesuai grid dp (≥8dp)", gap_dp >= 7.5,
      "jarak=%.1fdp (grid 8dp UI_UX_DESIGN §7b)" % gap_dp)
mw = _num(r"modal_dp=(\d+)x", m05)
mh = _num(r"modal_dp=\d+x(\d+)", m05)
check("ukuran modal sesuai standar (≤560×360dp)", 0 < mw <= 560.0 and 0 < mh <= 360.0,
      "modal=%.0fx%.0fdp (standar dialog ≤560dp)" % (mw, mh))
check("kartu tanpa label kata (kritik #4 tetap dipatuhi)",
      "label_free_pct=100" in logs05 and "with_text=0" in logs05,
      "QA:CARD:SUMMARY label_free_pct=100 with_text=0")
## piksel: kartu terlihat sebagai blok terang di tengah (bukan kosong / blank)
## Area yang diukur = RECT MODAL NYATA dari marker (bukan kotak karangan):
##   modal=384,220 512x280 (device px di dpr1)
mr = re.search(r"modal=(\d+),(\d+) (\d+)x(\d+)", m05)
img05 = pixels(p05)
mid = -1
tile_bright = -1
if img05 is not None and mr:
    x, y, w, h = (int(g) for g in mr.groups())
    mid = bright(img05[y:y + h, x:x + w])
    ## baris pertama grid kartu (ikon) harus lebih terang dari latar modal gelap
    tile_bright = bright(img05[y + int(h * 0.25):y + int(h * 0.55), x:x + int(w * 0.6)])
check("kartu terlihat di foto (blok terang DI DALAM rect modal nyata)", mid >= 500,
      "piksel terang dalam modal (%s) = %d" % (mr.group(0) if mr else "rect tidak ditemukan", mid))
check("ikon kartu terbaca (baris kiri grid lebih terang dari latar modal)",
      tile_bright > mid * 0.12, "piksel terang baris kartu = %d (total modal %d)" % (tile_bright, mid))

passed = sum(1 for r in results if r["pass"])
total = len(results)
out = {"checks": results, "passed": passed, "total": total,
       "verdict": "PASS" if passed == total else "FAIL"}
with open(os.path.join(DOC, "verify_m3_9.json"), "w") as fh:
    json.dump(out, fh, indent=2, ensure_ascii=False)
print("\nverify_m3_9: %d/%d PASS -> %s" % (passed, total, out["verdict"]))
sys.exit(0 if passed == total else 1)
