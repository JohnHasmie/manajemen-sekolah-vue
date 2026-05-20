import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionDataMixin on State<DaySessionManagementSheet> {
  List<dynamic> get sessions;
  set sessions(List<dynamic> value);

  // Abstract method provided by SessionDialogMixin
  Widget _buildDeleteConfirmDialog();

  Future<void> refreshSessions() async {
    try {
      final allSettings = await getIt<ApiSettingsService>()
          .getLessonHourSettings();
      final dayId = widget.day['id'].toString();
      final updated = allSettings
          .where((s) => s['day_id'].toString() == dayId)
          .toList();
      updated.sort(
        (a, b) => (a['hour_number'] as int).compareTo(b['hour_number'] as int),
      );

      if (mounted) setState(() => sessions = updated);
      widget.onSave();
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal memuat ulang sesi: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> copySchedule(dynamic sourceDay) async {
    final sourceDayId = sourceDay['id'].toString();
    final sourceSessions = widget.allSessionsByDay[sourceDayId] ?? [];
    if (sourceSessions.isEmpty) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) =>
            const Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
      for (final s in sourceSessions) {
        await getIt<ApiSettingsService>().createLessonSession(
          dayId: widget.day['id'].toString(),
          hourNumber: s['hour_number'],
          startTime: s['start_time'],
          endTime: s['end_time'],
        );
      }
      if (mounted) AppNavigator.pop(context);
      await refreshSessions();
      if (mounted) {
        SnackBarUtils.showSuccess(context, 'Berhasil menyalin jadwal');
      }
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) AppNavigator.pop(context);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menyalin: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }

  Future<void> deleteSession(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => _buildDeleteConfirmDialog(),
    );

    if (confirm != true) return;

    try {
      await getIt<ApiSettingsService>().deleteLessonSession(id);
      await refreshSessions();
    } catch (e) {
      AppLogger.error('settings', e);
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal menghapus: ${ErrorUtils.getFriendlyMessage(e)}',
        );
      }
    }
  }
}
