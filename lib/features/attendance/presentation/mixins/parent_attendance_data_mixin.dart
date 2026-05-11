import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/parent_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/parent_attendance_state_mixin.dart';

/// Handles data loading, caching, and refresh for parent attendance.
mixin ParentAttendanceDataMixin
    on ConsumerState<ParentAttendanceScreen>, ParentAttendanceStateMixin {
  Future<void> loadData({bool useCache = true}) async {
    final cacheKey = _getCacheKey();

    if (useCache) {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached != null && cached is Map<String, dynamic>) {
        if (!mounted) return;
        if (cached['attendanceData'] != null) {
          final attendance = (cached['attendanceData'] as List)
              .map(
                (json) => Attendance.fromJson(Map<String, dynamic>.from(json)),
              )
              .toList();
          final s = cached['studentData'] != null
              ? Student.fromJson(
                  Map<String, dynamic>.from(cached['studentData'] as Map),
                )
              : null;

          setAttendanceData(attendance);
          if (s != null) setStudent(s);
          calculateMonthlySummary();
          setLoading(false);

          AppLogger.debug(
            'attendance',
            'PresenceParent: from cache (${attendance.length})',
          );
          return;
        }
      }
    }

    if (attendanceData.isEmpty && mounted) {
      setLoading(true);
    }

    try {
      final userId = widget.parent['id']?.toString();
      final guardianEmail = widget.parent['email']?.toString();

      final studentData = await getIt<ApiStudentService>().getStudent(
        userId: userId,
        guardianEmail: guardianEmail,
      );
      final s = studentData
          .map((sd) => Student.fromJson(sd))
          .firstWhere((sd) => sd.id == currentStudentId);

      final attendance = await AttendanceService.getAttendance(
        studentId: currentStudentId,
        academicYearId: currentAcademicYearId,
      );

      if (!mounted) return;
      setStudent(s);
      setAttendanceData(attendance);
      calculateMonthlySummary();
      setLoading(false);

      LocalCacheService.save(cacheKey, {
        'studentData': s.toJson(),
        'attendanceData': attendance,
      });

      final hasUnread = attendance.any((a) => !a.isRead);
      if (hasUnread) {
        AttendanceService.markAttendanceRead(studentId: currentStudentId);
      }
    } catch (e) {
      AppLogger.error('attendance', e);
      if (!mounted) return;
      setLoading(false);

      if (attendanceData.isEmpty && mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  Future<void> forceRefresh() async {
    final cacheKey = _getCacheKey();
    await LocalCacheService.invalidate(cacheKey);
    loadData(useCache: false);
  }

  String _getCacheKey() =>
      'parent_presence_${currentStudentId}_'
      '${currentAcademicYearId ?? "default"}';

  void calculateMonthlySummary() {
    monthlySummary.updateAll((key, value) => 0);

    for (final record in attendanceData) {
      final date = record.date;

      if (selectedMonthFilter != null) {
        if (date.month.toString() != selectedMonthFilter) continue;
      }

      if (selectedSemesterFilter != null) {
        final month = date.month;
        final semester = (month >= 7) ? '1' : '2';
        if (semester != selectedSemesterFilter) continue;
      }

      final status = normalizeStatus(record.status);
      monthlySummary[status] = (monthlySummary[status] ?? 0) + 1;
    }
    setState(() {});
  }

  String normalizeStatus(dynamic rawStatus);
}
