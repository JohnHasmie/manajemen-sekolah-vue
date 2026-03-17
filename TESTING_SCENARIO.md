# Skenario Testing Harian - Manajemen Sekolah App

## Konfigurasi Tester

| No | Tester | Role | Sekolah | Keterangan |
|----|--------|------|---------|------------|
| T1 | Tester 1 | **Guru** | Sekolah A | Guru Matematika + Wali Kelas |
| T2 | Tester 2 | **Guru** | Sekolah A | Guru Bahasa Indonesia |
| T3 | Tester 3 | **Guru** | Sekolah B | Guru IPA + Wali Kelas |
| T4 | Tester 4 | **Wali** | Sekolah A | Orang tua 1 anak |
| T5 | Tester 5 | **Wali** | Sekolah A | Orang tua 2 anak |
| T6 | Tester 6 | **Wali** | Sekolah B | Orang tua 1 anak |
| T7 | Tester 7 | **Guru + Wali** | Sekolah B | Dual role (guru & orang tua) |

---

## Tugas Harian Testing

### PAGI (08:00 - 10:00) — Login, Dashboard & Pengumuman

#### Semua Tester
- [ ] Login dengan akun masing-masing
- [ ] Verifikasi dashboard tampil sesuai role (guru/wali)
- [ ] Cek statistik dashboard muncul dengan benar
- [ ] Cek notifikasi/badge unread pada setiap menu
- [ ] Buka halaman Pengumuman, baca pengumuman terbaru
- [ ] Verifikasi badge unread hilang setelah pengumuman dibaca
- [ ] Ganti bahasa (Indonesia ↔ English), verifikasi teks berubah
- [ ] Cek interactive tour/tutorial muncul untuk user baru

#### T7 (Dual Role)
- [ ] Switch role dari Guru ke Wali dan sebaliknya
- [ ] Verifikasi dashboard berubah sesuai role aktif

---

### GURU: Jadwal & Aktivitas Kelas (09:00 - 11:00)

#### T1, T2, T3, T7 (sebagai Guru)

**Jadwal Mengajar:**
- [ ] Buka halaman Jadwal Mengajar
- [ ] Verifikasi jadwal hari ini tampil dengan benar
- [ ] Cek jadwal minggu ini

**Aktivitas Kelas (CRUD):**
- [ ] Buat aktivitas kelas baru tipe **Umum** (judul, deskripsi, kelas)
- [ ] Buat aktivitas kelas tipe **Siswa Tertentu** (pilih beberapa siswa)
- [ ] Buat aktivitas kelas tipe **Tugas/PR** dengan deadline
- [ ] Buat aktivitas kelas dengan **link meeting online**
- [ ] Edit salah satu aktivitas yang sudah dibuat
- [ ] Hapus salah satu aktivitas
- [ ] Filter aktivitas berdasarkan tanggal
- [ ] Filter aktivitas berdasarkan kelas
- [ ] Filter aktivitas berdasarkan mata pelajaran

---

### GURU: Absensi Siswa (10:00 - 11:30)

#### T1, T2, T3, T7 (sebagai Guru)

- [ ] Buka halaman Absensi/Presensi
- [ ] Pilih kelas yang diajar
- [ ] Input absensi: tandai beberapa siswa **Hadir**
- [ ] Input absensi: tandai 1-2 siswa **Sakit**
- [ ] Input absensi: tandai 1 siswa **Izin**
- [ ] Input absensi: tandai 1 siswa **Alpha**
- [ ] Simpan data absensi
- [ ] Verifikasi rekap absensi (jumlah hadir/sakit/izin/alpha benar)
- [ ] Buka detail absensi per siswa
- [ ] Filter absensi berdasarkan rentang tanggal

---

### SIANG (11:00 - 13:00) — Materi & RPP

#### T1, T2, T3, T7 (sebagai Guru)

**Materi Pembelajaran (CRUD):**
- [ ] Buka halaman Materi Pembelajaran
- [ ] Buat materi baru (judul, bab, sub-bab, konten)
- [ ] Edit materi yang sudah ada
- [ ] Hapus materi
- [ ] **Generate materi dengan AI** — masukkan prompt, tunggu hasil
- [ ] Verifikasi hasil AI materi tampil dengan benar
- [ ] Regenerate materi AI dengan prompt berbeda

