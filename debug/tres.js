/**
 * tres.js — parser file .tres Godot (versi cukup untuk data game kita).
 * Mendukung: StringName (&"x"), String, number, bool, Dictionary, Array,
 * Vector2i, ExtResource, komentar (;), section [gd_resource]/[ext_resource]/[resource].
 */

function splitTop(s) {
	const parts = [];
	let depth = 0;
	let cur = "";
	let inStr = false;
	for (let i = 0; i < s.length; i++) {
		const c = s[i];
		if (inStr) {
			cur += c;
			if (c === '"') inStr = false;
			continue;
		}
		if (c === '"') { inStr = true; cur += c; continue; }
		if (c === "{" || c === "[") depth++;
		if (c === "}" || c === "]") depth--;
		if (c === "," && depth === 0) { parts.push(cur.trim()); cur = ""; continue; }
		cur += c;
	}
	if (cur.trim() !== "") parts.push(cur.trim());
	return parts;
}

export function parseValue(v) {
	v = v.trim();
	if (v === "{}") return {};
	if (v === "[]") return [];
	let m;
	if ((m = v.match(/^&"(.*)"$/))) return m[1]; // StringName → string polos
	if ((m = v.match(/^"(.*)"$/))) return m[1];
	if (v === "true") return true;
	if (v === "false") return false;
	if ((m = v.match(/^Vector2i\((.*)\)$/))) {
		const [x, y] = splitTop(m[1]).map(Number);
		return { __vector2i: [x, y] };
	}
	if ((m = v.match(/^ExtResource\("(.*)"\)$/))) return { __ext: m[1] };
	if (v.startsWith("{")) {
		const out = {};
		for (const part of splitTop(v.slice(1, -1))) {
			const idx = part.indexOf(":");
			const k = parseValue(part.slice(0, idx).trim());
			out[typeof k === "string" ? k : String(k)] = parseValue(part.slice(idx + 1).trim());
		}
		return out;
	}
	if (v.startsWith("[")) {
		return splitTop(v.slice(1, -1)).map(parseValue);
	}
	if (/^-?\d+(\.\d+)?$/.test(v)) return Number(v);
	return v;
}

export function parseTres(text) {
	const sections = { resource: [] };
	let current = null;
	for (const raw of text.split(/\r?\n/)) {
		const line = raw.trim();
		if (line === "" || line.startsWith(";")) continue;
		const sec = line.match(/^\[(gd_resource|ext_resource|sub_resource|resource)\b/);
		if (sec) { current = sec[1]; continue; }
		if (current === "resource" && line.includes("=")) {
			const idx = line.indexOf("=");
			sections.resource.push({ key: line.slice(0, idx).trim(), val: line.slice(idx + 1).trim() });
		}
	}
	const props = {};
	for (const { key, val } of sections.resource) props[key] = parseValue(val);
	return { props };
}
