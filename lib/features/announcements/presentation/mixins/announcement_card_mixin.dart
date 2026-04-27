import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for building announcement card widgets.
mixin AnnouncementCardMixin on ConsumerState<ParentAnnouncementScreen> {
  Color getPrimaryColor();

  Widget buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
    void Function(Map<String, dynamic>) onTap,
  ) {
    final isUnread = _isUnread(announcementData);
    final isImportant = _isImportant(announcementData);
    final accentColor = isImportant ? ColorUtils.warning600 : getPrimaryColor();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(announcementData),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: _buildCardInner(
            announcementData,
            accentColor,
            isImportant,
            isUnread,
          ),
        ),
      ),
    );
  }

  Widget _buildCardInner(
    Map<String, dynamic> announcementData,
    Color accentColor,
    bool isImportant,
    bool isUnread,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: _cardDecoration(),
      child: _buildCardRow(
        announcementData,
        accentColor,
        isImportant,
        isUnread,
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(14)),
      border: Border.all(color: ColorUtils.slate200, width: 1),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    );
  }

  Widget _buildCardRow(
    Map<String, dynamic> announcementData,
    Color accentColor,
    bool isImportant,
    bool isUnread,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildIconContainer(accentColor, isImportant),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _buildCardContent(announcementData)),
        const SizedBox(width: AppSpacing.sm),
        if (isUnread) _buildUnreadDot(),
      ],
    );
  }

  bool _isUnread(Map<String, dynamic> data) {
    return !Announcement.fromJson(data).isRead;
  }

  bool _isImportant(Map<String, dynamic> data) {
    return ['penting', 'important'].contains(data['priority']);
  }

  Widget _buildIconContainer(Color accentColor, bool isImportant) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
      ),
      child: Icon(
        isImportant ? Icons.campaign_rounded : Icons.announcement_outlined,
        color: accentColor,
        size: 22,
      ),
    );
  }

  Widget _buildCardContent(Map<String, dynamic> announcementData) {
    final model = Announcement.fromJson(announcementData);
    final isImportant = _isImportant(announcementData);
    final dateLabel = _formatRelativeDate(model.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row — title + optional "Penting" pill (matches teacher version)
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                model.title.isNotEmpty ? model.title : 'No Title',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isImportant) ...[
              const SizedBox(width: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ColorUtils.warning600.withValues(alpha: 0.12),
                  borderRadius: const BorderRadius.all(Radius.circular(6)),
                  border: Border.all(
                    color: ColorUtils.warning600.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  'Penting',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.warning600,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          model.content,
          style: TextStyle(
            fontSize: 12,
            color: ColorUtils.slate600,
            height: 1.4,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // Date / time-since meta — added per UI_Redesign_Audit P0 #10.
        // Teacher version (T11) already shows this; bringing parent in line.
        if (dateLabel.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 11,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  /// Compact relative date for the meta row.
  /// Examples: "Baru saja", "30 menit lalu", "3 jam lalu", "Kemarin",
  /// "13 Apr 14:32" (older than a week).
  String _formatRelativeDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '';
    final parsed = DateTime.tryParse(dateString);
    if (parsed == null) return '';
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays == 1) return 'Kemarin';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
    ];
    return '${parsed.day} ${months[parsed.month - 1]} '
        '${parsed.hour.toString().padLeft(2, '0')}:'
        '${parsed.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildUnreadDot() {
    return Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: ColorUtils.error600,
        shape: BoxShape.circle,
      ),
    );
  }
}
