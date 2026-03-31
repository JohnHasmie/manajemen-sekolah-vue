import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/teacher_attendance_state.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Parameters for the Teacher Attendance Controller.
class TeacherAttendanceParams {
  final String subjectId;
  final String classId;
  final DateTime date;
  final String teacherId;
  final String? lessonHourId;

  const TeacherAttendanceParams({
    required this.subjectId,
    required this.classId,
    required this.date,
    required this.teacherId,
    this.lessonHourId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeacherAttendanceParams &&
          runtimeType == other.runtimeType &&
          subjectId == other.subjectId &&
          classId == other.classId &&
          date == other.date &&
          teacherId == other.teacherId &&
          lessonHourId == other.lessonHourId;

  @override
  int get hashCode =>
      subjectId.hashCode ^
      classId.hashCode ^
      date.hashCode ^
      teacherId.hashCode ^
      lessonHourId.hashCode;
}

/// Controller for Teacher Attendance Detail.
/// Manages student lists and individual attendance records reactively.
class TeacherAttendanceController
    extends AsyncNotifier<TeacherAttendanceState> {
  /// The params passed at construction time (replaces the old `arg` property
  /// from AutoDisposeFamilyAsyncNotifier, which no longer exists in Riverpod 3.x).
  final TeacherAttendanceParams arg;

  TeacherAttendanceController(this.arg);

  @override
  FutureOr<TeacherAttendanceState> build() async {
    return await _initialize();
  }

  /// Initial data fetch from API.
  Future<TeacherAttendanceState> _initialize() async {
    try {
      // 1. Load attendance data
      final attendanceRecords = await AttendanceService.getAttendance(
        subjectId: arg.subjectId,
        date: DateFormat('yyyy-MM-dd').format(arg.date),
        teacherId: arg.teacherId,
        lessonHourId: arg.lessonHourId,
        classId: arg.classId,
      );

      // 2. Load students by class ID
      final studentData = await getIt<ApiStudentService>().getStudentByClass(
        arg.classId,
      );
      final students = studentData.map((s) => Student.fromJson(s)).toList();

      // 3. Initialize edited status map from current records
      final Map<String, String> editedStatus = {};
      for (var student in students) {
        editedStatus[student.id] = _getInitialStatus(student.id, attendanceRecords);
      }

      return TeacherAttendanceState(
        students: students,
        attendanceRecords: attendanceRecords,
        editedStatus: editedStatus,
      );
    } catch (e, st) {
      AppLogger.error('attendance', 'Failed to initialize attendance controller: $e');
      return Future.error(e, st);
    }
  }

  /// Helper to map API record to initial local status.
  String _getInitialStatus(String studentId, List<Attendance> records) {
    try {
      final record = records.firstWhere(
        (a) => a.studentId.toString() == studentId.toString(),
      );
      return record.status.toLowerCase();
    } catch (_) {
      return 'absent'; // Default fallback
    }
  }

  /// Toggles between read-only and edit mode.
  void toggleEdit() {
    final currentState = state.value;
    if (currentState == null) return;
    state = AsyncData(currentState.copyWith(isEditing: !currentState.isEditing));
  }

  /// Updates a student's status in the local [editedStatus] map.
  void updateStatus(String studentId, String status) {
    final currentState = state.value;
    if (currentState == null) return;

    final newEditedStatus = Map<String, String>.from(currentState.editedStatus);
    newEditedStatus[studentId] = status;

    state = AsyncData(currentState.copyWith(editedStatus: newEditedStatus));
  }

  /// Saves all pending changes to the API sequentially.
  Future<bool> saveChanges() async {
    final currentState = state.value;
    if (currentState == null) return false;

    state = AsyncData(currentState.copyWith(isSaving: true));

    try {
      int successCount = 0;
      
      for (var student in currentState.students) {
        final initialStatus = _getInitialStatus(student.id, currentState.attendanceRecords);
        final currentStatus = currentState.editedStatus[student.id];

        // Only save if the status has actually changed
        if (currentStatus != null && currentStatus != initialStatus) {
          // Resolve lesson_hour_id if in "All Hours" view
          String? targetLessonHourId = arg.lessonHourId;
          if (targetLessonHourId == null) {
            try {
              final existingRecord = currentState.attendanceRecords.firstWhere(
                (a) => a.studentId.toString() == student.id.toString(),
              );
              targetLessonHourId = existingRecord.lessonHourId;
            } catch (_) {}
          }

          await AttendanceService.createAttendance({
            'student_id': student.id,
            'teacher_id': arg.teacherId,
            'subject_id': arg.subjectId,
            'class_id': arg.classId,
            'date': DateFormat('yyyy-MM-dd').format(arg.date),
            'status': _mapToBackendStatus(currentStatus),
            'notes': '',
            'lesson_hour_id': targetLessonHourId,
          });
          successCount++;
        }
      }

      // Re-initialize to get fresh server data after save
      if (successCount > 0) {
        state = const AsyncLoading();
        state = await AsyncValue.guard(_initialize);
      } else {
        state = AsyncData(currentState.copyWith(isSaving: false, isEditing: false));
      }
      return true;
    } catch (e) {
      AppLogger.error('attendance', 'Error saving changes: $e');
      state = AsyncData(currentState.copyWith(isSaving: false));
      return false;
    }
  }

  String _mapToBackendStatus(String status) {
    // Map internal English keys to backend-specific strings if necessary.
    // Parity with legacy _mapStatusToBackend logic.
    switch (status.toLowerCase()) {
      case 'present':
      case 'hadir':
        return 'present';
      case 'late':
      case 'terlambat':
        return 'late';
      case 'excused':
      case 'izin':
        return 'excused';
      case 'sick':
      case 'sakit':
        return 'sick';
      case 'absent':
      case 'alpha':
        return 'absent';
      default:
        return 'present';
    }
  }
}

/// Provider for TeacherAttendanceController.
final teacherAttendanceProvider = AsyncNotifierProvider.family<
    TeacherAttendanceController,
    TeacherAttendanceState,
    TeacherAttendanceParams>(
  TeacherAttendanceController.new,
  isAutoDispose: true,
);
