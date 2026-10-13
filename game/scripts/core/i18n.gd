extends Node
## I18n — terjemahan runtime ID→EN (M3 #5 "bahasa").
##
## Kenapa runtime (bukan .po/.csv): build pck dibuat tanpa editor
## (tools/godot/make_pck.py), jadi importer Godot tidak tersedia — Translation
## dibuat dari Dictionary saat boot (Translation.add_message) lalu didaftarkan
## ke TranslationServer. Pola sama dengan icons.json/sfx.json.
##
## Cakupan (JUJUR — dilaporkan, bukan diklaim penuh): permukaan MENU
## (menu utama, pengaturan, pause). Teks HUD gameplay & katalog BANGUN/ARMADA
## masih Bahasa Indonesia; jumlah string yang belum diterjemahkan dihitung dan
## dicetak ke marker `QA:I18N:COVERAGE` supaya tidak ada klaim palsu.
##
## Aturan istilah (keputusan user, M3.5): label utama Bahasa Indonesia; istilah
## teknis (WAVE/ARMOR/HP/ATK/Lv, E/M) tidak diterjemahkan di kedua bahasa.

## id → en. Kunci = teks PERSIS yang ada di kode (dipakai `tr("...")`).
const MESSAGES := {
	# --- menu utama ---
	"PANGKALAN ANTARIKSA": "SPACE OUTPOST",
	"MULAI": "START",
	"LANJUTKAN": "CONTINUE",
	"LANJUTKAN PERMAINAN": "RESUME GAME",
	"MULAI BARU": "NEW GAME",
	"MULAI BARU (reset)": "NEW GAME (reset)",
	"PENGATURAN": "SETTINGS",
	"KREDIT": "CREDITS",
	"TUTUP": "CLOSE",
	"Bangun basis • tahan gelombang • kuasai sektor": "Build your base • hold the waves • own the sector",
	"Belum ada kemajuan tersimpan": "No saved progress yet",
	"Pengaturan — M3 #5 (belum ada)": "Settings — M3 #5 (not available yet)",
	# --- pause ---
	"LANJUT": "RESUME",
	"KEMBALI KE MENU": "BACK TO MENU",
	"Kemajuan tersimpan — kembali ke menu utama.": "Progress saved — returning to main menu.",
	"Gagal menyimpan — tetap di game.": "Save failed — staying in game.",
	"Yakin kembali ke menu utama?": "Return to the main menu?",
	"YA, KEMBALI": "YES, RETURN",
	"BATAL": "CANCEL",
	# --- pengaturan (panel M3 #5) ---
	"AUDIO": "AUDIO",
	"Volume utama": "Master volume",
	"Efek suara": "Sound effects",
	"Musik": "Music",
	"TAMPILAN": "DISPLAY",
	"Layar penuh": "Fullscreen",
	"Ukuran UI": "UI size",
	"Kecil": "Small",
	"Normal": "Normal",
	"Besar": "Large",
	"BAHASA": "LANGUAGE",
	"Bahasa": "Language",
	"Kembalikan default": "Reset to defaults",
	"Pengaturan dikembalikan ke default": "Settings reset to defaults",
	"Kembalikan pengaturan ke default?": "Reset settings to defaults?",
	"Belum ada musik (M3 #5 lanjutan)": "No music track yet (M3 #5 follow-up)",
	"Terjemahan EN: menu & pengaturan; HUD/katalog masih ID (dilaporkan)":
		"EN translation: menus & settings; HUD/catalog still ID (reported)",
	"Pengaturan tersimpan": "Settings saved",
}


func _ready() -> void:
	_register()


func _register() -> void:
	var en := Translation.new()
	en.locale = "en"
	for src in MESSAGES.keys():
		en.add_message(StringName(src), String(MESSAGES[src]))
	TranslationServer.add_translation(en)
	var id := Translation.new()
	id.locale = "id"
	for src in MESSAGES.keys():
		id.add_message(StringName(src), String(src))
	TranslationServer.add_translation(id)
	TranslationServer.set_locale("id")
	QaMarkers.marker("I18N", "READY", {"messages": MESSAGES.size(), "locales": "id,en"})


## Berapa string UI yang sudah punya terjemahan (untuk laporan cakupan).
func message_count() -> int:
	return MESSAGES.size()


## Terjemahkan; fallback ke teks asal bila belum ada padanan (tidak crash).
func t(text: String) -> String:
	var out := tr(text)
	return out if out != "" else text
