// AdminSubjectCard — a tappable row card showing one subject in the admin
// class-activity drill-down (second level: Subject list for a teacher).
//
// Extracted from `AdminClassActivityScreenState._buildSubjectCard`.
// Think of this like a Vue `<AdminSubjectCard :subject="item" @tap />` — a
// pure presentational widget; the parent handles navigation via [onTap].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A single card representing one subject in the admin class-activity screen.
///
/// Constructor params (Vue-style props):
/// - [subject] — raw API map for the subject entry
/// - [index]   — list position, used to pick the accent colour
/// - [onTap]   — called when the card is tapped; parent handles navigation
class AdminSubjectCard extends StatelessWidget {
  final Map<String, dynamic> subject;
  final int index;

  /// Fired when the user taps the card.
  /// The parent screen calls [_loadActivitiesBySubject] in response —
  /// this widget stays stateless.
  final VoidCallback onTap;

  const AdminSubjectCard({
    super.key,
    required this.subject,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subjectName = subject['name']?.toString() ?? 'Mata Pelajaran';
    final subjectColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // Coloured icon container
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: subjectColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: subjectColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: subjectColor,
                    size: 22,
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                // Subject name + hint text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      Text(
                        'Ketuk untuk melihat kegiatan',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Chevron
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.chevron_right,
                    color: ColorUtils.slate500,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
