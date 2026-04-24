// AdminTeacherCard — a tappable row card showing one teacher in the admin
// class-activity drill-down (first level: Teacher list).
//
// Extracted from `AdminClassActivityScreenState._buildTeacherCard`.
// Think of this like a Vue `<AdminTeacherCard :teacher="item" @tap />` component —
// a pure presentational widget; all navigation is delegated via [onTap].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_info_tag.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// A single card representing one teacher in the admin class-activity screen.
///
/// Constructor params (Vue-style props):
/// - [teacher] — raw API map for the teacher entry
/// - [index]   — list position, used to pick the avatar colour
/// - [onTap]   — called when the card is tapped; parent handles navigation
class AdminTeacherCard extends StatelessWidget {
  final Map<String, dynamic> teacher;
  final int index;

  /// Fired when the user taps the card.
  /// The parent screen calls [_loadSubjectsByTeacher] in response —
  /// this widget stays stateless and has no knowledge of that logic.
  final VoidCallback onTap;

  const AdminTeacherCard({
    super.key,
    required this.teacher,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final model = Teacher.fromJson(teacher);
    final teacherName = model.name.isNotEmpty
        ? model.name
        : 'Nama tidak tersedia';
    final teacherEmail = model.email;
    final teacherNip = model.employeeNumber ?? '';
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // CircleAvatar with first letter of teacher name
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    teacherName[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Teacher info column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        teacherName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (teacherEmail.isNotEmpty || teacherNip.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            if (teacherEmail.isNotEmpty)
                              ActivityInfoTag(
                                icon: Icons.email_outlined,
                                label: teacherEmail,
                              ),
                            if (teacherNip.isNotEmpty)
                              ActivityInfoTag(
                                icon: Icons.badge_outlined,
                                label: 'NIP: $teacherNip',
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Chevron
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ColorUtils.slate100,
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
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
