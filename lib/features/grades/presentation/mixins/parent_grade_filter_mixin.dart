import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/parent_grade_screen.dart';
import 'package:manajemensekolah/features/grades/presentation/mixins/parent_grade_data_loading_mixin.dart';

/// Handles filtering logic and sheet display for grades (nilai).
///
/// Uses the shared [AppFilterBottomSheet] scaffold so the parent grades
/// filter matches every other teacher/parent filter sheet.
mixin ParentGradeFilterMixin
    on ConsumerState<ParentGradeScreen>, ParentGradeDataLoadingMixin {
  bool hasActiveFilter = false;
  String? selectedGradeTypeFilter;

  void checkActiveFilter() {
    setState(() {
      hasActiveFilter = selectedGradeTypeFilter != null;
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedGradeTypeFilter = null;
      hasActiveFilter = false;
    });
    // Force refresh the list with no filter
    resetPagination();
    loadGrades(useCache: false);
  }

  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = ColorUtils.brandAzureDeep;

    String? tempGradeTypeFilter = selectedGradeTypeFilter;
    final gradeTypes = getGradeTypeList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) {
          return AppFilterBottomSheet(
            title: languageProvider.getTranslatedText({
              'en': 'Filter Grades',
              'id': 'Filter Nilai',
            }),
            primaryColor: primaryColor,
            maxHeightFactor: 0.75,
            onApply: () {
              Navigator.pop(ctx);
              setState(() {
                selectedGradeTypeFilter = tempGradeTypeFilter;
                checkActiveFilter();
              });
              resetPagination();
              loadGrades(useCache: false);
            },
            onReset: () => FilterSheetHelpers.reset(ctx, clearAllFilters),
            content: TeacherFilterContent(
              sections: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: languageProvider.getTranslatedText({
                        'en': 'Grade Type',
                        'id': 'Tipe Nilai',
                      }),
                      icon: Icons.category_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: gradeTypes.map((t) {
                        return FilterOption<String>(
                          value: t['val']!,
                          label: languageProvider.getTranslatedText({
                            'en': t['en']!,
                            'id': t['id']!,
                          }),
                        );
                      }).toList(),
                      selectedValue: tempGradeTypeFilter,
                      onSelected: (val) => setSS(() {
                        tempGradeTypeFilter = val == tempGradeTypeFilter
                            ? null
                            : val;
                      }),
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Map<String, String>> getGradeTypeList() {
    return [
      {'en': 'Assignment', 'id': 'Tugas', 'val': 'Tugas'},
      {'en': 'Quiz', 'id': 'Ulangan Harian', 'val': 'UH'},
      {'en': 'Midterm', 'id': 'PTS', 'val': 'PTS'},
      {'en': 'Finals', 'id': 'PAS', 'val': 'PAS'},
      {'en': 'Practice', 'id': 'Praktek', 'val': 'Praktek'},
      {'en': 'Portfolio', 'id': 'Portofolio', 'val': 'Portofolio'},
      {'en': 'Project', 'id': 'Proyek', 'val': 'Proyek'},
    ];
  }
}
