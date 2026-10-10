/**
 * app.js — dashboard Debug & Preview Last-Space.
 * Dijalankan dari index.html (root repo) via: python3 -m http.server 8000 --bind 0.0.0.0
 * Meng-import modul debug/*.js — SEMUA check jalan di browser, berbasis data nyata.
 */
import { loadGameData, pathExists } from "./data.js";
import { runSetupChecks, runDataChecks, runLogicChecks } from "./checks.js";

function el(tag, className, text) {
	const e = document.createElement(tag);
	if (className) e.className = className;
	if (text !== undefined) e.textContent = text;
	return e;
}

function renderCheck(container, c) {
	const row = el("div", "check");
	row.appendChild(el("span", "name", c.name));
	row.appendChild(el("span", "detail", c.detail || ""));
	row.appendChild(el("span", `badge ${c.pass ? "pass" : "fail"}`, c.pass ? "PASS" : "FAIL"));
	container.appendChild(row);
}

async function main() {
	const content = document.getElementById("content");
	content.textContent = "";

	// --- load data game ---
	const loading = el("section", "", "Memuat data game (game/data/*.tres)…");
	content.appendChild(loading);
	const { data, errors } = await loadGameData();

	// --- jalankan semua check ---
	const setup = await runSetupChecks();
	const dataChecks = runDataChecks(data, errors);
	const logic = runLogicChecks(data);
	const all = [...setup, ...dataChecks, ...logic];
	const passed = all.filter((c) => c.pass).length;
	const failed = all.filter((c) => !c.pass).length;
	for (const c of all.filter((c) => !c.pass)) {
		console.log(`DEBUG:CHECK:FAIL [${c.group}] ${c.name} | ${c.detail}`);
	}

	// --- summary ---
	const summary = document.getElementById("summary");
	summary.textContent = `HASIL: ${passed}/${all.length} check PASS — ${failed} FAIL`;
	summary.classList.add(failed === 0 ? "all-pass" : "has-fail");
	console.log(`DEBUG:PAGE:DONE passed=${passed} failed=${failed} total=${all.length}`);

	// --- render per group ---
	for (const group of ["Setup", "Data", "Logic"]) {
		const section = el("section");
		section.appendChild(el("h2", "", group));
		const rows = all.filter((c) => c.group === group);
		if (rows.length === 0) section.appendChild(el("p", "hint", "tidak ada check"));
		for (const c of rows) renderCheck(section, c);
		content.appendChild(section);
	}

	// --- preview game (Godot web build) ---
	const preview = el("section");
	preview.appendChild(el("h2", "", "🎮 Preview Game (Godot web build)"));
	const buildReady = await pathExists("tools/godot/build/game/index.html");
	if (buildReady) {
		const frame = el("iframe", "preview");
		frame.src = "tools/godot/build/game/index.html";
		frame.title = "Last-Space game preview";
		preview.appendChild(frame);
		preview.appendChild(el("p", "hint",
			"Game berjalan di atas: build → produce → fleet → alien wave. " +
			"Rebuild: bash tools/godot/run_game_check.sh all"));
	} else {
		preview.appendChild(el("p", "hint",
			"Build game belum ada. Jalankan: bash tools/godot/run_game_check.sh all " +
			"(atau minimal: python3 tools/godot/make_script_class_cache.py game && " +
			"python3 tools/godot/make_pck.py game tools/godot/build/game/game.pck lalu salin shell+runtime)."));
	}
	content.appendChild(preview);

	// marker akhir untuk verifikasi otomatis
	console.log("DEBUG:PAGE:COMPLETE");
}

main().catch((e) => {
	console.error("DEBUG:PAGE:ERROR", e);
	document.getElementById("summary").textContent = `ERROR: ${e.message}`;
});
