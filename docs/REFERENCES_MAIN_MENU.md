# Referensi Menu Utama — riset tata letak (M3 #4)

Sumber: riset web + screenshot game nyata yang tersedia di repo
(`docs/references/doomsday/`). Semua keputusan tata letak di bawah **diturunkan
dari referensi**, bukan asumsi (koreksi user M3.6: standar harus dicari).

## 1. Referensi lokal (screenshot game nyata di repo)

| Ref | File | Yang terlihat | Yang ditiru di Last-Space |
|---|---|---|---|
| Doomsday F1 (Login/Menu) | `doomsday-last-survivors-main-menu-loadin-1..5` + `FRAME_BY_FRAME.md` F1 | Latar = scene 3D nyata; tombol **Start besar di tengah-bawah**; ikon kecil di atas | Latar = base 3D hidup (kamera idle), panel menu **tengah-bawah** dengan tombol utama 56dp |
| Doomsday F1 note | `FRAME_BY_FRAME.md` baris 25 | Backlog: "Main menu (Play/Settings)" | Menu = Play/Continue + Pengaturan (+ Kredit) |
| Doomsday F4 (selection) | `m37_visual/command_selected_16x9.png` (hasil kita) | Panel konteks di bawah | Aksi utama selalu di area bawah (jempol) |

## 2. Riset web (sumber resmi/industri)

| Sumber | Temuan | Yang ditiru |
|---|---|---|
| Supercell — *Clash of Clans UI revamp* (blog resmi) | "Everything on screen that isn't the village itself is UI" — base tetap jadi bintang; UI = lapisan chrome; satu tombol = satu rumah aksi; elemen kondisional (progressive disclosure) | Menu **tidak** menutup base (scrim 62% saja); "Mulai Baru" hanya muncul bila ada save; tombol utama berubah label sesuai state (MULAI / LANJUTKAN / LANJUTKAN PERMAINAN) |
| Medium — *Revolutionizing Clash of Clans UX/UI* (design-bootcamp) | Navigasi intuitif, ikon jelas, informasi bertingkat, aksesibilitas (opsi besar teks/audio) | Satu tombol utama + maksimum 3 aksi sekunder; pengaturan (teks/audio) jadi aksi eksplisit, statusnya jujur "M3 #5" |
| therookies.co (panduan UI mobile game) | Zona jempol (thumb zone): aksi utama di 1/3 bawah layar, bukan di atas | Panel di-anchor `PRESET_CENTER_BOTTOM`, margin 16dp dari tepi bawah |
| Material Design 3 (dipakai repo sejak M3.6) | Tombol utama ≥56dp, sekunder ≥48dp, dialog ≤560dp, margin 16dp, teks ≥11dp | Panel 336dp (≤560dp), Play 56dp, sekunder 48dp, 1 px = 0,5dp |
| r/ClashOfClans (2 thread kritik pemain) | Tombol diperkecil → sulit ditekan/dibaca; posisi tombol berpindah antar layar terasa tidak natural | Tidak ada tombol di bawah 48dp; urutan aksi konsisten dengan pause menu (utama → sekunder → keluar) |

## 3. Aturan → implementasi → bukti

| Aturan (dari riset) | Implementasi | Bukti |
|---|---|---|
| Latar = game nyata, bukan gambar | Base 3D + kamera idle orbit ±5,7° / dolly ±3,5% (`base_scene._menu_camera_idle`) | Foto `docs/m3_main_menu/00/01` (base + bintang + planet terlihat) |
| Aksi utama di bawah, besar | Panel `PRESET_CENTER_BOTTOM`, tombol utama 112px = **56dp** | `QA:MENU:DUMP primary_dp=56 secondary_dp=48`, test `mm.primary_56dp` |
| Satu tombol utama, sisanya sekunder | `MULAI`/`LANJUTKAN`/`LANJUTKAN PERMAINAN` + PENGATURAN + (MULAI BARU) + KREDIT | Foto `02/04`, test `mm.primary_text_*` |
| Elemen kondisional | "MULAI BARU" hanya bila ada save; "LANJUTKAN PERMAINAN" hanya bila sesi berjalan | Test `mm.action_new` / `mm.action_resume` / `mm.action_load` |
| Tombol tidak mengecil / posisi stabil | Ukuran tetap dp (design px = dp×2, scale = dpr/2) di 16:9 & 19,5:9 | Foto 1280×720 & 2340×1080 (`00`–`03`) |
| Panel tidak boleh melimpah | Tinggi = konten nyata (`get_combined_minimum_size` + margin) | `QA:MENU:FIT fit=ok`, test `mm.fit` / `mm.credits_fit` |
| Chrome HUD tidak boleh ikut terlihat di menu | `hud.set_chrome_visible(false)` saat menu dibuka | `QA:HUD:LAYOUT ..._hidden`, gate `game` cek `_hidden` |
| Menu bukan pengganti halaman utama | Root tetap game (`index.html` → game → fase MENU) | Gate `game` (`QA:GAME:READY` + `QA:MENU:READY`) |
| Dialog: permukaan sendiri + scrim, tap luar menutup [23] | `UiTheme.C_MODAL` (α=0.995) + `_credits_scrim` (tap → tutup) | `QA:MENU:MODAL scrim=true surface_alpha=0.995`; `verify_menu.py` "area padding modal bersih" |
| Teks dunia (label 3D) bukan bagian dari menu | semua label disembunyikan saat `_menu_idle` | `QA:SCENE:LABEL_MENU state=hidden total=1`; piksel: baris teks netral di luar panel 45 → **0** |

## 4. Yang TIDAK ditiru (sengaja)

- Ikon store/event/VIP di atas layar Doomsday → tidak ada monetisasi (ROADMAP).
- Pilih server → single-player, tanpa backend (ROADMAP).
- Efek kamera sinematik/3D berputar penuh → cukup orbit halus (hemat SwiftShader;
  fps software GL ±4 pada gate perf).
