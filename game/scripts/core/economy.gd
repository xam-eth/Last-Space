extends Node
## Economy — PEMILIK TUNGGAL saldo sumber daya dan transaksi
## (DATA_CONTRACTS.md §1). Sistem lain mengakses lewat API ini atau event.
##
## Aturan: saldo selalu integer (hindari float drift); earn dibatasi storage cap;
## spend atomik (gagal = tidak ada perubahan).

var balances: Dictionary = {}  ## resource_id -> int
var caps: Dictionary = {}      ## resource_id -> int


func _ready() -> void:
	_init_from_config()


func _init_from_config() -> void:
	balances.clear()
	caps.clear()
	var cfg := GameData.economy_config
	if cfg == null:
		push_error("Economy: economy config tidak ter-load")
		return
	for res_id in cfg.starting_resources.keys():
		balances[_key(res_id)] = int(cfg.starting_resources[res_id])
	for res_id in cfg.storage_caps.keys():
		caps[_key(res_id)] = int(cfg.storage_caps[res_id])
	QaMarkers.marker("ECONOMY", "INIT", _snapshot())


## Reset ke state awal dari data (dipakai new game & test).
func reset() -> void:
	_init_from_config()


func get_amount(resource_id: StringName) -> int:
	return int(balances.get(_key(resource_id), 0))


func get_cap(resource_id: StringName) -> int:
	return int(caps.get(_key(resource_id), 0))


func can_afford(cost: Dictionary) -> bool:
	for res_id in cost.keys():
		if get_amount(_key(res_id)) < int(cost[res_id]):
			return false
	return true


## Kembalikan true jika saldo cukup (dan saldo terpotong). Jika tidak cukup,
## tidak ada perubahan sama sekali.
func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	for res_id in cost.keys():
		_add(_key(res_id), -int(cost[res_id]))
	return true


## Tambah saldo (dibatasi storage cap). Mengembalikan jumlah aktual yang masuk.
func earn(resource_id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var rid := _key(resource_id)
	var room := maxi(0, get_cap(rid) - get_amount(rid))
	var added := mini(amount, room)
	if added > 0:
		_add(rid, added)
		QaMarkers.marker("ECONOMY", "PRODUCE", {"resource": rid, "amount": added, "balance": get_amount(rid)})
	return added


func add_cap(resource_id: StringName, bonus: int) -> void:
	var rid := _key(resource_id)
	caps[rid] = get_cap(rid) + bonus


func _add(resource_id: StringName, delta: int) -> void:
	var old := get_amount(resource_id)
	var new := old + delta
	balances[resource_id] = new
	EventBus.resource_changed.emit(resource_id, old, new, delta)
	QaMarkers.marker("ECONOMY", "CHANGE", {"resource": resource_id, "old": old, "new": new, "delta": delta})


func get_state() -> Dictionary:
	return {"balances": balances.duplicate(true), "caps": caps.duplicate(true)}


func set_state(state: Dictionary) -> void:
	# Normalisasi ke int: JSON.parse_string menghasilkan float untuk semua angka.
	var new_balances := {}
	for res_id in (state.get("balances", {}) as Dictionary).keys():
		new_balances[_key(res_id)] = int((state.get("balances", {}) as Dictionary)[res_id])
	var new_caps := {}
	for res_id in (state.get("caps", {}) as Dictionary).keys():
		new_caps[_key(res_id)] = int((state.get("caps", {}) as Dictionary)[res_id])
	balances = new_balances
	caps = new_caps
	for res_id in balances.keys():
		EventBus.resource_changed.emit(res_id, 0, get_amount(res_id), get_amount(res_id))
	QaMarkers.marker("ECONOMY", "RESTORE", _snapshot())


func _snapshot() -> Dictionary:
	var out := {}
	for res_id in balances.keys():
		out[res_id] = "%d/%d" % [get_amount(res_id), get_cap(res_id)]
	return out


func _key(resource_id) -> StringName:
	return StringName(str(resource_id))
