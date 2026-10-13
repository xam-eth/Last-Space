class_name UiTheme
extends RefCounted
## UiTheme — token design-system bersama (M3 #4).
##
## Satu sumber warna, radius, margin & gaya tombol supaya layar baru tidak
## menyalin konstanta (kritik user M3.6: "component design system kurang tepat").
## Nilai mengikuti palet UI_UX_DESIGN.md §3.1 yang sudah dipakai HUD/build/ship/
## pause (angka identik) → layar baru konsisten dengan layar lama.
##
## Ukuran (dp; design px = dp × 2 pada scale = dpr/2, UI_UX_DESIGN.md §3):
##   margin 16dp · gap 8dp · radius 12dp · border 1dp · type ≥ 11dp
##   tombol utama 56dp, sekunder 48dp (touch target minimum Material)

# ---------------------------------------------------------------- warna ----
const C_PANEL := Color(0.043, 0.063, 0.125, 0.92)
const C_CARD := Color(0.055, 0.082, 0.16, 0.90)
const C_BORDER := Color(0.208, 0.816, 1.0, 0.55)
const C_BORDER_SEL := Color(0.208, 0.816, 1.0, 1.0)
const C_TEXT := Color(0.918, 0.965, 1.0, 1.0)
const C_MUTED := Color(0.62, 0.70, 0.80, 1.0)
const C_ACCENT := Color(0.208, 0.816, 1.0, 1.0)
const C_WARN := Color(1.0, 0.72, 0.30, 1.0)
const C_DANGER := Color(1.0, 0.36, 0.36, 1.0)
const C_OK := Color(0.30, 1.0, 0.53, 1.0)
const C_DIM := Color(0.45, 0.45, 0.50, 0.85)
const C_SCRIM := Color(0.0, 0.0, 0.0, 0.62)
## Permukaan MODAL (dialog): hampir opaque supaya isi panel di belakangnya
## tidak menembus (temuan foto KREDIT: teks panel terbaca di atas modal =
## kesan teks bertumpuk).
const C_MODAL := Color(0.043, 0.063, 0.125, 0.995)

# --------------------------------------------------------------- ukuran ----
const RADIUS := 24     ## 12dp — kartu/panel (spesifikasi Frame 3)
const BORDER_W := 2    ## 1dp
const GAP := 16        ## 8dp — kelipatan grid Material
const MICRO := 8       ## 4dp
const MARGIN := 32     ## 16dp — edge margin standar Material
const BTN_PRIMARY_H := 112  ## 56dp — tombol utama (spesifikasi Frame 3)
const BTN_H := 96      ## 48dp — touch target minimum Material
const APP_BAR_H := 112 ## 56dp


static func ls(size: int, color: Color) -> LabelSettings:
	## LabelSettings terpusat; outline gelap supaya teks tetap terbaca di atas
	## base 3D (pola sama dengan menu lain).
	var s := LabelSettings.new()
	s.font_size = size  ## design px (1 px = 0,5 dp)
	s.font_color = color
	s.shadow_color = Color(0.0, 0.0, 0.0, 0.75)
	s.shadow_offset = Vector2(2, 2)
	s.outline_size = 4
	s.outline_color = Color(0.02, 0.03, 0.08, 0.9)
	return s


static func panel_box(bg: Color = C_PANEL, border: Color = C_BORDER,
		radius: int = RADIUS, border_w: int = BORDER_W) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_content_margin_all(MARGIN)
	return s


static func button_box(bg: Color, border: Color, radius: int = RADIUS,
		border_w: int = BORDER_W) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_content_margin_all(GAP)
	return s


## Tombol standar: 56dp (big) / 48dp (sekunder) dengan state lengkap
## (normal/hover/pressed/focus/disabled) — bukan hanya normal.
static func style_button(btn: Button, big: bool = false) -> void:
	btn.custom_minimum_size = Vector2(0, BTN_PRIMARY_H if big else BTN_H)
	btn.add_theme_stylebox_override("normal", button_box(C_CARD, C_BORDER))
	btn.add_theme_stylebox_override("hover", button_box(C_CARD.lightened(0.06), C_BORDER_SEL))
	btn.add_theme_stylebox_override("pressed", button_box(C_ACCENT.darkened(0.55), C_BORDER_SEL))
	btn.add_theme_stylebox_override("focus", button_box(C_CARD, C_BORDER_SEL))
	btn.add_theme_stylebox_override("disabled", button_box(C_PANEL, C_DIM))
	btn.add_theme_font_size_override("font_size", 32 if big else 28)  ## 16dp / 14dp
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	btn.add_theme_color_override("font_disabled_color", C_DIM)


# ---------------------------------------------------------------- ikon -----
const ICONS_JSON := "res://assets/ui/icons.json"
static var _icons_cache: Dictionary = {}


## Ikon dari icons.json (base64, runtime — build pck tanpa importer Godot).
## Cache statis: satu decode per id untuk seluruh aplikasi.
static func get_icon(id: String) -> Texture2D:
	if _icons_cache.has(id):
		return _icons_cache[id]
	var tex: Texture2D = null
	var text := FileAccess.get_file_as_string(ICONS_JSON)
	if text != "":
		var data: Dictionary = JSON.parse_string(text)
		var b64 := String((data.get("icons", {}) as Dictionary).get(id, ""))
		if b64 != "":
			var img := Image.new()
			if img.load_png_from_buffer(Marshalls.base64_to_raw(b64)) == OK:
				tex = ImageTexture.create_from_image(img)
	_icons_cache[id] = tex
	return tex


## device px per CSS px (≈ dp) — sama dengan HUD (hud.gd::_device_pixel_ratio):
## web → DisplayServer.screen_get_scale() = window.devicePixelRatio (data nyata
## browser), fallback dpi/96, fallback terakhir 2.0 = referensi xhdpi.
static func device_pixel_ratio() -> float:
	var sc := DisplayServer.screen_get_scale()
	if sc > 0.0:
		return clampf(sc, 1.0, 4.0)
	var dpi := DisplayServer.screen_get_dpi()
	if dpi > 0:
		return clampf(float(dpi) / 96.0, 1.0, 4.0)
	return 2.0


## Design frame untuk Control di luar subtree HUD: isi penuh window di semua
## aspek, design px = dp × 2 (scale = dpr/2) → komponen berukuran TETAP dalam
## dp (tidak membesar di layar besar). Mengembalikan scale yang dipakai.
static func apply_design_frame(ctl: Control) -> float:
	var vp: Vector2 = ctl.get_viewport().get_visible_rect().size
	if vp.y <= 0.0:
		return 1.0
	var s := clampf(device_pixel_ratio() / 2.0, 0.5, 3.0)
	ctl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctl.offset_left = 0
	ctl.offset_right = 0
	ctl.offset_top = 0
	ctl.offset_bottom = 0
	ctl.size = vp / s  ## design space; di layar = size × scale = vp
	ctl.scale = Vector2(s, s)
	ctl.position = Vector2.ZERO
	return s
