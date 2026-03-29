// Student list card widget - extracted from admin_student_management_screen.dart.
//
// Like a Vue component that renders a single row in the students table.
// Receives all data + callbacks as constructor params (no direct Riverpod reads),
// keeping this purely presentational — equivalent to a "dumb component" in Vue.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Renders a single student list card with avatar, name, class, gender,
/// status badge, and optional edit/delete action buttons.
///
/// [student]    - the raw API map for this student.
/// [index]      - list index used to derive the avatar color palette.
/// [primaryColor] - the role accent color (admin = blue-ish).
/// [isReadOnly] - when true hides edit/delete buttons (read-only academic year).
/// [genderText] - already-translated gender label ("Male" / "Female").
/// [onTap]      - navigate to student detail.
/// [onEdit]     - open the edit bottom sheet.
/// [onDelete]   - trigger delete confirmation.
class StudentCardWidget extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  final Color primaryColor;
  final bool isReadOnly;
  final String genderText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StudentCardWidget({
    super.key,
    required this.student,
    required this.index,
    required this.primaryColor,
    required this.isReadOnly,
    required this.genderText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = ColorUtils.getColorForIndex(index);
    final className = student['class']?['name'] ?? '-';

    return Container(
      margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200, width: 1),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              children: [
                // Compact Avatar — first letter of student name.
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    (student['name'] ?? 'N')[0].toUpperCase(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),

                // Student info — name + class/gender chips.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Text(
                        student['name'] ?? 'No Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      // Compact info chips
                      Row(
                        children: [
                          _StudentInfoTag(
                            icon: Icons.school_outlined,
                            text: className,
                          ),
                          SizedBox(width: 6),
                          _StudentInfoTag(
                            icon: Icons.person_outline,
                            text: genderText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),

                // Right side: status badge + action buttons.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Active status dot badge
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: ColorUtils.success600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: ColorUtils.success600.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: ColorUtils.success600,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: AppSpacing.xs),
                          Text(
                            'Active',
                            style: TextStyle(
                              color: ColorUtils.success600,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Edit / Delete buttons — hidden in read-only mode.
                    if (!isReadOnly) ...[
                      SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          // Edit button
                          InkWell(
                            onTap: onEdit,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.edit_outlined,
                                size: 16,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          // Delete button
                          InkWell(
                            onTap: onDelete,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: ColorUtils.error600.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.delete_outline,
                                size: 16,
                                color: ColorUtils.error600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon + text pill used inside [StudentCardWidget].
///
/// Like a tiny Vue chip component — just an icon and a label in a rounded box.
class _StudentInfoTag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _StudentInfoTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          SizedBox(width: 3),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
