// Class selection card for the grade recap wizard (step 0).
// Like a Vue `<ClassCard>` presentational component that emits an `onTap` event.
//
// Extracted from `_buildClassCard` in `teacher_grade_recap_screen.dart`.
// All state (selectedClass, currentStep) lives in the parent — this widget is
// purely presentational and calls [onTap] when the user selects a class.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_info_tag.dart';

/// A tappable card that displays classroom info in the grade recap wizard.
///
/// Receives [item] (the raw classroom map from the API), [primaryColor] for
/// the icon background, [isToday] to show a "TODAY" badge, and [onTap] which
/// the parent uses to advance the wizard to step 1.
///
/// In Laravel terms: one row of `ClassroomController@index` output.
class GradeRecapClassCard extends StatelessWidget {
  /// Raw classroom map from the API (keys: id, nama/name, grade_level,
  /// homeroom_teacher / wali_kelas, wali_kelas_name, etc.).
  final Map<String, dynamic> item;

  /// Brand colour derived from the teacher's role.
  final Color primaryColor;

  /// Whether this class has a schedule entry for today — shows a TODAY badge.
  final bool isToday;

  /// Translated label for the "TODAY" badge (varies by locale).
  final String todayLabel;

  /// Called when the user taps the card; the parent advances the wizard.
  final VoidCallback onTap;

  const GradeRecapClassCard({
    super.key,
    required this.item,
    required this.primaryColor,
    required this.isToday,
    required this.todayLabel,
    required this.onTap,
  });

  /// Resolves the homeroom-teacher display name from the normalized
  /// [Classroom] model.
  String _resolveHomeroomTeacher(Classroom model) {
    final name = model.homeroomTeacherName;
    return (name != null && name.isNotEmpty) ? name : '-';
  }

  @override
  Widget build(BuildContext context) {
    final model = Classroom.fromJson(item);
    final homeroomTeacher = _resolveHomeroomTeacher(model);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          boxShadow: ColorUtils.corporateShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                ),
                child: Center(
                  child: Icon(
                    Icons.class_outlined,
                    color: primaryColor,
                    size: 26,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['nama'] ?? item['name'] ?? '-',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: ColorUtils.slate900,
                            ),
                          ),
                        ),
                        if (isToday)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: ColorUtils.success600.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: const BorderRadius.all(
                                Radius.circular(4),
                              ),
                            ),
                            child: Text(
                              todayLabel,
                              style: TextStyle(
                                color: ColorUtils.success600,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        GradeRecapInfoTag(
                          icon: Icons.layers_outlined,
                          text: '${item['grade_level'] ?? '-'}',
                        ),
                        GradeRecapInfoTag(
                          icon: Icons.person_outline,
                          text: homeroomTeacher,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: ColorUtils.slate300),
            ],
          ),
        ),
      ),
    );
  }
}
