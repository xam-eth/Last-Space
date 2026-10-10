class_name CombatSimulator
extends RefCounted
## CombatSimulator — simulasi pertempuran DETERMINISTIK, murni (tanpa scene
## tree, tanpa UI). Input: BattleInput. Output: BattleResult.
##
## Aturan (TECH_ARCHITECTURE.md §6, RISK_ANALYSIS.md bottleneck #5):
## - Simulasi dan visualisasi terpisah; visualizer menampilkan hasil INI.
## - Seed sama + input sama → hasil sama persis (reproducible).
## - Statistik unit (dari data) menentukan hasil.
##
## Model: tick-based. Prioritas target attacker: kapal defender → turret →
## bangunan (shield menyerap damage ke bangunan lebih dulu). Damage =
## max(1, weapon.damage - armor) × multiplier (vs_structure untuk turret/bangunan).

const MAX_TICKS := 3000


func simulate(input: BattleInput) -> BattleResult:
	var result := BattleResult.new()
	result.seed = input.seed
	if input.seed != 0:
		SeededRng.set_seed(input.seed)

	var attackers: Array[Dictionary] = []
	for ship_id in input.attacker:
		var def := GameData.get_ship_def(ship_id)
		if def != null:
			attackers.append({"def": def, "hp": def.max_hp, "cd": 0})
	var defenders: Array[Dictionary] = []
	for ship_id in input.defender_ships:
		var def := GameData.get_ship_def(ship_id)
		if def != null:
			defenders.append({"def": def, "hp": def.max_hp, "cd": 0})
	var turrets: Array[Dictionary] = []
	for i in input.defender_turrets.size():
		var t: Dictionary = input.defender_turrets[i]
		var w := GameData.get_weapon_def(t.get("weapon_id", &""))
		if w == null:
			continue
		for c in int(t.get("count", 1)):
			turrets.append({"weapon": w, "hp": int(t.get("hp", 100)), "cd": 0, "index": i})
	var buildings: Array[Dictionary] = []
	for b in input.defender_buildings:
		buildings.append({
			"instance_id": String(b.get("instance_id", "")),
			"hp": int(b.get("hp", 0)),
		})
	var shield := input.shield_hp

	var tick := 0
	while tick < MAX_TICKS:
		tick += 1
		if _alive_count(attackers) == 0:
			result.winner = "defender"
			break
		if _alive_count(defenders) == 0 and _alive_count(turrets) == 0 and _alive_count(buildings) == 0:
			result.winner = "attacker"
			break

		# --- Attacker menembak ---
		for a in attackers:
			if a.hp <= 0:
				continue
			a.cd = maxi(0, int(a.cd) - 1)
			if a.cd > 0:
				continue
			var w := GameData.get_weapon_def(a.def.weapon_id)
			if w == null:
				continue
			var target = _first_alive(defenders)
			var kind := "ship"
			if target == null:
				target = _first_alive(turrets)
				kind = "turret"
			if target == null:
				target = _first_alive(buildings)
				kind = "building"
			if target == null:
				break
			var dmg := 0
			if kind == "ship":
				dmg = maxi(1, w.damage - int(target.def.armor))
			elif kind == "turret":
				dmg = maxi(1, int(w.damage * w.vs_structure_multiplier))
			else:
				dmg = maxi(1, int(w.damage * w.vs_structure_multiplier))
				if shield > 0:
					var absorbed := mini(shield, dmg)
					shield -= absorbed
					result.shield_damage += absorbed
					dmg -= absorbed
				if dmg <= 0:
					a.cd = w.cooldown_ticks
					continue
			target.hp -= dmg
			if kind == "building":
				result.building_damage[target.instance_id] = int(result.building_damage.get(target.instance_id, 0)) + dmg
			elif kind == "turret":
				result.turret_damage[target.index] = int(result.turret_damage.get(target.index, 0)) + dmg
			a.cd = w.cooldown_ticks

		# --- Defender (kapal + turret) menembak balik ---
		for d in defenders:
			if d.hp <= 0:
				continue
			d.cd = maxi(0, int(d.cd) - 1)
			if d.cd > 0:
				continue
			var w := GameData.get_weapon_def(d.def.weapon_id)
			if w == null:
				continue
			var target = _first_alive(attackers)
			if target == null:
				break
			target.hp -= maxi(1, w.damage - int(target.def.armor))
			d.cd = w.cooldown_ticks
		for t in turrets:
			if t.hp <= 0:
				continue
			t.cd = maxi(0, int(t.cd) - 1)
			if t.cd > 0:
				continue
			var target = _first_alive(attackers)
			if target == null:
				break
			target.hp -= maxi(1, t.weapon.damage - int(target.def.armor))
			t.cd = t.weapon.cooldown_ticks

	result.duration_ticks = tick
	if result.winner == "":
		result.winner = "draw"
	for a in attackers:
		if a.hp <= 0:
			result.attacker_losses[a.def.id] = int(result.attacker_losses.get(a.def.id, 0)) + 1
	for d in defenders:
		if d.hp <= 0:
			result.defender_ship_losses[d.def.id] = int(result.defender_ship_losses.get(d.def.id, 0)) + 1
	return result


func _alive_count(pool: Array) -> int:
	var n := 0
	for u in pool:
		if int(u.hp) > 0:
			n += 1
	return n


func _first_alive(pool: Array):
	for u in pool:
		if int(u.hp) > 0:
			return u
	return null
