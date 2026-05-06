// Teacher "Teaching" tab root — hub of teaching/lesson surfaces.
//
// Per `P1_BottomNav_Spec.md` § 2.2 — guru's Mengajar tab groups
// planning + delivery screens: Jadwal, RPP, Materi, Kegiatan Kelas.
//
// Most destinations need a `teacher: Map<String, String>` param built
// from `DashboardState.userData`, so the hub reads the dashboard
// provider on tap rather than at build-time (avoids coupling the
// hub's mount to dashboard state being ready).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/shell/widgets/shell_tab_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';
import 'package:manajemensekolah/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:manajemensekolah/features/teachers/presentation/providers/teacher_provider.dart';
import 'package:manajemensekolah/features/dashboard/presentation/widgets/menu_item_card.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/teacher_lesson_plan_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/teacher_schedule_screen.dart';

class TeacherTeachingHub extends ConsumerWidget {
  const TeacherTeachingHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ColorUtils.getRoleColor('guru');
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ShellTabHeader(
            title: 'Mengajar',
            subtitle: 'Jadwal, materi, RPP, dan kegiatan kelas',
            accentColor: accent,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              children: [
                MenuItemCard(
                  title: 'Jadwal Mengajar',
                  icon: Icons.schedule_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const TeachingScheduleScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Kegiatan Kelas',
                  icon: Icons.local_activity_outlined,
                  primaryColor: accent,
                  onTap: () => AppNavigator.push(
                    context,
                    const TeacherClassActivityScreen(),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'Materi Pembelajaran',
                  icon: Icons.book_outlined,
                  primaryColor: accent,
                  onTap: () => _openMaterials(context, ref),
                ),
                const SizedBox(height: AppSpacing.sm),
                MenuItemCard(
                  title: 'RPP Saya',
                  icon: Icons.description_outlined,
                  primaryColor: accent,
                  onTap: () => _openLessonPlans(context, ref),
                ),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openMaterials(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(context, TeacherMaterialScreen(teacher: teacherData));
  }

  void _openLessonPlans(BuildContext context, WidgetRef ref) {
    final teacherData = _resolveTeacherData(ref);
    if (teacherData == null) {
      SnackBarUtils.showInfo(context, 'ID guru tidak ditemukan.');
      return;
    }
    AppNavigator.push(
      context,
      LessonPlanScreen(
        teacherId: teacherData['id']!,
        teacherName: teacherData['nama']!,
      ),
    );
  }

  /// Build the teacher map shape that downstream screens expect.
  /// Returns null when the teacher id is missing — caller should toast.
  Map<String, String>? _resolveTeacherData(WidgetRef ref) {
    final tp = ref.read(teacherRiverpod);
    final id = tp.teacherId;
    if (id == null || id.isEmpty) return null;
    return {
      'id': id,
      'nama': tp.teacherName ?? 'Teacher',
      'email': ref.read(dashboardProvider).asData?.value
              .userData['email']?.toString() ?? '',
      'role': 'guru',
    };
  }
}

/// Same gradient-header pattern as the admin hubs. Local copy keeps each
/// tab file self-contained until Sub-PR 5/6 extracts a shared widget.
