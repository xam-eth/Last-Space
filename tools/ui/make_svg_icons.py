#!/usr/bin/env python3
"""make_svg_icons.py — SET IKON SVG ASLI untuk Last-Space (M3 #7).

Latar belakang (koreksi pemain 2026-10-13): "kamu masih pakai code semua icon
harusnya pakai svg real bukan code html". Sebelumnya ikon digambar oleh KODE
(PIL di `make_icons.py` → base64 PNG di `icons.json`, dan prompt rotasi ditulis
inline di HTML). Sekarang ikon adalah **berkas .svg nyata** (XML + path vektor)
yang dibaca apa adanya oleh game (Godot) dan halaman web — tidak ada ikon yang
digambar oleh kode saat runtime.

Struktur tiap berkas (viewBox 64×64, satu ikon per berkas):
  <svg viewBox="0 0 64 64">
    <defs><linearGradient id="bg">…</linearGradient></defs>
    <rect x="2" y="2" width="60" height="60" rx="14" fill="url(#bg)"
          stroke="#35d0ff" stroke-width="2.5"/>   ← badge (bahasa desain lama)
    …glyph vektor (path/rect/circle) warna #eaf6ff…
  </svg>

Glyph ditulis sebagai data path SVG (`d="…"`) — bukan digambar runtime.

Output (dua lokasi, satu sumber):
  assets/ui/icons/<id>.svg        → dipakai halaman web (loading/rotate prompt)
  game/assets/ui/icons/<id>.svg   → dipakai game (res://assets/ui/icons, di-PCK)

Usage: python3 tools/ui/make_svg_icons.py
"""

import os

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_ROOT = os.path.join(REPO, "assets", "ui", "icons")
OUT_GAME = os.path.join(REPO, "game", "assets", "ui", "icons")

ACCENT = "#35d0ff"
GLYPH = "#eaf6ff"
GLYPH_DIM = "#9fb6d8"

