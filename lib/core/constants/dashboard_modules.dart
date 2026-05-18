// Canonical icon + color per dashboard module.
//
// One module name → one icon → one accent color, used identically by
// every role's `QuickActionGrid` and `ModulLainStrip`. Lets the parent
// dashboard's "Nilai" tile look the same as the teacher's "Nilai"
// tile, the same as the admin's "Nilai" entry — so users moving
// between roles see a visually consistent module identity.
//
// The palette is anchored to `ParentAcademicHub` (the most-touched
// parent surface): Nilai = green star, Raport = blue
// assignment_turned_in, Kegiatan Kelas = amber menu-book, Pengumuman
// = cyan campaign. Other modules use complementary tones from
// `ColorUtils` so the dashboard reads as one design system.
//
// Usage:
//   final m = DashboardModules.nilai;
//   QuickAction(icon: m.icon, label: m.defaultLabel, color: m.color, onTap: …)
//
// Don't pass arbitrary `Color` / `IconData` literals when an entry
// exists in this catalog — the goal is a single source of truth.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Visual identity for one dashboard module. Immutable.
class DashboardModule {
  /// Outlined Material icon for the tile.
  final IconData icon;

  /// Accent color — drives QuickAction icon background tint and
  /// ModulLainStrip icon foreground.
  final Color color;

  /// Default label shown to the user if the caller doesn't override.
  final String defaultLabel;

  const DashboardModule({
    required this.icon,
    required this.color,
    required this.defaultLabel,
  });
}

/// Single source of truth for the per-module icon + accent across
/// every dashboard role.
abstract final class DashboardModules {
  // ── Academic ────────────────────────────────────────────────────
  /// Nilai (grades) — green `Icons.star_rounded`.
  /// Anchored to ParentAcademicHub's "Nilai" card.
  static final DashboardModule nilai = DashboardModule(
    icon: Icons.star_rounded,
    color: ColorUtils.success600,
    defaultLabel: 'Nilai',
  );

  /// Raport (report card) — blue `Icons.assignment_turned_in_outlined`.
  static final DashboardModule raport = DashboardModule(
    icon: Icons.assignment_turned_in_outlined,
    color: ColorUtils.brandAzure,
    defaultLabel: 'Raport',
  );

  /// Kegiatan Kelas (class activity) — amber `Icons.menu_book_rounded`.
  static final DashboardModule kegiatanKelas = DashboardModule(
    icon: Icons.menu_book_rounded,
    color: ColorUtils.warning600,
    defaultLabel: 'Kegiatan Kelas',
  );

  /// Pengumuman (announcement) — cyan `Icons.campaign_outlined`.
  static final DashboardModule pengumuman = DashboardModule(
    icon: Icons.campaign_outlined,
    color: ColorUtils.info600,
    defaultLabel: 'Pengumuman',
  );

  /// Kehadiran / Presensi — violet `Icons.fact_check_outlined`.
  /// Used as Kehadiran on parent and admin; Presensi on teacher.
  static final DashboardModule kehadiran = DashboardModule(
    icon: Icons.fact_check_outlined,
    color: ColorUtils.violet700,
    defaultLabel: 'Kehadiran',
  );

  /// Tagihan (billing / finance) — red `Icons.account_balance_wallet_outlined`.
  static final DashboardModule tagihan = DashboardModule(
    icon: Icons.account_balance_wallet_outlined,
    color: ColorUtils.error600,
    defaultLabel: 'Tagihan',
  );

  /// Rekomendasi (teacher → parent) — indigo `Icons.lightbulb_outline_rounded`.
  static final DashboardModule rekomendasi = DashboardModule(
    icon: Icons.lightbulb_outline_rounded,
    color: ColorUtils.indigo600,
    defaultLabel: 'Rekomendasi',
  );

  // ── Teacher-only operational ───────────────────────────────────
  /// Materi (lesson material) — indigo `Icons.article_outlined`.
  static final DashboardModule materi = DashboardModule(
    icon: Icons.article_outlined,
    color: ColorUtils.indigo500,
    defaultLabel: 'Materi',
  );

  /// RPP (lesson plan) — cobalt `Icons.description_outlined`.
  static final DashboardModule rpp = DashboardModule(
    icon: Icons.description_outlined,
    color: ColorUtils.brandCobalt,
    defaultLabel: 'RPP',
  );

  /// Rekap Nilai (grade summary) — green `Icons.assessment_outlined`.
  /// Shares the success accent with Nilai since both are grade-flavoured.
  static final DashboardModule rekapNilai = DashboardModule(
    icon: Icons.assessment_outlined,
    color: ColorUtils.success600,
    defaultLabel: 'Rekap Nilai',
  );

  /// Buku Nilai (gradebook entry) — green `Icons.bookmark_outline_rounded`.
  static final DashboardModule bukuNilai = DashboardModule(
    icon: Icons.bookmark_outline_rounded,
    color: ColorUtils.success600,
    defaultLabel: 'Buku Nilai',
  );

  // ── Schedule / Calendar ────────────────────────────────────────
  /// Jadwal (schedule) — cobalt `Icons.calendar_today_outlined`.
  static final DashboardModule jadwal = DashboardModule(
    icon: Icons.calendar_today_outlined,
    color: ColorUtils.brandCobalt,
    defaultLabel: 'Jadwal',
  );

  // ── Admin operational ──────────────────────────────────────────
  /// Siswa (students) — corporate-blue `Icons.people_alt_outlined`.
  static final DashboardModule siswa = DashboardModule(
    icon: Icons.people_alt_outlined,
    color: ColorUtils.corporateBlue600,
    defaultLabel: 'Siswa',
  );

  /// Guru (teachers) — violet `Icons.person_outline`.
  /// Distinct from Siswa so admin's People hub reads at a glance.
  static final DashboardModule guru = DashboardModule(
    icon: Icons.person_outline,
    color: ColorUtils.violet700,
    defaultLabel: 'Guru',
  );

  /// Kelas (classes) — amber `Icons.class_outlined`.
  static final DashboardModule kelas = DashboardModule(
    icon: Icons.class_outlined,
    color: ColorUtils.warning600,
    defaultLabel: 'Kelas',
  );

  /// Mata Pelajaran (subjects) — indigo `Icons.book_outlined`.
  /// Shares the indigo accent with Materi since both are "what's
  /// being taught".
  static final DashboardModule mataPelajaran = DashboardModule(
    icon: Icons.book_outlined,
    color: ColorUtils.indigo500,
    defaultLabel: 'Mata Pelajaran',
  );

  /// Keuangan (finance dashboard) — red wallet — same accent as Tagihan.
  static final DashboardModule keuangan = DashboardModule(
    icon: Icons.account_balance_wallet_outlined,
    color: ColorUtils.error600,
    defaultLabel: 'Keuangan',
  );

  /// Laporan / Reports overview — amber `Icons.summarize_outlined`.
  static final DashboardModule laporan = DashboardModule(
    icon: Icons.summarize_outlined,
    color: ColorUtils.warning600,
    defaultLabel: 'Laporan',
  );

  // ── Settings / Account ─────────────────────────────────────────
  /// Pengaturan / Settings — slate `Icons.settings_outlined`.
  static final DashboardModule pengaturan = DashboardModule(
    icon: Icons.settings_outlined,
    color: ColorUtils.slate600,
    defaultLabel: 'Pengaturan',
  );

  /// Akun (account / profile) — slate `Icons.account_circle_outlined`.
  static final DashboardModule akun = DashboardModule(
    icon: Icons.account_circle_outlined,
    color: ColorUtils.slate600,
    defaultLabel: 'Akun',
  );
}
