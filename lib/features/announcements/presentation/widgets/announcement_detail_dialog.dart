// Detail bottom-sheet for an announcement. Phase-4 surface 2.
//
// Was a center `Dialog` with a top-of-card gradient header + "Tutup"
// footer button. The Phase-4 redesign converts it to a brand-style
// bottom sheet:
//
//   • Drag handle on top, close-X in top-right
//   • Compact header: tinted icon badge + role-target chip + title
//   • Prominent body content (the announcement text itself)
//   • Optional attachment chip (file name + size)
//   • 2x2 detail grid at the bottom (Dibuat oleh, Role Target,
//     Tanggal Mulai, Tanggal Berakhir, Dibuat pada)
//   • No footer "Tutup" button — close-X + tap-outside dismisses
//
// The widget signature is preserved so the existing `mixins/
// admin_dialog_mixin.dart` caller works unchanged; only the parent
// invocation switched from `showDialog` to `showModalBottomSheet`.
//
// Used by admin AND parent announcement screens (parent invokes the
// same mixin via inheritance).

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_event_detail_hero.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/personal_reminder_picker_sheet.dart';

class AnnouncementDetailDialog extends StatelessWidget {
  final Map<String, dynamic> announcementData;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;
  final String Function(String?) formatDate;
  final String Function(Map<String, dynamic>) getTargetText;
  final void Function(String url, String fileName) onOpenFile;

  /// 'admin' | 'teacher' | 'parent'. Drives which reminder block
  /// renders on the event hero — admin sees the audit ("status
  /// peringatan") list, non-admin sees their personal reminders +
  /// the "Atur Pengingat" CTA.
  final String viewerRole;

  const AnnouncementDetailDialog({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
    required this.formatDate,
    required this.getTargetText,
    required this.onOpenFile,
    this.viewerRole = 'admin',
  });

  @override
  Widget build(BuildContext context) {
    final model = Announcement.fromJson(announcementData);
    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);
    final filePath = announcementData['file_path']?.toString();
    final fileName = announcementData['file_name']?.toString();
    final creator =
        announcementData['creator']?['name'] ??
        announcementData['creator_name'] ??
        '—';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(28),
              topRight: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              _buildDragHandle(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    8,
                    AppSpacing.md,
                    AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, model, isImportant),
                      AppSpacing.v16,
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      AppSpacing.v16,
                      _buildBody(model),
                      // Acara hero — rendered only when the
                      // announcement carries an event_at. Drops
                      // the countdown + admin reminder status under
                      // the body, above any attachment. Admin sees
                      // the audit list; teacher/wali see personal
                      // reminders + the "Tambah" picker.
                      if (AnnouncementEvent.fromJson(announcementData)
                          case final ev?) ...[
                        AppSpacing.v16,
                        AnnouncementEventDetailHero(
                          event: ev,
                          adminReminders: viewerRole == 'admin'
                              ? _remindersFrom(announcementData)
                              : null,
                          personalReminders: viewerRole == 'admin'
                              ? null
                              : _personalRemindersFrom(announcementData),
                          onAddPersonalReminder: viewerRole == 'admin'
                              ? null
                              : () => _openPersonalReminderPicker(
                                  context,
                                  ev.announcementId,
                                ),
                        ),
                      ],
                      if (filePath != null && filePath.isNotEmpty) ...[
                        AppSpacing.v16,
                        _buildAttachment(filePath, fileName),
                      ],
                      AppSpacing.v16,
                      const Divider(height: 1, color: Color(0xFFF1F5F9)),
                      AppSpacing.v16,
                      _buildDetailGrid(creator, model),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── pieces ────────────────────────────────────────────────────────

