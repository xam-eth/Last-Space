/**
 * logic.js — port JavaScript dari logika inti game (game/scripts/).
 * Ini mirror untuk debug/preview di browser: logika SAMA dengan yang
 * diverifikasi di Godot (lihat game/tests/). Verifikasi otoritatif tetap
 * `bash tools/godot/run_game_check.sh tests`.
 */

/** Economy — port dari game/scripts/core/economy.gd */
export class Economy {
	constructor(cfg) {
		this.balances = {};
		this.caps = {};
		for (const [k, v] of Object.entries(cfg.starting_resources || {})) this.balances[k] = v;
		for (const [k, v] of Object.entries(cfg.storage_caps || {})) this.caps[k] = v;
	}
	get(id) { return this.balances[id] || 0; }
	cap(id) { return this.caps[id] || 0; }
	canAfford(cost) {
		return Object.entries(cost).every(([k, v]) => this.get(k) >= v);
	}
	spend(cost) {
		if (!this.canAfford(cost)) return false;
		for (const [k, v] of Object.entries(cost)) this.balances[k] -= v;
		return true;
	}
	earn(id, amount) {
		if (amount <= 0) return 0;
		const room = Math.max(0, this.cap(id) - this.get(id));
		const added = Math.min(amount, room);
		if (added > 0) this.balances[id] = this.get(id) + added;
		return added;
	}
}

/** Produksi integer-exact — port dari game/scripts/building/building.gd */
export function productionTotal(def, level, prodTicks, state) {
	if (!def.produces || state === "destroyed") return 0;
	const base = Math.floor((def.production_per_minute * level) * prodTicks / (60 * 10));
	return state === "normal" ? base : Math.floor(base / 2);
}

/** CombatSimulator — port dari game/scripts/combat/combat_simulator.gd */
export function simulateCombat(input, data) {
	const MAX_TICKS = 3000;
	const result = {
		attacker_losses: {},
		defender_ship_losses: {},
		turret_damage: {},
		shield_damage: 0,
		building_damage: {},
		duration_ticks: 0,
		winner: "",
		seed: input.seed || 0,
	};
	const attackers = (input.attacker || [])
		.map((id) => ({ def: data.ships[id], hp: data.ships[id] ? data.ships[id].max_hp : 0, cd: 0 }))
		.filter((u) => u.def);
	const defenders = (input.defender_ships || [])
		.map((id) => ({ def: data.ships[id], hp: data.ships[id] ? data.ships[id].max_hp : 0, cd: 0 }))
		.filter((u) => u.def);
	const turrets = [];
	(input.defender_turrets || []).forEach((t, i) => {
		const w = data.weapons[t.weapon_id];
		if (!w) return;
		for (let c = 0; c < (t.count || 1); c++) turrets.push({ weapon: w, hp: t.hp || 100, cd: 0, index: i });
	});
	const buildings = (input.defender_buildings || []).map((b) => ({ instance_id: b.instance_id, hp: b.hp }));
	let shield = input.shield_hp || 0;

	const alive = (pool) => pool.filter((u) => u.hp > 0).length;
	const firstAlive = (pool) => pool.find((u) => u.hp > 0) || null;

	let tick = 0;
	while (tick < MAX_TICKS) {
		tick++;
		if (alive(attackers) === 0) { result.winner = "defender"; break; }
		if (alive(defenders) === 0 && alive(turrets) === 0 && alive(buildings) === 0) { result.winner = "attacker"; break; }

		for (const a of attackers) {
			if (a.hp <= 0) continue;
			a.cd = Math.max(0, a.cd - 1);
			if (a.cd > 0) continue;
			const w = data.weapons[a.def.weapon_id];
			if (!w) continue;
			let target = firstAlive(defenders); let kind = "ship";
			if (!target) { target = firstAlive(turrets); kind = "turret"; }
			if (!target) { target = firstAlive(buildings); kind = "building"; }
			if (!target) break;
			let dmg;
			if (kind === "ship") dmg = Math.max(1, w.damage - (target.def.armor || 0));
			else dmg = Math.max(1, Math.floor(w.damage * w.vs_structure_multiplier));
			if (shield > 0) {
				const absorbed = Math.min(shield, dmg);
				shield -= absorbed;
				result.shield_damage += absorbed;
				dmg -= absorbed;
				if (dmg <= 0) { a.cd = w.cooldown_ticks; continue; }
			}
			target.hp -= dmg;
			if (kind === "building") result.building_damage[target.instance_id] = (result.building_damage[target.instance_id] || 0) + dmg;
			else if (kind === "turret") result.turret_damage[target.index] = (result.turret_damage[target.index] || 0) + dmg;
			a.cd = w.cooldown_ticks;
		}
		for (const d of defenders) {
			if (d.hp <= 0) continue;
			d.cd = Math.max(0, d.cd - 1);
			if (d.cd > 0) continue;
			const w = data.weapons[d.def.weapon_id];
			if (!w) continue;
			const target = firstAlive(attackers);
			if (!target) break;
			target.hp -= Math.max(1, w.damage - (target.def.armor || 0));
			d.cd = w.cooldown_ticks;
		}
		for (const t of turrets) {
			if (t.hp <= 0) continue;
			t.cd = Math.max(0, t.cd - 1);
			if (t.cd > 0) continue;
			const target = firstAlive(attackers);
			if (!target) break;
			target.hp -= Math.max(1, t.weapon.damage - (target.def.armor || 0));
			t.cd = t.weapon.cooldown_ticks;
		}
	}
	result.duration_ticks = tick;
	if (!result.winner) result.winner = "draw";
	for (const a of attackers) if (a.hp <= 0) result.attacker_losses[a.def.id] = (result.attacker_losses[a.def.id] || 0) + 1;
	for (const d of defenders) if (d.hp <= 0) result.defender_ship_losses[d.def.id] = (result.defender_ship_losses[d.def.id] || 0) + 1;
	return result;
}

/** ProgressionSystem — bagian reward (tepat satu kali) */
export class Progression {
	constructor(cfg) {
		this.unlocked = [...(cfg.starting_unlocks || [])];
		this.territories = [...(cfg.starting_territories || [])];
		this.granted = new Set();
		this.defenseWins = 0;
	}
	grantReward(economy, rewards, source) {
		if (this.granted.has(source)) return false;
		this.granted.add(source);
		for (const [k, v] of Object.entries(rewards)) economy.earn(k, v);
		return true;
	}
	onCombatFinished(result, data, economy) {
		if (result.winner !== "defender") return;
		this.defenseWins += 1;
		for (const [id, def] of Object.entries(data.sectors)) {
			if (this.territories.includes(id)) continue;
			if (def.unlock_condition === `defend_home_base_${this.defenseWins}`) {
				this.territories.push(id);
				this.grantReward(economy, def.rewards, `sector:${id}`);
				break;
			}
		}
	}
}
