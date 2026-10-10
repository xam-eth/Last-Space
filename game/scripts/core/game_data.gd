extends Node
## GameData — load semua resource data dari res://data/ saat boot; registry by id.
## Satu-satunya loader data game (TECH_ARCHITECTURE.md §3).

var economy_config: EconomyConfig
var progression_config: ProgressionConfig
var buildings: Dictionary = {}  ## id -> BuildingDef
var ships: Dictionary = {}      ## id -> ShipDef
var weapons: Dictionary = {}    ## id -> WeaponDef
var waves: Dictionary = {}      ## id -> WaveDef
var sectors: Dictionary = {}    ## id -> SectorDef

var load_errors: Array[String] = []


func _ready() -> void:
	_load_all()


func _load_all() -> void:
	economy_config = _load_one("res://data/economy.tres")
	progression_config = _load_one("res://data/progression.tres")
	_load_dir("res://data/buildings", buildings)
	_load_dir("res://data/ships", ships)
	_load_dir("res://data/weapons", weapons)
	_load_dir("res://data/waves", waves)
	_load_dir("res://data/sectors", sectors)
	QaMarkers.marker("DATA", "LOADED", {
		"buildings": buildings.size(),
		"ships": ships.size(),
		"weapons": weapons.size(),
		"waves": waves.size(),
		"sectors": sectors.size(),
		"errors": load_errors.size(),
	})


func _load_one(path: String) -> Resource:
	if not ResourceLoader.exists(path):
		load_errors.append("missing: %s" % path)
		return null
	return ResourceLoader.load(path)


func _load_dir(dir: String, into: Dictionary) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		load_errors.append("missing dir: %s" % dir)
		return
	d.list_dir_begin()
	var name := d.get_next()
	while name != "":
		if name.ends_with(".tres"):
			var res: Resource = ResourceLoader.load("%s/%s" % [dir, name])
			if res == null:
				load_errors.append("failed to load: %s/%s" % [dir, name])
			else:
				var id: StringName = res.get("id")
				if id == &"" or into.has(id):
					load_errors.append("duplicate/empty id in %s/%s" % [dir, name])
				else:
					into[id] = res
		name = d.get_next()
	d.list_dir_end()


func get_building_def(id: StringName) -> BuildingDef:
	return buildings.get(id)


func get_ship_def(id: StringName) -> ShipDef:
	return ships.get(id)


func get_weapon_def(id: StringName) -> WeaponDef:
	return weapons.get(id)


func get_wave_def(id: StringName) -> WaveDef:
	return waves.get(id)


func get_sector_def(id: StringName) -> SectorDef:
	return sectors.get(id)
