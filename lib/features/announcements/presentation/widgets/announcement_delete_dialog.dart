// Delete confirmation dialog for admin announcement screen.
//
// Extracted from AdminAnnouncementScreenState._deleteAnnouncement().
// Returns true via Navigator.pop when the user confirms deletion.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Confirmation dialog shown before deleting an announcement.
///
/// Like a Vue `<ConfirmDeleteModal>` component that emits `confirm` or `cancel`.
/// Pops with `true` on confirm, `false` on cancel.
class AnnouncementDeleteDialog extends StatelessWidget {
  final LanguageProvider languageProvider;

  const AnnouncementDeleteDialog({
    super.key,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Danger gradient header
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(AppSpacing.xl),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  ColorUtils.error600,
                  ColorUtils.error600.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.delete_outline,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'Delete Announcement',
                          'id': 'Hapus Pengumuman',
                        }),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        languageProvider.getTranslatedText({
                          'en': 'This action cannot be undone',
                          'id': 'Tindakan ini tidak dapat dibatalkan',
                        }),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Message body
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              languageProvider.getTranslatedText({
                'en':
                    'Are you sure you want to delete this announcement? All related data will be permanently removed.',
                'id':
                    'Yakin ingin menghapus pengumuman ini? Semua data terkait akan dihapus secara permanen.',
              }),
              style: TextStyle(
                fontSize: 14,
                color: ColorUtils.slate700,
                height: 1.5,
              ),
            ),
          ),
          // Footer buttons
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => AppNavigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Cancel',
                        'id': 'Batal',
                      }),
                      style: TextStyle(
                        color: ColorUtils.slate700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => AppNavigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      backgroundColor: ColorUtils.error600,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      languageProvider.getTranslatedText({
                        'en': 'Delete',
                        'id': 'Hapus',
                      }),
                      style: TextStyle(fontWeight: FontWeight.bold),
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
}
