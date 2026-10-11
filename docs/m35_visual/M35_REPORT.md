# M3.5 — Visual & UI polish (Arena space + Bahasa Indonesia + card besar)

Tanggal: 2026-10-12. Branch: `arena/d80e2902-last-space`.
Status: **VERIFIED** — gate 8/8 suite PASS exit 0; pixel verify arena 5/5 PASS;
verify_ui_m3 (M3 #1–#3) tetap **20/20 PASS**; record per frame PASS.

## Latar belakang (kritik user, jujur)

User kritik keras: gameplay UI/UX berantakan (teks tidak tepat, card jelek),
visual game semua placeholder (kotak-kotak tidak jelas), tidak ada arena/aset,
canvas & isi di atasnya kotak. Diakui: M1/M2 fokus sistem + arsitektur, visual
memang placeholder per roadmap; arena memang kosong (ground polos); M3 UI masih
kasar. M3.5 = perbaikan 2 tahap (A: visual game; B: teks & card UI).

## Tahap A — Arena space (visual game) VERIFIED

Semua dari kode (tanpa aset eksternal), di `base_scene.gd::_create_environment()`:

- **Sky**: WorldEnvironment, BG dark space (0.015, 0.02, 0.045) + ambient.
- **Bintang**: MultiMeshInstance3D 300 bola kecil putih (unshaded), seeded
  (deterministik). Catatan jujur: CPUParticles3D dicoba dulu tapi **tidak
  ter-render di SwiftShader** (verifikasi foto) → diganti MultiMesh.
- **Planet**: bola biru r=22 @ (80, 32, −105) + **bulan** r=8 @ (48, 42, −72).
  Awalnya planet di belakang kamera (z positif) → tidak terlihat; kamera
  dinaikkan (0, 20, 30) + look_at (0, 3, −8) + fov 82 supaya langit masuk FOV.
- **Platform**: BoxMesh 80×0.5×80 + **grid emissive cyan** (tekstur runtime
  256², garis 64px, uv1_scale 10 → grid 8m×8m) — menggantikan ground polos.
- **Asteroid**: 7 buah, posisi/ukuran seeded (SeededRng, deterministik).
- **Bangunan jelas** (`building.gd`): Label3D nama + Lv di atas bangunan
  (billboard, font 40, outline) + glow kategori (emission ×0.45, ikut state).
- **Kapal engine glow** (`ship.gd::_add_engine_glow`): 2 bola emissive cyan
  di belakang kapal (EngineGlow_L/R, z=−1.2). Muncul saat placeholder maupun
  model GLB. (Catatan: nama awal duplikat → Godot rename; test disesuaikan.)
- **Benchmark**: stress/perf scene panggil `reduce_environment_for_benchmark()`
  (hapus dekorasi berat) — tanpa ini sampling 12 detik tidak selesai < 180s di
  SwiftShader. Benchmark mengukur gameplay, bukan dekorasi.

### Verifikasi piksel arena (`tools/vision/verify_m35_arena.py`) — 5/5 PASS

| Cek | Hasil (data nyata) |
|---|---|
| sky_stars | 1371 px terang di langit (min 40) |
| planet_blue | 10123 px biru (min 5000; avg RGB 44,73,130) |
| moon_warm | 2269 px warm bulan (min 400; avg RGB 153,144,132) |
| platform_grid_cyan | 5016 px cyan grid (min 3000) |
| battle_engine_glow_cyan | 4315 px cyan engine glow (min 150) |

Evidence foto: `arena_1280f.png`, `arena_final.png`, `battle_1280.png`.

## Tahap B — Teks & card UI VERIFIED

Keputusan sementara bahasa (dokumen belum tetapkan; Settings bahasa = M3 #5):
**label utama Bahasa Indonesia, istilah teknis tetap Inggris** (WAVE/HP/ATK/
ARMOR/E=Energi/M=Mineral). Bisa diubah saat M3 #5.

- **HUD** (`hud.gd`): ENERGI/MINERAL/ARMADA, "0 kapal", ARENA BERSIH,
  OBJEKTIF, "Pusat komando aktif.", status Indonesia (Ditingkatkan / Sumber
  daya tidak cukup / Pembangunan selesai / PERINGATAN: WAVE … tiba dalam N
  detik! / PERTEMPURAN: … MENANG / WILAYAH TERBUKA / Quest selesai), tooltip
  "Bangun — …" / "Armada — …", "LEVEL MAKS", "Upgrade ke Lv N", GRATIS.
- **Build menu** (`build_menu.gd`): judul BANGUN, tombol BANGUN, card
  **2 kolom landscape** (ikon 48dp kiri + nama 24px/biaya 20px/jumlah kanan;
  sebelumnya kotak 94dp 3 kolom), kategori EKONOMI/PRODUKSI/PERTAHANAN/PUSAT,
  "+N ENERGI/detik (Lv1)", "+N ENERGI simpanan", "Senjata: …", "Perisai N",
  "Biaya: E.. M..", "Waktu bangun: Ns", status Indonesia.
- **Ship menu** (`ship_menu.gd`): judul ARMADA, tombol PRODUKSI, card sama,
  PESAWAT TEMPUR — PENGINTAS/PRAMALA, KECEPATAN/PASOKAN, "Waktu produksi",
  "Butuh Hangar Pesawat", status Indonesia.
- **Pause menu** (`pause_menu.gd`): DIJEDA / LANJUT / PENGATURAN / MENU UTAMA,
  konfirmasi "Simpan kemajuan & keluar ke menu utama?", YA/TIDAK, status
  "Kemajuan tersimpan. …" / "Pengaturan — segera hadir (M3 #5)" /
  "Gagal menyimpan — tetap di game."
- **Quest** (`quest_tracker.gd`): "Tambah Daya", "Hangar Pertama",
  "Skuadron Pertama", "Tahan Garis".
- **Data** (`.tres` display_name): Pusat Komando, Reaktor Energi, Hangar
  Pesawat, Turret Laser, Ekstraktor Mineral, Generator Perisai, Sektor Asal,
  Sabuk Luar.

Catatan: test `pm.saved_message` ikut diupdate (needle "Kemajuan tersimpan");
test `model.placeholder_fallback` diupdate (placeholder = 1 mesh + 2 EngineGlow)
+ test baru `model.engine_glow`. Tidak ada test lain yang mengikat teks.

Evidence foto: `ui_build3.png` (BANGUN + card 2 kolom), `ui_ship.png` (ARMADA),
`ui_pause3.png` (DIJEDA/LANJUT/PENGATURAN/MENU UTAMA), `ui_full.png` (HUD ID).

## Verifikasi

- **Gate 8/8 PASS exit 0**: tests 285/0, e2e 36/0, game PASS, asset 17/0,
  sim 12/0, stress 8/0 + JSHeap 8.2MB, ui PASS, perf 3×8/0.
- **verify_ui_m3.py (M3 #1–#3)**: tetap **20/20 PASS** (tidak rusak).
- **verify_m35_arena.py**: **5/5 PASS** (tabel di atas).
- **Record per frame** (`record.mjs` + `analyze_record.py`, mode=game 20s):
  11 frame @0.55fps, **0 blank 0 invalid**, scene konsisten `command_hud` →
  PASS. Evidence `record_game/` (RECORD_QA.md + report.json + sampled frames).
- **Perf (SwiftShader, data nyata)**: stress tanpa dekorasi fps_avg 3.17 (1x),
  1.33 (4x), 1.17 (6x); heap ~8.2MB. Catatan jujur: dengan dekorasi penuh +
  screencast, fps record turun ke ~0.5 (sebelumnya 4.2 tanpa dekorasi) —
  ini batas SwiftShader software GL, bukan GPU device asli.

## File berubah

- `game/scripts/base_scene.gd` (environment + kamera + reduce benchmark)
- `game/scripts/building/building.gd` (Label3D + glow kategori)
- `game/scripts/fleet/ship.gd` (engine glow)
- `game/scripts/ui/hud.gd`, `ui/build_menu.gd`, `ui/ship_menu.gd`,
  `ui/pause_menu.gd` (teks ID + card 2 kolom)
- `game/scripts/progression/quest_tracker.gd` (judul quest ID)
- `game/data/buildings/*.tres`, `game/data/sectors/*.tres` (display_name ID)
- `game/tests/integration/test_ship_model.gd`, `test_pause_menu.gd` (update)
- `game/tests/e2e/stress_scene.gd` (reduce environment untuk benchmark)
- `tools/vision/verify_m35_arena.py` (verifier baru)
- `docs/m35_visual/` (foto + verify + record evidence + report ini)
- `web/` tersinkron (build WebGL preview)

## Berikutnya

Roadmap lanjut: **M3 #4 Main menu** (Play/Pengaturan/Keluar) atau M3 #6/#7.
