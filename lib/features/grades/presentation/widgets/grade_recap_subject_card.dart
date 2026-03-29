// Subject selection card for the grade recap wizard (step 1).
// Like a Vue `<SubjectCard>` presentational component that emits an `onTap`.
//
// Extracted from `_buildSubjectCard` in `teacher_grade_recap_screen.dart`.
// Stateless — all navigation logic stays in the parent state via [onTap].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_recap_info_tag.dart';

/// A tappable card that displays subject info in the grade recap wizard.
///
/// Receives [item] (raw subject map from the API) and [onTap] which the parent
/// uses to store the selected subject and advance to step 2.
///
/// In Laravel terms: one row of `SubjectController@index` output.
class GradeRecapSubjectCard extends StatelessWidget {
  /// Raw subject map from the API (keys: id, nama/name, subject_code).
  final Map<String, dynamic> item;

  /// Called when the user taps the card; the parent advances the wizard.
  final VoidCallback onTap;

  const GradeRecapSubjectCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: ColorUtils.corporateShadow(),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Icon container — uses warning600 to distinguish subjects from classes
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    Icons.book_outlined,
                    color: ColorUtils.warning600,
                    size: 26,
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nama'] ?? item['name'] ?? '-',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    GradeRecapInfoTag(
                      icon: Icons.history_edu_outlined,
                      text: item['subject_code'] ?? 'Mata Pelajaran',
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
