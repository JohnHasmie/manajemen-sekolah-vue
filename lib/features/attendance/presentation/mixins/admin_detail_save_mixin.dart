import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/attendance/data/attendance_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for saving attendance changes in AdminAttendanceDetailPage
mixin AdminDetailSaveMixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Attendance> get attendanceData;

  List<Student> get studentList;

  bool get isSaving;
  set isSaving(bool value);

  bool get isEditing;
  set isEditing(bool value);

  Map<String, String> get tempAttendanceStatus;

  /// Returns the widget being used in this state
  @override
  AdminAttendanceDetailPage get widget => super.widget;

  String mapStatusToBackend(String status);

  Future<void> loadData();

  Future<void> saveChanges() async {
    final languageProvider = ref.read(languageRiverpod);
    setState(() => isSaving = true);

    final teacherId = _getTeacherId();
    if (teacherId == null) {
      _handleMissingTeacherId();
      return;
    }

    final result = await _saveStudentAttendance(teacherId);

    if (!mounted) return;

    if (result.success) {
      _handleSaveSuccess(languageProvider, result.count);
      await loadData();
    } else {
      _handleSaveError(languageProvider, result.error);
    }
  }

  String? _getTeacherId() {
    return attendanceData.isNotEmpty ? attendanceData.first.teacherId : null;
  }

  void _handleMissingTeacherId() {
    setState(() => isSaving = false);
    SnackBarUtils.showError(context, 'Error: Guru ID tidak ditemukan');
  }

  Future<_SaveResult> _saveStudentAttendance(String teacherId) async {
    int successCount = 0;
    String lastError = '';
    final dateStr = DateFormat('yyyy-MM-dd').format(widget.date);

    try {
      for (final student in studentList) {
        try {
          final status = tempAttendanceStatus[student.id] ?? 'alpha';
          await AttendanceService.createAttendance({
            'student_id': student.id,
            'teacher_id': teacherId,
            'subject_id': widget.subjectId,
            'class_id': widget.classId,
            'date': dateStr,
            'status': mapStatusToBackend(status),
            'lesson_hour_id': widget.lessonHourId,
            'notes': '',
          });
          successCount++;
        } catch (e) {
          lastError = e.toString();
          AppLogger.error('attendance', 'Error saving for ${student.name}: $e');
        }
      }
      return _SaveResult(
        success: successCount > 0,
        count: successCount,
        error: lastError,
      );
    } catch (e) {
      return _SaveResult(success: false, count: 0, error: e.toString());
    }
  }

  void _handleSaveSuccess(LanguageProvider languageProvider, int count) {
    SnackBarUtils.showInfo(
      context,
      languageProvider.getTranslatedText({
        'en': 'Attendance updated successfully ($count students)',
        'id': 'Absensi berhasil diperbarui ($count siswa)',
      }),
    );
    setState(() {
      isEditing = false;
      isSaving = false;
    });
  }

  void _handleSaveError(LanguageProvider languageProvider, String error) {
    setState(() => isSaving = false);
    SnackBarUtils.showError(
      context,
      'Gagal menyimpan: '
      '${ErrorUtils.getFriendlyMessage(Exception(error))}',
    );
  }
}

class _SaveResult {
  final bool success;
  final int count;
  final String error;

  _SaveResult({
    required this.success,
    required this.count,
    required this.error,
  });
}
