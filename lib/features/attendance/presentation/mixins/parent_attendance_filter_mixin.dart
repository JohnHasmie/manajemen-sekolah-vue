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
  /// Implemented by [ParentAttendanceDataMixin]; declared abstract
  /// here so the filter sheet's `onApply` can recompute the KPI
  /// summary right after a filter change without a circular `on`
  /// constraint between the two mixins.
  void calculateMonthlySummary();

  void checkActiveFilter() {
    setState(() {
      hasActiveFilter =
          selectedMonthFilter != null ||
          selectedSemesterFilter != null ||
          selectedStatusFilter != null ||
          searchController.text.isNotEmpty;
    });
  }

  void clearAllFilters() {
    setState(() {
      // Re-seed Bulan to current month so the screen always shows
      // "Bulan ini" by default, never an unfiltered all-year view.
      selectedMonthFilter = DateTime.now().month.toString();
      selectedSemesterFilter = null;
      selectedStatusFilter = null;
      searchController.clear();
      hasActiveFilter = false;
    });
  }

  void showFilterSheet() {
    final languageProvider = ref.read(languageRiverpod);
    final primaryColor = getPrimaryColor();

    String? tempMonthFilter = selectedMonthFilter;
    String? tempStatusFilter = selectedStatusFilter;

    final months = getMonthsList();
    final statuses = getStatusList();

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
                selectedStatusFilter = tempStatusFilter;
                // Semester is always derived from month — there is
                // no longer a user-facing semester filter, but the
                // legacy field stays in state for back-compat with
                // the data mixin's calculateMonthlySummary.
                selectedSemesterFilter = null;
                checkActiveFilter();
              });
              // Recompute the KPI breakdown for the freshly-picked
              // month/status. Without this the hero card kept the
              // previously-computed `monthlySummary` map and only
              // refreshed after a pull-to-refresh (which incidentally
              // re-runs calculateMonthlySummary inside loadData).
              calculateMonthlySummary();
            },
            onReset: () => setSS(() {
              tempMonthFilter = DateTime.now().month.toString();
              tempStatusFilter = null;
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
                        'en': 'Status',
                        'id': 'Status',
                      }),
                      icon: Icons.check_circle_outline_rounded,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: statuses.map((s) {
                        return FilterOption<String>(
                          value: s['val']!,
                          label: languageProvider.getTranslatedText({
                            'en': s['en']!,
                            'id': s['id']!,
                          }),
                        );
                      }).toList(),
                      selectedValue: tempStatusFilter,
                      onSelected: (val) => setSS(() {
                        tempStatusFilter =
                            val == tempStatusFilter ? null : val;
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

  /// Status options available in the filter sheet. Values are the
  /// canonical lowercase Indonesian keys consumed by
  /// [ParentAttendanceStatusMixin.normalizeStatus].
  List<Map<String, String>> getStatusList() {
    return [
      {'en': 'Present', 'id': 'Hadir', 'val': 'hadir'},
      {'en': 'Late', 'id': 'Terlambat', 'val': 'terlambat'},
      {'en': 'Permission', 'id': 'Izin', 'val': 'izin'},
      {'en': 'Sick', 'id': 'Sakit', 'val': 'sakit'},
      {'en': 'Alpha', 'id': 'Alpha', 'val': 'alpha'},
    ];
  }

  Color getPrimaryColor();
}
