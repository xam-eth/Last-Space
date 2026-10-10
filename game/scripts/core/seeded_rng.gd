extends Node
## SeededRng — RNG deterministik (splitmix64). Seed disimpan/dipulihkan oleh
## SaveSystem sehingga hasil simulasi bisa direplay (TECH_ARCHITECTURE.md §6).

## splitmix64. Konstanta di bawah adalah nilai unsigned 0x9E3779B97F4A7C15,
## 0xBF58476D1CE4E5B9, 0x94D049BB133111EB dalam bentuk signed int64 (GDScript
## tidak menerima hex literal di atas int64 max). int64 overflow = wrap, jadi
## hasil bit-identik dengan versi unsigned.
var _state: int = -7046029254386353131

const GOLDEN := -7046029254386353131
const MIX1 := -4658895280553007687
const MIX2 := -7723592293110705685


func set_seed(seed_value: int) -> void:
	_state = seed_value if seed_value != 0 else GOLDEN
	# warm up agar bit awal tidak terlalu terpola
	for i in 8:
		_next()


func get_seed() -> int:
	return _state


func _next() -> int:
	_state = _state + GOLDEN  ## int64 overflow = wrap (deterministik)
	var z := _state
	z = (z ^ (z >> 30)) * MIX1
	z = (z ^ (z >> 27)) * MIX2
	z = z ^ (z >> 31)
	return z


func next_int() -> int:
	return _next()


## Rentang inklusif [from, to].
func next_int_range(from: int, to: int) -> int:
	if to <= from:
		return from
	return from + ((_next() & 0x7FFFFFFFFFFFFFFF) % (to - from + 1))


func next_float() -> float:
	return float(_next() & 0x7FFFFFFFFFFFFFFF) / 9223372036854775807.0
