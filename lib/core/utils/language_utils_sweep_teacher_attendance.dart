// Part of the AppLocalizations API — i18n strings for the ADMIN
// teacher-attendance (Presensi Guru) report. Mirrors the web admin
// report view's copy (web-vue AdminTeacherAttendanceView.vue, "Laporan"
// tab) adapted to a mobile layout. Keys are plain `{en, id}` maps used
// via the `.tr` extension; `$`-interpolation placeholders are escaped so
// the analyzer doesn't read them as Dart string interpolation.
part of 'language_utils.dart';

// ── Module / screen chrome ────────────────────────────────────────
const kTarModule = {'en': 'Teacher Attendance', 'id': 'Presensi Guru'};
const kTarKicker = {'en': 'Attendance · Report', 'id': 'Kehadiran · Laporan'};
const kTarTitle = {
  'en': 'Teacher Attendance Report',
  'id': 'Laporan Presensi Guru',
};

// ── Period filter ─────────────────────────────────────────────────
const kTarPeriod = {'en': 'Period', 'id': 'Periode'};
const kTarFrom = {'en': 'From', 'id': 'Dari'};
const kTarTo = {'en': 'To', 'id': 'Sampai'};
const kTarTeacherIdLabel = {'en': 'Teacher ID', 'id': 'ID Guru'};
const kTarTeacherIdHint = {
  'en': 'Teacher / User ID',
  'id': 'ID Guru / Pengguna',
};
const kTarApply = {'en': 'Apply', 'id': 'Terapkan'};
const kTarReset = {'en': 'Reset', 'id': 'Reset'};
const kTarPeriodHint = {
  'en': 'Leave dates empty to use the default period (start of this month '
      'to today).',
  'id': 'Kosongkan tanggal untuk memakai periode default (awal bulan ini '
      'sampai hari ini).',
};
const kTarPickDate = {'en': 'Pick date', 'id': 'Pilih tanggal'};

// ── Rekap (per-teacher summary) ───────────────────────────────────
const kTarRecapTitle = {
  'en': 'Attendance Recap per Teacher',
  'id': 'Rekap Kehadiran per Guru',
};
const kTarTeacherCount = {'en': 'teachers', 'id': 'guru'};
const kTarRecapEmptyTitle = {
  'en': 'No attendance recap yet',
  'id': 'Belum ada rekap presensi',
};
const kTarRecapEmptyDesc = {
  'en': 'No teacher attendance data for this period.',
  'id': 'Tidak ada data presensi guru untuk periode ini.',
};
const kTarTotalRow = {'en': 'Total', 'id': 'Total'};
const kTarPresentPct = {'en': '% Attendance', 'id': '% Kehadiran'};

// ── Status column labels (mirror web statusColumnLabel) ────────────
const kTarStatusPresent = {'en': 'Present', 'id': 'Hadir'};
const kTarStatusLate = {'en': 'Late', 'id': 'Telat'};
const kTarStatusSick = {'en': 'Sick', 'id': 'Sakit'};
const kTarStatusExcused = {'en': 'Excused', 'id': 'Izin'};
const kTarStatusAbsent = {'en': 'Absent', 'id': 'Alpa'};

// ── Status pill labels (per-row detail) ───────────────────────────
const kTarPillPresent = {'en': 'On Time', 'id': 'Tepat Waktu'};
const kTarPillLate = {'en': 'Late', 'id': 'Terlambat'};

// ── Detail (per-row list) ─────────────────────────────────────────
const kTarDetailTitle = {'en': 'Row Detail', 'id': 'Detail per Baris'};
const kTarDetailSubtitle = {
  'en': "Teachers' daily attendance records (in/out, location, photo).",
  'id': 'Catatan presensi harian guru (masuk/pulang, lokasi, foto).',
};
const kTarSingleDate = {'en': 'Date (single day)', 'id': 'Tanggal (1 hari)'};
const kTarStatusFilter = {'en': 'Status', 'id': 'Status'};
const kTarStatusAll = {'en': 'All', 'id': 'Semua'};
const kTarRecords = {'en': 'records', 'id': 'catatan'};
const kTarOnTimeThisPage = {
  'en': 'on time (this page)',
  'id': 'tepat waktu (hal. ini)',
};
const kTarLateThisPage = {
  'en': 'late (this page)',
  'id': 'terlambat (hal. ini)',
};
const kTarDetailEmptyTitle = {
  'en': 'No attendance data',
  'id': 'Belum ada data presensi',
};
const kTarDetailEmptyDesc = {
  'en': 'No teacher attendance records for this filter.',
  'id': 'Tidak ada catatan presensi guru untuk filter ini.',
};
const kTarColTeacher = {'en': 'Teacher', 'id': 'Guru'};
const kTarColDate = {'en': 'Date', 'id': 'Tanggal'};
const kTarColIn = {'en': 'In', 'id': 'Masuk'};
const kTarColOut = {'en': 'Out', 'id': 'Pulang'};
const kTarColLocation = {'en': 'Location', 'id': 'Lokasi'};
const kTarOutsideArea = {'en': 'Outside area', 'id': 'Luar area'};
const kTarPageOf = {'en': 'Page', 'id': 'Hal'};

// ── Shared states ─────────────────────────────────────────────────
const kTarLoading = {'en': 'Loading report…', 'id': 'Memuat laporan…'};
const kTarLoadError = {
  'en': 'Failed to load the teacher attendance report.',
  'id': 'Gagal memuat laporan presensi guru.',
};
const kTarRetry = {'en': 'Try again', 'id': 'Coba lagi'};
