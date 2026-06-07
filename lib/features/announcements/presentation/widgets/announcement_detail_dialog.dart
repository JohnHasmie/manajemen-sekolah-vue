import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
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

  final String viewerRole;

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

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
    this.onEdit,
    this.onDelete,
  });

  // ── Date helpers ──────────────────────────────────────────────────

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];

  String _prettyDate(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  String _prettyTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '—';
    }
  }

  String _prettyDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${_months[local.month - 1]} ${local.year}, $h:$m';
  }

  // ── Build ────────────────────────────────────────────────────────

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
    final hasEvent = announcementData['event_at'] != null;

    final titleStr = model.title.isNotEmpty ? model.title : kAnnNoTitle.tr;

    return AppBottomSheet(
      title: isImportant ? kAnnImportantTitle.tr : kAnnDetailTitle.tr,
      subtitle: titleStr,
      icon: isImportant ? Icons.warning_amber_rounded : Icons.campaign_outlined,
      primaryColor: isImportant ? ColorUtils.error600 : primaryColor,
      footer: BottomSheetFooter(
        primaryLabel: kAnnEditData.tr,
        secondaryLabel: onDelete != null ? kDelete.tr : kClose.tr,
        secondaryDestructive: onDelete != null,
        primaryColor: primaryColor,
        primaryEnabled: onEdit != null,
        onPrimary: () {
          if (onEdit != null) {
            Navigator.pop(context);
            onEdit?.call();
          }
        },
        onSecondary: () {
          Navigator.pop(context);
          if (onDelete != null) onDelete?.call();
        },
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBody(model),

          // Event hero
          if (AnnouncementEvent.fromJson(announcementData) case final ev?) ...[
            const SizedBox(height: 16),
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
                  : () =>
                        _openPersonalReminderPicker(context, ev.announcementId),
            ),
          ],

          // Attachment
          if (filePath != null && filePath.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAttachment(filePath, fileName),
          ],

          const SizedBox(height: 20),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // ── Detail cards ──
          _buildInfoSection(creator, model, hasEvent),
        ],
      ),
    );
  }

  // ── Pieces ────────────────────────────────────────────────────────

  List<Map<String, dynamic>>? _remindersFrom(Map<String, dynamic> data) {
    final raw = data['reminders'];
    if (raw is! List) return null;
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  List<Map<String, dynamic>> _personalRemindersFrom(Map<String, dynamic> data) {
    final raw = data['personal_reminders'];
    if (raw is! List) return const [];
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

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

  // ── Body ──────────────────────────────────────────────────────────

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
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: ColorUtils.slate400,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          model.content.isEmpty ? '—' : model.content,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.6,
            color: ColorUtils.slate700,
          ),
        ),
      ],
    );
  }

  // ── Attachment ────────────────────────────────────────────────────

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

  // ── Info section ───────────────────────────────────────

  Widget _buildInfoSection(String creator, Announcement model, bool hasEvent) {
    final eventLocation = announcementData['event_location']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INFORMASI',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.6,
            color: ColorUtils.slate400,
          ),
        ),
        const SizedBox(height: 10),

        // ── Metadata card ──
        _InfoCard(
          children: [
            _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Dibuat oleh',
              value: creator,
              color: primaryColor,
            ),
            _InfoRow(
              icon: Icons.group_outlined,
              label: 'Target',
              value: getTargetText(announcementData),
              color: primaryColor,
            ),
            _InfoRow(
              icon: Icons.access_time_rounded,
              label: 'Dibuat pada',
              value: _prettyDateTime(model.createdAt),
              color: primaryColor,
            ),
          ],
        ),

        const SizedBox(height: 10),

        // ── Broadcast schedule card ──
        _InfoCard(
          accent: const Color(0xFF0EA5E9),
          children: [
            _InfoRow(
              icon: Icons.play_circle_outline_rounded,
              label: 'Mulai Tayang',
              value: _prettyDate(announcementData['start_date']?.toString()),
              color: const Color(0xFF0EA5E9),
            ),
            _InfoRow(
              icon: Icons.stop_circle_outlined,
              label: 'Selesai Tayang',
              value: announcementData['end_date'] != null
                  ? _prettyDate(announcementData['end_date']?.toString())
                  : 'Selamanya',
              color: const Color(0xFF0EA5E9),
            ),
          ],
        ),

        // ── Event schedule card ──
        if (hasEvent) ...[
          const SizedBox(height: 10),
          _InfoCard(
            accent: const Color(0xFF8B5CF6),
            children: [
              _InfoRow(
                icon: Icons.event_rounded,
                label: 'Tanggal Acara',
                value: _prettyDate(announcementData['event_at']?.toString()),
                color: const Color(0xFF8B5CF6),
              ),
              _InfoRow(
                icon: Icons.schedule_rounded,
                label: 'Jam Acara',
                value: announcementData['event_has_time'] == false
                    ? 'Sepanjang hari'
                    : _prettyTime(announcementData['event_at']?.toString()),
                color: const Color(0xFF8B5CF6),
              ),
              if (eventLocation != null && eventLocation.isNotEmpty)
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Lokasi',
                  value: eventLocation,
                  color: const Color(0xFF8B5CF6),
                ),
            ],
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════
// Private widgets
// ═════════════════════════════════════════════════════════════════════

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  final Color? accent;

  const _InfoCard({required this.children, this.accent});

  @override
  Widget build(BuildContext context) {
    final a = accent ?? ColorUtils.slate400;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: a.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
              const Divider(height: 1, indent: 44, color: Color(0xFFF1F5F9)),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate400,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
