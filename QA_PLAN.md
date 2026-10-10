# QA PLAN — Last-Space (Verification Gates & QA per Phase)

Dokumen ini menetapkan **bagaimana setiap phase diverifikasi berulang lalu QA**
sebelum lanjut ke phase berikutnya. Mengikat `AI_GOVERNANCE.md` §3 (evidence
labels), §4 (Definition of Done), §5 (anti-non-progress), §6 (anti-loop), dan
bottleneck #3 di `RISK_ANALYSIS.md`.

> **Aturan emas: "bukan asal jalan."** Sebuah phase tidak VERIFIED hanya karena
> kode berjalan tanpa error. VERIFIED = lulus pengujian yang ditentukan, dengan
> bukti berupa hasil test/log/screenshot, berdasarkan **data nyata** dari
> `res://data/` dan state game aktual — bukan asumsi.

## 1. Status Gate (wajib dipakai untuk setiap phase/task)

| Status | Arti | Kriteria transisi ke status ini |
|---|---|---|
| `NOT STARTED` | Belum dikerjakan | — |
| `IMPLEMENTED` | Kode atau aset telah dibuat | Kode/aset ada di repo; belum tentu jalan |
| `RUNNABLE` | Berhasil dijalankan | Jalan di runtime target (WASM/Chromium) tanpa crash; log bersih |
| `VERIFIED` | Lulus pengujian yang ditentukan | Test unit/integrasi/e2e yang relevan **PASS** + marker QA dengan nilai aktual ter-assert |
| `INTEGRATED` | Berhasil bekerja dengan sistem terkait | Terhubung ke sistem nyata lewat event/API (bukan demo terpisah); cross-system test PASS |
| `REGRESSION PASS` | Perubahan tidak merusak fungsi yang sudah ada | Test suite lengkap (unit + integration + e2e) tetap PASS setelah perubahan |

**Aturan:**
- Tidak boleh loncat gate. `IMPLEMENTED` bukan `VERIFIED`.
- AI tidak boleh menyatakan selesai hanya karena kode berhasil ditulis.
- Setiap perubahan setelah VERIFIED → wajib REGRESSION PASS (jalankan ulang
  test yang relevan + marker QA utama) sebelum lanjut.
- Status setiap task dicatat di `PROJECT_STATUS.md` (bukan diingat di chat).

## 2. Metode Verifikasi (berdasarkan data nyata)

| Metode | Alat | Apa yang dibuktikan |
|---|---|---|
| **Unit test** | `tests/unit/` via test runner (WASM runtime) | Logika murni benar: ekonomi, RNG determinism, combat sim (fixed seed), save round-trip |
| **Data test** | `tests/unit/test_data_validation.gd` | **Data nyata valid**: load `res://data/*.tres` asli; cek referensi, nilai, kelengkapan (lihat `DATA_CONTRACTS.md` §3) |
| **Integration test** | `tests/integration/` | Sistem ↔ sistem via EventBus dengan state aktual |
| **E2E playthrough** | `tests/e2e/` + `tools/godot/run_smoke.sh` pola + `tools/vision/capture.mjs --wait-for` | Satu rantai gameplay lengkap; marker `QA:LOOP:*` muncul dengan nilai aktual; screenshot tiap fase |
| **Vision check** | capture tool + analisis piksel (Pillow) | Screenshot valid (PNG, dimensi benar) dan bukan blank (cek piksel) |
| **Regression run** | Jalankan ulang semua test + marker utama | Tidak ada yang rusak setelah perubahan |

**Marker QA (standar output untuk verifikasi):** setiap sistem mencetak
`QA:<PHASE>:<EVENT> key=value ...` dengan nilai dibaca dari state aktual.
Contoh:

```
QA:ECONOMY:PRODUCE energy=120 minerals=45
QA:BUILD:PLACE id=energy_reactor level=1 pos=2,0
QA:FLEET:SPAWN id=shp_001_interceptor hp=100
QA:COMBAT:FINISH winner=defender attacker_losses=4 duration_ticks=320 seed=42
QA:LOOP:COMPLETE cycles=1
```

Test dinyatakan PASS jika marker yang diwajibkan **muncul dengan nilai yang
di-assert** (misal: `energy=120` benar-benar sama dengan nilai di Economy saat
itu) — bukan sekadar muncul.

## 3. QA Matrix per Phase (urutan kerja dari RISK_ANALYSIS §10)

Setiap phase: implementasi → RUNNABLE → VERIFIED (test+data) → INTEGRATED →
QA review → REGRESSION PASS → lanjut.

