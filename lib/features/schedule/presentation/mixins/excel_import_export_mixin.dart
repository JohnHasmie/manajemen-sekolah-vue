import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/domain/models/schedule.dart';
import 'package:manajemensekolah/features/schedule/exports/schedule_export_service.dart';

/// Mixin providing Excel import and export functionality
/// for the admin schedule controller.
mixin ExcelImportExportMixin {
  /// Opens a file picker and imports schedules from an Excel
  /// file. Returns true if the import succeeded.
  Future<bool> importFromExcel() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        await getIt<ApiScheduleService>().importSchedulesFromExcel(
          File(result.files.single.path!),
        );
        getIt<ApiScheduleService>().invalidateCache();
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error('schedule', e);
      rethrow;
    }
  }

  /// Enriches schedules with day names and academic year
  /// labels, then writes to an Excel file.
  Future<void> exportToExcel({
    required BuildContext context,
    required List<dynamic> scheduleList,
    required List<dynamic> dayList,
    required List<dynamic> availableAcademicYears,
  }) async {
    final enrichedSchedules = scheduleList.map((schedule) {
      final model = Schedule.fromJson(
        Map<String, dynamic>.from(schedule as Map),
      );
      final dayId = model.dayId ?? '';
      final dayData = dayList.firstWhere(
        (d) => d['id'].toString() == dayId,
        orElse: () => <String, dynamic>{},
      );

      final Map<String, dynamic> newSchedule = Map.from(schedule);
      if ((dayData as Map).isNotEmpty) {
        newSchedule['day_name'] = dayData['name'] ?? dayData['nama'];
      }

      final academicYearId = schedule['academic_year_id']?.toString() ?? '';
      if (academicYearId.isNotEmpty) {
        final academicYearData = availableAcademicYears.firstWhere(
          (ay) => ay['id'].toString() == academicYearId,
          orElse: () => <String, dynamic>{},
        );
        if ((academicYearData as Map).isNotEmpty) {
          newSchedule['academic_year'] =
              academicYearData['year'] ?? academicYearData['name'] ?? '';
        }
      }
      return newSchedule;
    }).toList();

    await ExcelScheduleService.exportSchedulesToExcel(
      schedules: enrichedSchedules,
      context: context,
    );
  }

  /// Downloads the Excel import template.
  Future<void> downloadTemplate(BuildContext context) async {
    await ExcelScheduleService.downloadTemplate(context);
  }
}
