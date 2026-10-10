extends Node
## QaMarkers — mencetak marker verifikasi ke console dengan nilai state NYATA
## (bukan konstanta). Format: QA:<PHASE>:<EVENT> key=value ...
##
## Dipakai oleh: test assertions (capture tool --wait-for) dan verifikasi e2e.
## Aturan: setiap perubahan state penting mencetak marker berisi nilai aktual
## yang dibaca dari state saat itu (QA_PLAN.md §2 — "bukan asal jalan").


func marker(phase: String, event: String, values: Dictionary = {}) -> void:
	var parts := PackedStringArray()
	for key in values.keys():
		parts.append("%s=%s" % [key, values[key]])
	print("QA:%s:%s %s" % [phase, event, " ".join(parts)])
