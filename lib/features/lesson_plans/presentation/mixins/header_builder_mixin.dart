import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/drag_handle.dart';
import 'package:manajemensekolah/features/lesson_plans/domain/models/lesson_plan.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin HeaderBuilderMixin on State<LessonPlanAdminDetailPage> {
  late Map<String, dynamic> lessonPlan;

  String get _lpTitle => LessonPlan.fromJson(lessonPlan).title;

  /// Builds the gradient header for the admin detail **bottom sheet**.
  ///
  /// Matches the sheet shell now used by [LessonPlanDetailHeader] on the
  /// teacher side: drag handle on top, status-bar compensation removed
  /// (the sheet sits inside SafeArea), rounded top corners, and a close-X
  /// affordance instead of the old back-arrow.
  Widget buildHeader(BuildContext context, Color statusColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
      decoration: buildHeaderDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const DragHandle.onGradient(),
          Row(
            children: [
              buildBackButton(context),
              const SizedBox(width: AppSpacing.md),
              buildHeaderTitle(),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration buildHeaderDecoration() {
    // Brand-aligned gradient + shadow (HH.11). The previous alpha-faded
    // single-color gradient was replaced with `ColorUtils.brandGradient`
    // so the admin detail sheet uses the same two-stop navy as the rest
    // of the brand surfaces (matches `RoleDashboardHero` admin variant).
    // Shadow values match the brand spec: α=0.18 / blur 18 / y-offset 6.
    // Top-only corner radius is kept — this is a bottom-sheet header,
    // not a page header.
    return BoxDecoration(
      gradient: ColorUtils.brandGradient('admin'),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      boxShadow: [
        BoxShadow(
          color: getPrimaryColor().withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    );
  }

  Widget buildBackButton(BuildContext context) {
    return GestureDetector(
      onTap: () => AppNavigator.pop(context),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
      ),
    );
  }

  Widget buildHeaderTitle() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detail RPP',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
          if (_lpTitle.isNotEmpty) buildHeaderSubtitle(),
        ],
      ),
    );
  }

  Widget buildHeaderSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 2),
        Text(
          _lpTitle,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.85),
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget buildHeaderMenu(BuildContext context) {
    return PopupMenuButton(
      onSelected: (value) {
        if (value == 'approve') {
          showUpdateStatusDialog(context, 'Disetujui');
        } else if (value == 'reject') {
          showUpdateStatusDialog(context, 'Ditolak');
        }
      },
      icon: buildMenuIcon(),
      itemBuilder: (context) => buildMenuItems(),
    );
  }

  Widget buildMenuIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
    );
  }

  List<PopupMenuEntry<String>> buildMenuItems() {
    return [
      PopupMenuItem(
        value: 'approve',
        child: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: ColorUtils.success600,
              size: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Text('Setujui RPP'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'reject',
        child: Row(
          children: [
            Icon(Icons.cancel_outlined, color: ColorUtils.error600, size: 20),
            const SizedBox(width: AppSpacing.sm),
            const Text('Tolak RPP'),
          ],
        ),
      ),
    ];
  }

  // Abstract methods
  Color getPrimaryColor();
  void showUpdateStatusDialog(BuildContext context, String status);
}
