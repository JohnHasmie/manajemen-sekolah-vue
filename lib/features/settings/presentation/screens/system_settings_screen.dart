// Admin Pengaturan ("Sistem") hub.
//
// Visual contract — matches the parent Akademik hub / admin People +
// Academic hubs so every dashboard list-menu surface reads as the same
// brand:
//
//   1. Navy `ShellTabHeader` — title "Sistem" + descriptive subtitle,
//      no back button (shell handles back via PopScope).
//   2. Vertical list of `DashboardListTile` cards — one per settings
//      sub-module (Tahun Ajaran, Waktu Pembelajaran, Manajemen Data,
//      Bahasa, Notifikasi, Backup & Audit). Icons + accents come from
//      the shared `DashboardModules` catalog so identity stays
//      consistent if the same module surfaces elsewhere.
//   3. `AuditLogPin` — pinned card at the bottom with the latest audit
//      log entry. Unchanged from the prior implementation.
//
// `schoolName`, `schoolLogoUrl`, and `subtitle` constructor params are
// retained for backward compatibility with the dashboard's
// `_openPengaturan` call site, but the new header no longer surfaces
// them — the tab-header pattern intentionally keeps the strip tight.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_settings_components.dart'
    show AuditLogPin;
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/settings/data/system_settings_service.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/time_settings_screen.dart';

class SystemSettingsScreen extends ConsumerWidget {
  /// Active-school display name. Retained for backwards compatibility
  /// with the dashboard's _openPengaturan call site; the new header
  /// doesn't render it.
  final String? schoolName;

  /// Optional logo URL — see `schoolName`.
  final String? schoolLogoUrl;

  /// Subtitle previously surfaced under the school name. The
  /// `ShellTabHeader`'s subtitle now describes the section instead.
  final String subtitle;

  const SystemSettingsScreen({
    super.key,
    this.schoolName,
    this.schoolLogoUrl,
    this.subtitle = 'Admin sekolah',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ShellTabHeader(
              title: 'Sistem',
              subtitle: 'Konfigurasi · sinkron sehat',
              accentColor: accent,
            ),
            const SizedBox(height: AppSpacing.md),
            ..._buildTiles(context, ref),
            const SizedBox(height: AppSpacing.md),
            _AuditLogPinConsumer(),
            SizedBox(
              height: AppSpacing.xl + MediaQuery.of(context).padding.bottom,
            ),
          ],
        ),
      ),
    );
  }

  /// One `DashboardListTile` per sub-module — same shape, padding, and
  /// shadow as the parent Akademik hub so cross-role list menus
  /// render identically.
  List<Widget> _buildTiles(BuildContext context, WidgetRef ref) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Tahun Ajaran',
          subtitle: 'Periode aktif & arsip · profil sekolah',
          icon: DashboardModules.tahunAjaran.icon,
          color: DashboardModules.tahunAjaran.color,
          onTap: () =>
              AppNavigator.push(context, const SchoolLevelSettingsScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Waktu Pembelajaran',
          subtitle: 'Jam pelajaran & durasi per hari',
          icon: DashboardModules.waktuPembelajaran.icon,
          color: DashboardModules.waktuPembelajaran.color,
          onTap: () => AppNavigator.push(context, const TimeSettingsScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Manajemen Data',
          subtitle: 'Siswa, guru, kelas, mapel',
          icon: DashboardModules.manajemenData.icon,
          color: DashboardModules.manajemenData.color,
          onTap: () =>
              AppNavigator.push(context, const AdminDataManagementScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Bahasa',
          subtitle: 'Antarmuka & laporan · Indonesia',
          icon: DashboardModules.bahasa.icon,
          color: DashboardModules.bahasa.color,
          onTap: () => AppNavigator.push(context, const SettingsScreen()),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Notifikasi',
          subtitle: 'Push, email, SMS · segera hadir',
          icon: DashboardModules.notifikasi.icon,
          color: DashboardModules.notifikasi.color,
          onTap: () => _comingSoon(context),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: DashboardListTile(
          title: 'Backup & Audit',
          subtitle: 'Cadangan otomatis · harian',
          icon: DashboardModules.backupAudit.icon,
          color: DashboardModules.backupAudit.color,
          onTap: () => _comingSoon(context),
        ),
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

class _AuditLogPinConsumer extends ConsumerWidget {
  const _AuditLogPinConsumer();

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
