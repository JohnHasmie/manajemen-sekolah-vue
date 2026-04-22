import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for content state UI (loading, error, empty, list).
mixin ContentStateMixin on ConsumerState<ParentAnnouncementScreen> {
  bool get isLoading;

  String? get errorMessage;

  Future<void> forceRefresh();

  Color getPrimaryColor();

  List<dynamic> get filteredAnnouncement;

  TextEditingController get searchController;

  GlobalKey? get listKey;

  void onItemVisible(Map<String, dynamic> announcement);

  Widget buildAnnouncementCard(
    Map<String, dynamic> announcementData,
    int index,
    void Function(Map<String, dynamic>) onTap,
  );

  void showAnnouncementDetail(Map<String, dynamic> announcementData);

  Widget buildContent(LanguageProvider languageProvider) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (errorMessage != null) {
      return _buildErrorState();
    }

    if (filteredAnnouncement.isEmpty) {
      return _buildEmptyState(languageProvider);
    }

    return _buildListContent();
  }

  Widget _buildLoadingState() {
    return SkeletonListLoading(
      itemCount: 6,
      infoTagCount: 3,
      baseColor: getPrimaryColor().withValues(alpha: 0.15),
      highlightColor: getPrimaryColor().withValues(alpha: 0.05),
    );
  }

  Widget _buildErrorState() {
    return ErrorScreen(errorMessage: errorMessage!, onRetry: forceRefresh);
  }

  Widget _buildEmptyState(LanguageProvider languageProvider) {
    return EmptyState(
      icon: Icons.announcement_outlined,
      title: languageProvider.getTranslatedText({
        'en': 'No Announcements',
        'id': 'Tidak Ada Pengumuman',
      }),
      subtitle: languageProvider.getTranslatedText({
        'en': searchController.text.isNotEmpty
            ? 'No results'
            : 'No announcements',
        'id': searchController.text.isNotEmpty
            ? 'Tidak ada hasil'
            : 'Tidak ada pengumuman',
      }),
      buttonText: languageProvider.getTranslatedText({
        'en': 'Refresh',
        'id': 'Muat Ulang',
      }),
      onPressed: forceRefresh,
    );
  }

  Widget _buildListContent() {
    return RefreshIndicator(
      onRefresh: forceRefresh,
      color: getPrimaryColor(),
      backgroundColor: Colors.white,
      child: ListView.builder(
        key: listKey,
        padding: const EdgeInsets.only(top: 8, bottom: 16),
        itemCount: filteredAnnouncement.length,
        itemBuilder: (context, index) {
          return Builder(
            builder: (context) {
              onItemVisible(filteredAnnouncement[index]);
              return buildAnnouncementCard(
                filteredAnnouncement[index],
                index,
                showAnnouncementDetail,
              );
            },
          );
        },
      ),
    );
  }
}
