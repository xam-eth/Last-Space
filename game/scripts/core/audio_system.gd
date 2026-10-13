extends Node
## AudioSystem — SFX UI/gameplay (M3 #5). Bank bunyi = `assets/audio/sfx.json`
## (PCM16 base64 hasil tools/audio/make_sfx.py) → AudioStreamWAV dibangun
## runtime (build pck tanpa importer Godot). Volume mengikuti SettingsSystem
## (bus SFX/Music), jadi slider pengaturan benar-benar terdengar.
##
## Sumber aturan (bukan asumsi): Godot AudioStreamWAV.data = PCM mentah sesuai
## `format`; AudioServer bus dipakai untuk volume per-kategori (UI_UX_DESIGN §7b
## pola M3.6). Bunyi dipicu oleh peristiwa NYATA (EventBus), bukan timer palsu.

const SFX_JSON := "res://assets/audio/sfx.json"
const POOL := 6  ## 6 pemutar paralel — tap cepat tidak memotong bunyi sebelumnya

var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _counts: Dictionary = {}   ## statistik per bunyi (untuk marker/QA)
var _music: AudioStreamPlayer


func _ready() -> void:
	_load_bank()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = SettingsSystem.BUS_SFX
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = SettingsSystem.BUS_MUSIC
	add_child(_music)
	EventBus.building_placed.connect(_on_building_placed)
	EventBus.building_upgraded.connect(_on_confirm)
	EventBus.production_completed.connect(_on_production_completed)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.wave_incoming.connect(_on_wave_incoming)
	EventBus.combat_finished.connect(_on_combat_finished)
	QaMarkers.marker("AUDIO", "READY", {"streams": _streams.size(),
		"players": _players.size(), "sfx_bus": SettingsSystem.BUS_SFX})


func _load_bank() -> void:
	var text := FileAccess.get_file_as_string(SFX_JSON)
	if text == "":
		push_error("AudioSystem: bank SFX tidak ada (%s)" % SFX_JSON)
		return
	var data: Dictionary = JSON.parse_string(text)
	var rate := int(data.get("mix_rate", 22050))
	for id in (data.get("sounds", {}) as Dictionary).keys():
		var s: Dictionary = data["sounds"][id]
		var stream := AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.stereo = false
		stream.mix_rate = rate
		stream.data = Marshalls.base64_to_raw(String(s.get("data_b64", "")))
		_streams[String(id)] = stream
		_counts[String(id)] = 0


func has_sound(id: String) -> bool:
	return _streams.has(id)


## Durasi (detik) dari data PCM nyata — dipakai QA (bukan angka dari kode).
func duration_of(id: String) -> float:
	var s: AudioStreamWAV = _streams.get(id, null)
	if s == null:
		return 0.0
	return s.data.size() / 2.0 / float(s.mix_rate)


func play(id: String) -> bool:
	## Putar bila ada; true = benar-benar mulai diputar.
	var s: AudioStreamWAV = _streams.get(id, null)
	if s == null:
		return false
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = s
	p.play()
	_counts[id] = int(_counts.get(id, 0)) + 1
	return p.playing


## Klik tombol UI — dipanggil layar (HUD, menu, katalog, pengaturan).
func ui_click() -> void:
	play("ui_click")


func ui_confirm() -> void:
	play("ui_confirm")


func ui_cancel() -> void:
	play("ui_cancel")


func counts() -> Dictionary:
	return _counts.duplicate()


func stream_ids() -> Array:
	var ids := _streams.keys()
	ids.sort()
	return ids


# ------------------------------------------------------- pemicu peristiwa ----
func _on_building_placed(_id: StringName, _inst: String, _pos: Vector3) -> void:
	ui_confirm()


func _on_confirm(_a = null, _b = null, _c = null, _d = null) -> void:
	ui_confirm()


func _on_production_completed(_kind: String, _id: StringName, _amount: int) -> void:
	ui_confirm()


func _on_quest_completed(_quest_id: StringName) -> void:
	ui_confirm()


func _on_wave_incoming(_wave_id: StringName, _eta: int) -> void:
	play("wave_alarm")


func _on_combat_finished(_result: BattleResult) -> void:
	play("ui_cancel")
