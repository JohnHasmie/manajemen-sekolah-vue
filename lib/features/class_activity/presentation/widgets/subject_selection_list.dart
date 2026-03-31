// SubjectSelectionList — Step 1 of the class-activity wizard.
//
// Extracted from `ClassActivityScreenState._buildSubjectList`.
// Think of this like a Vue `<SubjectList :subjects="list" />` component.
// It is purely presentational: selecting a subject fires [onSubjectSelected]
// and the parent screen owns all state.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

/// The subject selection list rendered when the wizard is on Step 1.
///
/// Props (constructor params — like Vue props):
/// - [isLoading]           — shows a skeleton while the API call is in flight
/// - [subjectList]         — raw API maps for each subject
/// - [selectedClassName]   — name of the class chosen in Step 0 (shown in header)
/// - [languageProvider]    — translation helper (read-only)
/// - [onSubjectSelected]   — called with the chosen subject map when the user taps
class SubjectSelectionList extends StatelessWidget {
  final bool isLoading;
  final List<dynamic> subjectList;
  final String? selectedClassName;
  final LanguageProvider languageProvider;

  /// Callback fires with the full subject map when a row is tapped.
  /// The parent is responsible for updating [_selectedSubjectId] etc.
  final void Function(Map<String, dynamic> subject) onSubjectSelected;

  const SubjectSelectionList({
    super.key,
    required this.isLoading,
    required this.subjectList,
    required this.selectedClassName,
    required this.languageProvider,
    required this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    // Loading state — same skeleton as the original _buildSubjectList.
    if (isLoading) {
      return SkeletonListLoading(itemCount: 6, infoTagCount: 1);
    }

    // Empty state — no subjects for this class.
    if (subjectList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No Subjects Found',
          'id': 'Mata Pelajaran Tidak Ditemukan',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'No subjects suitable for this class found.',
          'id': 'Tidak ditemukan mata pelajaran yang sesuai untuk kelas ini.',
        }),
        icon: Icons.menu_book_outlined,
      );
    }

    return Column(
      children: [
        // ── Selection Header ──────────────────────────────────────────────
        // Shows which class was selected in Step 0.
        // Like a Vue `<div class="selection-header">` at the top.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.lg),
          color: ColorUtils.slate50,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'Selected Class:',
                  'id': 'Kelas Terpilih:',
                }),
                style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                selectedClassName ?? '-',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColorUtils.slate900,
                ),
              ),
            ],
          ),
        ),

        // ── Subject List ──────────────────────────────────────────────────
        // One tappable card per subject, like a Vue `v-for` list.
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            itemCount: subjectList.length,
            itemBuilder: (context, index) {
              final subject = subjectList[index];
              final subjectName = subject['name'] ?? subject['nama'] ?? '-';
              final subjectCode = subject['code'] ?? subject['kode'] ?? '';

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    onTap: () => onSubjectSelected(
                      Map<String, dynamic>.from(subject as Map),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.all(Radius.circular(14)),
                        border: Border.all(
                          color: ColorUtils.slate200,
                          width: 1,
                        ),
                        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
                      ),
                      child: Row(
                        children: [
                          // ── Colored icon circle ──────────────────────
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: ColorUtils.getColorForIndex(
                                index,
                              ).withValues(alpha: 0.12),
                              borderRadius: const BorderRadius.all(Radius.circular(12)),
                              border: Border.all(
                                color: ColorUtils.getColorForIndex(
                                  index,
                                ).withValues(alpha: 0.25),
                              ),
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: ColorUtils.getColorForIndex(index),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),

                          // ── Subject name + code + read-only badge ────
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subjectName,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: ColorUtils.slate900,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  subjectCode.isNotEmpty
                                      ? subjectCode
                                      : 'Ketuk untuk melihat kegiatan',
                                  style: TextStyle(
                                    color: ColorUtils.slate500,
                                    fontSize: 12,
                                  ),
                                ),
                                // Read-only badge when teacher cannot edit
                                if (subject['can_edit'] == false)
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                                      border: Border.all(
                                        color: ColorUtils.warning600.withValues(
                                          alpha: 0.5,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Text(
                                      languageProvider.getTranslatedText({
                                        'en': 'Read Only',
                                        'id': 'Hanya Lihat',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: ColorUtils.warning600,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),

                          // ── Chevron ──────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: ColorUtils.slate100,
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
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
          ),
        ),
      ],
    );
  }
}
