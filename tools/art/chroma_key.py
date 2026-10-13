#!/usr/bin/env python3
"""chroma_key.py — potong latar CHROMA-KEY dari foto aset arena → PNG transparan.

Permintaan pemain 2026-10-13: "untuk arena itu elementnya juga pakai png, kamu
generate foto dengan chromase seperti planet dll". Foto mentah digenerate oleh
model gambar dengan latar MAGENTA murni (#FF00FF) supaya bisa dipotong bersih.

Algoritma (bukan sekadar threshold warna — dijaga supaya ISI objek tidak
berubah warna: planet biru/ungu TIDAK boleh ikut terhapus):
  1. Jarak warna ke key: d = |P − K| (Euclidean RGB). Piksel dianggap latar
     hanya bila d < D_IN (55). Catatan penting: skor "sumbu magenta" seperti
     (max(r,b) − g) SALAH untuk aset biru/ungu — versi pertama saya menghapus
     badan planet (bug nyata yang terlihat di hasil; dilaporkan di laporan §5).
  2. Penghapusan GLOBAL untuk piksel yang benar-benar dekat key (d < 55) —
     termasuk lubang magenta DI DALAM cincin planet (temuan foto: versi
     "flood fill dari tepi" menyisakan blob magenta di dalam cincin). Objek
     yang berisi warna dekat-magenta tidak ada di set aset ini; kedekatan
     dijaga ketat (jarak Euclidean 55/441 = 12%).
  3. Despill: warna piksel setengah-transparan di-un-mix terhadap warna key
     (P = a·F + (1-a)·K  →  F = (P − (1−a)·K)/a) supaya tidak ada halo magenta.
  4. Crop ke bbox alpha + margin, perkecil ke maks 512 px (hemat PCK), simpan
     PNG RGBA ke assets/arena/ dan game/assets/arena/.

Usage:
  python3 tools/art/chroma_key.py            # proses semua assets/arena/_raw/*.png
  python3 tools/art/chroma_key.py --info     # laporkan statistik hasil saja
"""

import os
import sys
from collections import deque

from PIL import Image

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RAW_DIR = os.path.join(REPO, "assets", "arena", "_raw")
OUT_DIRS = (os.path.join(REPO, "assets", "arena"),
            os.path.join(REPO, "game", "assets", "arena"))
KEY = (255, 0, 255)          ## magenta chroma
D_IN = 55.0                  ## |P−K| < ini = latar pasti (dipakai flood fill)
D_OUT = 115.0                ## |P−K| > ini = objek pasti (alpha 1, warna utuh)
MAX_SIZE = 512
MARGIN = 6
SPILL = 0.9                  ## kekuatan despill tepi


def key_dist(r, g, b):
    dr, dg, db = r - KEY[0], g - KEY[1], b - KEY[2]
    return (dr * dr + dg * dg + db * db) ** 0.5


def clean_edges(out):
    """Bersihkan sisa magenta yang MUNCUL LAGI setelah penskalaan.

    Temuan nyata (verifikasi piksel M3 #7): `Image.LANCZOS` saat 1024 → 512
    mencampur ulang piksel transparan ber-warna-key di tepi dengan piksel isi
    sehingga muncul kembali piksel setengah-transparan bernuansa key (mis.
    `station_orbital.png` 201 px magenta kuat, x=50 baris 10–17). Despill
    sebelum resize tidak bisa mencegahnya, jadi pembersihan WAJIB diulang
    setelah resize:

      - alpha < 240 dan |P−K| < 70  → nyaris warna key, mustahil berasal dari
        objek; jadikan transparan (ini bleed resize, bukan seni).
      - alpha < 250 → un-mix terhadap key lalu despill, membunuh halo magenta.

    Piksel OPAK (alpha ≥ 240) tidak disentuh: nebula memang berwarna magenta
    sebagai seni, dan menghapusnya = menghapus objek (bug chroma v1).
    """
    w, h = out.size
    px = out.load()
    cleared = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            d = key_dist(r, g, b)
            if a < 240 and d < 70.0:
                px[x, y] = (0, 0, 0, 0)
                cleared += 1
                continue
            if a < 250 and d < 130.0:
                af = max(0.02, a / 255.0)
                inv = 1.0 - af
                fr = min(255.0, max(0.0, (r - inv * KEY[0]) / af))
                fg = min(255.0, max(0.0, (g - inv * KEY[1]) / af))
                fb = min(255.0, max(0.0, (b - inv * KEY[2]) / af))
                spill = max(0.0, (min(fr, fb) - fg) / 255.0)
                fr = max(0.0, fr - spill * 255.0 * inv)
                fb = max(0.0, fb - spill * 255.0 * inv)
                fg = min(255.0, fg + spill * 120.0 * inv)
                px[x, y] = (int(fr), int(fg), int(fb), a)
    return cleared


