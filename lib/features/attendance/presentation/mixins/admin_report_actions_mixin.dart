import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/attendance/exports/attendance_export_service.dart';
import 'package:manajemensekolah/features/attendance/presentation/controllers/admin_attendance_report_controller.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_report_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/widgets/attendance_export_dialog.dart';

/// Mixin for user-triggered actions in admin report screen.
/// Handles deletion, navigation, export.
mixin AdminReportActionsMixin on ConsumerState<AdminAttendanceReportScreen> {
  // Access state variables from main state class
  AdminAttendanceReportController get controller;
  Map<String, dynamic>? get selectedClassData;
  List<dynamic> get subjectList;
  bool get isLoadingSummary;
  set isLoadingSummary(bool value);

  Future<void> loadData({bool useCache = true});

  Widget _buildDeleteConfirmDialog(LanguageProvider languageProvider) {
    return Dialog(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.error600,
                  ColorUtils.error600.withValues(alpha: 0.85),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Text(
                  languageProvider.getTranslatedText({
                    'en': 'Delete Attendance',
                    'id': 'Hapus Absensi',
                  }),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Text(
                  languageProvider.getTranslatedText({
                    'en':
                        'Are you sure you want to delete this '
                        'attendance record?',
                    'id':
                        'Apakah Anda yakin ingin menghapus data '
                        'absensi ini?',
                  }),
                  style: TextStyle(fontSize: 14, color: ColorUtils.slate700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Cancel',
                            'id': 'Batal',
                          }),
                          style: TextStyle(color: ColorUtils.slate700),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => AppNavigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          backgroundColor: ColorUtils.error600,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(10)),
                          ),
                        ),
                        child: Text(
                          languageProvider.getTranslatedText({
                            'en': 'Delete',
                            'id': 'Hapus',
                          }),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndDeleteAttendance(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
  ) async {
    try {
      setState(() => isLoadingSummary = true);
      await controller.deleteAttendance(summary);
      if (!mounted) return;
      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Attendance deleted successfully',
          'id': 'Absensi berhasil dihapus',
        }),
      );
      loadData(useCache: false);
    } catch (e) {
      setState(() => isLoadingSummary = false);
      if (!mounted) return;
      SnackBarUtils.showError(
        context,
        'Gagal menghapus absensi: '
        '${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }

  Future<void> deleteAttendance(
    AttendanceSummary summary,
    LanguageProvider languageProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildDeleteConfirmDialog(languageProvider),
    );
    if (confirmed == true) {
      await _confirmAndDeleteAttendance(summary, languageProvider);
    }
  }

  void navigateToAttendanceDetail(AttendanceSummary summary) {
    AppNavigator.push(
      context,
      AdminAttendanceDetailPage(
        subjectId: summary.subjectId,
        subjectName: summary.subjectName,
        date: summary.date,
        classId: summary.classId,
        className: summary.className,
        lessonHourId: summary.lessonHourId,
        lessonHourName: summary.lessonHourName,
        academicYearId: summary.academicYearId,
      ),
    );
  }

  Future<int> _processMonthlyExports(List<DateTime> months) async {
    int successCount = 0;
    for (final month in months) {
      final exportRows = await controller.buildExportRows(
        month: month,
        selectedClassData: selectedClassData!,
        subjectList: subjectList,
      );
      if (exportRows.isNotEmpty && mounted) {
        await ExcelPresenceService.exportPresenceToExcel(
          presenceData: exportRows,
          context: context,
          filters: {},
        );
        successCount++;
      }
      await Future.delayed(const Duration(seconds: 1));
    }
    return successCount;
  }

  void _handleExportSuccess(
    int successCount,
    LanguageProvider languageProvider,
  ) {
    if (mounted) {
      AppNavigator.pop(context);
      SnackBarUtils.showSuccess(
        context,
        languageProvider.getTranslatedText({
          'en': 'Exported $successCount files successfully',
          'id': 'Berhasil mengexport $successCount file',
        }),
      );
    }
  }

  Future<void> processExport(List<DateTime> months) async {
    final languageProvider = ref.read(languageRiverpod);
    months.sort();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final count = await _processMonthlyExports(months);
      _handleExportSuccess(count, languageProvider);
    } catch (e) {
      if (mounted) {
        AppNavigator.pop(context);
        SnackBarUtils.showError(context, 'Export failed: $e');
      }
    }
  }

  void showExportDialog() {
    if (selectedClassData != null) {
      AttendanceExportDialog.show(
        context: context,
        ref: ref,
        onExport: processExport,
      );
    } else {
      final languageProvider = ref.read(languageRiverpod);
      SnackBarUtils.showInfo(
        context,
        languageProvider.getTranslatedText({
          'en': 'Please select a class first',
          'id': 'Mohon pilih kelas terlebih dahulu',
        }),
      );
    }
  }
}
