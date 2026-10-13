#!/usr/bin/env python3
"""verify_menu.py — verifikasi MENU UTAMA M3 #4 (foto nyata + marker runtime).

Sumber kriteria (bukan asumsi):
  · GAMEPLAY_FLOW.md Frame 3  — scene menu: base 3D idle + panel aksi.
  · UI_UX_DESIGN.md §8 #2     — panel 320dp+, tombol utama 56dp / sekunder 48dp.
  · docs/REFERENCES_MAIN_MENU.md — satu tombol = satu aksi, aksi utama di thumb
    zone (therookies/Doomsday F1), padding panel, progressive disclosure.
  · Standar dp M3.6: 1 css px = 1 dp, design px = dp×2, scale = dpr/2,
    margin tepi 16dp, touch ≥48dp, dialog ≤560dp.

Cara verifikasi (DUA lapis, keduanya harus lolos):

  A. Marker runtime (angka dari game, bukan tebakan):
     QA:MENU:FIT  → panel dari konten, fit=ok, credits_fit=ok, side_dp≥8,
                    off_dp=16 (jarak panel ke tepi bawah); kalau tidak fit,
                    panel meluber keluar layar (cacat, bukan "hampir ok").
     QA:MENU:DUMP → primary_dp=56, secondary_dp=48 (touch target standar).
     QA:MENU:OVERLAP count=0 → tidak ada Control bertumpuk (anti-tumpuk M3.7).
     QA:SCENE:LABEL_MENU state=hidden → label dunia 3D disembunyikan di menu.

  B. Piksel foto (apa yang benar-benar terlihat):
     1. Rect panel DIHITUNG dari marker (panel + avail + off_dp), bukan ditebak
        dari histogram; lalu di-skala ke device px dengan dpr/2.
     2. Di dalam panel: ≥3 pita teks terang, jarak antar pita ≥4dp = teks benar
        tergambar dan tidak saling menempel (anti-tumpuk piksel).
     3. Tinta teks ≥8dp dari SETIAP tepi panel = padding panel nyata.
     4. Di LUAR panel: nol piksel sangat terang (min channel >200) → tidak ada
        label dunia / chrome yang menembus area menu.
     5. Aksi utama di bawah titik tengah (thumb zone) — band terendah > 50% h.
     6. Konsistensi dp antar dpr: tinggi pita teks utama & lebar panel sama
        dalam dp (toleransi 6dp / 2dp) → komponen tidak ikut membesar di layar
        besar (aturan "size komposisi tidak boleh terlalu besar").

Foto fase gameplay (step=load) diverifikasi beda: HUD aktif, panel menu
tertutup; yang dicek anti-tumpuk teks HUD + marker bebas overlap + fase COMMAND.

Usage: python3 verify_menu.py <img_dir> [--out out.json]
Exit code 0 = semua lolos.
"""
import glob
import json
import os
import sys

from PIL import Image

RED, GRN, RST = "\033[31m", "\033[32m", "\033[0m"
BRIGHT = 200  ## "sangat terang" (label putih 0.92–1.0 × 255 ≈ 235+)
## Ambang "tinta TEKS" (min channel): panel gelap ≈16, border cyan ≈53,
## teks sekunder C_MUTED ≈158, teks utama putih ≈235 → 110 memisahkan tinta
## teks dari latar & border tanpa bergantung tema terang/gelap.
TEXT_THR = 110
results = []


def check(name, ok, evidence):
    results.append({"name": name, "ok": bool(ok), "evidence": evidence})
    print(f"{GRN if ok else RED}{'PASS' if ok else 'FAIL'}{RST} {name} — {evidence}")


def logs_of(png):
    j = png + ".json"
    if not os.path.exists(j):
        return [], {}
    r = json.load(open(j))
    return r.get("consoleLogs", []), r


def find(logs, pat):
    for l in reversed(logs):
        if pat in l:
            return l
    return ""


def kv(line, key, cast=float):
    for tok in line.split():
        if tok.startswith(key + "="):
            try:
                return cast(tok.split("=", 1)[1])
            except ValueError:
                return None
    return None


