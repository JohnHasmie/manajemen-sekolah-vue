import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Displays student information card with avatar, name, NIS, and class.
class ParentAttendanceStudentInfo extends StatelessWidget {
  final Student? student;
  final Color primaryColor;

  const ParentAttendanceStudentInfo({
    super.key,
    required this.student,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            ),
            child: Icon(Icons.person, color: primaryColor, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student?.name ?? 'Nama Siswa',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'NIS: ${student?.studentNumber ?? '-'}',
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
                ),
                Text(
                  'Kelas: ${student?.className ?? '-'}',
                  style: TextStyle(fontSize: 13, color: ColorUtils.slate600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
