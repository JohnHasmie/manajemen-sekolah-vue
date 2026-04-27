// Redesigned announcement card for teacher role — minimal, modern style.
// Matches the LessonPlanCard pattern: status bar left, content middle, metadata.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:intl/intl.dart';

/// A clean, minimal announcement card for the teacher list view.
class TeacherAnnouncementCard extends StatelessWidget {
  final Map<String, dynamic> announcementData;
  final Color primaryColor;
  final VoidCallback onTap;

  const TeacherAnnouncementCard({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final model = Announcement.fromJson(announcementData);
    final isImportant = [
      'penting',
      'important',
    ].contains((announcementData['priority'] ?? '').toString().toLowerCase());
    final isUnread = !model.isRead;
    final accentColor = isImportant ? ColorUtils.warning600 : primaryColor;

    final roleTarget = (announcementData['role_target'] ?? '')
        .toString()
        .toLowerCase();
    final targetLabel = _getTargetLabel(roleTarget);
    final dateStr = _formatDate(announcementData['created_at']?.toString());

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(12)),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Left accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(12),
                      ),
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row + unread dot
                          Row(
                            children: [
                              if (isUnread)
                                Container(
                                  width: 7,
                                  height: 7,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.error600,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  model.title.isNotEmpty
                                      ? model.title
                                      : 'Tanpa Judul',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: isUnread
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: ColorUtils.slate800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isImportant)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ColorUtils.warning600.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: const BorderRadius.all(
                                      Radius.circular(4),
                                    ),
                                  ),
                                  child: Text(
                                    'Penting',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: ColorUtils.warning600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),

                          // Content preview
                          Text(
                            model.content,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: ColorUtils.slate500,
                              height: 1.4,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          // Meta row: date · target
                          Row(
                            children: [
                              Icon(
                                Icons.access_time_outlined,
                                size: 12,
                                color: ColorUtils.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.people_outline,
                                size: 12,
                                color: ColorUtils.slate400,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                targetLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: ColorUtils.slate400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Chevron
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: ColorUtils.slate300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
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

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy', 'id').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}
