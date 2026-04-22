import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/domain/models/attendance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for exporting attendance data in AdminAttendanceDetailPage
mixin admin_detail_export_mixin on ConsumerState<AdminAttendanceDetailPage> {
  // Abstract properties - must be implemented by consuming class
  List<Attendance> get attendanceData;

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
      await ExcelPresenceService.exportPresenceToExcel(
        presenceData: attendanceData,
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
