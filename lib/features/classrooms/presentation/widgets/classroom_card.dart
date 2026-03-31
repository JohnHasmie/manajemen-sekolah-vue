// Classroom list card widget extracted from AdminClassManagementScreen.
//
// Like a Vue `<ClassroomCard>` component — renders a single classroom row
// with avatar, name, grade, homeroom teacher, student count chip, and
// edit/delete action buttons.  Edit/delete buttons are hidden when the
// academic year is read-only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    hide Provider, Consumer;
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A small pill-shaped tag with an icon and a text label.
///
/// Used inside [ClassroomCard] to show grade-level and homeroom-teacher info.
/// Stateless — receives [icon] and [text] as constructor params (Vue props).
class ClassroomInfoTag extends StatelessWidget {
  const ClassroomInfoTag({
    super.key,
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: ColorUtils.slate600),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Classroom list-item card rendered inside the infinite-scroll list.
///
/// Like a Vue `<ClassroomCard>` component.  All data comes via constructor
/// params (props); interaction is forwarded via callbacks (Vue `$emit`).
///
/// The edit/delete action row is conditionally hidden when the academic year
/// is read-only — this is checked via [academicYearRiverpod] inside the widget
/// so the parent doesn't need to pass it down.
///
/// Props:
/// - [classData] — raw Map from the API response
/// - [index] — list index, used to deterministically pick avatar colour
/// - [gradeText] — pre-formatted grade string (e.g. "Grade 7 SMP")
/// - [onTap] — called when the whole card is tapped (open detail dialog)
/// - [onEdit] — called when the edit icon is tapped
/// - [onDelete] — called when the delete icon is tapped
class ClassroomCard extends ConsumerWidget {
  const ClassroomCard({
    super.key,
    required this.classData,
    required this.index,
    required this.gradeText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> classData;
  final int index;
  final String gradeText;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageProvider = ref.read(languageRiverpod);
    final avatarColor = ColorUtils.getColorForIndex(index);
    final className = classData['name'] ?? 'Class';
    final studentCount = classData['student_count'] ?? 0;

    // Resolve homeroom teacher name from various API response shapes
    final teacherName = _resolveTeacherName(classData, languageProvider);

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
                // Colored initial avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: avatarColor.withValues(alpha: 0.15),
                  child: Text(
                    className.isNotEmpty ? className[0].toUpperCase() : 'C',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: avatarColor,
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                // Name + info tags
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        className,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      ClassroomInfoTag(
                        icon: Icons.layers_outlined,
                        text: gradeText,
                      ),
                      SizedBox(height: AppSpacing.xs),
                      ClassroomInfoTag(
                        icon: Icons.person_outline,
                        text: teacherName,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                // Student count chip + edit/delete action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildStudentCountChip(studentCount, languageProvider),
                    Builder(
                      builder: (context) {
                        final academicYearProvider = ref.watch(
                          academicYearRiverpod,
                        );
                        if (academicYearProvider.isReadOnly) {
                          return SizedBox.shrink();
                        }
                        return Column(
                          children: [
                            SizedBox(height: AppSpacing.sm),
                            Row(
                              children: [
                                _buildIconButton(
                                  icon: Icons.edit_outlined,
                                  color: ColorUtils.corporateBlue600,
                                  onTap: onEdit,
                                ),
                                const SizedBox(width: 6),
                                _buildIconButton(
                                  icon: Icons.delete_outline,
                                  color: ColorUtils.error600,
                                  onTap: onDelete,
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Renders the blue "N students" pill chip.
  Widget _buildStudentCountChip(
    int studentCount,
    LanguageProvider languageProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: AppSpacing.xs),
          Text(
            '$studentCount ${languageProvider.getTranslatedText({'en': 'students', 'id': 'siswa'})}',
            style: TextStyle(
              color: ColorUtils.corporateBlue600,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Renders a square icon button with a translucent tinted background.
  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  /// Resolves the homeroom teacher display name from the various shapes
  /// the API can return (flat key, List pivot, Map relation).
  String _resolveTeacherName(
    Map<String, dynamic> classData,
    LanguageProvider languageProvider,
  ) {
    if (classData['homeroom_teacher'] is List &&
        (classData['homeroom_teacher'] as List).isNotEmpty) {
      return classData['homeroom_teacher'][0]['name'];
    }
    if (classData['homeroom_teacher'] is Map) {
      return classData['homeroom_teacher']['name'];
    }
    return classData['homeroom_teacher_name'] ??
        classData['wali_kelas_nama'] ??
        languageProvider.getTranslatedText({
          'en': 'Not Assigned',
          'id': 'Belum Ditugaskan',
        });
  }
}
