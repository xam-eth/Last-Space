# Doomsday: Last Survivors — Frame-by-Frame Gameplay Research

Research lengkap (2026-10-11) untuk reference UI/UX & gameplay flow Last-Space.
Sumber: screenshot resmi (Google Play / Uptodown / levelwinner / reddit /
iofreeonline) tersimpan di folder ini (30 file), beginner guides (levelwinner,
ldshop, packsify, gameloop, fandom wiki), deskripsi store.
**Lisensi:** screenshot milik IGG — dipakai sebagai **referensi research
internal** (bukan aset game, tidak untuk dipublikasi ulang).

> Konteks: Doomsday: Last Survivors = mobile **base-building survival 3D**
> (shelter, resource, troops, heroes, world map, PvE/PvP). Sama dengan
> Last-Space secara struktur (base + armada + defense + ekspansi) — beda
> tema (zombie vs alien) & unit (troops vs pesawat).

---

## Frame 0 — Splash / Loading
- **Visual:** logo IGG / game, background kota hancur. Progress bar bawah.
- **Logika:** load asset → masuk login/menu.
- **→ Last-Space:** ✅ sudah ada (loading screen cinematic, `01_loading_screen.png`).

## Frame 1 — Login / Main Menu
- **Visual:** background kota rusak + karakter; tombol **Login/Start** besar bawah tengah; atas: ikon store/event.
- **Logika:** pilih server → masuk shelter (base).
- **→ Last-Space:** 🔶 Main menu (Play/Settings) — backlog M3 #4. Root page langsung game (sesuai requirement human: halaman utama = GAME).

## Frame 2 — Tutorial (story combat pertama)
- **Visual:** gameplay 3D (jalan kota rusak) + **dialog bubble bawah tengah** (nama karakter + teks) + instruksi langkah (panah kuning di atas objek) + tombol aksi kanan bawah (kotak/ikon besar).
- **Elemen:** top-left fullscreen icon; bottom-left chat mini; bottom-right circular action button; tengah-bawah dialog bubble.
- **Logika:** guided step-by-step (tap objek → aksi → lanjut), tidak bisa skip cepat.
- **→ Last-Space:** 🔶 tutorial guided (dialog bubble + highlight) — backlog. Toast sistem sudah ada.

## Frame 3 — SHELTER BASE VIEW (gameplay utama) ⭐
Screenshot: `doomsday-last-survivors-shelter-base-vie-1.webp` (1000×481),
`...-vie-4.jpg` (Headquarters), `...-troops-training--4.jpg` (Radar Station).

- **Visual:** canvas 3D isometric full screen — shelter (bangunan tersebar di tanah), karakter kecil, kendaraan.
- **Top bar (penuh lebar, tinggi ~48dp):**
  - **Kiri:** avatar pemain (kotak, ~40dp) + power (angka besar) + VIP badge + 2 ikon kecil; bawah avatar: jam server (UTC).
  - **Tengah:** 5 **resource chips** horizontal (ikon + angka + `+` kecil): food, wood, steel, (oil), gem.
  - **Kanan:** event icons (Club VIP, VIP Pass + countdown, 1st Buy, Mall, event banner) + ikon kecil lain.
- **Kiri tengah — QUEST PANEL** (lebar ~22% layar): list misi aktif (nama misi + progress "6/8" + bar/angka, contoh: "Towards Dawn", "Fully Armed 290.9K/480.0K", "Strengthen D... 4/5"). Panel semi-transparan.
- **Kiri bawah:** tombol **Region** (ikon globe, ~48dp) + **chat** (3 baris pesan + avatar + input).
- **Tengah bawah — 3 TOMBOL BESAR BULAT** (~64dp, ikon + label bawah): **Info**, **Intel**, **Events** (Radar Station terpilih). Pada HQ: **Info**, **Level Up** (panah kuning di atas = aksi utama), **Buff**, **Skins**.
- **Kanan bawah — 4 TOMBOL BULAT** (~56dp, ikon + label): **Campaign**, **Bag**, **Alliance**, **Hero**; pojok kanan bawah: **hamburger menu** (settings/pause). Di atasnya: ikon kecil (mail + badge angka, countdown event, kotak, chat) + portrait kecil.
- **Kanan tengah:** indikator bangunan lain (ikon tangan = bantuan alliance, panah kuning, progress bar hijau).
- **Tengah (saat bangunan dipilih):** nama bangunan besar + level + **2 panah hijau** kiri-kanan (indikator fokus).
- **Logika:** klik bangunan → fokus + aksi konteks; klik kosong → build; resource update real-time; quest panel auto-update.
- **Ukuran (dari screenshot 1000×481, tinggi = 360dp):**
  top bar ≈ 48dp; tombol bawah ≈ 48–64dp (ikon 40dp + label 12pt); chip resource ≈ 110×36dp; quest panel ≈ 220×180dp kiri tengah; avatar 40dp.
