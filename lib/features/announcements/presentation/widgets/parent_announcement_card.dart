// Announcement list-card widget for the parent (wali murid) announcement screen.
// Displays title, content preview, metadata chips, and an unread dot. No edit/delete actions.
// Like a Vue <ParentAnnouncementCard> component — fully stateless, driven by callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_info_tag.dart';

/// A single announcement card row rendered inside the parent (wali murid) list.
///
/// In Vue terms this is equivalent to a `<ParentAnnouncementCard>` component
/// that receives all data via props and emits a single tap event (no edit/delete).
/// In Laravel/Blade terms, think of it as:
/// `@include('partials.parent-announcement-card', ['data' => $announcement])`.
/// No business logic lives here — parent passes callbacks (like Vue `$emit`).
class ParentAnnouncementCard extends StatelessWidget {
  /// The raw announcement map from the API response.
  final Map<String, dynamic> announcementData;

  /// The accent/brand colour for the current role (wali murid).
  final Color primaryColor;

  /// Formatted display string for `created_at` (pre-computed by parent).
  final String formattedDate;

  /// Human-readable target audience string (pre-computed by parent).
  final String targetText;

  /// Translated label for the "Important" priority badge (pre-computed by parent).
  final String importantLabel;

  /// Called when the card is tapped — opens the detail dialog in the parent.
  final VoidCallback onTap;

  const ParentAnnouncementCard({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.formattedDate,
    required this.targetText,
    required this.importantLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine read state — mirrors the logic in _buildAnnouncementCard.
    // An item is unread when is_read is explicitly false/0/'0'/null (not set).
    final isUnread =
        announcementData['is_read'] != null &&
        announcementData['is_read'] != true &&
        announcementData['is_read'] != 1 &&
        announcementData['is_read'] != '1';

    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);

    // Important announcements use the warning accent; others use role colour.
    final accentColor = isImportant ? ColorUtils.warning600 : primaryColor;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.all(Radius.circular(14)),
              border: Border.all(color: ColorUtils.slate200, width: 1),
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

                // Middle: title + content preview + metadata info chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title — single line with ellipsis overflow
                      Text(
                        announcementData['title'] ?? 'No Title',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: ColorUtils.slate900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      // Content preview — two lines max
                      Text(
                        announcementData['content'] ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: ColorUtils.slate600,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Metadata chip row: date · creator · target · priority
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          AnnouncementInfoTag(
                            icon: Icons.access_time_outlined,
                            text: formattedDate,
                          ),
                          AnnouncementInfoTag(
                            icon: Icons.person_outline,
                            text: announcementData['pembuat_nama'] ?? 'Unknown',
                          ),
                          AnnouncementInfoTag(
                            icon: Icons.people_outline,
                            text: targetText,
                          ),
                          if (isImportant)
                            AnnouncementInfoTag(
                              icon: Icons.warning_amber_rounded,
                              text: importantLabel,
                              tagColor: ColorUtils.warning600,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),

                // Right: unread indicator dot (red circle when not yet read)
                if (isUnread)
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: ColorUtils.error600,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
