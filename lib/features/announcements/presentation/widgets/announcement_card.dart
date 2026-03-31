// Announcement list-card widget for the admin announcement screen.
// Displays title, content preview, metadata chips, and edit/delete action buttons.
// Like a Vue <AnnouncementCard> component — fully stateless, driven by callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
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

  /// Called when the edit icon is tapped — opens the edit form sheet.
  final VoidCallback onEdit;

  /// Called when the delete icon is tapped — triggers delete confirmation.
  final VoidCallback onDelete;

  /// i18n label for "Important" — passed from parent to avoid re-reading the provider here.
  final String importantLabel;

  const AnnouncementCard({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.formattedDate,
    required this.targetText,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.importantLabel,
  });

  @override
  Widget build(BuildContext context) {
    final isUnread =
        announcementData['is_read'] != null &&
        announcementData['is_read'] != true &&
        announcementData['is_read'] != 1 &&
        announcementData['is_read'] != '1';
    final isImportant = [
      'penting',
      'important',
    ].contains(announcementData['priority']);
    final accentColor = isImportant ? Colors.orange : primaryColor;

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

                // Middle: title + content preview + info chips
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
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
                      // Content preview
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

                // Right: unread dot + icon action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600,
                          shape: BoxShape.circle,
                        ),
                      ),
                    // Edit icon button
                    InkWell(
                      onTap: onEdit,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: primaryColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Delete icon button
                    InkWell(
                      onTap: onDelete,
                      borderRadius: const BorderRadius.all(Radius.circular(8)),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ColorUtils.error600.withValues(alpha: 0.1),
                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Icon(
                          Icons.delete_outline,
                          size: 16,
                          color: ColorUtils.error600,
                        ),
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
