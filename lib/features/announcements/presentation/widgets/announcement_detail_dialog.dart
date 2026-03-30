// Detail view dialog for admin announcement screen.
//
// Extracted from AdminAnnouncementScreenState._showAnnouncementDetail().
// Shows full announcement metadata, content, and file attachment.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_row.dart';

/// Dialog that shows full details of a single announcement.
///
/// Like a Vue `<AnnouncementDetailModal>` component — receives data via props
/// and fires `onOpenFile` to the parent when the attachment is tapped.
class AnnouncementDetailDialog extends StatelessWidget {
  final Map<String, dynamic> announcementData;
  final Color primaryColor;
  final LinearGradient cardGradient;
  final LanguageProvider languageProvider;
  final String Function(String?) formatDate;
  final String Function(Map<String, dynamic>) getTargetText;
  final void Function(String url, String fileName) onOpenFile;

  const AnnouncementDetailDialog({
    super.key,
    required this.announcementData,
    required this.primaryColor,
    required this.cardGradient,
    required this.languageProvider,
    required this.formatDate,
    required this.getTargetText,
    required this.onOpenFile,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with gradient
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                gradient: cardGradient,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.announcement,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          announcementData['title'] ?? 'No Title',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: AppSpacing.sm),
                  Text(
                    formatDate(announcementData['created_at']),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Priority badge
                  if ([
                    'penting',
                    'important',
                  ].contains(announcementData['priority']))
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.orange),
                          SizedBox(width: 6),
                          Text(
                            languageProvider.getTranslatedText({
                              'en': 'Important Announcement',
                              'id': 'Pengumuman Penting',
                            }),
                            style: TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: AppSpacing.lg),

                  // Content text
                  Text(
                    announcementData['content'] ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: ColorUtils.slate800,
                    ),
                  ),

                  SizedBox(height: AppSpacing.xl),

                  // Attachment Section
                  if (announcementData['file_path'] != null) ...[
                    Text(
                      languageProvider.getTranslatedText({
                        'en': 'Attachment',
                        'id': 'Lampiran',
                      }),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: ColorUtils.slate600,
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    InkWell(
                      onTap: () => onOpenFile(
                        announcementData['file_path'],
                        announcementData['file_name'] ?? 'attachment',
                      ),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: ColorUtils.slate50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: ColorUtils.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: ColorUtils.slate200,
                                ),
                              ),
                              child: Icon(
                                Icons.attach_file,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    announcementData['file_name'] ??
                                        languageProvider.getTranslatedText({
                                          'en': 'Download File',
                                          'id': 'Unduh File',
                                        }),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: ColorUtils.slate800,
                                    ),
                                  ),
                                  Text(
                                    languageProvider.getTranslatedText({
                                      'en': 'Tap to open',
                                      'id': 'Ketuk untuk membuka',
                                    }),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: ColorUtils.slate500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.download_rounded,
                              color: ColorUtils.slate400,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: AppSpacing.xl),
                  ],

                  // Metadata
                  Container(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: ColorUtils.slate50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        AnnouncementDetailRow(
                          icon: Icons.person,
                          label: languageProvider.getTranslatedText({
                            'en': 'Created by',
                            'id': 'Dibuat oleh',
                          }),
                          value:
                              announcementData['creator']?['name'] ??
                              announcementData['creator_name'] ??
                              'Unknown',
                          primaryColor: primaryColor,
                        ),
                        SizedBox(height: AppSpacing.sm),
                        AnnouncementDetailRow(
                          icon: Icons.people,
                          label: languageProvider.getTranslatedText({
                            'en': 'Target Role',
                            'id': 'Role Target',
                          }),
                          value: getTargetText(announcementData),
                          primaryColor: primaryColor,
                        ),
                        if (announcementData['start_date'] != null)
                          SizedBox(height: AppSpacing.sm),
                        if (announcementData['start_date'] != null)
                          AnnouncementDetailRow(
                            icon: Icons.calendar_today,
                            label: languageProvider.getTranslatedText({
                              'en': 'Start Date',
                              'id': 'Tanggal Mulai',
                            }),
                            value: formatDate(announcementData['start_date']),
                            primaryColor: primaryColor,
                          ),
                        if (announcementData['end_date'] != null)
                          SizedBox(height: AppSpacing.sm),
                        if (announcementData['end_date'] != null)
                          AnnouncementDetailRow(
                            icon: Icons.event_busy,
                            label: languageProvider.getTranslatedText({
                              'en': 'End Date',
                              'id': 'Tanggal Berakhir',
                            }),
                            value: formatDate(announcementData['end_date']),
                            primaryColor: primaryColor,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Close button
            Container(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => AppNavigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Text(
                        languageProvider.getTranslatedText({
                          'en': 'Close',
                          'id': 'Tutup',
                        }),
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
