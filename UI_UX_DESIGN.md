# UI/UX DESIGN — Last-Space (Workflow Desain Awal)

Dokumen ini menetapkan **workflow UI/UX awal game** — disiapkan SEBELUM
Milestone 2 (sesuai requirement human developer). Menggabungkan
`ART_DIRECTION.md` §8 (tema UI), `Asset_Request_List.md` Kelompok I/N
(UI & menu), dan `Game_Concept.md` §7.

> **Catatan human developer (tercatat):** game ini **bukan game "asal jalan"** —
> UI/UX dan visualnya harus real game. Loading screen, menu, dan HUD harus
> terasa seperti game sungguhan, bukan placeholder.

## 1. Prinsip Desain

1. **Tema: military command holographic** — panel taktis, garis tipis, aksen
   cyan hologram, indikator ancaman merah. Konsisten dengan `ART_DIRECTION.md`.
2. **Informasi jelas tanpa mengganggu** — HUD tidak menutupi benteng/armada.
3. **Real values** — UI menampilkan nilai aktual dari sistem (read-only),
   tidak pernah mengarang angka (DATA_CONTRACTS.md §1).
4. **Responsif & terbaca** — panel/ikon harus terbaca di layar kecil (mobile).
5. **16:9 full landscape** — layar game selalu 16:9 (viewport 1920×1080,
   stretch `canvas_items` + aspect `keep`; letterbox warna dark space).
6. **Satu design system** — warna, font, komponen yang sama di semua layar.

## 2. Inventaris Layar (Screen Inventory)

| # | Layar | Status | Keterangan |
|---|---|---|---|
| 1 | **Loading Screen** | ✅ implemented (website) | Slideshow background cinematic + icon + animasi |
| 2 | **Main Menu** | PLANNED (M2) | New Game / Continue / Settings / Quit |
| 3 | **Command Mode HUD** | ✅ implemented (in-game) | Resource HUD, fleet, build menu, ship button |
| 4 | **Build Menu** | ✅ implemented (in-game) | Tombol per bangunan unlocked (biaya dari data) |
| 5 | **Production Queue** | PLANNED (M2) | Antrian konstruksi/kapal/repair + progress |
| 6 | **Battle HUD** | ✅ implemented (in-game) | Wave warning, result panel |
| 7 | **Galaxy Map** | PLANNED (M2) | Node sektor, territory, rute |
| 8 | **Settings** | PLANNED (M2) | Grafik, audio, bahasa |
| 9 | **Pause Menu** | PLANNED (M2) | Resume / Save / Load / Quit |

## 3. Design System

### 3.1 Palet Warna

| Token | Warna | Penggunaan |
|---|---|---|
| `bg` | `#05070f` | Latar belakang utama (deep space) |
| `panel` | `#0b1020` | Panel/kartu |
| `border` | `#1c2a4a` | Garis tepi panel |
| `text` | `#d7e3ff` | Teks utama |
| `muted` | `#8fa3c8` | Teks sekunder |
| `accent` | `#7df9ff` | Aksen cyan (hologram, fokus) |
| `danger` | `#ff5c5c` | Ancaman/arus merah |
| `pass` | `#2ecc71` | Sukses/positif |
| `energy` | `#ffd75f` | Resource energy |
| `minerals` | `#c8b48a` | Resource minerals |

### 3.2 Tipografi

- **Judul:** sans-serif bold, letter-spacing lebar (military/tactical).
- **HUD/angka:** monospace untuk angka (mudah dibaca saat berubah cepat).
- **Ukuran minimum:** 12px (mobile), 14px (desktop).

### 3.3 Komponen Standar

| Komponen | Spesifikasi |
|---|---|
| Panel | `panel` bg, `border` 1px, radius 8px, padding 12–16px |
| Button | Panel + teks; hover: aksen; disabled: muted; biaya ditampilkan di tombol |
| Resource Bar | Ikon + nilai `X / Y` (nilai aktual + cap) + warna resource |
| Progress Bar | Tinggi 6px, warna aksen, latar panel |
| Badge | Kecil, uppercase, warna status (pass/danger/warn) |
| Icon | 1:1, grid konsisten, gaya sama (icon design system) |

