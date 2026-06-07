import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Tab bar for sub-chapter detail with Material, Quiz, Reference tabs.
class SubChapterTabBar extends StatelessWidget {
  final TabController controller;
  final Color primaryColor;
  final List<Map<String, dynamic>> quizzes;

  const SubChapterTabBar({
    super.key,
    required this.controller,
    required this.primaryColor,
    required this.quizzes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: TabBar(
        controller: controller,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: primaryColor,
        unselectedLabelColor: ColorUtils.slate500,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        // Tab labels use `Flexible(child: Text(..., overflow: ellipsis))`
        // rather than plain Text. Without the Flexible, the intrinsic width
        // of `Icon(16) + SizedBox(6) + Text('Referensi')` edges past the
        // per-tab slot (3 tabs, ~117 px each on a 6.1" screen), producing
        // a 0.28 px right-side overflow that Flutter paints the yellow/black
        // overflow hatching for (#136). Flexible lets the text ellipsize
        // before it busts the row, and MainAxisSize.min keeps the label
        // centered within the slot when it doesn't need to shrink.
        tabs: [
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.auto_stories_rounded, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(kMatMaterialsTab.tr, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.quiz_rounded, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(kMatQuizTab.tr, overflow: TextOverflow.ellipsis),
                ),
                if (quizzes.isNotEmpty) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.15),
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                    ),
                    child: Text(
                      '${quizzes.length}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Tab(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.menu_book_rounded, size: 16),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(kMatReferenceTab.tr, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
