#!/usr/bin/env python3
"""make_sfx.py — bunyi UI prosedural M3 #5 (tanpa aset pihak ketiga).

Kenapa dibuat sendiri (bukan unduh): pipeline aset repo ini tidak memakai importer
Godot (build pck dibuat manual oleh tools/godot/make_pck.py tanpa editor), jadi
audio harus dapat dibangun RUNTIME: script ini menulis PCM 16-bit mono ke
`assets/audio/*.wav` (untuk didengar manusia) SEKALIGUS membenamkan base64 PCM ke
`game/assets/audio/sfx.json` (yang dibaca AudioSystem → AudioStreamWAV runtime,
pola sama dengan `game/assets/ui/icons.json`).

Sumber parameter (standar audio UI, bukan asumsi):
  · durasi klik UI 40–80 ms; nada pendek 600–1200 Hz (Material/HIG sound design)
  · konfirmasi = 2 nada naik (rising interval, "aksi diterima")
  · alarm = 2 denyut 440 Hz (nada peringatan konvensional), tidak >1 s (tidak
    mengganggu saat gelombang datang)
  · 22050 Hz mono 16-bit = cukup untuk SFX UI, ukuran kecil (mobile-first)

Usage: python3 tools/audio/make_sfx.py
"""
import base64
import json
import math
import os
import struct
import wave

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_WAV = os.path.join(REPO, "assets", "audio")
OUT_JSON = os.path.join(REPO, "game", "assets", "audio", "sfx.json")
RATE = 22050


def _env(i, n, attack=0.01, release=0.35):
    """Amplop linear attack/release (mencegah klik/pop di awal/akhir)."""
    a = max(1, int(n * attack))
    r = max(1, int(n * release))
    if i < a:
        return i / a
    if i > n - r:
        return max(0.0, (n - i) / r)
    return 1.0


def tone(freq, ms, vol=0.5, wave_fn=math.sin, decay=2.2):
    """Nada tunggal dengan decay eksponensial (terasa 'chip', bukan beep kasar)."""
    n = int(RATE * ms / 1000.0)
    out = []
    for i in range(n):
        t = i / RATE
        v = wave_fn(2 * math.pi * freq * t) * math.exp(-decay * t)
        out.append(v * vol * _env(i, n))
    return out


def silence(ms):
    return [0.0] * int(RATE * ms / 1000.0)


def square(x):
    return 1.0 if math.sin(x) >= 0 else -1.0


def mix(*parts):
    """Gabungkan beberapa potongan berurutan (bukan paralel)."""
    out = []
    for p in parts:
        out.extend(p)
    return out


def clip(samples, peak=0.92):
    m = max(1e-9, max(abs(s) for s in samples))
    k = peak / m if m > peak else 1.0
    return [s * k for s in samples]


def to_pcm16(samples):
    return b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)


SFX = {
    # klik UI: 55 ms, 900 Hz — di bawah ambang "mengganggu" saat tap cepat
    "ui_click": lambda: clip(mix(tone(900, 55, 0.45, decay=5.0))),
    # konfirmasi: dua nada naik 660 → 990 Hz (interval kuint, "berhasil")
    "ui_confirm": lambda: clip(mix(tone(660, 90, 0.5, decay=3.0),
                                   silence(8),
                                   tone(990, 130, 0.5, decay=2.6))),
    # batal/tutup: dua nada turun 520 → 330 Hz
    "ui_cancel": lambda: clip(mix(tone(520, 90, 0.45, decay=3.2),
                                  silence(8),
                                  tone(330, 140, 0.45, decay=2.6))),
    # alarm gelombang: 2 denyut 440 Hz (0,7 s total) — peringatan, tidak panjang
    "wave_alarm": lambda: clip(mix(tone(440, 150, 0.5, square, decay=1.2),
                                   silence(70),
                                   tone(440, 150, 0.5, square, decay=1.2),
                                   silence(70),
                                   tone(587, 220, 0.5, decay=1.6))),
}


def main():
    os.makedirs(OUT_WAV, exist_ok=True)
    os.makedirs(os.path.dirname(OUT_JSON), exist_ok=True)
    bank = {
        "system": "Last-Space SFX (prosedural, tools/audio/make_sfx.py)",
        "format": "pcm16",
        "mix_rate": RATE,
        "channels": 1,
        "sounds": {},
    }
    for name, fn in SFX.items():
        samples = fn()
        pcm = to_pcm16(samples)
        path = os.path.join(OUT_WAV, name + ".wav")
        with wave.open(path, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm)
        bank["sounds"][name] = {
            "data_b64": base64.b64encode(pcm).decode("ascii"),
            "frames": len(samples),
            "ms": round(len(samples) * 1000.0 / RATE, 1),
            "bytes": len(pcm),
        }
        print("SFX: %-12s %5.1f ms  %6d bytes -> %s" % (
            name, len(samples) * 1000.0 / RATE, len(pcm), path))
    with open(OUT_JSON, "w") as f:
        json.dump(bank, f, separators=(",", ":"))
    size = os.path.getsize(OUT_JSON)
    print("RUNTIME bank: %s (%d bytes, %d bunyi)" % (OUT_JSON, size, len(bank["sounds"])))


if __name__ == "__main__":
    main()
