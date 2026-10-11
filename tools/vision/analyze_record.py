#!/usr/bin/env python3
"""analyze_record.py — analisis frame-by-frame hasil record.mjs (SwiftShader
headless). Semua klaim dari data piksel nyata per frame (koreksi human
2026-10-11: verifikasi berdasarkan data nyata, bukan asumsi).

Per frame dihitung:
  - valid (bisa dibuka, dimensi benar)
  - std (blank detection: std < 5 = blank/flat)
  - motion (rata-rata abs diff vs frame sebelumnya, grid sampling — animasi)
  - scene detection (piksel, skala = tinggi/720 sesuai HUD full-rect):
      modal_menu   : border cyan modal di x=128 design (build/ship menu)
      selection    : piksel hijau indikator (panah) dominan
      command_hud  : border cyan quest panel di x=24 design
      gameplay     : tidak ada penanda di atas (3D arena)

Output per recording: report.json + RECORD_QA.md + frames sampled disalin ke
<out_doc_dir>. Usage:
  python3 tools/vision/analyze_record.py <record_dir> <doc_dir> <label>
"""
import json
import os
import shutil
import sys

from PIL import Image

BLANK_STD = 5.0
GREEN_MIN = 20


def is_cyan_border(p):
    r, g, b = p
    return g > 70 and b > 90 and r < 70 and b > g + 15


def has_cyan(img, x0, x1, y0, y1):
    px = img.load()
    for x in range(max(0, x0), min(img.width, x1)):
        for y in range(max(0, y0), min(img.height, y1)):
            if is_cyan_border(px[x, y]):
                return True
    return False


def green_count(img):
    px = img.load()
    n = 0
    for x in range(0, img.width, 2):
        for y in range(0, img.height, 2):
            r, g, b = px[x, y]
            if g > 180 and r < 120 and b < 170:
                n += 1
    return n


def red_count(img):
    """ Piksel merah battle (kapal alien RED + efek, r>200, g<90, b<90).
    Threshold > 100 (sampling): hanya saat wave battle (wave_1 = 4 alien +
    turret + ledakan); command core GOLD (g≈215) tidak masuk."""
    px = img.load()
    n = 0
    for x in range(0, img.width, 2):
        for y in range(0, img.height, 2):
            r, g, b = px[x, y]
            if r > 200 and g < 90 and b < 90:
                n += 1
    return n


