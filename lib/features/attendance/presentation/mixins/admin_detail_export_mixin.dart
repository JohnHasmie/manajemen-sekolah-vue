import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Mixin for exporting attendance data in AdminAttendanceDetailPage
mixin AdminDetailExportMixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Attendance> get attendanceData;
  List<Student> get studentList;

  bool get isLoading;
  set isLoading(bool value);

  Future<void> exportDetail() async {
    if (attendanceData.isEmpty) {
      SnackBarUtils.showWarning(context, 'Tidak ada data untuk diekspor');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final exportData = attendanceData.map((record) {
        final student = studentList.firstWhere(
          (s) => s.id == record.studentId,
          orElse: () => const Student(
            id: '',
            name: '',
            className: '',
            studentNumber: '',
            address: '',
            guardianName: '',
            phoneNumber: '',
          ),
        );

        return {
          'nis': student.studentNumber,
          'student_name': student.name,
          'class_name': student.className.isNotEmpty
              ? student.className
              : widget.className,
          'subject_name': record.subjectName ?? widget.subjectName,
          'date': DateFormat('yyyy-MM-dd').format(record.date),
          'status': record.status,
          'notes': '',
          'teacher_name': '',
          'lesson_hour': record.lessonHourName ?? widget.lessonHourName ?? '',
        };
      }).toList();

      await ExcelPresenceService.exportPresenceToExcel(
        presenceData: exportData,
        context: context,
      );
    } catch (e) {
      AppLogger.error('attendance', 'Error exporting activities: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
