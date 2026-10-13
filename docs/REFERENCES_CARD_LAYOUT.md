# Referensi Tata Letak CARD — Riset (M3.7c)

Status: **VERIFIED** (sumber diambil dan dibaca 2026-10-13; bukan asumsi).
Tujuan: menjawab kritik user — *"search lagi reference ui ux card layout game strategi lain,
tata letak component nya dll, tiru itu. Satu catatan yg paling utama: semua card itu 70% tidak
ada teks label; yang pakai label cuma menu, itu pun tidak semua."*

## 1. Aturan yang diambil dari catatan user (kriteria penerimaan)

| Aturan | Arti teknis | Bukti otomatis |
|---|---|---|
| "card 70% tidak ada teks label" | Mayoritas **card/ tile katalog** tanpa label kata: art/ikon dominan; angka boleh | `QA:CARD:SUMMARY menu=build tiles=5 with_text=0 label_free_pct=100` + test `ui.cards_label_free_70` (ambang ≥70%) |
| "yang pakai label cuma menu" | Label teks hidup di **chrome menu**: judul, chip resource, panel detail (KATEGORI/BIAYA/WAKTU), tombol aksi | `QA:HUD:LABELS total=10 labeled=10 unlabeled=[]` (chrome HUD + modal) |
| "itu pun tidak semua" | Tidak semua elemen menu berlabel: **tab kategori = ikon saja** | test `ui.cards_tabs_icon_only` (0 Label di dalam `CategoryTabs`) |
| "tiru tata letak game strategi" | Tab ikon di atas grid tile art-dominan + badge angka + panel detail terpisah | Bagian 2 di bawah (sumber) + `docs/ui_m3_build_menu/02_build_menu_*.png` |

## 2. Sumber yang dibaca (2026-10-13)

| # | Sumber | Yang diambil |
|---|---|---|
| 1 | Clash of Clans — UI revamp (blog resmi Supercell, supercell.com) | Tombol *Build/Shop* jadi satu rumah dengan **4 TAB** (Building & Heroes / Army Upgrades / Hero Equipment / Hero Pets); kategori dipindah ke tab, bukan daftar teks berderet |
| 2 | gameuidatabase.com — Clash of Clans | HUD memakai **image grid + tile menu + diegetic icon**: ikon adalah elemen utama, teks minim |
| 3 | interfaceingame.com — Clash of Clans (quest/inventory/BAG) | Inventaris = **grid tile**, item punya badge/kuantitas, detail muncul saat item dipilih |
| 4 | tekrevol.com — mobile strategy UI (2026) | Touch target ≥44×44px, aksi kritis ≤2 tap — dasar tile 76dp & tab 48dp |
| 5 | bandurart.com — mobile game UI inventory | Grid per kategori, ikon + badge, highlight state terpilih |
| 6 | itch.io "Casual Strategy UI Kit" (IndigoLay) | Set elemen: tile, badge, ribbon — dipakai data-driven (bukan hardcode) |
| 7 | `docs/references/doomsday/` (referensi lokal user, 15 gambar + FRAME_BY_FRAME.md) | Modal penuh + tombol aksi besar; HELP list & talent tree = **node ikon + counter angka** (mis. `x2`), bukan teks panjang |

Catatan kejujuran: **Doomsday tidak punya grid card build** (menu-nya list). Pola *tab + grid tile
art-dominan + badge* karena itu diambil dari keluarga CoC (sumber 1–3, 5, 6) dan diverifikasi
ulang lewat foto lokal (sumber 7) untuk gaya badge/counter.

## 3. Pemetaan referensi → implementasi (komponen)

Komponen: `game/scripts/ui/catalog_tile.gd` (`class_name CatalogTile`) — dipakai bersama oleh
`build_menu.gd` (BANGUN) dan `ship_menu.gd` (ARMADA), jadi satu gaya & satu audit.

| Elemen | Referensi | Implementasi (design px; 1px = 0,5dp) |
|---|---|---|
| Baris tab kategori | CoC (4 tab ikon) | `CategoryTabs` — tab 96×96 (48dp persegi), **ikon saja** (`make_tab`), tooltip untuk desktop; tab kosong disembunyikan, 1 tab = baris tab disembunyikan |
| Grid tile | CoC shop / DoK BAG | `CardGrid` 4 kolom, tile **152×152 (76dp)**, di dalam `ScrollContainer` (katalog bertambah = digeser, bukan meluber) |
| Isi tile | "card 70% tanpa label" | **Ikon 70% sisi tile** (`ICON_RATIO = 0.70`) terpusat; satu-satunya teks = badge angka; `label_nodes()` mengaudit 0 label kata |
| Badge angka | DoK counter `x2`, CoC level badge | `QtyBadge` kapsul di sudut kanan-atas, isi `"x2"`; tampil bila pemain punya ≥1; **angka, bukan label kata** |
| Gembok | CoC/Evony tile belum terbuka | `LockBadge` (ikon gembok, tanpa teks) — API siap, belum ada item terkunci di data |
| Panel detail (berlabel) | RoK/Evony detail item | `DetailPanel`: header (art 48 + nama + KATEGORI), blok efek/stats, lalu `BIAYA` / `WAKTU BANGUN` / tombol aksi 48dp + status |
| Tombol aksi | DoK modal besar | Tombol `BANGUN`/`PRODUKSI` tinggi 96 (48dp) + tombol `TUTUP` berikon |

## 4. Anggaran tata letak (dihitung, diuji otomatis)

Modal 1088×560 (544×280dp), `PanelContainer` + margin isi 16 (24px):

```
tinggi konten 560-32 = 528
  title row 96 (tombol TUTUP 48dp menentukan)  +  tab 96  +  2×8 gap  =  208
  area grid = 320  = 2 baris tile 152 + gap 16  ✓
lebar konten 1056
  grid 4×152 + 3×16 = 656  |  16  |  detail 360   = 1032  ≤ 1056  ✓
```

Diuji: `ui.menu_fit_build` / `ui.menu_fit_ship` (tidak ada anak modal yang keluar rect modal > 2px)
dan `verify_ui_m3.py` (region piksel) pada foto `docs/ui_m3_build_menu/`.

## 5. Yang TIDAK diambil (agar tidak mengarang)

- Animasi buka-tutup tile, sistem "queue builder" CoC, dan ikon berbayar dari kit pihak ketiga:
  di luar scope M3 (tidak ada di kriteria user).
- Grid *inventory* pemain: belum ada gameplay inventory di MILESTONE saat ini.
