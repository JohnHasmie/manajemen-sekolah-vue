// Admin Pengaturan hub (Phase 6 · T4.5).
//
// Why this exists
// ---------------
// The old admin Pengaturan tile routed straight to [SchoolSettingsScreen],
// which is a 2-card grid (General Settings · Time Settings) — same visual
// as Settings on the guru role because it just wraps the shared
// [UIMixin.buildMainScaffold]. That leaves no room for admin-only
// concerns (promotion, notifications, system users, data management) and
// buries them behind unrelated tiles on the dashboard grid.
//
// [SystemSettingsScreen] replaces that target. It is the admin-only
// "kitchen sink" settings hub: one expanded [SchoolPill] hero, two
// sections of list-card menu items, one ListView. Everything the admin
// can configure about the school (data + system + account) is reachable
// from here instead of being scattered across the dashboard grid.
//
// Shape
// -----
//   1. Navy gradient header with back button + title ("Pengaturan Sistem")
//   2. SchoolPill.expanded — matches Dashboard hero so the same school
//      identity renders identically on both surfaces
//   3. Section "Manajemen Sistem":
//        • Profil sekolah      → SchoolLevelSettingsScreen
//        • Waktu pembelajaran  → TimeSettingsScreen
//        • Manajemen data      → AdminDataManagementScreen (Siswa/Guru/…)
//        • Naik kelas & kelulusan (stub)
//   4. Section "Notifikasi & Akun":
//        • Pengaturan notifikasi (stub)
//        • Pengguna sistem       (stub)
//        • Profil akun           → SettingsScreen (shared profile)
//
// Satu-implementasi-tiga-role
// ---------------------------
// This hub is admin-only by construction — it is targeted from the
// admin dashboard's Pengaturan tile. Guru/wali continue to reach profile
// settings directly through [SettingsScreen]. The stub menu items show a
// "Segera hadir" snackbar rather than navigating, matching the pattern
// used elsewhere when a destination is queued for a later phase.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/school_pill.dart';
import 'package:manajemensekolah/core/widgets/section_header.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/data_management_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/school_level_settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/time_settings_screen.dart';

/// Admin Pengaturan hub screen.
///
/// Accepts the active-school name and optional logo URL so the hero
/// [SchoolPill.expanded] renders without waiting on its own fetch. The
/// dashboard already has these values in [DashboardState.userData], so it
/// just hands them through on navigation — no extra request needed.
class SystemSettingsScreen extends ConsumerWidget {
  /// Active-school display name. Dashboard passes
  /// `state.userData['nama_sekolah']`. A null/empty value falls back to
  /// the string 'Sekolah' so the hero never renders blank.
  final String? schoolName;

  /// Optional logo URL for the hero avatar. When null, [SchoolPill]
  /// renders a monogrammed initial instead.
  final String? schoolLogoUrl;

  /// Subtitle under the school name — usually the academic year.
  /// Defaults to 'Admin sekolah'.
  final String subtitle;

  const SystemSettingsScreen({
    super.key,
    this.schoolName,
    this.schoolLogoUrl,
    this.subtitle = 'Admin sekolah',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primary = ColorUtils.getRoleColor('admin');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _Header(primaryColor: primary),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SchoolPill.expanded(
                    schoolName: _resolvedSchoolName,
                    subtitle: subtitle,
                    logoUrl: schoolLogoUrl,
                    accentColor: primary,
                    // No onTap: school switching lives on the dashboard
                    // pill; here we just display the active school.
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Manajemen Sistem',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.school_rounded,
                    title: 'Profil sekolah',
                    subtitle: 'Jenjang, nama, dan alamat sekolah',
                    accentColor: primary,
                    onTap: () => AppNavigator.push(
                      context,
                      const SchoolLevelSettingsScreen(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.access_time_rounded,
                    title: 'Waktu pembelajaran',
                    subtitle: 'Jam pelajaran & durasi per hari',
                    accentColor: primary,
                    onTap: () =>
                        AppNavigator.push(context, const TimeSettingsScreen()),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.dataset_rounded,
                    title: 'Manajemen data',
                    subtitle: 'Siswa, guru, kelas, dan mata pelajaran',
                    accentColor: primary,
                    onTap: () => AppNavigator.push(
                      context,
                      const AdminDataManagementScreen(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.trending_up_rounded,
                    title: 'Naik kelas & kelulusan',
                    subtitle: 'Proses kenaikan kelas akhir tahun',
                    accentColor: primary,
                    trailingLabel: 'Segera',
                    onTap: () => _comingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SectionHeader(
                    title: 'Notifikasi & Akun',
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.notifications_active_rounded,
                    title: 'Pengaturan notifikasi',
                    subtitle: 'Kelola pemberitahuan sistem',
                    accentColor: primary,
                    trailingLabel: 'Segera',
                    onTap: () => _comingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.people_alt_rounded,
                    title: 'Pengguna sistem',
                    subtitle: 'Daftar akun guru & admin',
                    accentColor: primary,
                    trailingLabel: 'Segera',
                    onTap: () => _comingSoon(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _MenuCard(
                    icon: Icons.person_rounded,
                    title: 'Profil akun',
                    subtitle: 'Ubah nama, email, dan kata sandi Anda',
                    accentColor: primary,
                    onTap: () =>
                        AppNavigator.push(context, const SettingsScreen()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _resolvedSchoolName {
    final raw = schoolName?.trim();
    if (raw == null || raw.isEmpty) return 'Sekolah';
    return raw;
  }

  void _comingSoon(BuildContext context) {
    SnackBarUtils.showInfo(
      context,
      'Segera hadir — fitur ini sedang disiapkan.',
    );
  }
}

/// Navy gradient header with back button + page title.
///
/// Kept local (not extracted to `gradient_page_header.dart`) because the
/// admin Pengaturan hub uses the role-navy accent while
/// [GradientPageHeader] defaults to corporate blue. When a second admin
/// settings screen lands we can promote this to a shared widget.
class _Header extends StatelessWidget {
  final Color primaryColor;

  const _Header({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
        ),
      ),
      child: Row(
        children: [
          _BackButton(onTap: () => AppNavigator.pop(context)),
          const SizedBox(width: AppSpacing.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pengaturan Sistem',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kelola sekolah, pengguna, dan preferensi',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
      ),
    );
  }
}

/// A single list-card menu item.
///
/// Visual: 44×44 accent-tinted icon tile on the left, title + subtitle
/// in the middle, optional trailing "Segera" chip + chevron on the
/// right. Matches the existing list-card pattern used on the admin
/// dashboard inbox rows for visual consistency across admin hubs.
class _MenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;

  /// When non-null, renders a small pill (e.g. "Segera") between the
  /// subtitle and the chevron to flag upcoming features.
  final String? trailingLabel;

  const _MenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.trailingLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(14)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.10),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailingLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: const BorderRadius.all(Radius.circular(999)),
                  ),
                  child: Text(
                    trailingLabel!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
              ],
              Icon(
                Icons.chevron_right_rounded,
                color: ColorUtils.slate400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
