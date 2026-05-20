import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/settings/data/settings_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/settings/presentation/widgets/day_session_management_sheet.dart';

mixin SessionAddEditMixin on State<DaySessionManagementSheet> {
  // Abstract methods that must be implemented by the state
  Future<void> refreshSessions();
  Widget buildTimeFields(
    TimeOfDay startTime,
    TimeOfDay endTime,
    Future<void> Function(bool isStart) onPickTime,
  );
  Widget buildHourField(TextEditingController hourController);

  void showAddEditSessionDialog({Map<String, dynamic>? session}) {
    final bool isEdit = session != null;
    final hourController = TextEditingController(
      text: isEdit ? session['hour_number'].toString() : '',
    );

    TimeOfDay startTime = const TimeOfDay(hour: 7, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 7, minute: 45);

    if (isEdit) {
      try {
        final startParts = session['start_time'].toString().split(':');
        final endParts = session['end_time'].toString().split(':');
        startTime = TimeOfDay(
          hour: int.parse(startParts[0]),
          minute: int.parse(startParts[1]),
        );
        endTime = TimeOfDay(
          hour: int.parse(endParts[0]),
          minute: int.parse(endParts[1]),
        );
      } catch (_) {}
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildAddEditSessionSheet(
        isEdit: isEdit,
        session: session,
        hourController: hourController,
        initialStartTime: startTime,
        initialEndTime: endTime,
      ),
    );
  }

  Widget _buildAddEditSessionSheet({
    required bool isEdit,
    required Map<String, dynamic>? session,
    required TextEditingController hourController,
    required TimeOfDay initialStartTime,
    required TimeOfDay initialEndTime,
  }) {
    // Mutable state lives HERE — in the same scope as the
    // StatefulBuilder. The builder closure below captures these
    // variables by reference; calling `setModalState` re-runs the
    // closure which then reads the mutated values. This is the fix
    // for the long-standing "jam tidak berubah" bug.
    TimeOfDay startTime = initialStartTime;
    TimeOfDay endTime = initialEndTime;
    const bool isSaving = false;
    return StatefulBuilder(
      builder: (context, setModalState) {
        Future<void> pickTime(bool isStart) async {
          final picked = await showTimePicker(
            context: context,
            initialTime: isStart ? startTime : endTime,
          );
          if (picked == null) return;
          setModalState(() {
            if (isStart) {
              startTime = picked;
            } else {
              endTime = picked;
            }
          });
        }

        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Container(
            margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogHeader(isEdit),
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Column(
                      children: [
                        buildHourField(hourController),
                        const SizedBox(height: AppSpacing.md),
                        buildTimeFields(startTime, endTime, pickTime),
                      ],
                    ),
                  ),
                ),
              ),
              _buildDialogFooter(
                isEdit,
                isSaving,
                hourController,
                session,
                startTime,
                endTime,
                setModalState,
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  Widget _buildDialogHeader(bool isEdit) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: ColorUtils.headerFadeGradient(ColorUtils.brandAzure),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              isEdit ? Icons.edit_rounded : Icons.add_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Sesi' : 'Tambah Sesi',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Atur jam pelajaran untuk hari ini',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogFooter(
    bool isEdit,
    bool isSaving,
    TextEditingController hourController,
    Map<String, dynamic>? session,
    TimeOfDay startTime,
    TimeOfDay endTime,
    StateSetter setModalState,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => AppNavigator.pop(context),
                style: OutlinedButton.styleFrom(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: ColorUtils.slate300),
                ),
                child: Text(
                  AppLocalizations.cancel.tr,
                  style: TextStyle(
                    color: ColorUtils.slate700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () => _handleSaveSession(
                        isEdit,
                        hourController,
                        session,
                        startTime,
                        endTime,
                        setModalState,
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.corporateBlue600,
                  disabledBackgroundColor: ColorUtils.corporateBlue600
                      .withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(12)),
                  ),
                  elevation: 2,
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        AppLocalizations.save.tr,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSaveSession(
    bool isEdit,
    TextEditingController hourController,
    Map<String, dynamic>? session,
    TimeOfDay startTime,
    TimeOfDay endTime,
    StateSetter setModalState,
  ) async {
    if (hourController.text.isEmpty) return;
    setModalState(() {});
    final messenger = ScaffoldMessenger.of(context);
    final startStr =
        '${startTime.hour.toString().padLeft(2, '0')}:'
        '${startTime.minute.toString().padLeft(2, '0')}:00';
    final endStr =
        '${endTime.hour.toString().padLeft(2, '0')}:'
        '${endTime.minute.toString().padLeft(2, '0')}:00';
    final hourNum = int.tryParse(hourController.text) ?? 0;
    try {
      if (isEdit && session != null) {
        await getIt<ApiSettingsService>().updateLessonSession(
          id: session['id'].toString(),
          startTime: startStr,
          endTime: endStr,
          hourNumber: hourNum,
        );
      } else {
        await getIt<ApiSettingsService>().createLessonSession(
          dayId: widget.day['id'].toString(),
          hourNumber: hourNum,
          startTime: startStr,
          endTime: endStr,
        );
      }
      if (mounted) {
        AppNavigator.pop(context);
      }
      await refreshSessions();
    } catch (e) {
      AppLogger.error('settings', e);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan: '
            '${ErrorUtils.getFriendlyMessage(e)}',
          ),
          backgroundColor: ColorUtils.error600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setModalState(() {});
      }
    }
  }
}