## 4. Workflow: Desain → Aset → Implementasi → Verifikasi

```
1. DESAIN     — sketsa/wireframe layar + spesifikasi komponen (dokumen ini)
2. ASET       — generate/buat gambar (background, ikon, sprite) → assets/ui/...
                (2D sprite & foto: lihat §5; aturan AI-gen: AI_GOVERNANCE.md §11)
3. IMPLEMENTASI — Godot UI (game/) atau HTML/CSS (website root); komponen dari
                design system §3; UI read-only dari sistem (EventBus/API)
4. VERIFIKASI — vision screenshot (capture.mjs) + acceptance check; tidak boleh
                "asal jalan" — cek terbaca, konsisten, nilai nyata
5. REVIEW     — human developer review visual (real game, bukan placeholder)
```

## 5. Aset 2D (Sprite & Foto) — Loading Screen ✅ (session ini)

Lokasi: `assets/ui/loading/`

| File | Jenis | Penggunaan |
|---|---|---|
| `bg_01_nebula_fleet.jpg` | foto cinematic | Slideshow loading background 1 |
| `bg_02_battle_station.jpg` | foto cinematic | Slideshow loading background 2 |
| `bg_03_alien_fleet.jpg` | foto cinematic | Slideshow loading background 3 |
| `bg_04_space_battle.jpg` | foto cinematic | Slideshow loading background 4 |
| `bg_05_asteroid_planet.jpg` | foto cinematic | Slideshow loading background 5 |
| `icon_loading.png` | ikon (transparan) | Icon loading + animasi (spin + pulse glow) |

**Loading screen (website, root `index.html`):** slideshow 5 background
(crossfade tiap 4 detik) + overlay gelap + icon loading berputar + judul
"LAST-SPACE" + teks loading + progress bar animasi. Muncul saat halaman dimuat,
hilang (fade out) setelah semua check selesai (`DEBUG:PAGE:COMPLETE`).

**Aturan aset 2D ke depan (game):**
- Sprite/UI game masuk `game/assets/2d/...` (res://) — lihat `ASSET_PIPELINE.md` §4.
- Ikon: satu icon design system (grid, stroke, palet sama).
- Foto background game (menu/loading): format JPG/PNG, 16:9, epic cinematic,
  konsisten dengan palet §3.1.
- Aset hasil AI (foto/sprite) tetap melewati 10-step review
  (`ASSET_ACCEPTANCE_CRITERIA.md`) sebelum dipakai.

## 6. Loading Animation (spesifikasi)

- **Icon:** `icon_loading.png` berputar 360° tiap 1.6s (linear, infinite) +
  pulse glow (box-shadow cyan yang mengembang-empis tiap 1.6s).
- **Progress bar:** lebar 0→100% dengan pola indeterminate (CSS animation),
  warna aksen cyan di atas panel.
- **Slideshow:** 5 background, crossfade 1.2s, interval 4s per gambar,
  loop. Di belakang overlay gelap (rgba(5,7,15,0.55)) agar teks terbaca.

## 7. Acceptance Criteria UI/UX (checklist per layar)

- [ ] Semua teks/angka terbaca (kontras cukup, ukuran ≥ 12px)
- [ ] Nilai yang ditampilkan = nilai aktual sistem (bukan placeholder)
- [ ] Komponen konsisten dengan design system §3
- [ ] Tidak ada elemen yang menutupi konten penting (base/armada)
- [ ] Loading/menu/HUD terlihat seperti game sungguhan (real game)
- [ ] Verifikasi visual: screenshot via `capture.mjs` + review human developer
- [ ] Tidak ada error console saat layar tampil

## 8. Terkait

- `ART_DIRECTION.md` — standar visual (ikon, UI, VFX)
- `ASSET_PIPELINE.md` / `ASSET_ACCEPTANCE_CRITERIA.md` — pipeline & acceptance aset
- `QA_PLAN.md` — gate verifikasi (setiap layar diverifikasi sebelum lanjut)
- `DEV_PLAN.md` — M2: implementasi layar menu/galaxy map/settings dari dokumen ini
