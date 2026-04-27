// StudentCard widget -- renders a single student list item.
//
// Like a Vue `<StudentCard>` component. Extracted from
// AdminStudentManagementScreen._buildStudentCard so the card
// can be reused and tested independently.
//
// Props (like Vue props):
// - [student]       -- raw student map from the API
// - [index]         -- position in the list (drives avatar color)
// - [isReadOnly]    -- hides edit/delete buttons when the academic year is locked
// - [primaryColor]  -- role-based accent color passed down from the screen
// - [genderText]    -- pre-translated gender label
// - [onTap]         -- navigate to student detail
// - [onEdit]        -- open the edit dialog
// - [onDelete]      -- confirm and delete the student

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// A single student card in the admin student list.
///
/// Stateless -- all mutable data and actions are injected as constructor
/// params, the same way a Vue component receives props and emits events.
class StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final int index;
  final bool isReadOnly;
  final Color primaryColor;
  final String genderText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const StudentCard({
    super.key,
    required this.student,
    required this.index,
    required this.isReadOnly,
    required this.primaryColor,
    required this.genderText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Small icon+text chip -- like a Vue `<InfoTag>` sub-component.
  Widget _buildInfoTag(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          const SizedBox(width: 3),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final avatarColor = ColorUtils.getColorForIndex(index);
    final model = Student.fromJson(student);
    final className = model.className.isNotEmpty ? model.className : '-';

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
                // Compact Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    model.initials,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Student Info (expanded)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name row
                      Text(
                        model.name.isNotEmpty ? model.name : 'No Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      // Compact info chips
                      Row(
                        children: [
                          _buildInfoTag(Icons.school_outlined, className),
                          const SizedBox(width: 6),
                          _buildInfoTag(Icons.person_outline, genderText),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Right side: status + actions
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Status dot
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ColorUtils.success600.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
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
                          const SizedBox(width: AppSpacing.xs),
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
                    // Per-row edit/delete affordances removed (P0_PR_Plan
                    // PR-7 / Audit Theme 7). The outer InkWell already wires
                    // tap-to-detail; bulk-mode + 3-dot overflow surface the
                    // destructive actions. `onEdit` and `onDelete` are kept
                    // on the constructor so callers stay unchanged.
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
