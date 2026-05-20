import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_detail_sheet.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for UI interactions like detail dialogs and filtering.
///
/// Requires the mixing class to also implement [FileOperationsMixin]
/// for the [openFile] method.
mixin UiInteractionMixin on ConsumerState<ParentAnnouncementScreen> {
  TextEditingController get searchController;

  List<dynamic> get announcementList;

  Color getPrimaryColor();

  LinearGradient getCardGradient();

  Future<void> flushPendingReads();

  String formatDate(String? dateString);

  String getTargetText(
    Map<String, dynamic> announcementData,
    LanguageProvider languageProvider,
  );

  /// Opens a file - must be provided by [FileOperationsMixin].
  Future<void> openFile(String url, String fileName);

  List<dynamic> getFilteredAnnouncement() {
    if (searchController.text.isEmpty) {
      return announcementList;
    }

    final searchLower = searchController.text.toLowerCase();
    return announcementList.where((p) {
      final model = Announcement.fromJson(p as Map<String, dynamic>);
      final title = model.title.toLowerCase();
      final content = model.content.toLowerCase();
      final creatorName = p['pembuat_nama']?.toString().toLowerCase() ?? '';
      return title.contains(searchLower) ||
          content.contains(searchLower) ||
          creatorName.contains(searchLower);
    }).toList();
  }

  Future<void> popWithFlush(BuildContext context) async {
    await flushPendingReads();
    if (context.mounted) AppNavigator.pop(context);
  }

  void showAnnouncementDetail(Map<String, dynamic> announcementData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AnnouncementDetailSheet(
        announcementData: announcementData,
        primaryColor: getPrimaryColor(),
        // Parent context — surface personal reminder picker + list
        // inside the event hero. Same sheet, different reminder block.
        viewerRole: 'parent',
      ),
    );
  }
}
