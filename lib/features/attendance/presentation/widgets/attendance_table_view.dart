// Extracted from admin_attendance_report_screen.dart (_buildTableView).
// Like a Vue `<AttendanceTableView>` component -- renders the Syncfusion
// SfDataGrid showing student attendance in a matrix of dates × subjects.
//
// Stateless: all mutable data is passed in as constructor parameters.
// In Laravel terms this is like a Blade partial receiving a DataTable
// configuration object and rendering it with no side effects of its own.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_grid_data.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// Renders the table/grid view of student attendance for the admin report screen.
///
/// Parameters (like Vue props):
/// - [isLoading]             -- shows a skeleton while table data is loading
/// - [selectedClassIds]      -- list of selected class IDs; empty triggers a
///                             "please select a class" prompt
/// - [attendanceDataSource]  -- Syncfusion data source for the grid
/// - [studentList]           -- list of student records (used for empty check)
/// - [uniqueDates]           -- sorted list of date strings (yyyy-MM-dd)
/// - [uniqueSubjectIds]      -- list of subject IDs appearing as columns
/// - [primaryColor]          -- role-based accent color
/// - [languageProvider]      -- for translating UI strings
class AttendanceTableView extends StatelessWidget {
  final bool isLoading;
  final List<String> selectedClassIds;
  final AttendanceDataSource? attendanceDataSource;
  final List<dynamic> studentList;
  final List<String> uniqueDates;
  final List<String> uniqueSubjectIds;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const AttendanceTableView({
    super.key,
    required this.isLoading,
    required this.selectedClassIds,
    required this.attendanceDataSource,
    required this.studentList,
    required this.uniqueDates,
    required this.uniqueSubjectIds,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    // Skeleton while data is being fetched from the API.
    if (isLoading) {
      return const SkeletonListLoading(
        itemCount: 10,
        infoTagCount: 1,
        showActions: false,
      );
    }

    // Prompt the admin to select a class first (no class = no data to show).
    if (selectedClassIds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.class_outlined, size: 64, color: ColorUtils.slate400),
            const SizedBox(height: AppSpacing.lg),
            Text(
              languageProvider.getTranslatedText({
                'en': 'Please select a class to view the table',
                'id': 'Silakan pilih kelas untuk melihat tabel',
              }),
              style: TextStyle(color: ColorUtils.slate600),
            ),
          ],
        ),
      );
    }

    // Empty state when a class is selected but has no attendance records.
    if (attendanceDataSource == null || studentList.isEmpty) {
      return EmptyState(
        title: languageProvider.getTranslatedText({
          'en': 'No data available',
          'id': 'Tidak ada data',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': 'Please select a different class or criteria',
          'id': 'Silakan pilih kelas atau kriteria lain',
        }),
      );
    }

    // Group dates by month for the stacked header rows.
    // Like a PHP array_group_by() — maps 'MMMM yyyy' → [date strings].
    final Map<String, List<String>> monthsMap = {};
    for (final dateStr in uniqueDates) {
      try {
        final date = DateTime.parse(dateStr);
        final monthKey = DateFormat(
          'MMMM yyyy',
          languageProvider.currentLanguage,
        ).format(date);
        monthsMap.putIfAbsent(monthKey, () => []).add(dateStr);
      } catch (e) {
        monthsMap.putIfAbsent('', () => []).add(dateStr);
      }
    }

    return Container(
      margin: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate100,
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: SfDataGrid(
          source: attendanceDataSource!,
          frozenColumnsCount: 1,
          gridLinesVisibility: GridLinesVisibility.horizontal,
          headerGridLinesVisibility: GridLinesVisibility.horizontal,
          rowHeight: 60,
          headerRowHeight: 50,
          stackedHeaderRows: [
            // Top stacked row: month labels spanning their respective date
            // columns.
            if (monthsMap.isNotEmpty)
              StackedHeaderRow(
                cells: [
                  StackedHeaderCell(
                    child: Container(
                      color: primaryColor.withValues(alpha: 0.05),
                    ),
                    columnNames: ['student_info'],
                  ),
                  ...monthsMap.entries.map((entry) {
                    final columns = entry.value
                        .expand(
                          (date) => uniqueSubjectIds.map((sId) => '$date-$sId'),
                        )
                        .toList();

                    return StackedHeaderCell(
                      child: Container(
                        color: primaryColor,
                        alignment: Alignment.center,
                        child: Text(
                          entry.key.toUpperCase(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      columnNames: columns,
                    );
                  }),
                ],
              ),
            // Second stacked row: day-of-month numbers spanning subject
            // columns.
            StackedHeaderRow(
              cells: [
                StackedHeaderCell(
                  child: Container(
                    color: primaryColor.withValues(alpha: 0.05),
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'STUDENT INFO',
                        'id': 'INFORMASI SISWA',
                      }),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  columnNames: ['student_info'],
                ),
                ...uniqueDates.map((dateStr) {
                  String dayLabel = '';
                  try {
                    final date = DateTime.parse(dateStr);
                    dayLabel = DateFormat('d').format(date);
                  } catch (_) {
                    dayLabel = dateStr;
                  }

                  return StackedHeaderCell(
                    child: Container(
                      color: primaryColor.withValues(alpha: 0.1),
                      alignment: Alignment.center,
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    columnNames: uniqueSubjectIds
                        .map((sId) => '$dateStr-$sId')
                        .toList(),
                  );
                }),
              ],
            ),
          ],
          columns: [
            GridColumn(
              columnName: 'student_info',
              width: 250,
              label: Container(color: primaryColor.withValues(alpha: 0.05)),
            ),
            ...uniqueDates.expand((date) {
              return uniqueSubjectIds.map((sId) {
                final subjectName =
                    attendanceDataSource?.subjectMap[sId] ?? sId;
                return GridColumn(
                  columnName: '$date-$sId',
                  width: 100,
                  label: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: ColorUtils.slate200,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Text(
                      subjectName,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: ColorUtils.slate600,
                      ),
                    ),
                  ),
                );
              });
            }),
          ],
        ),
      ),
    );
  }
}
