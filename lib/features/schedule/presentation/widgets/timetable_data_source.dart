// Data classes for the timetable grid view, extracted from
// admin_schedule_management_screen.dart.
//
// Contains ScheduleGridData (a row in the timetable) and TimetableDataSource
// (Syncfusion DataGridSource that maps schedule data into grid cells).
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

// Data class for grid view
class ScheduleGridData {
  final String id;
  final String timeSlot;
  final String day;
  final String classroom;
  final String subject;
  final String teacher;
  final Map<String, dynamic>? originalData;

  ScheduleGridData({
    required this.id,
    required this.timeSlot,
    required this.day,
    required this.classroom,
    required this.subject,
    required this.teacher,
    this.originalData,
  });
}

// Data source for grid view
class TimetableDataSource extends DataGridSource {
  final List<String> timeSlots;
  final List<String> days;
  final List<dynamic> classList;
  final List<ScheduleGridData> gridData;
  final Color primaryColor;
  final Function(Map<String, dynamic>)? onScheduleTap;

  TimetableDataSource({
    required this.timeSlots,
    required this.days,
    required this.classList,
    required this.gridData,
    required this.primaryColor,
    this.onScheduleTap,
  }) {
    _dataGridRows = timeSlots.map<DataGridRow>((timeSlot) {
      return DataGridRow(
        cells: [
          DataGridCell<String>(columnName: 'waktu', value: timeSlot),
          ...days.map<DataGridCell<String>>(
            (day) => DataGridCell<String>(columnName: day, value: day),
          ),
        ],
      );
    }).toList();
  }

  List<DataGridRow> _dataGridRows = [];

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    // Get timeSlot from the first cell
    final String timeSlot = row.getCells()[0].value.toString();

    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        if (cell.columnName == 'waktu') {
          return Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Text(
              timeSlot,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 10),
              textAlign: TextAlign.center,
            ),
          );
        } else {
          // It's a day cell
          return _buildDayScheduleCell(timeSlot, cell.columnName);
        }
      }).toList(),
    );
  }

  Widget _buildDayScheduleCell(String timeSlot, String day) {
    final cellSchedules = gridData
        .where((data) => data.timeSlot == timeSlot && data.day == day)
        .toList();

    if (cellSchedules.isEmpty) {
      return Container();
    }

    return Container(
      padding: const EdgeInsets.all(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cellSchedules.map((schedule) {
          return GestureDetector(
            onTap: () {
              if (onScheduleTap != null && schedule.originalData != null) {
                onScheduleTap!(schedule.originalData!);
              }
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.1),
                borderRadius: const BorderRadius.all(Radius.circular(4)),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nama kelas
                  Container(
                    width: 24,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.all(Radius.circular(3)),
                    ),
                    child: Text(
                      schedule.classroom,
                      style: TextStyle(
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 3),
                  // Info mapel dan guru
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          schedule.subject,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 8,
                            color: Colors.grey[800],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (schedule.teacher.isNotEmpty) ...[
                          Text(
                            schedule.teacher,
                            style: TextStyle(
                              fontSize: 7,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