**RPP / Rencana Pelaksanaan Pembelajaran (CRUD):**
- [ ] Buka halaman RPP
- [ ] Buat RPP baru secara manual
- [ ] **Generate RPP dengan AI** — pilih kelas, mapel, topik
- [ ] Tunggu proses AI (verifikasi loading/polling berjalan)
- [ ] Verifikasi hasil RPP AI tampil lengkap
- [ ] Edit RPP yang sudah ada
- [ ] Lihat detail RPP
- [ ] Export RPP (verifikasi file terunduh/terbuka)
- [ ] Hapus RPP
- [ ] Cek status approval RPP (approved/rejected/pending)

---

### GURU: Input Nilai & Rekap (13:00 - 14:30)

#### T1, T2, T3, T7 (sebagai Guru)

**Input Nilai:**
- [ ] Buka halaman Input Nilai
- [ ] Pilih kelas dan mata pelajaran
- [ ] Input nilai untuk beberapa siswa (berbagai tipe penilaian)
- [ ] Simpan nilai
- [ ] Edit nilai yang sudah diinput
- [ ] Verifikasi nilai tersimpan dengan benar

**Rekap Nilai:**
- [ ] Buka halaman Rekap Nilai
- [ ] Verifikasi data rekap sesuai dengan nilai yang diinput
- [ ] Filter rekap berdasarkan mata pelajaran
- [ ] Filter berdasarkan tahun ajaran

**Raport (Guru):**
- [ ] Buka halaman Raport
- [ ] Pilih kelas dan semester
- [ ] Lihat detail raport per siswa
- [ ] Cetak/print raport (verifikasi output)

---

### GURU: Rekomendasi Pembelajaran AI (14:00 - 15:00)

#### T1, T3 (Guru Wali Kelas saja)

**Rekomendasi per Kelas:**
- [ ] Buka halaman Rekomendasi Pembelajaran
- [ ] Pilih kelas homeroom
- [ ] **Generate rekomendasi AI** untuk kelas
- [ ] Tunggu proses async job selesai
- [ ] Verifikasi hasil rekomendasi tampil
- [ ] Lihat detail rekomendasi

**Rekomendasi per Siswa:**
- [ ] Pilih siswa tertentu
- [ ] **Generate rekomendasi AI** untuk siswa individual
- [ ] Verifikasi hasil berbeda dari rekomendasi kelas
- [ ] Edit rekomendasi yang sudah ada
- [ ] Ubah status rekomendasi (pending → in_progress → completed)
- [ ] Dismiss rekomendasi

---

### WALI: Monitoring Anak (09:00 - 12:00)

#### T4, T5, T6, T7 (sebagai Wali)

**Pilih Anak (T5 - multi anak):**
- [ ] Verifikasi semua anak terdaftar di dashboard
- [ ] Switch antar anak, verifikasi data berubah

**Aktivitas Kelas:**
- [ ] Buka halaman Aktivitas Kelas
- [ ] Verifikasi aktivitas yang dibuat guru tampil
- [ ] Filter aktivitas berdasarkan tanggal
- [ ] Filter berdasarkan mata pelajaran
- [ ] Verifikasi badge unread hilang setelah dibaca
- [ ] Cek aktivitas tipe tugas/PR tampil dengan deadline

**Nilai/Grades:**
- [ ] Buka halaman Nilai
- [ ] Verifikasi nilai yang diinput guru tampil
- [ ] Filter nilai berdasarkan mata pelajaran
- [ ] Filter berdasarkan tahun ajaran
- [ ] Verifikasi badge unread untuk nilai baru

**Absensi/Kehadiran:**
- [ ] Buka halaman Kehadiran
- [ ] Verifikasi data absensi sesuai input guru
- [ ] Cek rekap bulanan kehadiran
- [ ] Filter berdasarkan rentang tanggal
- [ ] Verifikasi statistik kehadiran (hadir/sakit/izin/alpha)

