// Shared bottom sheet for viewing announcement details.
// Used by the teacher announcement screen when tapping an announcement.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_header.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';

/// Bottom sheet that displays full announcement details.
class AnnouncementDetailSheet extends StatelessWidget {
  final Map<String, dynamic> announcementData;
  final Color primaryColor;

  const AnnouncementDetailSheet({
    super.key,
    required this.announcementData,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final model = Announcement.fromJson(announcementData);
    final isImportant = [
      'penting',
      'important',
    ].contains((announcementData['priority'] ?? '').toString().toLowerCase());
    final creatorName =
        announcementData['pembuat_nama'] ??
        (announcementData['creator'] is Map
            ? (announcementData['creator'] as Map)['name']
            : null) ??
        '-';
    final roleTarget = (announcementData['role_target'] ?? '')
        .toString()
        .toLowerCase();
    final dateStr = _formatDate(announcementData['created_at']?.toString());
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BottomSheetHeader(
            title: isImportant ? 'Pengumuman Penting' : 'Detail Pengumuman',
            subtitle: dateStr,
            icon: isImportant
                ? Icons.campaign_rounded
                : Icons.announcement_outlined,
            primaryColor: isImportant ? ColorUtils.warning600 : primaryColor,
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    model.title.isNotEmpty ? model.title : 'Tanpa Judul',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Meta chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _MetaChip(
                        icon: Icons.person_outline,
                        label: creatorName.toString(),
                        color: primaryColor,
                      ),
                      _MetaChip(
                        icon: Icons.people_outline,
                        label: _getTargetLabel(roleTarget),
                        color: ColorUtils.info600,
                      ),
                      if (isImportant)
                        _MetaChip(
                          icon: Icons.priority_high_rounded,
                          label: 'Penting',
                          color: ColorUtils.warning600,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Divider
                  Divider(color: ColorUtils.slate100),
                  const SizedBox(height: 12),

                  // Content body
                  Text(
                    model.content,
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate700,
                      height: 1.6,
                    ),
                  ),

                  // File attachment indicator
                  if (announcementData['file_path'] != null &&
                      (announcementData['file_path'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ColorUtils.slate50,
                        borderRadius: const BorderRadius.all(
                          Radius.circular(10),
                        ),
                        border: Border.all(color: ColorUtils.slate200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.attach_file_rounded,
                            size: 18,
                            color: primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              announcementData['file_name']?.toString() ??
                                  'Lampiran',
                              style: TextStyle(
                                fontSize: 13,
                                color: ColorUtils.slate600,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', 'id').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getTargetLabel(String roleTarget) {
    switch (roleTarget) {
      case 'all':
        return 'Semua';
      case 'teacher':
      case 'guru':
        return 'Guru';
      case 'student':
      case 'siswa':
        return 'Siswa';
      case 'wali':
      case 'orang_tua':
        return 'Wali Murid';
      default:
        return roleTarget;
    }
  }
}

/// Small colored chip with icon + label for metadata display.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