# --- glyph: data vektor per ikon (prime: di dalam kotak 64×64, area 10–54) ---
GLYPHS = {
    # resource / HUD
    "energy": '<path d="M36 10 L18 36 h10 l-4 18 L44 28 h-10 z" fill="{g}"/>',
    "minerals": '<path d="M32 12 L50 24 L44 50 H20 L14 24 z" fill="none" stroke="{g}" '
                'stroke-width="4" stroke-linejoin="round"/>'
                '<path d="M32 12 v38 M14 24 h36" stroke="{g}" stroke-width="3"/>',
    "fleet": '<path d="M32 10 L44 34 H20 z" fill="{g}"/>'
             '<path d="M20 34 h24 l-4 12 H24 z" fill="{g}" opacity="0.85"/>'
             '<path d="M28 46 h8 v8 h-8 z" fill="{g}" opacity="0.7"/>',
    "command": '<path d="M32 14 L50 24 v16 L32 50 L14 40 V24 z" fill="none" stroke="{g}" '
               'stroke-width="4" stroke-linejoin="round"/>'
               '<circle cx="32" cy="32" r="6" fill="{g}"/>',
    # bangunan
    "reactor": '<circle cx="32" cy="32" r="8" fill="{g}"/>'
               '<path d="M32 8 v10 M32 46 v10 M8 32 h10 M46 32 h10 M15 15 l7 7 M42 42 l7 7 '
               'M49 15 l-7 7 M22 42 l-7 7" stroke="{g}" stroke-width="4" stroke-linecap="round"/>',
    "extractor": '<path d="M14 48 h36" stroke="{g}" stroke-width="4" stroke-linecap="round"/>'
                 '<path d="M22 48 L32 16 L42 48" fill="none" stroke="{g}" stroke-width="4" '
                 'stroke-linejoin="round"/>'
                 '<path d="M26 34 h12" stroke="{g}" stroke-width="4"/>',
    "hangar": '<path d="M12 46 V26 L32 12 L52 26 v20 z" fill="none" stroke="{g}" '
              'stroke-width="4" stroke-linejoin="round"/>'
              '<path d="M24 46 V34 h16 v12" fill="none" stroke="{g}" stroke-width="4"/>',
    "turret": '<circle cx="32" cy="40" r="10" fill="none" stroke="{g}" stroke-width="4"/>'
              '<path d="M32 30 V14" stroke="{g}" stroke-width="6" stroke-linecap="round"/>'
              '<path d="M20 50 h24" stroke="{g}" stroke-width="4" stroke-linecap="round"/>',
    "shield": '<path d="M32 8 L50 16 v14 c0 12 -8 20 -18 26 C22 50 14 42 14 30 V16 z" '
              'fill="none" stroke="{g}" stroke-width="4" stroke-linejoin="round"/>'
              '<path d="M32 18 v20" stroke="{g}" stroke-width="3"/>',
    "interceptor": '<path d="M32 8 L38 30 h10 L40 38 l3 16 -11 -8 -11 8 3 -16 -8 -8 h10 z" '
                   'fill="{g}"/>',
    "fort": '<path d="M12 48 V24 l6 -8 6 8 8 -10 8 10 6 -8 6 8 v24 z" fill="none" '
            'stroke="{g}" stroke-width="4" stroke-linejoin="round"/>'
            '<path d="M12 48 h40" stroke="{g}" stroke-width="4"/>',
    "factory": '<path d="M12 48 V26 l12 8 v-8 l12 8 v-8 l12 8 v14 z" fill="none" stroke="{g}" '
               'stroke-width="4" stroke-linejoin="round"/>'
               '<path d="M20 14 h6 v8 h-6 z" fill="{g}"/>',
    # chrome / navigasi
    "menu": '<path d="M14 20 h36 M14 32 h36 M14 44 h36" stroke="{g}" stroke-width="6" '
            'stroke-linecap="round"/>',
    "build": '<path d="M22 46 L40 20" stroke="{g}" stroke-width="6" stroke-linecap="round"/>'
             '<path d="M38 18 l8 -6 4 6 -8 6 z" fill="{g}"/>'
             '<path d="M16 46 h12" stroke="{g}" stroke-width="6" stroke-linecap="round"/>',
    "close": '<path d="M19 19 L45 45 M45 19 L19 45" stroke="{g}" stroke-width="6" '
             'stroke-linecap="round"/>',
    "upgrade": '<path d="M32 48 V18" stroke="{g}" stroke-width="6" stroke-linecap="round"/>'
               '<path d="M20 30 L32 16 L44 30" fill="none" stroke="{g}" stroke-width="6" '
               'stroke-linecap="round" stroke-linejoin="round"/>',
    "grid": '<rect x="14" y="14" width="15" height="15" rx="3" fill="{g}"/>'
            '<rect x="35" y="14" width="15" height="15" rx="3" fill="{g}" opacity="0.75"/>'
            '<rect x="14" y="35" width="15" height="15" rx="3" fill="{g}" opacity="0.75"/>'
            '<rect x="35" y="35" width="15" height="15" rx="3" fill="{g}"/>',
    "crate": '<path d="M14 22 L32 12 L50 22 v20 L32 52 L14 42 z" fill="none" stroke="{g}" '
             'stroke-width="4" stroke-linejoin="round"/>'
             '<path d="M14 22 l18 10 18 -10 M32 32 v20" stroke="{g}" stroke-width="3"/>',
    "warning": '<path d="M32 12 L54 50 H10 z" fill="none" stroke="{g}" stroke-width="4" '
               'stroke-linejoin="round"/>'
               '<path d="M32 26 v12" stroke="{g}" stroke-width="5" stroke-linecap="round"/>'
               '<circle cx="32" cy="44" r="3" fill="{g}"/>',
    "quest": '<path d="M16 12 h26 l8 8 v32 H16 z" fill="none" stroke="{g}" stroke-width="4" '
             'stroke-linejoin="round"/>'
             '<path d="M23 26 h18 M23 36 h18 M23 44 h10" stroke="{g}" stroke-width="3.5" '
             'stroke-linecap="round"/>',
    "info": '<circle cx="32" cy="32" r="20" fill="none" stroke="{g}" stroke-width="4"/>'
            '<path d="M32 28 v14" stroke="{g}" stroke-width="5" stroke-linecap="round"/>'
            '<circle cx="32" cy="21" r="3" fill="{g}"/>',
    "lock": '<rect x="18" y="28" width="28" height="22" rx="4" fill="none" stroke="{g}" '
            'stroke-width="4"/>'
            '<path d="M24 28 v-6 a8 8 0 0 1 16 0 v6" fill="none" stroke="{g}" stroke-width="4"/>'
            '<circle cx="32" cy="39" r="3" fill="{g}"/>',
    # setelan / kamera / kontrol baru (M3 #5/#6/#7)
    "settings": '<circle cx="32" cy="32" r="7" fill="none" stroke="{g}" stroke-width="4"/>'
                '<path d="M32 10 v6 M32 48 v6 M10 32 h6 M48 32 h6 M17 17 l4 4 M43 43 l4 4 '
                'M47 17 l-4 4 M21 43 l-4 4" stroke="{g}" stroke-width="4" '
                'stroke-linecap="round"/>',
    "play": '<path d="M22 14 L50 32 L22 50 z" fill="{g}"/>',
    "plus": '<path d="M32 16 v32 M16 32 h32" stroke="{g}" stroke-width="6" '
            'stroke-linecap="round"/>',
    "minus": '<path d="M16 32 h32" stroke="{g}" stroke-width="6" stroke-linecap="round"/>',
    "reset": '<path d="M18 32 a14 14 0 1 0 5 -11" fill="none" stroke="{g}" stroke-width="4" '
             'stroke-linecap="round"/>'
             '<path d="M14 14 v9 h9" fill="none" stroke="{g}" stroke-width="4" '
             'stroke-linecap="round" stroke-linejoin="round"/>',
    "planet": '<circle cx="32" cy="32" r="16" fill="none" stroke="{g}" stroke-width="4"/>'
              '<path d="M8 38 c14 8 34 6 48 -6" fill="none" stroke="{g}" stroke-width="3"/>'
              '<circle cx="26" cy="26" r="4" fill="{g}" opacity="0.7"/>',
    "check": '<path d="M16 34 l10 10 22 -24" fill="none" stroke="{g}" stroke-width="6" '
             'stroke-linecap="round" stroke-linejoin="round"/>',
    "timer": '<circle cx="32" cy="34" r="18" fill="none" stroke="{g}" stroke-width="4"/>'
             '<path d="M32 22 v12 l9 6" fill="none" stroke="{g}" stroke-width="4" '
             'stroke-linecap="round"/>'
             '<path d="M26 10 h12" stroke="{g}" stroke-width="4" stroke-linecap="round"/>',
    "crosshair": '<circle cx="32" cy="32" r="14" fill="none" stroke="{g}" stroke-width="4"/>'
                 '<path d="M32 10 v8 M32 46 v8 M10 32 h8 M46 32 h8" stroke="{g}" '
                 'stroke-width="4" stroke-linecap="round"/>'
                 '<circle cx="32" cy="32" r="3" fill="{g}"/>',
    "home": '<path d="M12 32 L32 14 L52 32" fill="none" stroke="{g}" stroke-width="5" '
            'stroke-linecap="round" stroke-linejoin="round"/>'
            '<path d="M18 32 v18 h28 V32" fill="none" stroke="{g}" stroke-width="5" '
            'stroke-linejoin="round"/>',
    "rotate": '<rect x="12" y="18" width="18" height="32" rx="4" fill="none" stroke="{g}" '
              'stroke-width="4"/>'
              '<rect x="34" y="24" width="30" height="20" rx="4" fill="none" stroke="{g}" '
              'stroke-width="4"/>'
              '<path d="M22 52 a12 12 0 1 0 8 -22" fill="none" stroke="{g}" stroke-width="3" '
              'stroke-linecap="round"/>'
              '<path d="M26 26 l4 4 -4 4" fill="none" stroke="{g}" stroke-width="3" '
              'stroke-linecap="round" stroke-linejoin="round"/>',
}