- **→ Last-Space mapping:**
  - ✅ Top bar resource chips (ENERGY/MINERALS/FLEET) — sudah ada, full width.
  - ✅ Action grid kanan bawah (ikon 48dp) — sudah ada (7 tombol).
  - ✅ Info panel kiri bawah — sudah ada (log/toast).
  - ✅ Wave indicator tengah atas — sudah ada.
  - ✅ Menu button kanan atas — sudah ada (ikon 40dp).
  - ➕ **BARU (disarankan adopsi): quest/mission panel kiri tengah** (progress misi aktif) — ganti/extend info panel.
  - ➕ **Tombol Region/world map kiri bawah** (ikon globe 48dp) — untuk ekspansi sektor (M3/M4).
  - ➕ **Chat kiri bawah** — future (multiplayer? default single-player, skip).
  - ➕ **Indikator bangunan terpilih** (nama + level + panah hijau + aksi konteks bawah: Info/Level Up/Buff) — saat klik bangunan di base 3D.
  - ➕ **Event icons kanan atas** — future (event/penawaran; Last-Space tanpa monetisasi → ganti jadi notifikasi/event game).
  - ➕ **Hamburger menu kanan bawah** — pause/settings (gabung dengan menu kanan atas).

## Frame 4 — BUILDING SELECTED (panel konteks)
Screenshot: `...-vie-4.jpg` (Headquarters Level 10).
- **Visual:** sama base view + fokus HQ (nama + "Level 10" + panah hijau) + **tombol aksi konteks bawah tengah**: Info, **Level Up** (utama, panah kuning di atas), Buff, Skins.
- **Logika:** tap bangunan → panel info/upgrade muncul; Level Up → cek resource → konstruksi (timer); Buff → bonus sementara.
- **→ Last-Space:** ➕ klik bangunan di base 3D → panel info + tombol Upgrade (Level Up) + progress konstruksi. Build menu (Frame 5) untuk bangunan baru.

