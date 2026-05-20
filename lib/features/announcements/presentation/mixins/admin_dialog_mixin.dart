import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/admin_announcement_compose_sheet.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_delete_dialog.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_dialog.dart';

/// Mixin for admin announcement dialog interactions.
///
/// Handles showing/hiding dialogs for adding, editing, deleting,
/// and viewing announcement details.
mixin AdminDialogMixin on ConsumerState<AdminAnnouncementScreen> {
  final ApiService _apiService = ApiService();

  Color getPrimaryColor();

  LinearGradient getCardGradient();

  String formatDate(String? dateString);

  String getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  );

  Future<void> openFile(String url, String fileName);

  Future<void> loadData({bool resetPage = true, bool useCache = true});

  /// Mockup #10 v3 admin compose sheet — uses the AudienceMatrix
  /// + AudienceSummaryStrip + PinScheduleToggleStack instead of the
  /// legacy single-target dropdown form.
  void showAddEditDialog({Map<String, dynamic>? announcementData}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return AdminAnnouncementComposeSheet(
          announcementData: announcementData,
          primaryColor: getPrimaryColor(),
          onSaved: () => loadData(resetPage: true, useCache: false),
        );
      },
    );
  }

  Future<void> deleteAnnouncement(Map<String, dynamic> announcementData) async {
    final languageProvider = ref.read(languageRiverpod);
    final confirmed = await AnnouncementDeleteDialog.show(
      context,
      languageProvider,
    );

    if (confirmed == true) {
      try {
        await _apiService.delete('/announcement/${announcementData['id']}');
        await loadData(resetPage: true, useCache: false);
        if (mounted) {
          SnackBarUtils.showSuccess(
            context,
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Announcement successfully deleted',
              'id': 'Pengumuman berhasil dihapus',
            }),
          );
        }
      } catch (e) {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            ref.read(languageRiverpod).getTranslatedText({
              'en': 'Failed to delete announcement: $e',
              'id': 'Gagal menghapus pengumuman: $e',
            }),
          );
        }
      }
    }
  }

  void showAnnouncementDetail(Map<String, dynamic> announcementData) {
    final languageProvider = ref.read(languageRiverpod);

    // Phase-4 surface 2: bottom sheet, not center dialog. Same
    // widget signature; the widget itself renders as a bottom-sheet
    // body now (see `AnnouncementDetailDialog`).
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => AnnouncementDetailDialog(
        announcementData: announcementData,
        primaryColor: getPrimaryColor(),
        cardGradient: getCardGradient(),
        languageProvider: languageProvider,
        formatDate: formatDate,
        getTargetText: (item) => getTargetText(item, languageProvider),
        onOpenFile: (path, fileName) => openFile(getFileUrl(path), fileName),
        onEdit: () {
          showAddEditDialog(announcementData: announcementData);
        },
        onDelete: () {
          deleteAnnouncement(announcementData);
        },
      ),
    );
  }

  String getFileUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/storage/$cleanPath';
  }
}
