extends Node
## TimeSystem — game clock dengan fixed tick. Semua sistem berbasis waktu
## (produksi, konstruksi, cooldown) mendengar signal `ticked`.
##
## `advance_ticks(n)` dipakai test/e2e untuk menjalankan waktu secara deterministik
## tanpa bergantung pada frame rate (TECH_ARCHITECTURE.md §6).

signal ticked(tick_count: int, delta_ticks: int)

const TICKS_PER_SECOND := 10

var tick_count: int = 0
var speed: float = 1.0  ## 0 = pause, 1 = normal, 2 = cepat

var _accumulator: float = 0.0


func _process(delta: float) -> void:
	if speed <= 0.0:
		return
	_accumulator += delta * speed * TICKS_PER_SECOND
	var n := int(_accumulator)
	if n <= 0:
		return
	_accumulator -= n
	advance_ticks(n)


## Majukan waktu game sebanyak n tick secara manual (deterministik, untuk test).
func advance_ticks(n: int) -> void:
	for i in n:
		tick_count += 1
		ticked.emit(tick_count, 1)


func set_speed(p_speed: float) -> void:
	speed = clampf(p_speed, 0.0, 4.0)


func pause() -> void:
	set_speed(0.0)


func resume() -> void:
	set_speed(1.0)
