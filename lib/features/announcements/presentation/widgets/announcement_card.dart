// Announcement list-card widget for the admin announcement screen.
// Displays title, content preview, metadata chips, and edit/delete action buttons.
// Like a Vue <AnnouncementCard> component — fully stateless, driven by
// callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement_event.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_event_block.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_info_tag.dart';

/// A single announcement card row rendered inside the admin list.
///
/// In Vue terms this is equivalent to a `<AnnouncementCard>` component
/// that receives all data via props and emits events for edit/delete/tap.
/// No business logic lives here — parent passes callbacks (like Vue `$emit`).
class AnnouncementCard extends StatelessWidget {
  /// The raw announcement map from the API response.
  final Map<String, dynamic> announcementData;

  /// The accent/brand colour for the current role (admin).
  final Color primaryColor;

  /// Formatted display string for `created_at` (pre-computed by parent).
  final String formattedDate;

  /// Human-readable target audience string (pre-computed by parent).
  final String targetText;

  /// Called when the card body is tapped — opens the detail dialog.
  final VoidCallback onTap;

  /// Called when the card is long-pressed — triggers bulk selection mode.
  final VoidCallback? onLongPress;

  /// Whether this card is currently selected in bulk mode.
  final bool isSelected;

  /// i18n label for "Important" — passed from parent to avoid re-reading the
  /// provider here.
  final String importantLabel;

  const AnnouncementCard({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.formattedDate,
    required this.targetText,
    required this.onTap,
    this.onLongPress,
    this.isSelected = false,
    required this.importantLabel,
  });

  @override
  Widget build(BuildContext context) {
    final model = Announcement.fromJson(announcementData);
    final event = AnnouncementEvent.fromJson(announcementData);
    final isUnread = !model.isRead;
    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);
    final accentColor = isImportant ? Colors.orange : primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      color: isSelected
          ? primaryColor.withValues(alpha: 0.04)
          : Colors.transparent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(
                color: isSelected ? primaryColor : ColorUtils.slate200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: coloured icon container (Pattern #8 avatar style)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    isImportant
                        ? Icons.campaign_rounded
                        : Icons.announcement_outlined,
                    color: accentColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),

                // Middle: title + content preview + info chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
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
                      // Content preview
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
                      // Event block (Pengumuman+Acara) — rendered only
                      // when the announcement carries an event_at.
                      if (event != null) ...[
                        const SizedBox(height: AppSpacing.sm),
                        AnnouncementEventBlock(event: event, dense: true),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      // Metadata chips row
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          AnnouncementInfoTag(
                            icon: Icons.access_time_outlined,
                            text: formattedDate,
                          ),
                          AnnouncementInfoTag(
                            icon: Icons.people_outline,
                            text: targetText,
                          ),
                          if (isImportant)
                            AnnouncementInfoTag(
                              icon: Icons.warning_amber_rounded,
                              text: importantLabel,
                              tagColor: Colors.orange,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                if (isUnread || isSelected)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isUnread && !isSelected)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: ColorUtils.error600,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (isSelected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