## Frame 5 — BUILD / CONSTRUCT MENU (modal)
- **Visual:** modal panel tengah (lebih kecil dari BAG), list bangunan yang bisa dibangun/upgrade: ikon + nama + level + requirement (resource + HQ level) + tombol.
- **Logika:** pilih → cek resource & prasyarat (HQ level) → mulai konstruksi (timer, antrian).
- **→ Last-Space:** 🔶 **Build menu (M3 #1)** — card bangunan (ikon 48dp + nama + level + biaya + waktu + tombol BUILD/UPGRADE), pola Doomsday.

## Frame 6 — BAG / INVENTORY (modal)
Screenshot: `doomsday-last-survivors-mobile-game-shel-2.webp`.
- **Visual:** modal besar tengah. **Top bar** resource chips tetap terlihat di atas modal. Title "BAG" kiri atas + **close X kanan atas**. **Sidebar kiri** tabs vertikal: RESOURCE / SPEED UP (badge 4) / BUFF (badge 2) / MATERIALS / OTHER (badge 24). **Tengah:** grid 5 kolom **item cards** (ikon kotak + quantity angka bawah, bingkai warna tier). **Kanan — detail panel:** ikon besar, nama ("50 Gem"), "Owned: 8", deskripsi, stepper (- 1 + MAX), tombol **USE** besar bawah.
- **Logika:** pilih item → detail; USE → konsumsi.
- **Ukuran:** card ≈ 56dp square; sidebar tab ≈ 48dp tinggi; tombol USE tinggi 48dp.
- **→ Last-Space:** pola modal (title + close + sidebar tabs + grid cards + detail + tombol besar) untuk **Build menu** & **Ship menu**. (Last-Space tidak ada inventory item — ganti jadi daftar bangunan/kapal.)

## Frame 7 — HERO MENU (modal)
Screenshot: `doomsday-last-survivors-mobile-game-shel-5.jpg`.
- **Visual:** modal besar. Kiri: **grid hero cards** (portrait kotak + bingkai tier + level). Kanan: hero besar (Jaden) + nama + **5 star rating** + power (angka besar 69) + stats + **2 tombol besar bawah** (TA NÂNG / AT BÁNNG = naik level / naik bintang).
- **Logika:** pilih hero → detail; upgrade pakai badge/manual.
- **→ Last-Space:** pola untuk **Ship menu (M3 #2)**: grid ship cards (portrait/ikon + nama + kelas) + detail kanan (model/nama/stats/HP) + tombol besar (PRODUCE/REPAIR).

## Frame 8 — RADAR / INTEL / EVENTS (panel kiri)
Screenshot: `...-troops-training--4.jpg` (Radar Station), quest panel kiri.
- **Visual:** panel kiri (quest list + progress) + tengah: Radar Station (nama + level + panah hijau) + bawah tengah: Info / Intel / Events.
- **Logika:** radar mendeteksi event (zombie, resource spot) → kirim squad (march) → dapat reward; exploration level naik.
- **→ Last-Space:** ✅ analog = **Radar mendeteksi armada alien → wave incoming** (sudah ada: WaveDirector + wave indicator). ➕ quest/mission panel kiri tengah (progress objektif) — adopsi.

## Frame 9 — WORLD MAP / REGION (ekspansi)
Screenshot: `doomsday-last-survivors-world-map-region-*.webp`, `...-shelter-base-vie-1.webp` ("BRAVE OFF-LIMITS ZONE").
- **Visual:** peta dunia (spherical/flat) full screen; **top bar** resource tetap; zona dengan **foto landscape** (danau, gunung berapi, gurun, hutan) sebagai ikon besar; pemain + squad sebagai marker; bawah tengah: judul zona; kiri bawah: search icon.
- **Logika:** pilih zona → deploy squad (march) → gather/kill zombie/attack; fog of war; zone unlock bertahap.
- **→ Last-Space:** 🔶 **World map / sektor ekspansi (M4)** — peta galaksi dengan sektor (foto/ikon sektor: asteroid, stasiun, planet), marker armada, kirim armada untuk kuasai. Tombol Region kiri bawah (Frame 3) untuk pindah shelter ↔ world map.

## Frame 10 — MARCH / BATTLE (combat)
- **Visual:** world map dengan squad bergerak (march line), atau battle view: troops vs zombie (3D), hero skill efek, HP bar musuh atas, hasil menang/kalah + report (loot, kerusakan).
- **Logika:** kirim squad → march timer → battle auto (statistik) → report + reward; kalah → troops mati/hospital.
- **→ Last-Space:** ✅ analog = **Combat Mode** (sudah ada): hasil dari CombatSimulator (fixed seed) → CombatVisualizer 3D (defender vs alien ALN-001, turret, ledakan, hasil toast). ➕ battle report panel (loot/kerusakan) — adopsi untuk hasil wave.

## Frame 11 — ALLIANCE (modal/sosial)
Screenshot: `...-build-construct--2.jpg` (alliance help points).
- **Visual:** panel alliance: chat, anggota list, bantuan (ikon tangan + progress bar + poin), event alliance.
- **Logika:** join alliance → bantuan bangun/research, reinforcement, rally.
- **→ Last-Space:** ❌ tidak diadopsi (default single-player, no backend — keputusan ROADMAP). Bantuan → ganti jadi **repair dock assist internal**.

## Frame 12 — SHOP / MALL / VIP (monetisasi)
Screenshot: top bar kanan (Mall, VIP Pass, 1st Buy, Club VIP).
- **Visual:** shop grid item (harga gem), VIP pass panel (benefit list + progress).
- **→ Last-Space:** ❌ tidak ada monetisasi (keputusan ROADMAP: none planned). Event icons kanan atas → ganti **notifikasi/event game** (tanpa IAP).

## Frame 13 — SETTINGS (dari hamburger menu kanan bawah)
- **Visual:** modal: tab (Gameplay/Display/Audio/UI/Language) + opsi + tombol.
- **→ Last-Space:** 🔶 Settings modal (M3 #5): audio, fullscreen, bahasa, reset progress.

---

## Ringkasan pola yang diadopsi untuk Last-Space (prioritas)

| # | Pola Doomsday | Last-Space | Prioritas |
|---|---|---|---|
| 1 | Top bar resource chips + wave/countdown tengah + menu kanan | ✅ sudah ada | — |
| 2 | Tombol aksi bawah (ikon besar + label) kanan bawah | ✅ action grid (ikon-only 48dp) | — |
| 3 | Info/log panel kiri bawah | ✅ info panel | — |
| 4 | **Quest/mission panel kiri tengah (progress objektif)** | ➕ tambah ke info panel | M3 |
| 5 | **Tombol Region (world map) kiri bawah** | ➕ sektor ekspansi | M3/M4 |
| 6 | **Indikator bangunan terpilih + aksi konteks (Info/Level Up/Buff)** | ➕ klik bangunan di 3D | M3 #1 |
| 7 | **Modal: title + close + sidebar tabs + grid cards + detail + tombol besar** | ➕ Build menu & Ship menu | M3 #1/#2 |
| 8 | Card: ikon/portrait + nama + level + quantity + bingkai | ➕ card bangunan/kapal | M3 #1/#2 |
| 9 | Dialog bubble bawah tengah (tutorial) | 🔶 tutorial guided | backlog |
| 10 | World map dengan zona (foto landscape) + march | 🔶 peta sektor galaksi | M4 |
| 11 | Battle report (loot/kerusakan) | ➕ hasil wave report | M3 |
| 12 | Hamburger menu kanan bawah (settings) | ➕ pause/settings | M3 #3/#5 |
| 13 | Alliance / Shop / VIP / chat | ❌ skip (single-player, no monetisasi) | — |

**Catatan ukuran (standar, dari screenshot 1000×481 ≈ tinggi 360dp):**
top bar 48dp; tombol bawah 48–64dp (ikon 40dp + label); chip resource 110×36dp;
card item/hero 56dp square; sidebar tab 48dp; modal ≤ 80% lebar; margin 12dp.
Semua konsisten dengan `UI_UX_DESIGN.md` §3 (dp, 48dp touch, 8dp grid).
