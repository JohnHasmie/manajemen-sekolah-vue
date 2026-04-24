import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';

/// Handles filtering logic and sheet display for attendance records.
///
/// Uses the shared [AppFilterBottomSheet] scaffold so the parent attendance
/// filter matches every other teacher/parent filter sheet: gradient header,
/// tinted-icon section headers, chip grid, and the standard Apply/Cancel
/// footer.
mixin ParentAttendanceFilterMixin
    on ConsumerState<ParentAttendanceScreen>, ParentAttendanceStateMixin {
  void checkActiveFilter() {
    setState(() {
      hasActiveFilter =
          selectedMonthFilter != null ||
          selectedSemesterFilter != null ||
          searchController.text.isNotEmpty;
    });
  }

  void clearAllFilters() {
    setState(() {
      selectedMonthFilter = null;
      selectedSemesterFilter = null;
      searchController.clear();
      hasActiveFilter = false;
    });
  }

  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = getPrimaryColor();

    String? tempMonthFilter = selectedMonthFilter;
    String? tempSemesterFilter = selectedSemesterFilter;

    final months = getMonthsList();
    final semesters = getSemestersList();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSS) {
          return AppFilterBottomSheet(
            title: languageProvider.getTranslatedText({
              'en': 'Filter Attendance',
              'id': 'Filter Absensi',
            }),
            primaryColor: primaryColor,
            maxHeightFactor: 0.75,
            onApply: () {
              Navigator.pop(ctx);
              setState(() {
                selectedMonthFilter = tempMonthFilter;
                selectedSemesterFilter = tempSemesterFilter;
                checkActiveFilter();
              });
            },
            onReset: () => setSS(() {
              tempMonthFilter = null;
              tempSemesterFilter = null;
            }),
            content: TeacherFilterContent(
              sections: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: languageProvider.getTranslatedText({
                        'en': 'Month',
                        'id': 'Bulan',
                      }),
                      icon: Icons.calendar_month_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: months.map((m) {
                        return FilterOption<String>(
                          value: m['val']!,
                          label: languageProvider.getTranslatedText({
                            'en': m['en']!,
                            'id': m['id']!,
                          }),
                        );
                      }).toList(),
                      selectedValue: tempMonthFilter,
                      onSelected: (val) => setSS(() {
                        tempMonthFilter = val == tempMonthFilter ? null : val;
                      }),
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: languageProvider.getTranslatedText({
                        'en': 'Semester',
                        'id': 'Semester',
                      }),
                      icon: Icons.event_note_rounded,
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
                      selectedValue: tempSemesterFilter,
                      onSelected: (val) => setSS(() {
                        tempSemesterFilter = val == tempSemesterFilter
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

  List<Map<String, String>> getMonthsList() {
    return [
      {'en': 'January', 'id': 'Januari', 'val': '1'},
      {'en': 'February', 'id': 'Februari', 'val': '2'},
      {'en': 'March', 'id': 'Maret', 'val': '3'},
      {'en': 'April', 'id': 'April', 'val': '4'},
      {'en': 'May', 'id': 'Mei', 'val': '5'},
      {'en': 'June', 'id': 'Juni', 'val': '6'},
      {'en': 'July', 'id': 'Juli', 'val': '7'},
      {'en': 'August', 'id': 'Agustus', 'val': '8'},
      {'en': 'September', 'id': 'September', 'val': '9'},
      {'en': 'October', 'id': 'Oktober', 'val': '10'},
      {'en': 'November', 'id': 'November', 'val': '11'},
      {'en': 'December', 'id': 'Desember', 'val': '12'},
    ];
  }

  List<Map<String, String>> getSemestersList() {
    return [
      {'en': 'Semester 1', 'id': 'Semester 1', 'val': '1'},
      {'en': 'Semester 2', 'id': 'Semester 2', 'val': '2'},
    ];
  }

  Color getPrimaryColor();
}