def band_rows(png, x0, x1, y0, y1, thr, step=2):
    """Baris (y, jumlah piksel terang) di ROI — dipakai untuk pita teks."""
    im = Image.open(png).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, x1 = max(0, int(x0)), min(w, int(x1))
    y0, y1 = max(0, int(y0)), min(h, int(y1))
    out = []
    for y in range(y0, y1, step):
        n = 0
        for x in range(x0, x1, step):
            r, g, b = px[x, y]
            if r > thr and g > thr and b > thr:
                n += 1
        out.append((y, n))
    return out


def bands_from_rows(rows, min_px=2):
    bands, cur = [], None
    for y, n in rows:
        if n >= min_px:
            if cur is None:
                cur = [y, y, 0]
            cur[1] = y
            cur[2] += n
        elif cur is not None:
            bands.append(tuple(cur))
            cur = None
    if cur is not None:
        bands.append(tuple(cur))
    return bands


def count_bright_outside(png, rect, thr=BRIGHT, step=2):
    """Piksel sangat terang di LUAR rect (device px) → label/chrome yang bocor."""
    im = Image.open(png).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, y0, x1, y1 = rect
    n = 0
    for y in range(0, h, step):
        for x in range(0, w, step):
            if x0 <= x <= x1 and y0 <= y <= y1:
                continue
            r, g, b = px[x, y]
            if min(r, g, b) > thr:
                n += 1
    return n


def band_extent_y(png, x0, x1, y0, y1, thr=TEXT_THR, step=2):
    """Pita teks teratas & terbawah + jarak tinta ke tepi atas/bawah ROI (device px)."""
    rows = band_rows(png, x0, x1, y0, y1, thr, step)
    bands = bands_from_rows(rows)
    if not bands:
        return None, None, None
    return bands[0][0], bands[-1][1], bands


def ink_extent_x(png, x0, x1, y0, y1, thr=TEXT_THR, step=2):
    im = Image.open(png).convert("RGB")
    w, h = im.size
    px = im.load()
    lo, hi = None, None
    for y in range(max(0, int(y0)), min(h, int(y1)), step):
        for x in range(max(0, int(x0)), min(w, int(x1)), step):
            r, g, b = px[x, y]
            if r > thr and g > thr and b > thr:
                lo = x if lo is None else min(lo, x)
                hi = x if hi is None else max(hi, x)
    return lo, hi


def luminance(p):
    r, g, b = p
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def modal_rect_device(fit_line, dpr, img_size):
    """Rect MODAL KREDIT di device px — marker credits=WxH, anchor CENTER."""
    credits = kv(fit_line, "credits", str) or ""
    avail = kv(fit_line, "avail", str) or ""
    if not credits or not avail:
        return None
    cw, ch = (float(v) for v in credits.split("x"))
    aw, ah = (float(v) for v in avail.split("x"))
    scale = dpr / 2.0
    x0 = (aw - cw) / 2.0 * scale
    x1 = (aw + cw) / 2.0 * scale
    y0 = (ah - ch) / 2.0 * scale
    y1 = (ah + ch) / 2.0 * scale
    w, h = img_size
    return (max(0.0, x0), max(0.0, y0), min(w, x1), min(h, y1))


def max_luminance(png, rect, step=1):
    """Luminance maksimum di dalam rect (device px) — dipakai uji kebersihan."""
    im = Image.open(png).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, y0, x1, y1 = (int(round(v)) for v in rect)
    mx = 0.0
    for y in range(max(0, y0), min(h, y1), step):
        for x in range(max(0, x0), min(w, x1), step):
            v = luminance(px[x, y])
            if v > mx:
                mx = v
    return mx


