// Paginated list body for the admin announcement screen.
// Handles loading/error/empty/data states and renders AnnouncementCard rows.
// Like a Vue <AnnouncementListContent> component — stateless, driven entirely by props and callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/error_screen.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';
import 'package:manajemensekolah/core/widgets/paginated_list_view.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_card.dart';

/// Scrollable content area for [AdminAnnouncementScreen].
///
/// In Vue terms this maps to `<AnnouncementListContent>` — it receives the
/// current data/loading/error state as props and emits events via callbacks.
/// The four possible states mirror a Vue `v-if/v-else-if` chain:
///   loading → skeleton · error → ErrorScreen · empty → EmptyState · data → PaginatedListView.
class AnnouncementListContent extends StatelessWidget {
  /// Whether the initial page is still loading (shows skeleton loader).
  final bool isLoading;

  /// Non-null when the initial fetch failed and no cached items exist.
  final String? errorMessage;

  /// Current list of announcement maps from the API / cache.
  final List<dynamic> announcements;

  /// Whether the pagination mixin is currently fetching the next page.
  final bool isLoadingMore;

  /// Whether there are more pages to load.
  final bool hasMoreData;

  /// Primary brand color for this role (admin).
  final Color primaryColor;

  /// Scroll controller from [PaginationMixin] — drives infinite-scroll detection.
  final ScrollController scrollController;

  /// Active language/translation provider.
  final LanguageProvider languageProvider;

  /// Text currently in the search field — used to pick the right empty-state copy.
  final String searchText;

  /// Called when [ErrorScreen] retry button is tapped.
  final VoidCallback onRetry;

  /// Called when the empty-state "Create Announcement" button is tapped.
  final VoidCallback onCreateTap;

  /// Called each time an item scrolls into view (triggers auto-mark-as-read).
  final void Function(Map<String, dynamic>) onItemVisible;

  /// Pre-computes the formatted date string for a single item (parent provides).
  final String Function(String?) formatDate;

  /// Pre-computes the human-readable target-audience string for a single item.
  final String Function(Map<String, dynamic>) getTargetText;

  /// Translated label for the "Important" priority badge.
  final String importantLabel;

  /// Called when the card body is tapped — opens the detail dialog.
  final void Function(Map<String, dynamic>) onItemTap;

  /// Called when the edit icon is tapped — opens the edit form sheet.
  final void Function(Map<String, dynamic>) onItemEdit;

  /// Called when the delete icon is tapped — shows the confirmation dialog.
  final void Function(Map<String, dynamic>) onItemDelete;

  /// Called when the list is pulled down to refresh.
  final Future<void> Function() onRefresh;

  /// Called when scrolling near the bottom to load more items.
  final Future<void> Function() onLoadMore;

  const AnnouncementListContent({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.announcements,
    required this.isLoadingMore,
    required this.hasMoreData,
    required this.primaryColor,
    required this.scrollController,
    required this.languageProvider,
    required this.searchText,
    required this.onRetry,
    required this.onCreateTap,
    required this.onItemVisible,
    required this.formatDate,
    required this.getTargetText,
    required this.importantLabel,
    required this.onItemTap,
    required this.onItemEdit,
    required this.onItemDelete,
    required this.onRefresh,
    required this.onLoadMore,
  });

  @override
  Widget build(BuildContext context) {
    // Error with no cached data → show full-screen error with retry button
    if (errorMessage != null) {
      return ErrorScreen(errorMessage: errorMessage!, onRetry: onRetry);
    }

    return PaginatedListView<Map<String, dynamic>>(
      items: announcements.cast<Map<String, dynamic>>(),
      itemBuilder: (context, item, index) {
        // Notify parent so it can batch-mark the item as read
        onItemVisible(item);

        return AnnouncementCard(
          announcementData: item,
          primaryColor: primaryColor,
          formattedDate: formatDate(item['created_at'] as String?),
          targetText: getTargetText(item),
          importantLabel: importantLabel,
          onTap: () => onItemTap(item),
          onEdit: () => onItemEdit(item),
          onDelete: () => onItemDelete(item),
        );
      },
      onLoadMore: onLoadMore,
      hasMore: hasMoreData,
      isLoadingMore: isLoadingMore,
      isInitialLoading: isLoading && announcements.isEmpty,
      loadingState: const SkeletonListLoading(
        padding: EdgeInsets.only(top: 8, bottom: 80),
      ),
      emptyState: EmptyState(
        icon: Icons.announcement_outlined,
        title: languageProvider.getTranslatedText({
          'en': 'No Announcements',
          'id': 'Tidak Ada Pengumuman',
        }),
        subtitle: languageProvider.getTranslatedText({
          'en': searchText.isNotEmpty
              ? 'No announcements found for your search'
              : 'Start creating announcements to share information',
          'id': searchText.isNotEmpty
              ? 'Tidak ada pengumuman yang sesuai dengan pencarian'
              : 'Mulai buat pengumuman untuk berbagi informasi',
        }),
        buttonText: languageProvider.getTranslatedText({
          'en': 'Create Announcement',
          'id': 'Buat Pengumuman',
        }),
        onPressed: onCreateTap,
      ),
      controller: scrollController,
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      onRefresh: onRefresh,
    );
  }
}
