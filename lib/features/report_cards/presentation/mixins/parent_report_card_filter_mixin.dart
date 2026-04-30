import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/parent_report_card_screen.dart';

/// Handles filtering logic and sheet display for E-Raport (Report Cards).
mixin ParentReportCardFilterMixin on ConsumerState<ParentReportCardScreen> {
  String get selectedTermId;
  set selectedTermId(String value);

  Future<void> loadData({bool useCache = true});

  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = ColorUtils.brandAzureDeep;

    String tempTermId = selectedTermId;
    final semesters = getSemestersList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) {
          return AppFilterBottomSheet(
            title: languageProvider.getTranslatedText({
              'en': 'Filter Report Cards',
              'id': 'Filter E-Raport',
            }),
            primaryColor: primaryColor,
            maxHeightFactor: 0.5,
            onApply: () {
              Navigator.pop(ctx);
              if (selectedTermId != tempTermId) {
                setState(() {
                  selectedTermId = tempTermId;
                });
                loadData();
              }
            },
            onReset: () => setSS(() {
              tempTermId = '1';
            }),
            content: TeacherFilterContent(
              sections: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: languageProvider.getTranslatedText({
                        'en': 'Semester',
                        'id': 'Semester',
                      }),
                      icon: Icons.date_range_rounded,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: semesters.map((s) {
                        return FilterOption<String>(
                          value: s['val']!,
                          label: languageProvider.getTranslatedText({
                            'en': s['en']!,
                            'id': s['id']!,
                          }),
                        );
                      }).toList(),
                      selectedValue: tempTermId,
                      onSelected: (val) => setSS(() {
                        // Don't allow unselecting, must always have a semester
                        if (val != null) tempTermId = val;
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

  List<Map<String, String>> getSemestersList() {
    return [
      {'en': 'Semester 1 (Ganjil)', 'id': 'Semester 1 (Ganjil)', 'val': '1'},
      {'en': 'Semester 2 (Genap)', 'id': 'Semester 2 (Genap)', 'val': '2'},
    ];
  }
}
