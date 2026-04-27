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
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/teacher_announcement_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
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
          _ShellTabHeader(
            title: 'Lainnya',
            subtitle: 'Pengumuman, rekomendasi belajar, dan akun',
            accentColor: accent,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: 'Pengumuman',
                  icon: Icons.announcement_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const TeacherAnnouncementScreen(),
                  ),
                ),
                if (isHomeroomTeacher) ...[
                  const SizedBox(height: AppSpacing.sm),
                  MenuItemCard(
                    title: 'Rekomendasi Belajar',
                    icon: Icons.auto_awesome_outlined,
                    primaryColor: accent,
                    onTap: () => _openRecommendation(context, ref),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Akun',
                  icon: Icons.person_outline,
                  primaryColor: accent,
                  onTap: () =>
                      AppNavigator.push(context, const SettingsScreen()),
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
      SnackBarUtils.showInfo(context, 'Data dashboard belum termuat.');
      return;
    }
    final userData = state.userData;
    final id =
        (userData['teacher_id'] ?? userData['id'])?.toString() ?? '';
    if (id.isEmpty) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    final teacherData = <String, String>{
      'id': id,
      'nama': (userData['nama'] ?? userData['name'] ?? 'Teacher').toString(),
      'email': (userData['email'] ?? '').toString(),
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

class _ShellTabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _ShellTabHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 16,
        right: 16,
        bottom: 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [accentColor, accentColor.withValues(alpha: 0.85)],
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }
}
