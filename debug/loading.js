/**
 * loading.js — fungsi bersama loading screen (slideshow + icon + animasi).
 * Dipakai oleh index.html (game) dan debug.html (dashboard).
 */

/** Mulai slideshow background (crossfade tiap 4 detik). */
export function startSlideshow() {
	const slides = [...document.querySelectorAll(".loading-slides .slide")];
	if (slides.length < 2) return;
	let i = 0;
	setInterval(() => {
		slides[i].classList.remove("active");
		i = (i + 1) % slides.length;
		slides[i].classList.add("active");
	}, 4000);
}

/** Sembunyikan loading screen (fade out). */
export function hideLoading() {
	const loading = document.getElementById("loading");
	if (loading) loading.classList.add("hidden");
}

/** Ubah teks loading. */
export function setLoadingText(text) {
	const el = document.getElementById("loading-text");
	if (el) el.textContent = text;
}

/** Progress determinate (0-100) — saat load engine/wasm. */
export function setProgress(pct) {
	const pct01 = Math.max(0, Math.min(100, pct));
	const fill = document.querySelector(".loading-bar-fill");
	if (fill) {
		fill.classList.add("determinate");
		fill.style.width = pct01 + "%";
	}
	const pctEl = document.getElementById("loading-pct");
	if (pctEl) pctEl.textContent = Math.round(pct01) + "%";
}

/** Tampilkan error di loading screen (misal build game belum ada). */
export function showError(msg) {
	const text = document.getElementById("loading-text");
	if (text) {
		text.textContent = msg;
		text.classList.add("error");
	}
	const progress = document.querySelector(".loading-progress");
	if (progress) progress.style.display = "none";
	const icon = document.getElementById("loading-icon");
	if (icon) icon.style.animation = "none";
	console.error("LOADING:ERROR", msg);
}
