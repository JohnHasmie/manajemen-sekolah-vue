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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          model.title.isNotEmpty ? model.title : 'No Title',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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
      ],
    );
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