---

### SORE (14:00 - 16:00) — Billing & Raport (Wali)

#### T4, T5, T6, T7 (sebagai Wali)

**Billing/Tagihan:**
- [ ] Buka halaman Billing/Tagihan
- [ ] Verifikasi tagihan tampil dengan benar
- [ ] Cek status pembayaran (lunas/belum)
- [ ] Lihat riwayat pembayaran
- [ ] Verifikasi badge unread untuk tagihan baru

**E-Raport:**
- [ ] Buka halaman E-Raport
- [ ] Pilih semester/tahun ajaran
- [ ] Lihat raport lengkap anak
- [ ] Verifikasi data raport sesuai dengan nilai yang diinput guru
- [ ] Download/view detail raport

---

### AKHIR HARI (15:00 - 16:00) — Cross-Check & Edge Cases

#### Semua Tester

**Cross-check Lintas Role (Sekolah A):**
- [ ] **T1/T2** buat aktivitas baru → **T4/T5** verifikasi tampil di sisi wali
- [ ] **T1/T2** input nilai baru → **T4/T5** verifikasi nilai muncul
- [ ] **T1/T2** input absensi → **T4/T5** verifikasi kehadiran terupdate
- [ ] **T4/T5** verifikasi badge unread muncul untuk data baru

**Cross-check Lintas Role (Sekolah B):**
- [ ] **T3** buat aktivitas baru → **T6** verifikasi tampil
- [ ] **T3** input nilai baru → **T6** verifikasi nilai muncul
- [ ] **T3** input absensi → **T6** verifikasi kehadiran terupdate

**Cross-check Dual Role (T7):**
- [ ] Sebagai Guru: buat aktivitas & input nilai
- [ ] Switch ke Wali: verifikasi data anak sendiri terupdate
- [ ] Switch kembali ke Guru: verifikasi data masih konsisten