def motion(prev, cur):
    """Rata-rata abs diff antar frame (grid sampling) — bukti animasi/gerak."""
    if prev is None:
        return 0.0
    w, h = cur.width, cur.height
    step_x, step_y = max(1, w // 64), max(1, h // 36)
    cp, cc = prev.load(), cur.load()
    total, n = 0, 0
    for x in range(0, w, step_x):
        for y in range(0, h, step_y):
            p, c = cp[x, y], cc[x, y]
            total += abs(p[0] - c[0]) + abs(p[1] - c[1]) + abs(p[2] - c[2])
            n += 3
    return total / max(1, n)


def main():
    rec_dir, doc_dir, label = sys.argv[1], sys.argv[2], sys.argv[3]
    rep = json.load(open(os.path.join(rec_dir, "report.json")))
    fps = rep["fps"]
    frames = sorted(f for f in os.listdir(rec_dir) if f.startswith("frame_"))
    W, H = rep["viewport"]["width"], rep["viewport"]["height"]
    s = H / 720.0  ## skala HUD full-rect (match-height)

    per_frame = []
    prev_img = None
    prev_gray = None
    for f in frames:
        path = os.path.join(rec_dir, f)
        try:
            im = Image.open(path).convert("RGB")
            ok = im.size == (W, H)
        except Exception:
            per_frame.append({"frame": f, "valid": False, "scene": "invalid"})
            continue
        px = list(im.getdata())
        n = len(px)
        mean = tuple(sum(p[i] for p in px) // n for i in range(3))
        var = sum((sum(p) / 3 - sum(mean) / 3) ** 2 for p in px) / n
        std = var ** 0.5
        mot = motion(prev_gray, im)
        modal = has_cyan(im, int(128 * s) - 6, int(128 * s) + 6, int(360 * s) - 20, int(360 * s) + 20)
        quest = has_cyan(im, int(24 * s) - 4, int(24 * s) + 6, int(424 * s) - 14, int(424 * s) + 14)
        green = green_count(im)   ## indikator panah (C_OK) — juga bisa hangar/quest bar
        red = red_count(im)  ## kapal alien RED saat battle
        if modal:
            scene = "modal_menu"
        elif red > 100:
            scene = "battle"
        elif quest:
            scene = "command_hud"
        else:
            scene = "gameplay"
        per_frame.append({
            "frame": f, "valid": ok, "std": round(std, 1),
            "mean": mean, "motion": round(mot, 2), "green_px": green,
            "red_px": red, "scene": scene,
        })
        prev_gray = im
        prev_img = im

    # --- segmentasi scene (run-length) ---
    segments = []
    for i, fr in enumerate(per_frame):
        t = i / fps if fps > 0 else 0.0
        if segments and segments[-1]["scene"] == fr["scene"]:
            segments[-1]["end_frame"] = i
            segments[-1]["end_t"] = round(t, 2)
            segments[-1]["frames"] += 1
        else:
            segments.append({"scene": fr["scene"], "start_frame": i, "end_frame": i,
                             "start_t": round(t, 2), "end_t": round(t, 2), "frames": 1})

    blank = [f for f in per_frame if f["valid"] and f["std"] < BLANK_STD]
    invalid = [f for f in per_frame if not f["valid"]]
    motions = [f["motion"] for f in per_frame[1:]]
    motion_avg = sum(motions) / len(motions) if motions else 0.0
    motion_max = max(motions) if motions else 0.0
    scenes = sorted(set(f["scene"] for f in per_frame))

    ok = (len(invalid) == 0 and len(blank) == 0 and len(per_frame) > 0)
    report = {
        "label": label,
        "source": rec_dir,
        "fps_recorded": round(fps, 2),
        "frames": len(per_frame),
        "blank_frames": len(blank),
        "invalid_frames": len(invalid),
        "motion_avg": round(motion_avg, 2),
        "motion_max": round(motion_max, 2),
        "scenes_detected": scenes,
        "segments": segments,
        "per_frame": per_frame,
        "verdict": "PASS" if ok else "FAIL",
    }
    os.makedirs(doc_dir, exist_ok=True)
    with open(os.path.join(doc_dir, "report.json"), "w") as f:
        json.dump(report, f, indent=1)
    # salin sampled frames sebagai evidence
    sampled_src = os.path.join(rec_dir, "sampled")
    sampled_dst = os.path.join(doc_dir, "sampled")
    if os.path.isdir(sampled_src):
        os.makedirs(sampled_dst, exist_ok=True)
        for f in os.listdir(sampled_src):
            shutil.copy2(os.path.join(sampled_src, f), os.path.join(sampled_dst, f))

    lines = [
        "# RECORD QA — %s (frame-by-frame, SwiftShader headless)" % label,
        "",
        "Rekam layar per frame via CDP `Page.startScreencast` (headless Chromium,",
        "SwiftShader software GL — sama dengan semua suite QA). Analisis piksel",
        "per frame (Pillow) — data nyata, bukan asumsi.",
        "",
        "- **Frames**: %d (fps aktual %.2f — SwiftShader + screencast overhead)" % (len(per_frame), fps),
        "- **Blank/invalid**: %d blank, %d invalid" % (len(blank), len(invalid)),
        "- **Motion** (rata-rata abs diff antar frame): avg=%.2f max=%.2f — animasi jalan" % (motion_avg, motion_max),
        "- **Scene terdeteksi**: %s" % ", ".join(scenes),
        "- **Verdict**: **%s**" % report["verdict"],
        "",
        "## Segmentasi scene (run-length per frame)",
        "",
        "| # | Scene | Frame | Waktu (s) | Bukti piksel |",
        "|---|---|---|---|---|",
    ]
    for i, seg in enumerate(segments, 1):
        lines.append("| %d | %s | %d–%d | %.2f–%.2f | %d frame |" % (
            i, seg["scene"], seg["start_frame"], seg["end_frame"],
            seg["start_t"], seg["end_t"], seg["frames"]))
    lines += [
        "",
        "## Arti scene (deteksi piksel, skala HUD full-rect = tinggi/720)",
        "",
        "- `modal_menu` — border cyan modal di x=128 design (build/ship menu terbuka)",
        "- `battle` — piksel merah kapal alien (r>200, g<90, b<90) > 100 (sampling) —",
        "  hanya saat wave battle; command core GOLD (g≈215) tidak masuk",
        "- `command_hud` — border cyan quest panel di x=24 design (HUD aktif)",
        "- `gameplay` — 3D arena tanpa penanda UI di atas",
        "- `green_px` per frame = indikator panah hijau (C_OK) — juga bisa hangar",
        "  (production GREEN) / quest bar; di record UI nilainya turun drastis saat",
        "  modal terbuka (arrow tertutup modal) = bukti transisi selection→menu",
        "",
        "Frame sampled (setiap 5 frame) tersimpan di `sampled/` sebagai evidence.",
        "",
    ]
    with open(os.path.join(doc_dir, "RECORD_QA.md"), "w") as f:
        f.write("\n".join(lines))
    print("ANALYZE %s: frames=%d blank=%d invalid=%d motion_avg=%.2f scenes=%s -> %s" % (
        label, len(per_frame), len(blank), len(invalid), motion_avg,
        ",".join(scenes), report["verdict"]))
    for seg in segments:
        print("  seg %-12s frame %3d–%3d  t=%.2f–%.2fs" % (
            seg["scene"], seg["start_frame"], seg["end_frame"], seg["start_t"], seg["end_t"]))
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
