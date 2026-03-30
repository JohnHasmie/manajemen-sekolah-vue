// Filter section for TeacherMaterialScreen: class/subject dropdowns, checked
// count summary badge, and the "Generate Kegiatan Kelas" action button.
//
// Extracted from TeacherMaterialScreen._buildFilterSection to keep the main
// screen under the line-count limit. Equivalent to a Vue child component
// that receives props and emits events.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_class_dropdown.dart';
import 'package:manajemensekolah/features/materials/presentation/widgets/material_subject_dropdown.dart';

/// Stateless filter panel shown below the header on TeacherMaterialScreen.
///
/// Displays a summary row (material count + checked badge), an optional
/// "Generate" button, and the class/subject dropdowns.
///
/// All state lives in TeacherMaterialScreenState — callbacks bubble changes up.
class MaterialFilterSection extends StatelessWidget {
  /// Key forwarded to the outer Container so the tutorial coach-mark can
  /// locate this widget on screen.
  final Key? containerKey;

  final List<dynamic> classList;
  final String? selectedClassId;
  final List<dynamic> subjectList;
  final String? selectedSubjectId;
  final LanguageProvider languageProvider;
  final Color primaryColor;

  /// Human-readable label for the currently selected subject (e.g. "Matematika").
  final String selectedSubjectName;

  /// Total number of chapters + sub-chapters that are currently checked.
  final int totalChecked;

  /// Number of checked items that have not yet been generated (actionable items).
  final int checkedNotGeneratedCount;

  /// Total chapter-material count for the summary label.
  final int chapterCount;

  final VoidCallback onGenerateTap;
  final void Function(String newValue) onClassChanged;
  final void Function(String newValue) onSubjectChanged;

  const MaterialFilterSection({
    super.key,
    this.containerKey,
    required this.classList,
    required this.selectedClassId,
    required this.subjectList,
    required this.selectedSubjectId,
    required this.languageProvider,
    required this.primaryColor,
    required this.selectedSubjectName,
    required this.totalChecked,
    required this.checkedNotGeneratedCount,
    required this.chapterCount,
    required this.onGenerateTap,
    required this.onClassChanged,
    required this.onSubjectChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      key: containerKey,
      padding: EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ColorUtils.slate200, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Info Filter Aktif
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.filter_alt_rounded,
                    size: 16,
                    color: primaryColor,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    subjectList.isEmpty
                        ? languageProvider.getTranslatedText({
                            'en': 'No subjects available',
                            'id': 'Tidak ada mata pelajaran',
                          })
                        : '$chapterCount ${languageProvider.getTranslatedText({'en': 'materials', 'id': 'bab materi'})} • $selectedSubjectName',
                    style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$totalChecked ${languageProvider.getTranslatedText({'en': 'checked', 'id': 'dicentang'})}',
                    style: TextStyle(
                      fontSize: 11,
                      color: primaryColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md),

          // Generate Activity button if any items are checked
          if (totalChecked > 0 && checkedNotGeneratedCount > 0) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onGenerateTap,
                icon: Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  'Generate Kegiatan Kelas ($checkedNotGeneratedCount)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.success600,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            SizedBox(height: AppSpacing.md),
          ],

          // Dropdown Kelas
          MaterialClassDropdown(
            classList: classList,
            selectedClassId: selectedClassId,
            languageProvider: languageProvider,
            onClassChanged: onClassChanged,
          ),
          SizedBox(height: AppSpacing.md),

          // Dropdown Mata Pelajaran
          MaterialSubjectDropdown(
            subjectList: subjectList,
            selectedSubjectId: selectedSubjectId,
            languageProvider: languageProvider,
            onSubjectChanged: onSubjectChanged,
          ),
        ],
      ),
    );
  }
}