**Edge Cases:**
- [ ] Logout dan login kembali — verifikasi data tetap ada
- [ ] Buka app tanpa koneksi internet — verifikasi cache/offline behavior
- [ ] Buka app lalu minimize, buka lagi — verifikasi state tetap
- [ ] Scroll cepat pada list panjang — verifikasi tidak crash
- [ ] Input nilai dengan angka desimal/batas (0, 100, 99.5)
- [ ] Buat aktivitas dengan teks sangat panjang
- [ ] Upload/input dengan karakter spesial (!@#$%^&*)

---

## Checklist Harian per Tester

### T1 (Guru - Sekolah A - Wali Kelas)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Jadwal Mengajar | ⬜ |
| 09:30 | Aktivitas Kelas (CRUD) | ⬜ |
| 10:00 | Absensi Siswa | ⬜ |
| 11:00 | Materi Pembelajaran + AI | ⬜ |
| 12:00 | RPP + AI Generate | ⬜ |
| 13:00 | Input Nilai | ⬜ |
| 13:30 | Rekap Nilai & Raport | ⬜ |
| 14:00 | Rekomendasi AI (Kelas & Siswa) | ⬜ |
| 15:00 | Cross-check dengan T4/T5 | ⬜ |
| 15:30 | Edge Cases | ⬜ |

### T2 (Guru - Sekolah A)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Jadwal Mengajar | ⬜ |
| 09:30 | Aktivitas Kelas (CRUD) | ⬜ |
| 10:00 | Absensi Siswa | ⬜ |
| 11:00 | Materi Pembelajaran + AI | ⬜ |
| 12:00 | RPP + AI Generate | ⬜ |
| 13:00 | Input Nilai | ⬜ |
| 13:30 | Rekap Nilai & Raport | ⬜ |
| 15:00 | Cross-check dengan T4/T5 | ⬜ |
| 15:30 | Edge Cases | ⬜ |

### T3 (Guru - Sekolah B - Wali Kelas)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Jadwal Mengajar | ⬜ |
| 09:30 | Aktivitas Kelas (CRUD) | ⬜ |
| 10:00 | Absensi Siswa | ⬜ |
| 11:00 | Materi Pembelajaran + AI | ⬜ |
| 12:00 | RPP + AI Generate | ⬜ |
| 13:00 | Input Nilai | ⬜ |
| 13:30 | Rekap Nilai & Raport | ⬜ |
| 14:00 | Rekomendasi AI (Kelas & Siswa) | ⬜ |
| 15:00 | Cross-check dengan T6 | ⬜ |
| 15:30 | Edge Cases | ⬜ |

### T4 (Wali - Sekolah A - 1 Anak)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Aktivitas Kelas Anak | ⬜ |
| 10:00 | Nilai Anak | ⬜ |
| 11:00 | Kehadiran Anak | ⬜ |
| 13:00 | Billing/Tagihan | ⬜ |
| 14:00 | E-Raport | ⬜ |
| 15:00 | Cross-check dengan T1/T2 | ⬜ |
| 15:30 | Edge Cases | ⬜ |

### T5 (Wali - Sekolah A - 2 Anak)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Switch Anak & Aktivitas Kelas | ⬜ |
| 10:00 | Nilai Anak 1 & Anak 2 | ⬜ |
| 11:00 | Kehadiran Anak 1 & Anak 2 | ⬜ |
| 13:00 | Billing Anak 1 & Anak 2 | ⬜ |
| 14:00 | E-Raport Anak 1 & Anak 2 | ⬜ |
| 15:00 | Cross-check dengan T1/T2 | ⬜ |
| 15:30 | Edge Cases (multi-anak) | ⬜ |

### T6 (Wali - Sekolah B - 1 Anak)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard | ⬜ |
| 08:30 | Pengumuman | ⬜ |
| 09:00 | Aktivitas Kelas Anak | ⬜ |
| 10:00 | Nilai Anak | ⬜ |
| 11:00 | Kehadiran Anak | ⬜ |
| 13:00 | Billing/Tagihan | ⬜ |
| 14:00 | E-Raport | ⬜ |
| 15:00 | Cross-check dengan T3 | ⬜ |
| 15:30 | Edge Cases | ⬜ |

### T7 (Guru + Wali - Sekolah B)
| Waktu | Task | Status |
|-------|------|--------|
| 08:00 | Login & Dashboard (Guru) | ⬜ |
| 08:30 | Switch Role & Verifikasi | ⬜ |
| 09:00 | [Guru] Jadwal & Aktivitas Kelas | ⬜ |
| 10:00 | [Guru] Absensi Siswa | ⬜ |
| 11:00 | [Guru] Materi + AI | ⬜ |
| 12:00 | [Guru] RPP + AI | ⬜ |
| 13:00 | [Guru] Input Nilai | ⬜ |
| 13:30 | Switch ke Wali | ⬜ |
| 14:00 | [Wali] Cek Aktivitas, Nilai, Kehadiran | ⬜ |
| 14:30 | [Wali] Billing & E-Raport | ⬜ |
| 15:00 | Cross-check Guru↔Wali sendiri | ⬜ |
| 15:30 | Edge Cases (role switching) | ⬜ |

---

## Format Laporan Bug

Jika menemukan bug, laporkan dengan format:

```
Tester: [T1-T7]
Sekolah: [A/B]
Role: [Guru/Wali]
Halaman: [nama halaman]
Langkah Reproduksi:
1. ...
2. ...
3. ...
Expected: [yang seharusnya terjadi]
Actual: [yang terjadi]
Screenshot: [lampirkan]
Severity: [Critical/Major/Minor/Cosmetic]
```

---

## Catatan Penting

1. **Sekolah A dan B harus punya data yang berbeda** — pastikan tidak ada data bocor lintas sekolah
2. **T5 khusus test multi-anak** — pastikan switching anak tidak mencampur data
3. **T7 khusus test dual role** — pastikan data konsisten saat switch role
4. **Fitur AI (T1, T3)** — perhatikan rate limiting dan waktu tunggu async job
5. **Cross-check wajib** — data yang diinput guru HARUS tampil di sisi wali
6. **Setiap hari reset checklist** dan ulangi skenario untuk konsistensi
