import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for data loading and statistics in AdminAttendanceDetailPage
mixin AdminDetailDataMixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Attendance> get attendanceData;
  set attendanceData(List<Attendance> value);

  List<Student> get studentList;
  set studentList(List<Student> value);

  bool get isLoading;
  set isLoading(bool value);

  Map<String, String> get tempAttendanceStatus;

  /// Returns the widget being used in this state
  @override
  AdminAttendanceDetailPage get widget => super.widget;

  String _getStudentStatus(String studentId) {
    try {
      final attendanceRecord = attendanceData.firstWhere(
        (a) => a.studentId.toString() == studentId.toString(),
        orElse: () => Attendance(
          id: '',
          studentId: studentId,
          date: widget.date,
          status: 'alpha',
        ),
      );
      return attendanceRecord.status.toLowerCase();
    } catch (e) {
      return 'alpha';
    }
  }

  Future<void> loadData() async {
    try {
      final attendanceDataLoaded = await AttendanceService.getAttendance(
        subjectId: widget.subjectId,
        date: DateFormat('yyyy-MM-dd').format(widget.date),
        classId: widget.classId,
        lessonHourId: widget.lessonHourId,
        academicYearId: widget.academicYearId,
      );

      final studentData = await _loadStudentData(attendanceDataLoaded);

      AppLogger.info(
        'attendance',
        'Loaded ${attendanceDataLoaded.length} attendance records',
      );

      setState(() {
        studentList = studentData.map((s) => Student.fromJson(s)).toList();
        attendanceData = attendanceDataLoaded;

        tempAttendanceStatus.clear();
        for (final s in studentList) {
          tempAttendanceStatus[s.id] = _getStudentStatus(s.id);
        }

        isLoading = false;
      });
    } catch (e) {
      AppLogger.error(
        'attendance',
        'Error loading absensi detail for admin: $e',
      );
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _loadStudentData(
    List<Attendance> attendanceData,
  ) async {
    if (widget.classId.isNotEmpty) {
      final students = await getIt<ApiStudentService>().getStudentByClass(
        widget.classId,
        academicYearId: widget.academicYearId,
      );
      AppLogger.info(
        'attendance',
        'Loaded ${students.length} students for class: '
            '${widget.classId}',
      );
      return students;
    }

    if (attendanceData.isNotEmpty) {
      final classId = attendanceData.first.classId;
      if (classId != null && classId.isNotEmpty) {
        final students = await getIt<ApiStudentService>().getStudentByClass(
          classId,
          academicYearId: widget.academicYearId,
        );
        AppLogger.info(
          'attendance',
          'Loaded ${students.length} students for class: '
              '$classId (from data)',
        );
        return students;
      }
    }

    final students = await getIt<ApiStudentService>().getStudent();
    AppLogger.info('attendance', 'Loaded all students');
    return students;
  }

  Map<String, int> calculateStatistics() {
    final stats = {
      'hadir': 0,
      'terlambat': 0,
      'izin': 0,
      'sakit': 0,
      'alpha': 0,
    };

    for (final student in studentList) {
      final status = _getStudentStatus(student.id);
      _incrementStatFor(stats, status);
    }

    stats['total'] = studentList.length;
    return stats;
  }

  void _incrementStatFor(Map<String, int> stats, String status) {
    switch (status.toLowerCase()) {
      case 'hadir' || 'present':
        stats['hadir'] = (stats['hadir'] ?? 0) + 1;
      case 'terlambat' || 'late':
        stats['terlambat'] = (stats['terlambat'] ?? 0) + 1;
      case 'izin' || 'excused' || 'permission':
        stats['izin'] = (stats['izin'] ?? 0) + 1;
      case 'sakit' || 'sick':
        stats['sakit'] = (stats['sakit'] ?? 0) + 1;
      case 'alpha' || 'absent':
        stats['alpha'] = (stats['alpha'] ?? 0) + 1;
    }
  }
}
