// Displays a single teacher row in the drill-down teacher-selection list.
// Extracted from AdminLessonPlanScreen._buildTeacherCard so the card can be
// tested and reused independently of the parent screen's state.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Tappable card showing a teacher's avatar, name and NIP.
///
/// Like a Vue `<TeacherCard>` component: data flows in via constructor and
/// the tap action bubbles up via [onTap] — no setState inside this widget.
class TeacherSelectCard extends StatelessWidget {
  /// Raw teacher map from the API response.
  final Map<String, dynamic> teacher;

  /// Position in the list — determines the avatar accent colour.
  final int index;

  /// Called when the card is tapped (selects this teacher).
  final VoidCallback onTap;

  const TeacherSelectCard({
    super.key,
    required this.teacher,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    teacher['name'] != null &&
                            (teacher['name'] as String).isNotEmpty
                        ? (teacher['name'] as String)[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacher['name'] ?? 'Unknown',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: ColorUtils.slate900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        teacher['employee_number'] != null
                            ? 'NIP: ${teacher['employee_number']}'
                            : 'No NIP',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate500,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: ColorUtils.slate400,
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
