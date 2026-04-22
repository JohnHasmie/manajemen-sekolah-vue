import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/schedule/data/schedule_service.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/conflict_resolution_dialog.dart';

/// Mixin providing CRUD operations for the admin schedule
/// controller.
mixin CrudOperationsMixin {
  /// Deletes a schedule by ID.
  /// Returns true on success, false on error.
  Future<bool> deleteSchedule(String id) async {
    try {
      await getIt<ApiScheduleService>().deleteSchedule(id);
      return true;
    } catch (e) {
      AppLogger.error('schedule', e);
      return false;
    }
  }

  /// Handles post-save conflict detection and resolution.
  /// Returns true if the schedule was ultimately saved.
  Future<bool> checkAndResolveConflicts(
    BuildContext context,
    Map<String, dynamic> newScheduleData, {
    String? editingScheduleId,
  }) async {
    try {
      final conflicts = await getIt<ApiScheduleService>()
          .getConflictingSchedules(
            daysIds:
                (newScheduleData['days_ids'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
            classId: newScheduleData['class_id'],
            teacherId: newScheduleData['teacher_id'],
            semesterId: newScheduleData['semester_id'],
            academicYearId: newScheduleData['academic_year_id'],
            lessonHourId: newScheduleData['lesson_hour_days_id'],
            excludeScheduleId: editingScheduleId,
          );

      if (conflicts.isNotEmpty) {
        if (!context.mounted) return false;
        final result = await showDialog<String>(
          context: context,
          builder: (context) => ConflictResolutionDialog(
            conflictingSchedules: conflicts,
            onDeleteConfirmed: (scheduleId) =>
                AppNavigator.pop(context, scheduleId),
            onCancel: () => AppNavigator.pop(context),
          ),
        );

        if (result != null) {
          await getIt<ApiScheduleService>().deleteSchedule(result);

          try {
            if (editingScheduleId != null) {
              await getIt<ApiScheduleService>().updateSchedule(
                editingScheduleId,
                newScheduleData,
              );
            } else {
              await getIt<ApiScheduleService>().addSchedule(newScheduleData);
            }
          } catch (e) {
            AppLogger.error('schedule', e);
          }
          return true;
        }
        return false;
      } else {
        try {
          if (editingScheduleId != null) {
            await getIt<ApiScheduleService>().updateSchedule(
              editingScheduleId,
              newScheduleData,
            );
          } else {
            await getIt<ApiScheduleService>().addSchedule(newScheduleData);
          }
        } catch (e) {
          AppLogger.error('schedule', e);
        }
        return true;
      }
    } catch (e) {
      AppLogger.error('schedule', e);
      rethrow;
    }
  }
}