TEMPLATE = """<?xml version="1.0" encoding="UTF-8"?>
<!-- Last-Space icon set — SVG asli (vektor). Sumber: tools/ui/make_svg_icons.py.
     Dipakai game (res://assets/ui/icons/) dan halaman web (assets/ui/icons/). -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"
     role="img" aria-label="{label}">
  <title>{label}</title>
  <defs>
    <linearGradient id="badge" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#16213f"/>
      <stop offset="1" stop-color="#0a1020"/>
    </linearGradient>
  </defs>
  <rect x="2" y="2" width="60" height="60" rx="14" fill="url(#badge)"
        stroke="{accent}" stroke-width="2.5"/>
  {glyph}
</svg>
"""

LABELS = {
    "energy": "Energi", "minerals": "Mineral", "fleet": "Armada",
    "command": "Pusat Komando", "reactor": "Reaktor Energi",
    "extractor": "Ekstraktor Mineral", "hangar": "Hanggar Pesawat",
    "turret": "Menara Laser", "shield": "Generator Perisai",
    "interceptor": "Interceptor", "fort": "Benteng", "factory": "Pabrik",
    "menu": "Menu", "build": "Bangun", "close": "Tutup", "upgrade": "Tingkatkan",
    "grid": "Kategori", "crate": "Sumber Daya", "warning": "Peringatan",
    "quest": "Objektif", "info": "Info", "lock": "Terkunci",
    "settings": "Pengaturan", "play": "Mulai", "plus": "Perbesar",
    "minus": "Perkecil", "reset": "Reset", "planet": "Planet", "check": "Selesai",
    "timer": "Waktu", "crosshair": "Pilih Sasaran", "home": "Pangkalan",
    "rotate": "Putar perangkat",
}


def build_svg(icon_id):
    glyph = GLYPHS[icon_id].format(g=GLYPH, d=GLYPH_DIM)
    return TEMPLATE.format(label=LABELS.get(icon_id, icon_id), accent=ACCENT, glyph=glyph)


def main():
    for d in (OUT_ROOT, OUT_GAME):
        os.makedirs(d, exist_ok=True)
    total = 0
    for icon_id in sorted(GLYPHS):
        svg = build_svg(icon_id)
        for d in (OUT_ROOT, OUT_GAME):
            with open(os.path.join(d, "%s.svg" % icon_id), "w", encoding="utf-8") as f:
                f.write(svg)
        total += len(svg)
    print("SVG icons: %d berkas × 2 lokasi (%s, %s) — total markup %d B" % (
        len(GLYPHS), OUT_ROOT, OUT_GAME, total))
    print("ids: %s" % " ".join(sorted(GLYPHS)))


if __name__ == "__main__":
    main()
