import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_detail.dart';

/// Mixin for student card building.
mixin TeacherAttendanceDetailCardMixin
    on ConsumerState<TeacherAttendanceDetailPage> {
  // Abstract methods that must be implemented by the consuming class
  String getStudentStatus(String studentId, TeacherAttendanceState state);
  Color getStatusColor(String status);
  String getStatusText(String status, LanguageProvider languageProvider);
  IconData getStatusIcon(String status);

  /// Build student card displaying attendance info
  Widget buildStudentCard(
    Student student,
    LanguageProvider languageProvider,
    TeacherAttendanceState state,
    int index,
  ) {
    final status = getStudentStatus(student.id, state);
    final Color statusColor = getStatusColor(status);
    final String statusText = getStatusText(status, languageProvider);
    final avatarColor = ColorUtils.getColorForIndex(index);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3.5, color: statusColor.withValues(alpha: 0.8)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            student.name.isNotEmpty
                                ? student.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: avatarColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              student.name,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: ColorUtils.slate900,
                                letterSpacing: -0.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'NIS: ${student.studentNumber}',
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.slate500,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusBadge(
                        label: statusText,
                        color: statusColor,
                        icon: getStatusIcon(status),
                        iconSize: 10,
                        fontSize: 10.5,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
