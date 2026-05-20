// Phase-4 announcement detail bottom sheet matching mockup surface 2.
//
// Layout:
//   • Icon + kicker ("PENGUMUMAN · UMUM") + title
//   • Body content text
//   • Attachment chip (if file_path present)
//   • Metadata grid 2x2 (Dibuat oleh, Role Target, Tanggal Mulai/Berakhir, Dibuat pada)
//   • Close X in top-right corner (no footer Tutup button)
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_event_detail_hero.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/personal_reminder_picker_sheet.dart';

class AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> announcementData;
  final Color primaryColor;

  /// 'teacher' | 'parent'. Drives whether the event hero shows the
  /// personal-reminder picker (this sheet isn't called for admin —
  /// admin uses [AnnouncementDetailDialog]).
  final String viewerRole;

  const AnnouncementDetailSheet({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    this.viewerRole = 'parent',
  });

  @override
  Widget build(BuildContext context) {
    final title = (announcementData['title'] ?? 'Tanpa Judul').toString();
    final content = (announcementData['content'] ?? '').toString();
    final event = AnnouncementEvent.fromJson(announcementData);
    final personalReminders =
        (announcementData['personal_reminders'] as List?)
                ?.whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList() ??
            const <Map<String, dynamic>>[];
    final isImportant = [
      'penting',
      'important',
    ].contains((announcementData['priority'] ?? '').toString().toLowerCase());
    final roleTarget = (announcementData['role_target'] ?? 'all').toString();
    final creatorName =
        announcementData['pembuat_nama'] ??
        (announcementData['creator'] is Map
            ? (announcementData['creator'] as Map)['name']
            : null) ??
        '-';
    final filePath =
        (announcementData['file_path'] ??
                announcementData['attachment_url'] ??
                '')
            .toString();
    final fileName =
        announcementData['attachment_name']?.toString() ??
        announcementData['file_name']?.toString() ??
        (filePath.isNotEmpty ? filePath.split('/').last : '');
    final startDate = _formatDate(announcementData['start_date']?.toString());
    final endDate = _formatDate(announcementData['end_date']?.toString());
    final createdAt = _formatDateTime(
      announcementData['created_at']?.toString(),
    );

    final typeLabel = isImportant ? 'PENTING' : 'UMUM';
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Content
          Flexible(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, 28, 24, 20 + bottomPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Icon + kicker + title
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              isImportant
                                  ? Icons.error_outline
                                  : Icons.campaign_outlined,
                              size: 28,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PENGUMUMAN · $typeLabel',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.slate400,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: ColorUtils.slate900,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 20),

                      // Body content
                      Text(
                        'ISI PENGUMUMAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        content.isNotEmpty ? content : 'Tidak ada isi.',
                        style: TextStyle(
                          fontSize: 13,
                          color: ColorUtils.slate600,
                          height: 1.6,
                        ),
                      ),

                      // Acara hero — countdown + personal reminder
                      // section. Hidden when announcement carries no
                      // event_at, so plain pengumuman renders as
                      // before.
                      if (event != null) ...[
                        const SizedBox(height: 16),
                        AnnouncementEventDetailHero(
                          event: event,
                          personalReminders: personalReminders,
                          onAddPersonalReminder: () =>
                              PersonalReminderPickerSheet.show(
                                context: context,
                                announcementId: event.announcementId,
                                roleColor: primaryColor,
                              ),
                        ),
                      ],

                      // Attachment chip
                      if (filePath.isNotEmpty && fileName.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: ColorUtils.slate50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 0.75,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.description_outlined,
                                size: 16,
                                color: primaryColor,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  fileName,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: ColorUtils.slate900,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 20),
                      const Divider(color: Color(0xFFF1F5F9), height: 1),
                      const SizedBox(height: 20),

                      // Metadata grid
                      Text(
                        'DETAIL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate400,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Row 1
                      Row(
                        children: [
                          Expanded(
                            child: _MetaCell(
                              label: 'Dibuat oleh',
                              value: creatorName.toString(),
                            ),
                          ),
                          Expanded(
                            child: _MetaCell(
                              label: 'Role Target',
                              value: _roleTargetLabel(roleTarget),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 2
                      Row(
                        children: [
                          Expanded(
                            child: _MetaCell(
                              label: 'Tanggal Mulai',
                              value: startDate ?? '-',
                            ),
                          ),
                          Expanded(
                            child: _MetaCell(
                              label: 'Tanggal Berakhir',
                              value: endDate ?? '-',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Row 3
                      _MetaCell(label: 'Dibuat pada', value: createdAt ?? '-'),
                    ],
                  ),
                ),
                // Close X top-right
                Positioned(
                  top: 14,
                  right: 14,
                  child: Material(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => Navigator.pop(context),
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.close,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleTargetLabel(String target) {
    return switch (target.toLowerCase()) {
      'all' => 'Semua Pengguna',
      'admin' => 'Admin',
      'guru' => 'Guru',
      'wali' => 'Wali Murid',
      'siswa' => 'Siswa',
      _ => target,
    };
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy', 'id_ID').format(dt);
  }

  String? _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
  }
}

class _MetaCell extends StatelessWidget {
  final String label;
  final String value;

  const _MetaCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 9.5, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }
}
