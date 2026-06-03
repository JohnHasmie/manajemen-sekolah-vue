import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
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
    final title = (announcementData['title'] ?? 'Tanpa Judul').toString();
    final content = (announcementData['content'] ?? '').toString();
    final event = AnnouncementEvent.fromJson(announcementData);
    final personalReminders =
        (announcementData['personal_reminders'] as List?)
            ?.whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList() ??
        const <Map<String, dynamic>>[];
    // Backend canonical priorities: `low` / `normal` / `high` / `urgent`.
    // Legacy: `biasa` → normal, `penting` → high.
    final isImportant = [
      'high',
      'urgent',
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
    final hasEvent = announcementData['event_at'] != null;
    final eventLocation = announcementData['event_location']?.toString();

    return AppBottomSheet(
      title: isImportant ? 'Pengumuman Penting' : 'Detail Pengumuman',
      subtitle: title,
      icon: isImportant ? Icons.error_outline : Icons.campaign_outlined,
      primaryColor: isImportant ? ColorUtils.error600 : primaryColor,
      simpleHeader: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Body content
          Text(
            'ISI PENGUMUMAN',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate400,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content.isNotEmpty ? content : 'Tidak ada isi.',
            style: TextStyle(
              fontSize: 13.5,
              color: ColorUtils.slate700,
              height: 1.6,
            ),
          ),

          // Event hero
          if (event != null) ...[
            const SizedBox(height: 16),
            AnnouncementEventDetailHero(
              event: event,
              personalReminders: personalReminders,
              onAddPersonalReminder: () => PersonalReminderPickerSheet.show(
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.75),
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
          const SizedBox(height: 16),

          // ── Info section ──
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

          // Metadata card
          _InfoCard(
            children: [
              _InfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Dibuat oleh',
                value: creatorName.toString(),
                color: primaryColor,
              ),
              _InfoRow(
                icon: Icons.group_outlined,
                label: 'Target',
                value: _roleTargetLabel(roleTarget),
                color: primaryColor,
              ),
              _InfoRow(
                icon: Icons.access_time_rounded,
                label: 'Dibuat pada',
                value: _prettyDateTime(
                  announcementData['created_at']?.toString(),
                ),
                color: primaryColor,
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Broadcast schedule card
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

          // Event schedule card
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
}

// ═════════════════════════════════════════════════════════════════════
// Shared private widgets
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
