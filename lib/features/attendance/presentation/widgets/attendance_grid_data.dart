// Extracted data classes for the attendance grid (SfDataGrid).
//
// These are independent of the screen state and handle only data modeling
// and cell rendering for the Syncfusion DataGrid widget.
// Think of AttendanceGridData as a DTO/ViewModel and AttendanceDataSource
// as the DataGrid adapter (like a Laravel Resource/Transformer for the grid).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// Data model for a single student's attendance across multiple dates/subjects.
/// Like a row in a pivot table: student info + date-subject -> status map.
class AttendanceGridData {
  final String studentId;
  final String nis;
  final String name;
  final Map<String, dynamic> attendance; // date -> {subjectId: status}

  AttendanceGridData({
    required this.studentId,
    required this.nis,
    required this.name,
    required this.attendance,
  });
}

/// DataGridSource that feeds student attendance data into a SfDataGrid.
/// Builds rows with a frozen "student_info" column and dynamic date-subject columns.
class AttendanceDataSource extends DataGridSource {
  final List<AttendanceGridData> students;
  final List<String> dates;
  final List<String> subjectIds;
  final Map<String, dynamic> subjectMap; // id -> name

  List<DataGridRow> dataGridRows = [];

  AttendanceDataSource({
    required this.students,
    required this.dates,
    required this.subjectIds,
    required this.subjectMap,
  }) {
    dataGridRows = students.map<DataGridRow>((data) {
      final List<DataGridCell> cells = [
        DataGridCell<AttendanceGridData>(columnName: 'student_info', value: data),
      ];

      for (var date in dates) {
        for (var subjectId in subjectIds) {
          final columnKey = '$date-$subjectId';
          final lookupKey = '${data.studentId}-$date-$subjectId';
          final status = data.attendance[lookupKey] ?? '-';
          cells.add(DataGridCell<String>(columnName: columnKey, value: status));
        }
      }

      return DataGridRow(cells: cells);
    }).toList();
  }

  @override
  List<DataGridRow> get rows => dataGridRows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((dataGridCell) {
        if (dataGridCell.columnName == 'student_info') {
          final data = dataGridCell.value as AttendanceGridData;
          return Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: ColorUtils.corporateBlue600.withValues(
                    alpha: 0.1,
                  ),
                  child: Text(
                    data.name.isNotEmpty ? data.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: ColorUtils.corporateBlue600,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: ColorUtils.slate800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data.nis,
                        style: TextStyle(
                          fontSize: 11,
                          color: ColorUtils.slate600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        final status = dataGridCell.value.toString();
        Color bgColor = Colors.transparent;
        Color textColor = ColorUtils.slate900;
        String text = '';

        if (status != '-') {
          text = getStatusAbbreviation(status);
          bgColor = getStatusColor(status);
          textColor = getStatusTextColor(status);
        }

        return Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(color: ColorUtils.slate200, width: 0.5),
            ),
          ),
          child: status == '-'
              ? Text('-', style: TextStyle(color: ColorUtils.slate300))
              : Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
        );
      }).toList(),
    );
  }

  Color getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'hadir' || s == 'present') {
      return ColorUtils.success600.withValues(alpha: 0.15);
    }
    if (s == 'sakit' || s == 'sick') {
      return ColorUtils.warning600.withValues(alpha: 0.15);
    }
    if (s == 'izin' || s == 'permit') {
      return ColorUtils.info600.withValues(alpha: 0.15);
    }
    if (s == 'alpa' || s == 'alpha' || s == 'absent') {
      return ColorUtils.error600.withValues(alpha: 0.15);
    }
    return Colors.transparent;
  }

  Color getStatusTextColor(String status) {
    final s = status.toLowerCase();
    if (s == 'hadir' || s == 'present') {
      return ColorUtils.success600;
    }
    if (s == 'sakit' || s == 'sick') {
      return ColorUtils.warning600;
    }
    if (s == 'izin' || s == 'permit') {
      return ColorUtils.info600;
    }
    if (s == 'alpa' || s == 'alpha' || s == 'absent') {
      return ColorUtils.error600;
    }
    return ColorUtils.slate900;
  }

  String getStatusAbbreviation(String status) {
    switch (status.toLowerCase()) {
      case 'hadir':
      case 'present':
        return 'H';
      case 'sakit':
      case 'sick':
        return 'S';
      case 'izin':
      case 'permit':
        return 'I';
      case 'alpa':
      case 'absent':
        return 'A';
      default:
        return '-';
    }
  }
}
