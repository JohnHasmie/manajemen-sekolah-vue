// Delete confirmation dialog for admin announcement screen.
//
// Extracted from AdminAnnouncementScreenState._deleteAnnouncement().
// Returns true via Navigator.pop when the user confirms deletion.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/action_confirm_sheet.dart';

/// Confirmation dialog shown before deleting an announcement.
///
/// Like a Vue `<ConfirmDeleteModal>` component that emits `confirm` or `cancel`.
/// Calls ActionConfirmSheet.show() with destructive styling.
class AnnouncementDeleteDialog {
  final LanguageProvider languageProvider;

  const AnnouncementDeleteDialog({required this.languageProvider});

  /// Shows the delete confirmation dialog and returns true if confirmed.
  static Future<bool?> show(
    BuildContext context,
    LanguageProvider languageProvider,
  ) async {
    return ActionConfirmSheet.show(
      context: context,
      title: languageProvider.getTranslatedText({
        'en': 'Delete Announcement',
        'id': 'Hapus Pengumuman',
      }),
      message: languageProvider.getTranslatedText({
        'en':
            'Are you sure you want to delete this announcement? All related data will be permanently removed.',
        'id':
            'Yakin ingin menghapus pengumuman ini? Semua data terkait akan dihapus secara permanen.',
      }),
      confirmText: languageProvider.getTranslatedText({
        'en': 'Delete',
        'id': 'Hapus',
      }),
      icon: Icons.delete_rounded,
      isDestructive: true,
    );
  }
}
