// Extracted from teacher_attendance_screen.dart (_buildStudentItem +
// _buildQuickStatusButton). Like a Vue `<StudentAttendanceRow>` component --
// renders one student row with avatar, NIS, current status badge, and five
// quick-select status buttons (H / T / S / I / A).
//
// Stateless: all mutable data flows in via parameters, changes flow out via
// [onStatusChanged]. The parent's setState is invoked through the callback,
// keeping this widget fully pure -- like a controlled component in Vue.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// One student row in the attendance input list.
///
/// Parameters (like Vue props):
/// - [student]          -- the Student model to display
/// - [currentStatus]    -- the current attendance status string (e.g. 'hadir')
/// - [onStatusChanged]  -- callback when the user taps a quick-status button;
///                         receives the [studentId] and new [status]
/// - [languageProvider] -- for translating status labels
class AttendanceStudentItem extends StatelessWidget {
  final Student student;
  final String currentStatus;
  final void Function(String studentId, String status) onStatusChanged;
  final LanguageProvider languageProvider;

  const AttendanceStudentItem({
    super.key,
    required this.student,
    required this.currentStatus,
    required this.onStatusChanged,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = attendanceStatusColor(currentStatus);
    final String statusText =
        attendanceStatusText(currentStatus, languageProvider);
    final avatarColor = _avatarColor(student.name);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar with first-letter initial
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    student.name.isNotEmpty
                        ? student.name[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: avatarColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                // Name + NIS
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NIS: ${student.studentNumber}',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                // Current status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // Quick-select status button row
            Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: const BorderRadius.all(Radius.circular(12)),
                border: Border.all(color: ColorUtils.slate200),
              ),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _QuickStatusButton(
                    status: 'hadir',
                    label: 'H',
                    color: ColorUtils.success600,
                    isSelected: currentStatus.toLowerCase() == 'hadir',
                    onTap: () => onStatusChanged(student.id, 'hadir'),
                  ),
                  _QuickStatusButton(
                    status: 'terlambat',
                    label: 'T',
                    color: ColorUtils.violet700,
                    isSelected: currentStatus.toLowerCase() == 'terlambat',
                    onTap: () => onStatusChanged(student.id, 'terlambat'),
                  ),
                  _QuickStatusButton(
                    status: 'sakit',
                    label: 'S',
                    color: ColorUtils.warning600,
                    isSelected: currentStatus.toLowerCase() == 'sakit',
                    onTap: () => onStatusChanged(student.id, 'sakit'),
                  ),
                  _QuickStatusButton(
                    status: 'izin',
                    label: 'I',
                    color: ColorUtils.info600,
                    isSelected: currentStatus.toLowerCase() == 'izin',
                    onTap: () => onStatusChanged(student.id, 'izin'),
                  ),
                  _QuickStatusButton(
                    status: 'alpha',
                    label: 'A',
                    color: ColorUtils.error600,
                    isSelected: currentStatus.toLowerCase() == 'alpha',
                    onTap: () => onStatusChanged(student.id, 'alpha'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// A single circular status button (H / T / S / I / A).
/// Extracted from the original `_buildQuickStatusButton`. Pure stateless --
/// selection state is passed in from the parent rather than held locally.
class _QuickStatusButton extends StatelessWidget {
  final String status;
  final String label;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _QuickStatusButton({
    required this.status,
    required this.label,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pure helper functions (no Flutter state dependency).
// Used by both this widget file and kept in sync with the parent screen.
// ---------------------------------------------------------------------------

/// Returns the display color for an attendance status string.
/// Like a Vue computed property that maps a status value to a Tailwind color.
Color attendanceStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'hadir':
      return Colors.green;
    case 'sakit':
      return Colors.orange;
    case 'izin':
      return Colors.blue;
    case 'alpha':
      return Colors.red;
    case 'terlambat':
      return Colors.purple;
    default:
      return Colors.green;
  }
}

/// Returns the translated display label for an attendance status string.
String attendanceStatusText(
  String status,
  LanguageProvider languageProvider,
) {
  switch (status.toLowerCase()) {
    case 'hadir':
      return languageProvider.getTranslatedText({
        'en': 'Present',
        'id': 'Hadir',
      });
    case 'sakit':
      return languageProvider.getTranslatedText({
        'en': 'Sick',
        'id': 'Sakit',
      });
    case 'izin':
      return languageProvider.getTranslatedText({
        'en': 'Permission',
        'id': 'Izin',
      });
    case 'alpha':
      return languageProvider.getTranslatedText({
        'en': 'Absent',
        'id': 'Alpha',
      });
    case 'terlambat':
      return languageProvider.getTranslatedText({
        'en': 'Late',
        'id': 'Terlambat',
      });
    default:
      return languageProvider.getTranslatedText({
        'en': 'Present',
        'id': 'Hadir',
      });
  }
}

/// Picks a deterministic avatar background color from the student's name.
Color _avatarColor(String name) {
  final index = name.isNotEmpty ? name.codeUnitAt(0) % 6 : 0;
  return ColorUtils.getColorForIndex(index);
}