| # | Phase | Fokus | Test yang wajib (data nyata) | Kriteria kelulusan (VERIFIED) |
|---|---|---|---|---|
| 1 | Fondasi proyek Godot | Struktur, autoload core, test runner | Struktur konsisten dengan `TECH_ARCHITECTURE.md`; test runner jalan; `make_pck` + capture jalan | Proyek berjalan di runtime target; test runner mencetak `TESTS:DONE` |
| 2 | Ekonomi & pembangunan | Economy, BuildingSystem, produksi, biaya, upgrade | Unit: transaksi, caps, insufficient funds, refund, integer tick; Data: `economy.tres` + 2–3 `BuildingDef` valid & first-build terjangkau; Integration: build→produce→saldo bertambah (nilai aktual di-assert) | Bangunan, produksi, biaya, dan upgrade bekerja konsisten; marker `QA:ECONOMY:*`/`QA:BUILD:*` dengan nilai aktual |
| 3 | Armada & pertempuran | FleetSystem, CombatSimulator, WaveDirector, CombatVisualizer | Unit: CombatSimulator fixed seed → hasil sama persis (reproducible); statistik menentukan hasil (ubah stats → ubah hasil); Data: `ShipDef`/`WeaponDef`/`WaveDef` valid & referensi resolve; E2E: wave datang → pertempuran → hasil sesuai BattleResult | Statistik unit menentukan hasil pertempuran secara benar; visual menampilkan hasil aktual; marker `QA:COMBAT:*` + screenshot |
| 4 | Integrasi progresi | Reward, territory unlock, ProgressionSystem | Integration: combat → reward → ekonomi bertambah **tepat 1×**; territory unlock setelah defend; Data: `SectorDef` valid; test double-grant (reward tidak ganda) | Hadiah pertempuran dapat digunakan untuk mengembangkan basis; reward 1× terbukti |
| 5 | Save/load | SaveSystem, skema v1, migrasi | Unit: round-trip (save→load→state sama persis); invalid state handling; no duplicate reward setelah load; schema version check | Progres tidak hilang atau berubah secara tidak sengaja; `QA:SAVE:*` round-trip PASS |
| 6 | Pipeline aset | Pilot asset SHP-001 + acceptance | `ASSET_ACCEPTANCE_CRITERIA.md` checklist; import GLB runtime test; screenshot di scene perwakilan; cek piksel | Pilot asset VERIFIED; baru boleh lanjut produksi aset lain |
| 7 | Performa (mobile/web) | Stress scene, metrik | Frame-time, memrik, draw call, waktu load tercatat di build representatif (Chromium headless + perangkat target nanti) | Adegan representatif memenuhi target performa (budget menyusul device class) |
| 8 | Variasi konten | Unit/musuh/teknologi/misi baru | Setiap konten baru: data test + integration test + distinct gameplay purpose (governance §14) | Konten memperluas gameplay, bukan duplikasi statistik |
| 9 | Balancing | Tempo ekonomi & progresi | Simulasi ekonomi headless (ratusan hari game); cek pemain tidak kehabisan tujuan / tidak terlalu cepat | Tempo diuji dengan data simulasi; nilai provisional diberi label |
| 10 | Validasi pemain | Playtest internal/awal | Observasi pemain: paham loop? mau lanjut? (catatan kualitatif + bukti) | Ada bukti pemain memahami dan ingin melanjutkan |

## 4. QA Review (manusia) — checklist per phase

Sebelum phase naik status, human developer memeriksa (centang di
`PROJECT_STATUS.md`):

- [ ] Semua test relevan PASS (bukan hanya "jalan")
- [ ] Marker QA dengan nilai aktual ter-assert
- [ ] Screenshot fase tersimpan (vision evidence) dan sudah di-review
- [ ] Tidak ada error/arning di console
- [ ] Kontrak data tidak dilanggar (UI bukan sumber kebenaran; reward 1×; dll)
- [ ] Perubahan tidak merusak fase sebelumnya (REGRESSION PASS)
- [ ] Dokumentasi status diperbarui seperlunya (minimal, sesuai perubahan)

## 5. Aturan Verifikasi Berulang (anti-loop)

- Setelah **setiap** perubahan: jalankan test yang relevan + marker utama
  (bukan seluruh suite kecuali perubahan cross-system).
- Jangan mengulang audit/test tanpa perubahan baru — governance §6. Sebelum
  mengulang, nyatakan apa yang berubah dan keputusan apa yang bisa diubah hasilnya.
- Jika test gagal: tangkap failure persis, reproduksi, klasifikasi layer
  (data/state/logic/integration/rendering/timing/environment), fix root cause
  terkecil, re-run test gagal + regresi relevan (governance §18). Jangan
  menulis ulang dokumen sebagai respons test gagal.

## 6. Evidence & Label

- Label wajib (governance §3): **VERIFIED** / **IMPLEMENTED** / **LIKELY** /
  **ASSUMPTION** / **UNKNOWN** / **BLOCKED**.
- Bukti yang disimpan: output test (console log), screenshot + report JSON,
  marker QA. Lokasi: `tools/godot/build/` & `tools/vision/out/` (gitignored);
  hasil dicatat di `PROJECT_STATUS.md` (verification record).
- Jangan pernah mengarang log, hasil test, screenshot, atau performa.

## 7. Definisi "Selesai" untuk Phase (menggabung governance §4)

Phase selesai hanya jika: perilaku yang diminta terimplementasi; terhubung ke
alur gameplay nyata; memakai kontrak data yang disepakati; kasus sukses/gagal/
batas/transisi state ditangani; test relevan PASS; test end-to-end fresh-state
PASS untuk perubahan gameplay; tidak ada regresi; cek runtime target sudah
dilakukan; status doc diperbarui minimal; limitasi diungkap.

Jika verifikasi tidak tersedia → laporkan **IMPLEMENTED — NOT VERIFIED**,
sebut test yang kurang, dan jangan diam-diam menurunkan standar.