def process(path, out_name):
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()

    # --- 1. jarak ke key + mask latar pasti ---
    dist = [[key_dist(*px[x, y]) for x in range(w)] for y in range(h)]
    bg_hard = [[dist[y][x] < D_IN for x in range(w)] for y in range(h)]

    # --- 2. flood fill dari tepi: hanya latar TERSAMBUNG TEPI yang transparan
    #        (lubang magenta di TENGAH objek tidak ikut terpotong) ---
    bg = [[bg_hard[y][x] for x in range(w)] for y in range(h)]  ## global
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if bg_hard[y][x] and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if bg_hard[y][x] and not bg[y][x]:
                bg[y][x] = True
                q.append((x, y))
    # --- 2b. pita tepi (≤3 px dari latar): alpha gradien untuk anti-alias ---
    edge = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            if bg[y][x]:
                continue
            for r_ in range(1, 4):
                found = False
                for dx in range(-r_, r_ + 1):
                    for dy in (-r_, r_):
                        nx, ny = x + dx, y + dy
                        if 0 <= nx < w and 0 <= ny < h and bg[ny][nx]:
                            found = True
                            break
                    if found:
                        break
                if found:
                    edge[y][x] = True
                    break

    # --- 3. komposit: isi objek TIDAK diubah warna (alpha 1), hanya pita tepi
    #        yang diberi alpha gradien + despill ringan (anti-halo magenta) ---
    out = Image.new("RGBA", (w, h))
    op = out.load()
    keyed = 0
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y]
            if bg[y][x]:
                op[x, y] = (0, 0, 0, 0)
                keyed += 1
                continue
            if not edge[y][x]:
                op[x, y] = (r, g, b, 255)
                continue
            d = dist[y][x]
            a = (d - D_IN) / (D_OUT - D_IN)
            a = min(1.0, max(0.0, a))
            if a <= 0.0:
                op[x, y] = (0, 0, 0, 0)
                keyed += 1
                continue
            inv = 1.0 - a
            fr = (r - inv * KEY[0]) / a
            fg = (g - inv * KEY[1]) / a
            fb = (b - inv * KEY[2]) / a
            spill = max(0.0, (min(fr, fb) - fg) / 255.0)   ## kelebihan magenta sisa
            fr = max(0.0, fr - spill * SPILL * 255.0 * inv)
            fb = max(0.0, fb - spill * SPILL * 255.0 * inv)
            fg = min(255.0, fg + spill * SPILL * 120.0 * inv)
            op[x, y] = (int(min(255, fr)), int(min(255, fg)), int(min(255, fb)),
                        int(a * 255))

    # --- 4. crop ke bbox isi + margin, lalu perkecil ---
    bbox = out.getbbox()
    if bbox:
        l, t_, r_, b_ = bbox
        l = max(0, l - MARGIN)
        t_ = max(0, t_ - MARGIN)
        r_ = min(w, r_ + MARGIN)
        b_ = min(h, b_ + MARGIN)
        out = out.crop((l, t_, r_, b_))
    if max(out.size) > MAX_SIZE:
        scale = MAX_SIZE / float(max(out.size))
        out = out.resize((max(1, int(out.size[0] * scale)), max(1, int(out.size[1] * scale))),
                         Image.LANCZOS)

    cleared = clean_edges(out)

    for d in OUT_DIRS:
        os.makedirs(d, exist_ok=True)
        out.save(os.path.join(d, out_name), optimize=True)
    return {"name": out_name, "size": out.size, "keyed_pct": round(100.0 * keyed / (w * h), 1),
            "edge_cleared": cleared,
            "bytes": os.path.getsize(os.path.join(OUT_DIRS[0], out_name))}


def main():
    if "--info" in sys.argv:
        for d in OUT_DIRS:
            for f in sorted(os.listdir(d)) if os.path.isdir(d) else []:
                if f.endswith(".png"):
                    p = os.path.join(d, f)
                    im = Image.open(p)
                    print("%-28s %s %d B" % (f, im.size, os.path.getsize(p)))
        return 0
    if not os.path.isdir(RAW_DIR):
        print("tidak ada %s" % RAW_DIR)
        return 1
    rows = []
    for f in sorted(os.listdir(RAW_DIR)):
        if not f.endswith(".png") or f.startswith("."):
            continue
        out_name = f.replace("_raw.png", ".png")
        rows.append(process(os.path.join(RAW_DIR, f), out_name))
    for r in rows:
        print("  %-26s %sx%s  latar dipotong %s%%  tepi dibersihkan %d px  %d B" % (
            r["name"], r["size"][0], r["size"][1], r["keyed_pct"], r["edge_cleared"], r["bytes"]))
    print("chroma_key: %d aset → %s" % (len(rows), " + ".join(os.path.relpath(d, REPO) for d in OUT_DIRS)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
