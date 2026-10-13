extends RefCounted
## TestIcons — M3 #7: set ikon adalah BERKAS SVG ASLI (bukan gambar hasil kode).
## Koreksi pemain 2026-10-13: "kamu masih pakai code, semua icon harusnya pakai
## svg real". Ekspektasi dihitung dari berkas nyata di res://assets/ui/icons/.

const ICON_DIR := "res://assets/ui/icons"

## Ikon yang WAJIB ada (dipakai HUD, menu katalog, panel pengaturan, katalog).
const REQUIRED := [
	"energy", "minerals", "fleet", "command", "reactor", "extractor", "hangar",
	"turret", "shield", "interceptor", "fort", "factory", "menu", "build",
	"close", "upgrade", "grid", "crate", "warning", "quest", "info", "lock",
	"settings", "play", "plus", "minus", "reset", "planet", "check", "timer",
	"crosshair", "home", "rotate",
]


func run(t) -> void:
	# --- 1. berkas .svg nyata ada (bukan digambar kode saat runtime) ---
	var ids := UiTheme.icon_ids()
	t.check("icons.dir_readable", ids.size() >= 30, "berkas .svg terdeteksi=%d" % ids.size())
	var missing: Array[String] = []
	for id in REQUIRED:
		if not ids.has(id):
			missing.append(id)
	t.check("icons.required_present", missing.is_empty(), "hilang: %s" % str(missing))

	# --- 2. isi berkas = XML SVG asli (bukan base64/gambar) ---
	var svg_text := FileAccess.get_file_as_string("%s/build.svg" % ICON_DIR)
	t.check("icons.file_is_svg_xml", svg_text.begins_with("<?xml") and svg_text.find("<svg") > 0
		and svg_text.find("viewBox=\"0 0 64 64\"") > 0, "awal: %s" % svg_text.substr(0, 24))
	t.check("icons.file_has_vector_glyph", svg_text.find("<path") > 0 or svg_text.find("<rect") > 0,
		"elemen vektor: path/rect ada")
	t.check("icons.not_base64_png", svg_text.find("base64") < 0 and svg_text.find("data:image") < 0,
		"tidak ada PNG base64 di dalam berkas ikon")

	# --- 3. engine merasterkan SVG (thorvg) → tekstur nyata ---
	var tex := UiTheme.get_icon("build", 128)
	t.check("icons.raster_ok", tex != null, "tekstur build.svg")
	if tex != null:
		t.check("icons.raster_size", tex.get_width() >= 64 and tex.get_height() >= 64,
			"%dx%d px (harap ≥64)" % [tex.get_width(), tex.get_height()])
		var img := tex.get_image()
		var opaque := 0
		for y in range(0, img.get_height(), 4):
			for x in range(0, img.get_width(), 4):
				if img.get_pixel(x, y).a > 0.5:
					opaque += 1
		t.check("icons.raster_has_ink", opaque > 100, "piksel terisi (sampling 1/16)=%d" % opaque)

	# --- 4. SUMBER ikon dilaporkan jujur: "svg" (bukan fallback PNG) ---
	var src := UiTheme.icon_source("build")
	t.check_eq("icons.source_is_svg", "svg", src)
	var fallbacks: Array[String] = []
	for id in ["menu", "fleet", "settings", "planet", "rotate", "turret"]:
		if UiTheme.icon_source(id) != "svg":
			fallbacks.append(id)
	t.check("icons.no_png_fallback", fallbacks.is_empty(), "fallback: %s" % str(fallbacks))

	# --- 5. cache: id yang sama tidak di-decode ulang (performa) ---
	var a := UiTheme.get_icon("menu", 128)
	var b := UiTheme.get_icon("menu", 128)
	t.check("icons.cache_same_instance", a == b, "instance sama dari cache")
	var big := UiTheme.get_icon("menu", 256)
	t.check("icons.size_variant", big != null and big.get_width() > a.get_width(),
		"%d px > %d px" % [big.get_width() if big != null else -1, a.get_width()])

	# --- 6. ikon yang diminta UI benar-benar dapat dimuat semua ---
	var failed_ids: Array[String] = []
	for id in REQUIRED:
		var t2 := UiTheme.get_icon(id)
		if t2 == null:
			failed_ids.append(id)
	t.check("icons.all_loadable", failed_ids.is_empty(), "gagal: %s" % str(failed_ids))
