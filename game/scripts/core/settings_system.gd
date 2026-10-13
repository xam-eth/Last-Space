extends Node
## SettingsSystem — pengaturan pemain (M3 #5: audio / tampilan / ukuran UI /
## bahasa). Persist ke `user://settings.json`; SEMUA nilai diterapkan ke sistem
## nyata (AudioServer bus, DisplayServer, HUD scale, TranslationServer) dan
## dilaporkan lewat marker berisi nilai AKTUAL, bukan konstanta.
##
## Sumber standar (bukan asumsi):
##   · Bus audio: Godot AudioServer bus "Master"/"SFX"/"Music" — linear 0..1 →
##     decibel via linear_to_db (volume 0 = -80 dB senyap, bukan -inf agar
##     marker terbaca).
##   · Ukuran UI: aplikasi memakai skala dp (UI_UX_DESIGN.md §3, scale = dpr/2);
##     "ukuran teks/HUD" = pengali 0,85 / 1,00 / 1,15 (kecil/normal/besar) —
##     tetap kelipatan dp, nilai default 1,00 tidak mengubah standar M3.6.
##   · Bahasa: BCP-47 ("id"/"en") lewat TranslationServer (Translation runtime,
##     bukan file importer — build pck tanpa editor, lihat tools/godot/make_pck.py).
##
## Aturan: HANYA SettingsSystem yang menulis file pengaturan; layar UI memanggil
## set_value()/reset_defaults() dan mendengarkan EventBus.settings_changed.

const PATH := "user://settings.json"
const SCHEMA := 1
const BUS_SFX := "SFX"
const BUS_MUSIC := "Music"

## Nilai default = hasil keputusan desain (bukan angka acak).
const DEFAULTS := {
	"master_volume": 0.80,
	"sfx_volume": 0.90,
	"music_volume": 0.60,
	"hud_scale": 1.00,
	"fullscreen": false,
	"language": "id",
}

## Rentang yang diizinkan per kunci (dipakai juga oleh UI slider → clamp di sini).
const RANGES := {
	"master_volume": [0.0, 1.0],
	"sfx_volume": [0.0, 1.0],
	"music_volume": [0.0, 1.0],
	"hud_scale": [0.85, 1.15],
	"language": ["id", "en"],
}

var _values: Dictionary = {}


func _ready() -> void:
	_values = DEFAULTS.duplicate(true)
	_ensure_buses()
	load_settings()
	apply_all()
	QaMarkers.marker("SET", "READY", {"keys": _values.size(), "language": _values["language"],
		"hud_scale": _values["hud_scale"], "fullscreen": _values["fullscreen"]})


## Buat bus SFX/Music bila belum ada → slider volume benar-benar mengatur bus.
func _ensure_buses() -> void:
	for bus_name in [BUS_SFX, BUS_MUSIC]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


func get_value(key: String):
	return _values.get(key, DEFAULTS.get(key))


func get_float(key: String) -> float:
	return float(get_value(key))


func get_bool(key: String) -> bool:
	return bool(get_value(key))


func get_string(key: String) -> String:
	return String(get_value(key))


func hud_scale() -> float:
	return float(get_value("hud_scale"))


func language() -> String:
	return String(get_value("language"))


## Set + clamp + terapkan + simpan + lapor (satu jalur untuk semua perubahan).
func set_value(key: String, value, save: bool = true) -> bool:
	if not DEFAULTS.has(key):
		push_error("SettingsSystem: kunci tidak dikenal %s" % key)
		return false
	var clamped = _clamp(key, value)
	if _values.get(key) == clamped:
		_apply_one(key)
		return true
	_values[key] = clamped
	_apply_one(key)
	QaMarkers.marker("SET", "CHANGED", {"key": key, "value": clamped,
		"applied": _applied_state(key)})
	EventBus.settings_changed.emit(key, clamped)
	if save:
		save_settings()
	return true


func _clamp(key: String, value):
	var r = RANGES.get(key, null)
	if r is Array and r.size() == 2 and typeof(r[0]) == TYPE_FLOAT:
		return clampf(float(value), float(r[0]), float(r[1]))
	if r is Array and typeof(r[0]) == TYPE_STRING:
		var s := String(value)
		return s if s in r else r[0]
	if typeof(DEFAULTS[key]) == TYPE_BOOL:
		return bool(value)
	if typeof(DEFAULTS[key]) == TYPE_FLOAT:
		return clampf(float(value), 0.0, 1.0)
	return value