def long_neutral_text_rows(png, rect, lum_lo=78, lum_hi=140, spread=14,
                           min_px=20, min_span=60):
    """Baris di LUAR panel yang memuat teks netral panjang (label dunia 3D).

    Label dunia (Label3D, modulate 0.92/0.96/1.0) ter-render abu netral
    (≈rgb(89,93,97), luminance ≈92) — jauh lebih gelap dari teks UI putih
    (min channel >200), jadi cek "piksel terang" saja TIDAK menangkapnya
    (temuan foto portrait: label "Pusat Komando Lv1" terlihat di atas panel).
    Predikat: piksel netral (spread channel kecil) dengan luminance sedang,
    ≥min_px dalam satu baris DAN membentang ≥min_span (menyaring bintik batu).
    """
    im = Image.open(png).convert("RGB")
    w, h = im.size
    px = im.load()
    x0, y0, x1, y1 = rect
    rows = 0
    widest = 0
    for y in range(h):
        lo = hi = None
        n = 0
        for x in range(w):
            if x0 <= x <= x1 and y0 <= y <= y1:
                continue
            r, g, b = px[x, y]
            if max(r, g, b) - min(r, g, b) > spread:
                continue
            l = 0.2126 * r + 0.7152 * g + 0.0722 * b
            if lum_lo <= l <= lum_hi:
                n += 1
                lo = x if lo is None else lo
                hi = x
        if n >= min_px and hi is not None and (hi - lo) >= min_span:
            rows += 1
            widest = max(widest, hi - lo)
    return rows, widest


def panel_rect_device(fit_line, dpr, img_size):
    """Rect panel di device px — dari marker (panel/avail/off_dp) × scale dpr/2."""
    panel = kv(fit_line, "panel", str) or ""
    avail = kv(fit_line, "avail", str) or ""
    off_dp = kv(fit_line, "off_dp", float)
    if not panel or not avail or off_dp is None:
        return None
    pw, ph = (float(v) for v in panel.split("x"))
    aw, ah = (float(v) for v in avail.split("x"))
    scale = dpr / 2.0                      # design px → device px
    off = off_dp * 2.0                     # dp → design px
    cx = aw / 2.0
    x0 = (cx - pw / 2.0) * scale
    x1 = (cx + pw / 2.0) * scale
    y1 = (ah - off) * scale
    y0 = (ah - off - ph) * scale
    w, h = img_size
    return (max(0.0, x0), max(0.0, y0), min(w, x1), min(h, y1))


