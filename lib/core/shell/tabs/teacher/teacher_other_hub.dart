// Teacher "Other" tab root — hub for communication, AI features, and
// account settings.
//
// Per `P1_BottomNav_Spec.md` § 2.2 — guru's Lainnya tab holds:
//   - Pengumuman (school announcements, read-only for teachers)
//   - Rekomendasi Belajar (AI feature, wali-kelas only — gated by
//     `state.homeroomClasses.isNotEmpty`)
//   - Akun (the user's profile / account settings)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/constants/dashboard_modules.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/dashboard_list_tile.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/recommendations/presentation/screens/recommendation_class_screen.dart';
import 'package:manajemensekolah/features/settings/presentation/screens/settings_screen.dart';

class TeacherOtherHub extends ConsumerWidget {
  const TeacherOtherHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('guru');
    final dashboardState = ref.watch(dashboardProvider).asData?.value;
    final isHomeroomTeacher =
        (dashboardState?.homeroomClasses ?? const []).isNotEmpty;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: kCorSheTabOther.tr,
            subtitle: kCorSheTeacherOtherSubtitle.tr,
            accentColor: accent,
          ),
          // Shared `DashboardListTile` — same card design as parent
          // Akademik hub. Icons + colors from the catalog.
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 16, 0, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: kAnnouncements.tr,
                    subtitle: kCorSheAdminAnnouncementsSubtitle.tr,
                    icon: DashboardModules.pengumuman.icon,
                    color: DashboardModules.pengumuman.color,
                    onTap: () => AppNavigator.push(
                      context,
                      const TeacherAnnouncementScreen(),
                    ),
                  ),
                ),
                if (isHomeroomTeacher)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: DashboardListTile(
                      title: kCorSheTeacherRecommendations.tr,
                      subtitle: kCorSheTeacherRecommendationsSubtitle.tr,
                      icon: DashboardModules.rekomendasi.icon,
                      color: DashboardModules.rekomendasi.color,
                      onTap: () => _openRecommendation(context, ref),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: DashboardListTile(
                    title: kCorSheAccount.tr,
                    subtitle: kCorSheProfileSettings.tr,
                    icon: DashboardModules.akun.icon,
                    color: DashboardModules.akun.color,
                    onTap: () =>
                        AppNavigator.push(context, const SettingsScreen()),
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRecommendation(BuildContext context, WidgetRef ref) {
    final state = ref.read(dashboardProvider).asData?.value;
    if (state == null) {
      SnackBarUtils.showInfo(context, kCorSheDashboardNotLoaded.tr);
      return;
    }
    final tp = ref.read(teacherRiverpod);
    final id = tp.teacherId;
    if (id == null || id.isEmpty) {
      SnackBarUtils.showInfo(context, kCorSheTeacherIdNotFound.tr);
      return;
    }
    final teacherData = <String, String>{
      'id': id,
      'nama': tp.teacherName ?? 'Teacher',
      'email': state.userData['email']?.toString() ?? '',
      'role': 'guru',
    };
    AppNavigator.push(
      context,
      LearningRecommendationClassScreen(
        teacher: teacherData,
        classes: state.homeroomClasses,
      ),
    );
  }
}