  /// Pull admin-scheduled reminder rows out of the API response.
  /// Backend embeds them under `reminders` (HasMany on Announcement).
  /// Returns null when the payload didn't include them — caller hides
  /// the status card in that case.
  List<Map<String, dynamic>>? _remindersFrom(Map<String, dynamic> data) {
    final raw = data['reminders'];
    if (raw is! List) return null;
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Same shape but for the viewer-scoped personal reminder list. The
  /// backend embeds these under `personal_reminders` for the
  /// authenticated user; empty list = card is shown with just the
  /// "Tambah" CTA.
  List<Map<String, dynamic>> _personalRemindersFrom(
    Map<String, dynamic> data,
  ) {
    final raw = data['personal_reminders'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }

  /// Open the personal-reminder picker sheet. On success the parent
  /// screen should re-fetch the announcement so the new row renders.
  Future<void> _openPersonalReminderPicker(
    BuildContext context,
    String announcementId,
  ) async {
    await PersonalReminderPickerSheet.show(
      context: context,
      announcementId: announcementId,
      roleColor: primaryColor,
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Stack(
        children: [
          // Centered drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Close-X in top-right
          Positioned(right: 8, top: -2, child: _CloseButton()),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    Announcement model,
    bool isImportant,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tinted icon badge
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Icon(
            isImportant ? Icons.warning_amber_rounded : Icons.campaign_outlined,
            color: primaryColor,
            size: 28,
          ),
        ),
        AppSpacing.h12,
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kickerLabel(isImportant),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                model.title.isNotEmpty ? model.title : '—',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _kickerLabel(bool isImportant) {
    final base = languageProvider.getTranslatedText({
      'en': 'ANNOUNCEMENT',
      'id': 'PENGUMUMAN',
    });
    if (!isImportant) return '$base · UMUM';
    return '$base · ${languageProvider.getTranslatedText({'en': 'IMPORTANT', 'id': 'PENTING'})}';
  }

  Widget _buildBody(Announcement model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          languageProvider.getTranslatedText({
            'en': 'CONTENT',
            'id': 'ISI PENGUMUMAN',
          }),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          model.content.isEmpty ? '—' : model.content,
          style: TextStyle(
            fontSize: 14,
            height: 1.55,
            color: ColorUtils.slate700,
          ),
        ),
      ],
    );
  }

  Widget _buildAttachment(String filePath, String? fileName) {
    return InkWell(
      onTap: () => onOpenFile(filePath, fileName ?? 'attachment'),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.attach_file_rounded,
                color: primaryColor,
                size: 18,
              ),
            ),
            AppSpacing.h12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName ?? 'lampiran',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: ColorUtils.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    languageProvider.getTranslatedText({
                      'en': 'Tap to open',
                      'id': 'Ketuk untuk membuka',
                    }),
                    style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
                  ),
                ],
              ),
            ),
            Icon(Icons.download_rounded, size: 18, color: ColorUtils.slate400),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailGrid(String creator, Announcement model) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DETAIL',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _DetailCell(
                label: languageProvider.getTranslatedText({
                  'en': 'Created by',
                  'id': 'Dibuat oleh',
                }),
                value: creator,
              ),
            ),
            Expanded(
              child: _DetailCell(
                label: languageProvider.getTranslatedText({
                  'en': 'Target Role',
                  'id': 'Role Target',
                }),
                value: getTargetText(announcementData),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _DetailCell(
                label: languageProvider.getTranslatedText({
                  'en': 'Start Date',
                  'id': 'Tanggal Mulai',
                }),
                value: announcementData['start_date'] != null
                    ? formatDate(announcementData['start_date']?.toString())
                    : '—',
              ),
            ),
            Expanded(
              child: _DetailCell(
                label: languageProvider.getTranslatedText({
                  'en': 'End Date',
                  'id': 'Tanggal Berakhir',
                }),
                value: announcementData['end_date'] != null
                    ? formatDate(announcementData['end_date']?.toString())
                    : '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailCell(
          label: languageProvider.getTranslatedText({
            'en': 'Created at',
            'id': 'Dibuat pada',
          }),
          value: formatDate(model.createdAt),
        ),
      ],
    );
  }
}

/// Top-right close-X. Uses a Builder so we can pop the right route.
class _CloseButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (ctx) => InkWell(
        onTap: () => Navigator.of(ctx).pop(),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.close_rounded,
            size: 16,
            color: ColorUtils.slate600,
          ),
        ),
      ),
    );
  }
}

/// One cell in the 2x2 detail grid — small uppercase label above
/// a bold value.
class _DetailCell extends StatelessWidget {
  final String label;
  final String value;

  const _DetailCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }
}
