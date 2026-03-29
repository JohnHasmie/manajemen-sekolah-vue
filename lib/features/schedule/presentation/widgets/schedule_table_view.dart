// Timetable grid widget extracted from
// TeachingScheduleManagementScreenState._buildTableView().
//
// Like a Vue `<ScheduleTableView :data-source="..." :days="..." />` component —
// purely presentational, all data flows in via constructor params.
// The Syncfusion DataGrid is stateless from this widget's perspective;
// the parent state owns [TimetableDataSource] and rebuilds this widget when
// data changes.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/timetable_data_source.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// Renders the weekly timetable grid using Syncfusion [SfDataGrid].
///
/// In Laravel terms: think of this as a Blade partial
/// `@include('schedule.partials.timetable-grid', ...)` — it just renders
/// the grid; the admin screen holds all the business logic.
class ScheduleTableView extends StatelessWidget {
  const ScheduleTableView({
    super.key,
    required this.timetableDataSource,
    required this.dayList,
    required this.classList,
    required this.selectedClassId,
    required this.gridData,
    required this.primaryColor,
    required this.languageProvider,
    required this.onExport,
    required this.translateDay,
  });

  /// The Syncfusion data source that maps schedule rows into grid cells.
  final TimetableDataSource timetableDataSource;

  /// Raw day objects from the API — used to build column headers.
  final List<dynamic> dayList;

  /// Raw class objects from the API — used to render class badges in headers.
  final List<dynamic> classList;

  /// If non-null, only show the class with this ID in the header badges.
  final String? selectedClassId;

  /// Flat list of grid-row data for dynamic row-height calculation.
  final List<ScheduleGridData> gridData;

  /// Role-specific accent colour (admin blue).
  final Color primaryColor;

  /// Used for translating UI strings; passed from [ref.watch(languageRiverpod)].
  final LanguageProvider languageProvider;

  /// Called when the user taps the Export button — triggers Excel export in
  /// the parent state (like a Vue `@click="$emit('export')"` event).
  final VoidCallback onExport;

  /// Translates a raw API day name to the user's current language.
  /// This is a pure function — safe to pass as a callback.
  final String Function(String dayName, String languageCode) translateDay;

  @override
  Widget build(BuildContext context) {
    final days = dayList
        .map(
          (d) => translateDay(
            d['name'] ?? d['nama'] ?? '',
            languageProvider.currentLanguage,
          ),
        )
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();

    final classNames = classList
        .where(
          (cls) =>
              selectedClassId == null ||
              cls['id'].toString() == selectedClassId,
        )
        .map((cls) => cls['name'] ?? cls['nama'] ?? '')
        .toList();

    return Column(
      children: [
        // ── Table info bar ──
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
            boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.table_chart_outlined,
                  size: 18,
                  color: primaryColor,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Weekly Schedule Table',
                        'id': 'Tabel Jadwal Mingguan',
                      }),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: ColorUtils.slate900,
                      ),
                    ),
                    Text(
                      '${gridData.length} ${languageProvider.getTranslatedText({'en': 'schedule entries', 'id': 'entri jadwal'})}',
                      style: TextStyle(
                        fontSize: 12,
                        color: ColorUtils.slate500,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: onExport,
                icon: const Icon(Icons.file_download_outlined, size: 16),
                label: Text(
                  languageProvider.getTranslatedText({
                    'en': 'Export',
                    'id': 'Ekspor',
                  }),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // ── DataGrid with styled card ──
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            clipBehavior: Clip.antiAlias,
            child: SfDataGridTheme(
              data: SfDataGridThemeData(
                gridLineColor: ColorUtils.slate200,
                gridLineStrokeWidth: 1.0,
                headerColor: primaryColor,
              ),
              child: SfDataGrid(
                source: timetableDataSource,
                frozenColumnsCount: 1,
                columnWidthMode: ColumnWidthMode.none,
                gridLinesVisibility: GridLinesVisibility.both,
                headerGridLinesVisibility: GridLinesVisibility.both,
                headerRowHeight: 72,
                onQueryRowHeight: (RowHeightDetails details) {
                  if (details.rowIndex == 0) return 72.0;

                  final String timeSlot =
                      timetableDataSource.timeSlots[details.rowIndex - 1];
                  final rowDays = timetableDataSource.days;

                  int maxSchedules = 0;
                  for (var day in rowDays) {
                    final count = gridData
                        .where((d) => d.timeSlot == timeSlot && d.day == day)
                        .length;
                    if (count > maxSchedules) maxSchedules = count;
                  }

                  if (maxSchedules == 0) return 40.0;
                  return (maxSchedules * 32.0 + 10.0).clamp(40.0, 500.0);
                },
                columns: [
                  GridColumn(
                    columnName: 'waktu',
                    width: 100,
                    label: Container(
                      color: primaryColor,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.access_time,
                            color: Colors.white.withValues(alpha: 0.85),
                            size: 14,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Time',
                              'id': 'Waktu',
                            }),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ...days.map((day) {
                    return GridColumn(
                      columnName: day,
                      width: 150,
                      label: Container(
                        color: primaryColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              day,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Flexible(
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 2,
                                alignment: WrapAlignment.center,
                                children: classNames.map((className) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.22,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      className.toString().length > 4
                                          ? className.toString().substring(0, 4)
                                          : className.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
