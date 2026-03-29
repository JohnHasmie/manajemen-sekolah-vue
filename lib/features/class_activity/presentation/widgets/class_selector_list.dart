// ClassSelectorList — Step 0 of the wizard: the scrollable list of classes
// a teacher can pick from before drilling into subjects and activities.
//
// Extracted from `ClassActivityScreenState._buildClassList`.
// Think of this like a Vue `<ClassSelectorList :classes :isLoading @select />`.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

/// Displays a scrollable list of classes for the teacher to select from.
///
/// Constructor params (Vue-style props):
/// - [isLoading]        — show skeleton placeholders while data loads
/// - [classList]        — raw list of class maps from the API
/// - [languageProvider] — translation helper (like `$t()` in Vue i18n)
/// - [onClassSelected]  — callback with the tapped class map; the parent
///                        is responsible for updating its own state
///                        (equivalent to passing setState logic up via callback)
class ClassSelectorList extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> classList;
  final LanguageProvider languageProvider;

  /// Called with the raw class map when the user taps a row.
  /// The parent (screen state) performs setState — this widget stays stateless.
  final void Function(Map<String, dynamic> classData) onClassSelected;

  const ClassSelectorList({
    super.key,
    required this.isLoading,
    required this.classList,
    required this.languageProvider,
    required this.onClassSelected,
  });

  @override
  Widget build(BuildContext context) {
    // ── Loading state: show skeleton cards ───────────────────────────────────
    if (isLoading) {
      return SkeletonListLoading(itemCount: 4, infoTagCount: 1);
    }

    // ── Empty state: no classes assigned ────────────────────────────────────
    if (classList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Classes Found',
          'id': 'Kelas Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'You do not have any assigned classes for this academic year.',
          'id':
              'Anda tidak memiliki kelas yang ditugaskan untuk tahun ajaran ini.',
        }),
        icon: Icons.class_outlined,
      );
    }

    // ── Normal state: list of class cards ────────────────────────────────────
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      itemCount: classList.length,
      itemBuilder: (context, index) {
        final classData = classList[index] as Map<String, dynamic>;
        final isHomeroom = classData['is_homeroom'] == true;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => onClassSelected(classData),
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
                    // ── Coloured icon avatar ──────────────────────────────
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: ColorUtils.getColorForIndex(index)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ColorUtils.getColorForIndex(index)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Icon(
                        isHomeroom
                            ? Icons.home_work_rounded
                            : Icons.class_rounded,
                        color: ColorUtils.getColorForIndex(index),
                      ),
                    ),
                    SizedBox(width: AppSpacing.lg),
                    // ── Class name + grade/major + homeroom teacher ───────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  classData['name'] ?? classData['nama'] ?? '-',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                              ),
                              // "Wali Kelas" badge
                              if (isHomeroom)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.primary,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text(
                                    'Wali Kelas',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(height: AppSpacing.xs),
                          // Grade • Major subtitle
                          if ([
                            classData['tingkat'],
                            classData['jurusan'],
                          ].any((e) => e != null && e.toString().isNotEmpty))
                            Text(
                              [classData['tingkat'], classData['jurusan']]
                                  .where(
                                    (e) =>
                                        e != null && e.toString().isNotEmpty,
                                  )
                                  .join(' • '),
                              style: TextStyle(
                                color: ColorUtils.slate500,
                                fontSize: 12,
                              ),
                            ),
                          // Homeroom teacher name
                          if (classData['homeroom_teacher_name'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                'Wali Kelas: ${classData['homeroom_teacher_name']}',
                                style: TextStyle(
                                  color: ColorUtils.slate500,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    // ── Chevron arrow ─────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate100,
                        borderRadius: BorderRadius.circular(8),
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
      },
    );
  }
}
