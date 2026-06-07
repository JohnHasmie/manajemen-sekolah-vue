// Pengumuman + Acara — picker sheet for personal reminders.
//
// Wali/guru tap "Tambah Pengingat" on the detail screen → this sheet
// opens with a row of preset offset chips (3 hari, 1 hari, 1 jam,
// 30 mnt, saat mulai). Picking one POSTs to
// /announcements/{id}/personal-reminder and pops with `true`.
//
// Backend de-dupes via the (announcement, user, offset) unique
// constraint — re-picking the same offset is idempotent.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';

class _ReminderPresetOption {
  const _ReminderPresetOption({required this.label, required this.minutes});
  final String label;
  final int minutes;
}

class PersonalReminderPickerSheet {
  /// Opens the sheet. Returns `true` when a reminder was successfully
  /// stored — caller refreshes its list. Returns `false` on dismiss
  /// or failure.
  static Future<bool> show({
    required BuildContext context,
    required String announcementId,
    required Color roleColor,
  }) async {
    final result = await AppBottomSheet.show<bool>(
      context: context,
      title: kAnnSetReminder.tr,
      subtitle: kAnnChooseReminderTime.tr,
      icon: Icons.notifications_active_rounded,
      primaryColor: roleColor,
      content: _PickerBody(
        announcementId: announcementId,
        roleColor: roleColor,
      ),
    );
    return result ?? false;
  }
}

class _PickerBody extends StatefulWidget {
  const _PickerBody({required this.announcementId, required this.roleColor});

  final String announcementId;
  final Color roleColor;

  @override
  State<_PickerBody> createState() => _PickerBodyState();
}

class _PickerBodyState extends State<_PickerBody> {
  static List<_ReminderPresetOption> get _presets => <_ReminderPresetOption>[
    _ReminderPresetOption(label: kAnnReminder3DaysBefore.tr, minutes: 4320),
    _ReminderPresetOption(label: kAnnReminder1DayBefore.tr, minutes: 1440),
    _ReminderPresetOption(label: kAnnReminder3HoursBefore.tr, minutes: 180),
    _ReminderPresetOption(label: kAnnReminder1HourBefore.tr, minutes: 60),
    _ReminderPresetOption(label: kAnnReminder30MinutesBefore.tr, minutes: 30),
    _ReminderPresetOption(label: kAnnReminderAtStart.tr, minutes: 0),
  ];

  bool _saving = false;

  Future<void> _pickPreset(int minutes) async {
    if (_saving) return;
    setState(() => _saving = true);
    final result = await AnnouncementService.setPersonalReminder(
      announcementId: widget.announcementId,
      offsetMinutes: minutes,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (result != null) {
      Navigator.of(context).pop(true);
      SnackBarUtils.showSuccess(context, kAnnReminderSaved.tr);
    } else {
      SnackBarUtils.showError(context, kAnnReminderSaveFailed.tr);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_saving)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LinearProgressIndicator(
                minHeight: 2,
                color: widget.roleColor,
                backgroundColor: widget.roleColor.withValues(alpha: 0.15),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presets.map((opt) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _pickPreset(opt.minutes),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: widget.roleColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: widget.roleColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_outlined,
                          size: 14,
                          color: widget.roleColor,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          opt.label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: widget.roleColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          Text(
            kAnnReminderNote.tr,
            style: TextStyle(
              fontSize: 11,
              color: ColorUtils.slate500,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
