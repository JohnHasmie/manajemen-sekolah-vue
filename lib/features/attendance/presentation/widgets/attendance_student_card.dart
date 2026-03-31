// Shows a single student row in the admin attendance detail list. Displays
// name, student number, current status badge, and (when isEditing is true) a
// row of AttendanceQuickStatusButton widgets. All state is passed in; mutations
// are surfaced via the onStatusChanged callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_quick_status_button.dart';

class AttendanceStudentCard extends StatelessWidget {
  final Student student;
  final int index;
  final String currentStatus;
  final String statusText;
  final Color statusColor;
  final bool isEditing;
  final String? tempStatus;

  /// Called when the user taps one of the quick-status buttons.
  /// The parent is responsible for updating its own state map.
  final void Function(String newStatus) onStatusChanged;

  const AttendanceStudentCard({
    super.key,
    required this.student,
    required this.index,
    required this.currentStatus,
    required this.statusText,
    required this.statusColor,
    required this.isEditing,
    required this.tempStatus,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final avatarColor = ColorUtils.getColorForIndex(index);

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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            if (isEditing) ...[
              const SizedBox(height: AppSpacing.md),
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
                    AttendanceQuickStatusButton(
                      status: 'hadir',
                      label: 'H',
                      color: ColorUtils.success600,
                      isSelected: tempStatus == 'hadir',
                      onTap: () => onStatusChanged('hadir'),
                    ),
                    AttendanceQuickStatusButton(
                      status: 'sakit',
                      label: 'S',
                      color: ColorUtils.warning600,
                      isSelected: tempStatus == 'sakit',
                      onTap: () => onStatusChanged('sakit'),
                    ),
                    AttendanceQuickStatusButton(
                      status: 'izin',
                      label: 'I',
                      color: ColorUtils.info600,
                      isSelected: tempStatus == 'izin',
                      onTap: () => onStatusChanged('izin'),
                    ),
                    AttendanceQuickStatusButton(
                      status: 'alpha',
                      label: 'A',
                      color: ColorUtils.error600,
                      isSelected: tempStatus == 'alpha',
                      onTap: () => onStatusChanged('alpha'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
