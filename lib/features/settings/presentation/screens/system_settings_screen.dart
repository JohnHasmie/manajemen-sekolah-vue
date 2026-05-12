// Admin Pengaturan hub — Mockup #14 applied.
//
// Visual contract (matches Admin_Mockups_Phase_Final.html, mockup 14):
//   1. Compact navy gradient hero (200px) with back button + title
//      ("Sistem") + subtitle "Konfigurasi" + HealthPill ("Sinkron ·
//      konfigurasi sehat").
//   2. CategoryGridHero — 2-column 170×120 tile grid below the hero.
//      Each tile has a pastel-tinted icon square + title + subline +
//      optional meta line.
//   3. AuditLogPin — pinned card at the bottom showing the latest
//      audit log entry. Tap drills to the full audit list (placeholder
//      snackbar until that screen lands).
//
// Routing for tiles is preserved from the prior implementation so
// nothing breaks for admins mid-flight; tiles that don't yet have a
// destination show a "Segera hadir" snackbar exactly like before.
//
// Satu-implementasi-tiga-role
// ---------------------------
// Hub is admin-only by construction (targeted from the admin
// dashboard's Sistem tile). All shared components used here
// (CategoryGridHero, AuditLogPin, HealthPill) live under
// `lib/core/widgets/` so future role-specific settings screens can
// adopt the same idiom.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_settings_components.dart';
import 'package:manajemensekolah/features/settings/data/system_settings_service.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/time_settings_screen.dart';

class SystemSettingsScreen extends ConsumerWidget {
  /// Active-school display name. Dashboard passes
  /// `state.userData['nama_sekolah']`. A null/empty value falls back
  /// to 'Sekolah' so the hero never renders blank.
  final String? schoolName;

  /// Optional logo URL — currently not surfaced in the new mockup
  /// (the hero is now compact + chip-driven instead of avatar-led).
  /// Kept on the constructor for backwards compatibility with
  /// callers that still pass it from earlier phases.
  final String? schoolLogoUrl;

  /// Subtitle under the hero — usually the academic year.
  final String subtitle;

  const SystemSettingsScreen({
    super.key,
    this.schoolName,
    this.schoolLogoUrl,
    this.subtitle = 'Admin sekolah',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navy = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _Hero(navy: navy, subtitle: subtitle),
          const SizedBox(height: AppSpacing.lg),
          CategoryGridHero(tiles: _buildTiles(context, ref, navy)),
          const SizedBox(height: AppSpacing.md),
          _AuditLogPinConsumer(navy: navy),
          SizedBox(
            height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
          ),
        ],
      ),
    );
  }

  List<CategoryTile> _buildTiles(
    BuildContext context,
    WidgetRef ref,
    Color navy,
  ) {
    return [
      CategoryTile(
        icon: Icons.calendar_today_rounded,
        iconBg: const Color(0xFFEEF2FF),
        iconFg: navy,
        title: 'Tahun Ajaran',
        subline: 'Periode aktif & arsip',
        meta: 'Profil sekolah · jenjang',
        onTap: () =>
            AppNavigator.push(context, const SchoolLevelSettingsScreen()),
      ),
      CategoryTile(
        icon: Icons.access_time_rounded,
        iconBg: const Color(0xFFFEF3C7),
        iconFg: const Color(0xFF92400E),
        title: 'Waktu Pembelajaran',
        subline: 'Jam pelajaran & durasi',
        meta: 'Per hari · per kelas',
        onTap: () => AppNavigator.push(context, const TimeSettingsScreen()),
      ),
      CategoryTile(
        icon: Icons.dataset_rounded,
        iconBg: const Color(0xFFDCFCE7),
        iconFg: const Color(0xFF166534),
        title: 'Manajemen Data',
        subline: 'Siswa, guru, kelas, mapel',
        onTap: () =>
            AppNavigator.push(context, const AdminDataManagementScreen()),
      ),
      CategoryTile(
        icon: Icons.language_rounded,
        iconBg: const Color(0xFFF3E8FF),
        iconFg: const Color(0xFF7C3AED),
        title: 'Bahasa',
        subline: 'Antarmuka & laporan',
        meta: 'Indonesia · default',
        onTap: () => AppNavigator.push(context, const SettingsScreen()),
      ),
      CategoryTile(
        icon: Icons.notifications_active_rounded,
        iconBg: const Color(0xFFFEE2E2),
        iconFg: const Color(0xFFDC2626),
        title: 'Notifikasi',
        subline: 'Push, email, SMS',
        trailingBadge: 'SEGERA',
        onTap: () => _comingSoon(context),
      ),
      CategoryTile(
        icon: Icons.backup_rounded,
        iconBg: const Color(0xFFE0E7FF),
        iconFg: const Color(0xFF4338CA),
        title: 'Backup & Audit',
        subline: 'Cadangan otomatis',
        meta: 'Harian · audit log',
        onTap: () => _comingSoon(context),
      ),
    ];
  }

  void _comingSoon(BuildContext context) {
    SnackBarUtils.showInfo(
      context,
      'Segera hadir — fitur ini sedang disiapkan.',
    );
  }
}

class _Hero extends StatelessWidget {
  final Color navy;
  final String subtitle;
  const _Hero({required this.navy, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        topInset + AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(gradient: ColorUtils.brandGradient('admin')),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => AppNavigator.pop(context),
              child: const SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Konfigurasi',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Sistem',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const HealthPill(
                  state: HealthState.ok,
                  label: 'Sinkron · konfigurasi sehat',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditLogPinConsumer extends ConsumerWidget {
  final Color navy;
  const _AuditLogPinConsumer({required this.navy});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(latestAuditLogProvider);
    return async.when(
      data: (result) => AuditLogPin(
        latest: result.latest,
        onSeeAll: () => SnackBarUtils.showInfo(
          context,
          'Layar audit log lengkap segera hadir.',
        ),
      ),
      // While loading or on error, render an empty pin so the layout
      // stays stable. Audit-log freshness is non-critical info.
      loading: () => const AuditLogPin(latest: null, onSeeAll: _noop),
      error: (_, __) => const AuditLogPin(latest: null, onSeeAll: _noop),
    );
  }
}

void _noop() {}
