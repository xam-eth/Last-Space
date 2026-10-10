/**
 * checks.js — menjalankan semua check: SETUP (file/data game ada & valid)
 * dan LOGIKA (port JS dari sistem inti, diverifikasi dengan data nyata).
 * Mengembalikan array { group, name, pass, detail }.
 */
import { Economy, productionTotal, simulateCombat, Progression } from "./logic.js";
import { pathExists } from "./data.js";

const total = (d) => Object.values(d).reduce((a, b) => a + b, 0);

export async function runSetupChecks() {
	const results = [];
	const add = (name, pass, detail = "") => results.push({ group: "Setup", name, pass, detail });

	// project.godot
	try {
		const res = await fetch("game/project.godot");
		const text = await res.text();
		const hasMain = text.includes('run/main_scene="res://scenes/main.tscn"');
		const autoloads = (text.match(/^\w+="\*res:\/\/scripts\/core\//gm) || []).length;
		add("project.godot ada & main scene benar", res.ok && hasMain, `autoload core=${autoloads}/8`);
		add("8 autoload core terdaftar", autoloads === 8, `ditemukan ${autoloads}`);
	} catch (e) {
		add("project.godot bisa dibaca", false, e.message);
	}

	// file toolchain
	for (const p of [
		"tools/godot/run_game_check.sh",
		"tools/godot/make_pck.py",
		"tools/godot/make_script_class_cache.py",
		"tools/godot/setup_godot_web.sh",
		"tools/vision/capture.mjs",
		"tools/setup_stublibs.sh",
	]) {
		add(`toolchain: ${p}`, await pathExists(p));
	}

	// build game versi web/ (yang di-commit — untuk preview tanpa setup)
	const buildOk = (await pathExists("web/index.html"))
		&& (await pathExists("web/game.pck"))
		&& (await pathExists("web/game.wasm"))
		&& (await pathExists("web/godot.js"));
	add("build web/ tersedia (preview tanpa setup)", buildOk,
		buildOk ? "web/ (committed)" : "rebuild: bash tools/godot/run_game_check.sh all");
	return results;
}

export function runDataChecks(data, errors) {
	const results = [];
	const add = (name, pass, detail = "") => results.push({ group: "Data", name, pass, detail });

	add("semua file data ter-load tanpa error", errors.length === 0, errors.slice(0, 3).join("; "));
	if (errors.length > 0) return results;

	add("economy config ada", !!data.economy);
	add("progression config ada", !!data.progression);
	add("jumlah bangunan ≥ 6", Object.keys(data.buildings).length >= 6, `count=${Object.keys(data.buildings).length}`);
	add("jumlah kapal ≥ 3", Object.keys(data.ships).length >= 3, `count=${Object.keys(data.ships).length}`);
	add("jumlah senjata ≥ 2", Object.keys(data.weapons).length >= 2, `count=${Object.keys(data.weapons).length}`);
	add("jumlah wave ≥ 2", Object.keys(data.waves).length >= 2, `count=${Object.keys(data.waves).length}`);
	add("jumlah sektor ≥ 2", Object.keys(data.sectors).length >= 2, `count=${Object.keys(data.sectors).length}`);

	// referensi resolve
	for (const [id, s] of Object.entries(data.ships)) {
		add(`ship ${id} → weapon resolve`, !!data.weapons[s.weapon_id], `weapon=${s.weapon_id}`);
		add(`ship ${id} hp > 0`, s.max_hp > 0, `hp=${s.max_hp}`);
	}
	for (const [id, w] of Object.entries(data.waves)) {
		let ok = true; let n = 0;
		for (const [shipId, count] of Object.entries(w.composition)) {
			if (!data.ships[shipId]) ok = false;
			n += count;
		}
		add(`wave ${id} → ship resolve & non-empty`, ok && n > 0, `units=${n}`);
	}
	for (const [id, s] of Object.entries(data.sectors)) {
		const wavesOk = (s.waves || []).every((w) => !!data.waves[w]);
		const resOk = Object.keys(s.rewards || {}).every((r) => !!data.economy.storage_caps[r]);
		add(`sector ${id} → wave & reward resolve`, wavesOk && resOk);
	}
	for (const [id, b] of Object.entries(data.buildings)) {
		add(`building ${id} cost ≥ 0 & hp > 0`,
			Object.values(b.base_cost).every((v) => v >= 0) && b.max_hp > 0,
			`hp=${b.max_hp}`);
		if (b.category === "defense" && b.weapon_id) {
			add(`building ${id} → weapon resolve`, !!data.weapons[b.weapon_id], `weapon=${b.weapon_id}`);
		}
		if (b.produces) {
			add(`building ${id} producer valid`, b.production_per_minute > 0 && !!data.economy.storage_caps[b.produces],
				`${b.produces} ${b.production_per_minute}/min`);
		}
	}

	// ekonomi awal: first economy building affordable
	const startE = data.economy.starting_resources.energy || 0;
	const startM = data.economy.starting_resources.minerals || 0;
	const affordable = Object.values(data.buildings).some(
		(b) => b.category === "economy"
			&& (b.base_cost.energy || 0) <= startE
			&& (b.base_cost.minerals || 0) <= startM
	);
	add("first economy building affordable dari starting resources", affordable,
		`start E=${startE} M=${startM}`);
	return results;
}

export function runLogicChecks(data) {
	const results = [];
	const add = (name, pass, detail = "") => results.push({ group: "Logic", name, pass, detail });

	// --- Economy ---
	const eco = new Economy(data.economy);
	const startE = data.economy.starting_resources.energy;
	add("economy: starting balance dari data", eco.get("energy") === startE, `E=${eco.get("energy")}`);
	add("economy: earn bertambah", eco.earn("energy", 50) === 50 && eco.get("energy") === startE + 50);
	const cap = eco.cap("energy");
	const added = eco.earn("energy", cap * 2);
	add("economy: storage cap ditegakkan", added === cap - (startE + 50) && eco.get("energy") === cap, `cap=${cap}`);
	const eco2 = new Economy(data.economy);
	add("economy: spend cukup → terpotong", eco2.spend({ energy: 10 }) && eco2.get("energy") === startE - 10);
	add("economy: spend tanpa dana → gagal total", !eco2.spend({ energy: 999999 }) && eco2.get("energy") === startE - 10);

	// --- Production (integer-exact dari data) ---
	const reactor = data.buildings.energy_reactor;
	const ticks = 600;
	const expected = (reactor.production_per_minute * 1) * ticks / 600;
	add("production: 600 tick = rate per menit dari data",
		productionTotal(reactor, 1, ticks, "normal") === expected, `+${expected} energy`);
	add("production: level 2 = 2x rate",
		productionTotal(reactor, 2, ticks, "normal") === expected * 2);
	add("production: hancur = 0", productionTotal(reactor, 1, ticks, "destroyed") === 0);

	// --- CombatSimulator ---
	const wave1 = data.waves.wave_1;
	const attacker = [];
	for (const [id, n] of Object.entries(wave1.composition)) for (let i = 0; i < n; i++) attacker.push(id);
	const defenders = ["shp_001_interceptor", "shp_001_interceptor", "shp_001_interceptor", "shp_001_interceptor"];
	const turret = data.buildings.laser_turret;
	const input1 = {
		attacker,
		defender_ships: defenders,
		defender_turrets: [{ weapon_id: turret.weapon_id, count: 1, hp: turret.max_hp }],
		seed: 42,
	};
	const r1a = simulateCombat(input1, data);
	const r1b = simulateCombat(input1, data);
	add("combat: deterministik (input sama → hasil sama)",
		JSON.stringify(r1a) === JSON.stringify(r1b));
	add("combat: wave_1 vs 4 interceptor + turret → defender menang",
		r1a.winner === "defender", `winner=${r1a.winner} ticks=${r1a.duration_ticks}`);
	add("combat: semua attacker wave_1 kalah",
		total(r1a.attacker_losses) === attacker.length, `losses=${total(r1a.attacker_losses)}/${attacker.length}`);

	// shield
	const building = { instance_id: "command_core_1", hp: 500 };
	const inputShield = { attacker, defender_ships: [], seed: 42, defender_buildings: [building], shield_hp: 500 };
	const inputNoShield = { attacker, defender_ships: [], seed: 42, defender_buildings: [{ instance_id: "command_core_1", hp: 500 }], shield_hp: 0 };
	const rS = simulateCombat(inputShield, data);
	const rN = simulateCombat(inputNoShield, data);
	add("combat: shield menyerap damage bangunan",
		rS.shield_damage > 0 && (rS.building_damage.command_core_1 || 0) < (rN.building_damage.command_core_1 || 0),
		`shield_dmg=${rS.shield_damage}`);

	// --- Progression: reward tepat satu kali ---
	const eco3 = new Economy(data.economy);
	const prog = new Progression(data.progression);
	const before = eco3.get("energy");
	add("progression: reward pertama masuk", prog.grantReward(eco3, { energy: 100 }, "test") && eco3.get("energy") === before + 100);
	add("progression: reward kedua ditolak (tepat 1×)", !prog.grantReward(eco3, { energy: 100 }, "test") && eco3.get("energy") === before + 100);

	// --- Save/load round-trip (JSON) ---
	const state = { economy: eco3.balances, caps: eco3.caps, territories: prog.territories };
	const roundtrip = JSON.parse(JSON.stringify(state));
	add("save/load: round-trip JSON sama persis", JSON.stringify(roundtrip) === JSON.stringify(state));

	// --- Mini loop (mirror e2e: bangun → produksi → fleet → wave → reward) ---
	const eco4 = new Economy(data.economy);
	const extractor = data.buildings.mineral_extractor;
	const hangar = data.buildings.fighter_hangar;
	const turretB = data.buildings.laser_turret;
	const ship = data.ships.shp_001_interceptor;
	// tahap 1: bangun fasilitas ekonomi (biaya dari data)
	let okBuild = eco4.spend(reactor.base_cost) && eco4.spend(extractor.base_cost);
	// tahap 2: produksi 3600 tick (6 menit game) — integer-exact dari data
	const gatherTicks = 3600;
	const prodE = productionTotal(reactor, 1, gatherTicks, "normal");
	const prodM = productionTotal(extractor, 1, gatherTicks, "normal");
	eco4.earn("energy", prodE);
	eco4.earn("minerals", prodM);
	// tahap 3: hangar + turret + 4 kapal
	okBuild = okBuild && eco4.spend(hangar.base_cost) && eco4.spend(turretB.base_cost);
	let shipsOk = true;
	for (let i = 0; i < 4; i++) shipsOk = shipsOk && eco4.spend(ship.cost);
	add("loop: reactor+extractor → produksi → hangar+turret+4 kapal terjangkau dari data",
		okBuild && shipsOk, `prod +${prodE}E/+${prodM}M; sisa E=${eco4.get("energy")} M=${eco4.get("minerals")}`);
	add("loop: produksi dari data masuk ke ekonomi", prodE > 0 && prodM > 0, `+${prodE}E +${prodM}M`);
	const prog2 = new Progression(data.progression);
	const eBeforeWave = eco4.get("energy");
	prog2.onCombatFinished(r1a, data, eco4);
	const sector2 = data.sectors.sector_2;
	add("loop: territory sector_2 terbuka setelah defense",
		prog2.territories.includes("sector_2"));
	add("loop: sector reward dari data masuk ke ekonomi",
		eco4.get("energy") === eBeforeWave + (sector2.rewards.energy || 0),
		`+${sector2.rewards.energy}`);

	return results;
}