## Nilai yang benar-benar berlaku di sistem (bukan yang diminta UI).
func _applied_state(key: String) -> Dictionary:
	match key:
		"master_volume", "sfx_volume", "music_volume":
			var bus := _bus_for(key)
			var i := AudioServer.get_bus_index(bus)
			return {"bus": bus, "db": AudioServer.get_bus_volume_db(i) if i >= 0 else 0.0,
				"linear": db_to_linear(AudioServer.get_bus_volume_db(i)) if i >= 0 else 1.0}
		"hud_scale":
			return {"hud_scale": hud_scale()}
		"fullscreen":
			return {"window_mode": DisplayServer.window_get_mode()}
		"language":
			return {"locale": TranslationServer.get_locale(), "tr_test": tr("PENGATURAN")}
	return {}


func _bus_for(key: String) -> String:
	match key:
		"sfx_volume":
			return BUS_SFX
		"music_volume":
			return BUS_MUSIC
		_:
			return "Master"


func _apply_one(key: String) -> void:
	match key:
		"master_volume", "sfx_volume", "music_volume":
			var bus := _bus_for(key)
			var i := AudioServer.get_bus_index(bus)
			if i >= 0:
				var v: float = get_float(key)
				## -80 dB = senyap (bukan -inf) supaya nilai tetap terbaca marker.
				AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
				AudioServer.set_bus_mute(i, v <= 0.001)
		"hud_scale":
			EventBus.settings_changed.emit("hud_scale", hud_scale())  ## HUD re-apply frame
		"fullscreen":
			_apply_fullscreen()
		"language":
			TranslationServer.set_locale(get_string("language"))


## Fullscreen: minta ke OS/browser lalu BACA BALIK mode nyata. Browser mensyaratkan
## gesture pengguna, jadi permintaan bisa DITOLAK (headless/otomasi) — nilai
## pengaturan disamakan dengan kenyataan supaya UI tidak berbohong; penolakan
## dicatat sebagai marker (bukan disembunyikan).
func _apply_fullscreen() -> void:
	var want := get_bool("fullscreen")
	var target := DisplayServer.WINDOW_MODE_FULLSCREEN if want else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != target:
		DisplayServer.window_set_mode(target)
	var actual := DisplayServer.window_get_mode()
	var is_full := actual == DisplayServer.WINDOW_MODE_FULLSCREEN \
		or actual == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if is_full != want:
		_values["fullscreen"] = is_full
		print("QA:SET:FULLSCREEN_REFUSED want=%s actual=%d (platform menolak permintaan)" % [str(want), actual])
		save_settings.call_deferred()


func apply_all() -> void:
	for key in DEFAULTS.keys():
		_apply_one(key)
	QaMarkers.marker("SET", "APPLY", {
		"master": _applied_state("master_volume"),
		"sfx_db": _applied_state("sfx_volume")["db"],
		"music_db": _applied_state("music_volume")["db"],
		"hud_scale": hud_scale(),
		"fullscreen": get_bool("fullscreen"),
		"language": language(),
		"locale": TranslationServer.get_locale(),
	})


func reset_defaults() -> void:
	_values = DEFAULTS.duplicate(true)
	apply_all()
	save_settings()
	QaMarkers.marker("SET", "RESET", _values.duplicate())


func save_settings() -> bool:
	var data := {"schema_version": SCHEMA, "values": _values}
	var text := JSON.stringify(data, "\t")
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_error("SettingsSystem: tidak bisa menulis %s" % PATH)
		return false
	f.store_string(text)
	f.close()
	QaMarkers.marker("SET", "SAVED", {"bytes": text.length(), "path": PATH})
	return true


func load_settings() -> bool:
	if not FileAccess.file_exists(PATH):
		QaMarkers.marker("SET", "LOAD_MISSING", {"path": PATH})
		return false
	var text := FileAccess.get_file_as_string(PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY or int((parsed as Dictionary).get("schema_version", 0)) != SCHEMA:
		## Berkas rusak / skema beda → pakai default (tidak crash, tidak diam-diam salah).
		print("QA:SET:LOAD_BAD_FILE bytes=%d -> defaults" % text.length())
		return false
	var vals: Dictionary = (parsed as Dictionary).get("values", {})
	for key in vals.keys():
		if DEFAULTS.has(key):
			_values[key] = _clamp(key, vals[key])
	## TERAPKAN nilai yang baru dimuat (temuan test: load hanya mengubah memori →
	## bus audio/HUD tetap nilai lama sampai aplikasi di-restart = bug nyata).
	apply_all()
	QaMarkers.marker("SET", "LOADED", {"keys": _values.size(), "path": PATH})
	return true


func snapshot() -> Dictionary:
	return _values.duplicate(true)
