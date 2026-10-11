#!/usr/bin/env python3
"""make_icons.py — icon design system HUD Last-Space (mobile-first landscape).

Mengikuti UI_UX_DESIGN.md §5 (Icon Design System) dan referensi eksternal:
- Retrostyle Games — "legible even at 32 pixels", satu simbol, high contrast
  (https://retrostylegames.com/blog/how-to-design-a-cool-app-icon-for-your-games/)
- CrazyOyster — satu simbol, satu focus point, warna kontras tinggi
  (https://crazyoystergames.com/blog/how-to-design-a-great-icon-for-a-mobile-game/)
- iStock — gaya badge rounded-square glossy untuk tombol UI game mobile
  (https://www.istockphoto.com/illustrations/buttons-and-icons-set-for-mobile-app-and-game-ui)

 Spesifikasi:
- Kanvas 1024×1024 → export 256×256 PNG (power-of-two, untuk Godot TextureButton)
- Badge: rounded-square (radius ~18%), gradient vertikal dark navy, outline
  ganda (dark luar + aksen cyan dalam), gloss highlight atas
- Glyph: satu simbol, near-white dengan shadow, kontras tinggi
- Warna aksen: cyan #35d0ff (faction), glyph #eaf6ff

Output:
- assets/ui/icons/<id>.png (12 ikon, source — untuk import via editor)
- game/assets/ui/icons.json (runtime: semua ikon embedded base64 — build wasm
  tidak punya loader .png saat runtime, decode via Image.load_png_from_buffer)

Usage: python3 tools/ui/make_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT_DIR = os.path.join(REPO, "assets", "ui", "icons")          # source PNG
RUNTIME_JSON = os.path.join(REPO, "game", "assets", "ui", "icons.json")  # runtime (base64)

S = 1024          # kanvas sumber
OUT = 256         # ukuran export
BADGE_M = 36      # margin badge
BADGE_R = 190     # radius rounded-square

# palet (UI_UX_DESIGN.md §3.1 + aksen mobile)
C_TOP = (30, 48, 82)       # gradient atas badge
C_BOT = (9, 14, 30)        # gradient bawah badge
C_OUTER = (4, 6, 14)       # outline luar (dark)
C_RIM = (53, 208, 255)     # rim aksen cyan
C_GLYPH = (234, 246, 255)  # glyph near-white
C_SHADOW = (3, 5, 12)      # shadow glyph


def _badge(img: Image.Image) -> None:
    """Rounded-square glossy badge + outline ganda."""
    d = ImageDraw.Draw(img)
    box = [BADGE_M, BADGE_M, S - BADGE_M, S - BADGE_M]
    # outline luar (dark, tebal)
    d.rounded_rectangle(box, radius=BADGE_R + 10, fill=None, outline=C_OUTER, width=26)
    # fill gradient vertikal
    grad = Image.new("RGB", (S, S))
    gd = ImageDraw.Draw(grad)
    for y in range(S):
        t = y / S
        c = tuple(int(C_TOP[i] + (C_BOT[i] - C_TOP[i]) * t) for i in range(3))
        gd.line([(0, y), (S, y)], fill=c)
    # terapkan gradient hanya di dalam badge (mask rounded rect)
    mask = Image.new("L", (S, S), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle(box, radius=BADGE_R, fill=255)
    img.paste(grad, (0, 0), mask)
    # rim aksen cyan (dalam)
    d.rounded_rectangle(box, radius=BADGE_R, fill=None, outline=C_RIM, width=8)
    # gloss highlight (band atas, lembut)
    gloss = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    gld = ImageDraw.Draw(gloss)
    gld.rounded_rectangle([BADGE_M, BADGE_M, S - BADGE_M, S // 2 + 60],
                          radius=BADGE_R, fill=(255, 255, 255, 46))
    gloss = gloss.filter(ImageFilter.GaussianBlur(28))
    img.paste(gloss, (0, 0), Image.composite(gloss, Image.new("L", (S, S), 0), mask))


def _layer() -> Image.Image:
    return Image.new("RGBA", (S, S), (0, 0, 0, 0))


def _paste_glyph(img: Image.Image, glyph: Image.Image) -> None:
    """Tempel glyph dengan shadow offset (kontras di atas badge)."""
    mask = glyph.split()[3]
    solid_shadow = Image.new("RGBA", (S, S), C_SHADOW + (255,))
    img.paste(solid_shadow, (10, 14), mask)
    img.paste(glyph, (0, 0), glyph)


def _poly(d: ImageDraw.ImageDraw, pts, fill=C_GLYPH, outline=None, width=0):
    d.polygon(pts, fill=fill, outline=outline, width=width)


def _star_points(cx, cy, r_out, r_in, n=5, rot=-math.pi / 2):
    pts = []
    for i in range(2 * n):
        r = r_out if i % 2 == 0 else r_in
        a = rot + i * math.pi / n
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# ---------------------------------------------------------------- glyphs ----
def g_bolt(d):
    _poly(d, [(0.56, 0.10), (0.34, 0.56), (0.50, 0.56), (0.42, 0.90),
              (0.70, 0.42), (0.53, 0.42), (0.64, 0.10)])


def g_crystal(d):
    _poly(d, [(0.50, 0.10), (0.78, 0.38), (0.66, 0.90), (0.34, 0.90), (0.22, 0.38)])
    d.line([(0.50, 0.10), (0.50, 0.90)], fill=C_GLYPH, width=10)
    d.line([(0.22, 0.38), (0.78, 0.38)], fill=C_GLYPH, width=10)


def g_ship(d):
    _poly(d, [(0.50, 0.08), (0.62, 0.34), (0.60, 0.86), (0.40, 0.86), (0.38, 0.34)])
    d.line([(0.50, 0.08), (0.50, 0.86)], fill=C_GLYPH, width=8)


def g_star(d):
    pts = _star_points(0.50, 0.52, 0.42, 0.18)
    _poly(d, pts)


def g_atom_full(img):
    cx, cy, r = 0.50 * S, 0.50 * S, 0.36 * S
    acc = _layer()
    for angle in (0, 60, 120):
        layer = _layer()
        ld = ImageDraw.Draw(layer)
        ld.ellipse([cx - r, cy - r * 0.36, cx + r, cy + r * 0.36],
                   outline=C_GLYPH, width=16)
        layer = layer.rotate(angle, center=(cx, cy), resample=Image.BICUBIC)
        acc.paste(layer, (0, 0), layer)
    ld = ImageDraw.Draw(acc)
    ld.ellipse([cx - 0.07 * S, cy - 0.07 * S, cx + 0.07 * S, cy + 0.07 * S], fill=C_GLYPH)
    return acc


def g_pickaxe(img):
    layer = _layer()
    d = ImageDraw.Draw(layer)
    # handle
    d.line([(0.30 * S, 0.82 * S), (0.66 * S, 0.34 * S)], fill=C_GLYPH, width=22)
    # head (busur melengkung)
    d.arc([0.30 * S, 0.10 * S, 0.86 * S, 0.56 * S], start=200, end=340, fill=C_GLYPH, width=22)
    return layer


def g_hangar(d):
    # badan hanggar
    d.rectangle([0.18, 0.42, 0.82, 0.86], outline=C_GLYPH, width=4)
    # atap
    _poly(d, [(0.12, 0.42), (0.50, 0.14), (0.88, 0.42)],
          fill=None, outline=C_GLYPH, width=4)
    # pintu (garis vertikal)
    for f in (0.34, 0.50, 0.66):
        d.line([(f, 0.52), (f, 0.86)], fill=C_GLYPH, width=2)


def g_cannon(img):
    layer = _layer()
    d = ImageDraw.Draw(layer)
    # roda
    d.ellipse([0.24 * S, 0.62 * S, 0.52 * S, 0.90 * S], outline=C_GLYPH, width=16)
    # laras (kotak panjang diputar)
    barrel = _layer()
    bd = ImageDraw.Draw(barrel)
    bd.rectangle([0.0, 0.44 * S, 0.95 * S, 0.56 * S], fill=C_GLYPH)
    barrel = barrel.rotate(-28, center=(0.42 * S, 0.50 * S), resample=Image.BICUBIC)
    layer.paste(barrel, (0, 0), barrel)
    # pangkal laras
    d.rectangle([0.34 * S, 0.44 * S, 0.56 * S, 0.66 * S], fill=C_GLYPH)
    return layer


def g_shield(d):
    _poly(d, [(0.50, 0.10), (0.84, 0.24), (0.84, 0.56), (0.50, 0.90), (0.16, 0.56),
              (0.16, 0.24)], outline=C_GLYPH, width=16)
    _poly(d, [(0.50, 0.30), (0.66, 0.38), (0.66, 0.54), (0.50, 0.70), (0.34, 0.54),
              (0.34, 0.38)])


def g_jet(d):
    # delta jet: badan + sayap
    _poly(d, [(0.50, 0.08), (0.58, 0.30), (0.88, 0.66), (0.62, 0.62), (0.56, 0.90),
              (0.44, 0.90), (0.38, 0.62), (0.12, 0.66), (0.42, 0.30)])


def g_gear(img):
    layer = _layer()
    d = ImageDraw.Draw(layer)
    cx, cy = 0.50 * S, 0.50 * S
    # gigi (8 kotak diputar)
    for i in range(8):
        tooth = _layer()
        td = ImageDraw.Draw(tooth)
        td.rectangle([cx - 0.055 * S, cy - 0.46 * S, cx + 0.055 * S, cy - 0.30 * S], fill=C_GLYPH)
        tooth = tooth.rotate(i * 45, center=(cx, cy), resample=Image.BICUBIC)
        layer.paste(tooth, (0, 0), tooth)
    # cakram + lubang
    d.ellipse([cx - 0.34 * S, cy - 0.34 * S, cx + 0.34 * S, cy + 0.34 * S], fill=C_GLYPH)
    d.ellipse([cx - 0.14 * S, cy - 0.14 * S, cx + 0.14 * S, cy + 0.14 * S], fill=C_BOT)
    return layer


def g_warning(d):
    _poly(d, [(0.50, 0.12), (0.90, 0.84), (0.10, 0.84)], outline=C_GLYPH, width=18)
    d.rectangle([0.46 * S, 0.38 * S, 0.54 * S, 0.62 * S], fill=C_GLYPH)
    d.ellipse([0.455 * S, 0.70 * S, 0.545 * S, 0.78 * S], fill=C_GLYPH)


# --- M3 #1: ikon UI baru (build menu, selection, quest panel) ---
def g_hammer(img):
    """Build — palu (konstruksi)."""
    layer = _layer()
    d = ImageDraw.Draw(layer)
    d.line([(0.26 * S, 0.88 * S), (0.60 * S, 0.38 * S)], fill=C_GLYPH, width=28)
    head = _layer()
    hd = ImageDraw.Draw(head)
    hd.rectangle([0.0, 0.16 * S, 0.52 * S, 0.40 * S], fill=C_GLYPH)
    head = head.rotate(-45, center=(0.26 * S, 0.28 * S), resample=Image.BICUBIC)
    layer.paste(head, (0, 0), head)
    return layer


def g_close(d):
    """Close — tanda silang (X)."""
    d.line([(0.24, 0.24), (0.76, 0.76)], fill=C_GLYPH, width=26)
    d.line([(0.76, 0.24), (0.24, 0.76)], fill=C_GLYPH, width=26)


def g_upgrade(d):
    """Upgrade — panah ke atas."""
    _poly(d, [(0.50, 0.12), (0.86, 0.48), (0.66, 0.48), (0.66, 0.88),
              (0.34, 0.88), (0.34, 0.48), (0.14, 0.48)])


def g_quest(d):
    """Quest — target (dua lingkaran + titik tengah)."""
    d.ellipse([0.20, 0.20, 0.80, 0.80], outline=C_GLYPH, width=10)
    d.ellipse([0.40, 0.40, 0.60, 0.60], outline=C_GLYPH, width=8)
    d.ellipse([0.46, 0.46, 0.54, 0.54], fill=C_GLYPH)


def g_info(d):
    """Info — huruf 'i' (titik + batang)."""
    d.ellipse([0.43, 0.16, 0.57, 0.30], fill=C_GLYPH)
    d.rectangle([0.43, 0.38, 0.57, 0.86], fill=C_GLYPH)


# name → (glyph drawer, butuh layer penuh)
ICONS = {
    "energy": lambda img: _paste_glyph(img, _draw_simple(g_bolt)),
    "minerals": lambda img: _paste_glyph(img, _draw_simple(g_crystal)),
    "fleet": lambda img: _paste_glyph(img, _draw_simple(g_ship)),
    "command": lambda img: _paste_glyph(img, _draw_simple(g_star)),
    "reactor": lambda img: _paste_glyph(img, g_atom_full(img)),
    "extractor": lambda img: _paste_glyph(img, g_pickaxe(img)),
    "hangar": lambda img: _paste_glyph(img, _draw_simple(g_hangar)),
    "turret": lambda img: _paste_glyph(img, g_cannon(img)),
    "shield": lambda img: _paste_glyph(img, _draw_simple(g_shield)),
    "interceptor": lambda img: _paste_glyph(img, _draw_simple(g_jet)),
    "menu": lambda img: _paste_glyph(img, g_gear(img)),
    "warning": lambda img: _paste_glyph(img, _draw_simple(g_warning)),
    # M3 #1 — build menu + building selection + quest panel
    "build": lambda img: _paste_glyph(img, g_hammer(img)),
    "close": lambda img: _paste_glyph(img, _draw_simple(g_close)),
    "upgrade": lambda img: _paste_glyph(img, _draw_simple(g_upgrade)),
    "quest": lambda img: _paste_glyph(img, _draw_simple(g_quest)),
    "info": lambda img: _paste_glyph(img, _draw_simple(g_info)),
}


def _draw_simple(fn) -> Image.Image:
    """Gambar glyph sederhana (langsung di layer dengan koordinat relatif)."""
    layer = _layer()
    d = ImageDraw.Draw(layer)
    # gambar dalam koordinat relatif 0..1 via transform: gambar di kanvas kecil lalu scale
    small = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    sd = ImageDraw.Draw(small)

    class _ScaledDraw:
        """Proxy: gambar dengan koordinat 0..1 → diskalakan ke 256."""
        def __init__(self, draw):
            self._d = draw
        def polygon(self, pts, **kw):
            self._d.polygon([(x * 256, y * 256) for x, y in pts], **kw)
        def line(self, pts, **kw):
            self._d.line([(x * 256, y * 256) for x, y in pts], **kw)
        def rectangle(self, box, **kw):
            self._d.rectangle([box[0] * 256, box[1] * 256, box[2] * 256, box[3] * 256], **kw)
        def ellipse(self, box, **kw):
            self._d.ellipse([box[0] * 256, box[1] * 256, box[2] * 256, box[3] * 256], **kw)
        def arc(self, box, **kw):
            self._d.arc([box[0] * 256, box[1] * 256, box[2] * 256, box[3] * 256], **kw)

    fn(_ScaledDraw(sd))
    return small.resize((S, S), Image.LANCZOS)


def main() -> None:
    import base64
    import json
    os.makedirs(OUT_DIR, exist_ok=True)
    runtime = {}
    for name, fn in ICONS.items():
        img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
        _badge(img)
        fn(img)
        out = img.resize((OUT, OUT), Image.LANCZOS)
        path = os.path.join(OUT_DIR, "%s.png" % name)
        out.save(path)
        # simpan juga sebagai base64 PNG untuk runtime (wasm tanpa loader .png)
        import io
        buf = io.BytesIO()
        out.save(buf, format="PNG")
        runtime[name] = base64.b64encode(buf.getvalue()).decode("ascii")
        print("ICON: %s -> %s (%d bytes)" % (name, path, os.path.getsize(path)))
    doc = {
        "system": "last-space icon design system (UI_UX_DESIGN.md §5)",
        "size": OUT,
        "icons": runtime,
    }
    os.makedirs(os.path.dirname(RUNTIME_JSON), exist_ok=True)
    with open(RUNTIME_JSON, "w") as f:
        json.dump(doc, f, separators=(",", ":"))
    print("ICON: runtime icons.json -> %s (%d bytes, %d ikon)" % (
        RUNTIME_JSON, os.path.getsize(RUNTIME_JSON), len(runtime)))


if __name__ == "__main__":
    main()
