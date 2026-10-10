/**
 * data.js — load semua data game (game/data/*.tres) lewat fetch dari server
 * root repo. Mengembalikan struktur sama dengan yang dipakai sistem Godot.
 */
import { parseTres } from "./tres.js";

const DATA_DIRS = {
	buildings: "buildings",
	ships: "ships",
	weapons: "weapons",
	waves: "waves",
	sectors: "sectors",
};

async function listTres(dir) {
	const res = await fetch(`game/data/${dir}/`);
	if (!res.ok) throw new Error(`tidak bisa list game/data/${dir}/ (HTTP ${res.status})`);
	const html = await res.text();
	return [...html.matchAll(/href="([^"?]+\.tres)"/g)].map((m) => m[1]);
}

export async function loadGameData() {
	const data = { buildings: {}, ships: {}, weapons: {}, waves: {}, sectors: {} };
	const errors = [];

	for (const f of ["economy.tres", "progression.tres"]) {
		try {
			const res = await fetch(`game/data/${f}`);
			if (!res.ok) { errors.push(`missing game/data/${f}`); continue; }
			const parsed = parseTres(await res.text());
			if (f === "economy.tres") data.economy = parsed.props;
			else data.progression = parsed.props;
		} catch (e) {
			errors.push(`gagal load game/data/${f}: ${e.message}`);
		}
	}

	for (const [cat, dir] of Object.entries(DATA_DIRS)) {
		let files = [];
		try {
			files = await listTres(dir);
		} catch (e) {
			errors.push(e.message);
			continue;
		}
		for (const f of files) {
			try {
				const res = await fetch(`game/data/${dir}/${f}`);
				if (!res.ok) { errors.push(`missing game/data/${dir}/${f}`); continue; }
				const parsed = parseTres(await res.text());
				const id = parsed.props.id;
				if (!id) errors.push(`id kosong di ${dir}/${f}`);
				else if (data[cat][id]) errors.push(`id duplikat ${id} di ${dir}/${f}`);
				else data[cat][id] = parsed.props;
			} catch (e) {
				errors.push(`gagal parse ${dir}/${f}: ${e.message}`);
			}
		}
	}
	return { data, errors };
}

export async function pathExists(path) {
	try {
		const res = await fetch(path, { method: "HEAD" });
		return res.ok;
	} catch {
		return false;
	}
}