def main():
    argv = sys.argv[1:]
    out_path = None
    if "--out" in argv:
        i = argv.index("--out")
        out_path = argv[i + 1]
        argv = argv[:i] + argv[i + 2:]
    img_dir = argv[0]
    photos = sorted(glob.glob(os.path.join(img_dir, "*.png")))
    if not photos:
        print(f"{RED}tidak ada foto di {img_dir}{RST}")
        return 1

    dp_land = []  ## (name, panel_dp, tallest_band_dp) untuk foto menu landscape
    for png in photos:
        name = os.path.basename(png)
        logs, report = logs_of(png)
        dpr = float(report.get("devicePixelRatio", 0) or 0)
        fit = find(logs, "QA:MENU:FIT ")
        dump = find(logs, "QA:MENU:DUMP ")
        over = find(logs, "QA:MENU:OVERLAP ")
        scene = find(logs, "QA:MENU:SCENE ")
        step_line = find(logs, "QA:MENU:SHOWCASE step=")
        step = (kv(step_line, "step", str) or "").strip()
        gameplay = step == "load"          ## foto akhir = fase COMMAND
        im = Image.open(png)
        w, h = im.size

        if gameplay:
            check(f"{name}: fase COMMAND + HUD tanpa tumpuk (marker)",
                  kv(scene, "state", str) == "playing"
                  and kv(scene, "phase", str) == "COMMAND"
                  and find(logs, "QA:GAME:PHASE phase=COMMAND") != ""
                  and kv(find(logs, "QA:HUD:OVERLAP "), "count", int) == 0,
                  f"step=load scene={kv(scene,'state',str)} phase={kv(scene,'phase',str)} "
                  f"hud_overlap={kv(find(logs,'QA:HUD:OVERLAP '),'count',int)}")
            _, _, bands = band_extent_y(png, 0, w, 0, h, TEXT_THR, 2)
            gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
            scale = dpr / 2.0 or 1.0
            mg = (min(gaps) / scale) if gaps else 0.0
            check(f"{name}: HUD layar gameplay — teks banyak & tidak bertumpuk",
                  len(bands) >= 4 and mg >= 3.0,
                  f"bands={len(bands)} min_gap={mg:.1f}dp")
            continue

        if not (fit and dump and over and scene):
            check(f"{name}: marker menu lengkap", False,
                  "fit=%s dump=%s overlap=%s scene=%s"
                  % (bool(fit), bool(dump), bool(over), bool(scene)))
            continue

        # ---------------- A. marker runtime ----------------
        panel = kv(fit, "panel", str) or ""
        pw, ph = (float(v) for v in panel.split("x"))
        fit_ok = kv(fit, "fit", str) == "ok"
        credits_ok = kv(fit, "credits_fit", str) == "ok"
        side_dp = kv(fit, "side_dp", int)
        off_dp = kv(fit, "off_dp", float)
        dp_ok = (kv(dump, "primary_dp", int) == 56 and kv(dump, "secondary_dp", int) == 48)
        over_ok = kv(over, "count", int) == 0
        label_ok = find(logs, "QA:SCENE:LABEL_MENU state=hidden") != ""
        check(f"{name}: panel dari konten + standar dp + anti-tumpuk (marker)",
              fit_ok and credits_ok and dp_ok and over_ok and label_ok
              and side_dp is not None and side_dp >= 8 and off_dp == 16.0,
              f"fit={kv(fit,'fit',str)}/{kv(fit,'credits_fit',str)} panel={panel} "
              f"side_dp={side_dp} off_dp={off_dp} dp={kv(dump,'primary_dp',int)}/"
              f"{kv(dump,'secondary_dp',int)} overlap={kv(over,'count',int)} label={label_ok}")

        # ---------------- B. piksel ----------------
        rect = panel_rect_device(fit, dpr, (w, h))
        scale = dpr / 2.0
        if rect is None:
            check(f"{name}: rect panel dari marker", False, "off_dp/panel/avail hilang")
            continue
        logs_act = find(logs, "QA:MENU:ACTION action=credits visible=true")
        modal = find(logs, "QA:MENU:MODAL ")
        modal_open = (logs_act != "" and modal != ""
                      and kv(modal, "visible", str) == "true")
        ## Saat dialog terbuka, yang harus diperiksa = ISI DIALOG: panel di
        ## belakangnya memang digelapkan scrim (bukan cacat).
        roi = modal_rect_device(fit, dpr, (w, h)) if modal_open else rect
        if roi is None:
            roi = rect
        x0, y0, x1, y1 = roi
        top, bottom, bands = band_extent_y(png, x0, x1, y0, y1)
        gaps = [bands[i + 1][0] - bands[i][1] for i in range(len(bands) - 1)]
        mg = (min(gaps) / scale) if gaps else 0.0
        check(f"{name}: teks di dalam panel terpisah (anti-tumpuk piksel)",
              len(bands) >= 3 and mg >= 4.0,
              f"bands={len(bands)} min_gap={mg:.1f}dp rect=({x0:.0f},{y0:.0f})-({x1:.0f},{y1:.0f})")

        lo, hi = ink_extent_x(png, x0 - 30 * scale, x1 + 30 * scale, y0, y1)
        pads = {}
        if lo is not None and top is not None:
            pads = {"l": (lo - x0) / scale, "r": (x1 - hi) / scale,
                    "t": (top - y0) / scale, "b": (y1 - bottom) / scale}
            ok = all(v >= 8.0 for v in pads.values())
            ev = " ".join(f"pad_{k}={v:.1f}dp" for k, v in pads.items())
            check(f"{name}: tinta teks ≥8dp dari tiap tepi panel (padding)", ok, ev)
        else:
            check(f"{name}: tinta teks ≥8dp dari tiap tepi panel (padding)", False,
                  "tidak ada tinta teks terdeteksi di dalam panel")

        # --- modal KREDIT: permukaan opaque + scrim + padding bersih ---
        if modal_open:
            surf_a = kv(modal, "surface_alpha", float) or 0.0
            scrim = kv(modal, "scrim", str) == "true"
            check(f"{name}: permukaan modal opaque + scrim aktif (marker)",
                  surf_a >= 0.99 and scrim,
                  f"surface_alpha={surf_a} scrim={scrim} (temuan foto: teks panel "
                  f"menembus modal)")
            mrect = modal_rect_device(fit, dpr, (w, h))
            if mrect is not None:
                mx0, my0, mx1, my1 = mrect
                pads = {
                    "atas": (mx0 + 40 * scale, mx1 - 40 * scale, my0 + 4 * scale, my0 + 14 * scale),
                    "bawah": (mx0 + 40 * scale, mx1 - 40 * scale, my1 - 14 * scale, my1 - 4 * scale),
                    "kiri": (mx0 + 4 * scale, mx0 + 14 * scale, my0 + 40 * scale, my1 - 40 * scale),
                    "kanan": (mx1 - 14 * scale, mx1 - 4 * scale, my0 + 40 * scale, my1 - 40 * scale),
                }
                worst = max(max_luminance(png, r) for r in pads.values())
                check(f"{name}: area padding modal bersih (tidak ada tinta tembus)",
                      worst <= 60.0,
                      "max_luminance=%.0f di strip padding modal (modal %s)"
                      % (worst, kv(fit, "credits", str)))

        rows, widest = long_neutral_text_rows(png, rect)
        check(f"{name}: tidak ada label dunia 3D di luar panel",
              rows == 0,
              f"baris teks netral panjang di luar panel={rows} span_maks={widest}px "
              f"(label dunia = abu netral; bukti marker QA:SCENE:LABEL_MENU)")

        outside = count_bright_outside(png, rect)
        check(f"{name}: bersih di luar panel — label dunia/chrome tidak bocor",
              outside <= 20, f"piksel sangat terang di luar panel={outside}")

        if bands:
            if modal_open:
                check(f"{name}: aksi utama di bawah titik tengah (thumb zone)",
                      True, "dilewati — dialog tengah layar (standar Material); "
                            "scrim menutup panel di belakang")
            else:
                check(f"{name}: aksi utama di bawah titik tengah (thumb zone)",
                      (bottom + top) / 2.0 > h * 0.5,
                      f"tengah pita teks ({top}-{bottom}) dari h={h}")

        # lebar panel dalam dp harus sama di semua resolusi (komponen tidak
        # membesar mengikuti layar) — dikumpulkan untuk cek lintas-foto di bawah
        if "portrait" not in name and not modal_open:
            dp_land.append((name, step, pw / 2.0, kv(fit, "content", str) or "",
                            [(b[1] - b[0]) / scale for b in bands]))

    if len(dp_land) >= 2:
        ref_panel = dp_land[0][2]
        bad = [f"{n}:{p:.0f}dp" for n, _, p, _, _ in dp_land[1:] if abs(p - ref_panel) > 2.0]
        check("lebar panel identik dalam dp antar resolusi/dpr",
              not bad, f"{dp_land[0][0]}={ref_panel:.0f}dp | " +
              ", ".join(f"{p:.0f}dp" for _, _, p, _, _ in dp_land))
        ## Bandingkan foto step SAMA pada dpr berbeda (00 vs 01, 02 vs 03):
        ## (a) ukuran konten dari marker QA:MENU:FIT (design px) harus identik —
        ##     bukti komposisi dalam dp, bukan ikut membesar di layar besar;
        ## (b) baris teks TERATAS (judul panel) harus sama tinggi dalam dp
        ##     (pita lain bisa tersegmentasi beda antar dpr — bergantung
        ##     sampling, bukan cacat tata letak).
        by_step = {}
        for n, st, _p, content, bd in dp_land:
            by_step.setdefault(st, []).append((n, content, bd))
        pairs = [(st, v) for st, v in by_step.items() if len(v) >= 2]
        if not pairs:
            check("ukuran konten & teks konsisten dalam dp antar resolusi (step sama)",
                  False, "tidak ada pasangan step sama pada dpr berbeda")
        for st, v in pairs:
            (n0, c0, b0), (n1, c1, b1) = v[0], v[1]
            d0 = abs(b0[0] - b1[0]) if b0 and b1 else 0.0
            check(f"konten identik dalam dp antar resolusi (step={st or 'boot'})",
                  c0 == c1 and d0 <= 6.0,
                  f"content {c0} vs {c1} (design px) | baris teks teratas "
                  f"{b0[0]:.1f}dp vs {b1[0]:.1f}dp (selisih {d0:.1f}dp)")

    passed = sum(1 for r in results if r["ok"])
    failed = len(results) - passed
    print(f"\n== verify_menu: {passed} PASS / {failed} FAIL ({len(photos)} foto)")
    if out_path:
        json.dump({"passed": passed, "failed": failed, "results": results},
                  open(out_path, "w"), indent=1)
        print(f"   → {out_path}")
    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
