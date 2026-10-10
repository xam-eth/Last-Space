extends RefCounted
## TestCombatSimulator — unit test simulasi pertempuran (deterministik, data nyata).


func _make_input(attackers: Array[StringName], defenders: Array[StringName], seed: int = 42) -> BattleInput:
	var input := BattleInput.new()
	input.attacker = attackers
	input.defender_ships = defenders
	input.seed = seed
	return input


func run(t) -> void:
	# --- Determinism: seed sama → hasil sama persis ---
	var input1 := _make_input([&"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout"], [&"shp_001_interceptor", &"shp_001_interceptor", &"shp_001_interceptor"], 42)
	var input2 := _make_input([&"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout"], [&"shp_001_interceptor", &"shp_001_interceptor", &"shp_001_interceptor"], 42)
	var r1 := CombatSimulator.new().simulate(input1)
	var r2 := CombatSimulator.new().simulate(input2)
	t.check_eq("sim.deterministic_json", JSON.stringify(_result_dict(r1)), JSON.stringify(_result_dict(r2)))

	# --- Statistik menentukan hasil: defender tanpa kapal & tanpa turret kalah ---
	var weak := _make_input([&"aln_001_scout"], [], 42)
	var rw := CombatSimulator.new().simulate(weak)
	t.check_eq("sim.no_defender_attacker_wins", "attacker", rw.winner)

	# --- Statistik menentukan hasil: attacker kosong → defender menang ---
	var none := _make_input([], [&"shp_001_interceptor"], 42)
	var rn := CombatSimulator.new().simulate(none)
	t.check_eq("sim.no_attacker_defender_wins", "defender", rn.winner)

	# --- Kekuatan defender lebih besar → attacker rugi total ---
	var strong := _make_input([&"aln_001_scout"], [&"shp_001_interceptor", &"shp_001_interceptor", &"shp_001_interceptor", &"shp_001_interceptor"], 42)
	var rs := CombatSimulator.new().simulate(strong)
	t.check_eq("sim.strong_defender_wins", "defender", rs.winner)
	t.check_eq("sim.attacker_total_loss", 1, _total_losses(rs.attacker_losses))
	t.check_eq("sim.defender_no_loss", 0, _total_losses(rs.defender_ship_losses))

	# --- Turret membantu: tanpa kapal tapi ada turret, attacker bisa menang ---
	var input_t := _make_input([&"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout"], [], 42)
	input_t.defender_turrets = [{"weapon_id": &"laser_cannon", "count": 1, "hp": 120}]
	var rt := CombatSimulator.new().simulate(input_t)
	t.check("sim.turret_fights", rt.duration_ticks > 0)
	t.check("sim.turret_has_effect", _total_losses(rt.attacker_losses) > 0 or int(rt.turret_damage.get(0, 0)) > 0)

	# --- Shield menyerap damage ke bangunan: bandingkan dengan tanpa shield ---
	var attackers8: Array[StringName] = [&"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout", &"aln_001_scout"]
	var input_shield := _make_input(attackers8, [], 42)
	input_shield.defender_buildings = [{"instance_id": "command_core_1", "hp": 500, "max_hp": 500}]
	input_shield.shield_hp = 500
	var input_noshield := _make_input(attackers8, [], 42)
	input_noshield.defender_buildings = [{"instance_id": "command_core_1", "hp": 500, "max_hp": 500}]
	input_noshield.shield_hp = 0
	var rsh := CombatSimulator.new().simulate(input_shield)
	var rns := CombatSimulator.new().simulate(input_noshield)
	t.check("sim.shield_absorbs", rsh.shield_damage > 0)
	t.check("sim.shield_reduces_building_damage",
		int(rsh.building_damage.get("command_core_1", 0)) < int(rns.building_damage.get("command_core_1", 0)))

	# --- Damage ke bangunan tercatat per instance ---
	t.check("sim.building_damage_keyed", rsh.building_damage.has("command_core_1"))

	# --- Durasi tercatat ---
	t.check("sim.duration_positive", rs.duration_ticks > 0)


func _total_losses(d: Dictionary) -> int:
	var n := 0
	for k in d.keys():
		n += int(d[k])
	return n


func _result_dict(r: BattleResult) -> Dictionary:
	return {
		"winner": r.winner,
		"duration_ticks": r.duration_ticks,
		"attacker_losses": r.attacker_losses,
		"defender_ship_losses": r.defender_ship_losses,
		"turret_damage": r.turret_damage,
		"shield_damage": r.shield_damage,
		"building_damage": r.building_damage,
		"seed": r.seed,
	}
