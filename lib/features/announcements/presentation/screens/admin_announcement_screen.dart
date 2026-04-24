/// Admin announcement management screen - CRUD for school announcements.
///
/// Like `pages/admin/announcements.vue` - manages school-wide announcements
/// with create, read, update, delete operations. Supports file attachments,
/// priority levels, target audience filtering, and infinite scroll pagination.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/mixins/pagination_mixin.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_state_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_ui_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_filter_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_data_loading_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_dialog_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_file_operations_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/admin_tour_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_screen_header.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_list_content.dart';

/// Admin announcement management screen.
///
/// This is a [ConsumerStatefulWidget] - like a Vue page component.
class AdminAnnouncementScreen extends ConsumerStatefulWidget {
  /// Optional status filter seeded before the first build.
  ///
  /// Set when the admin dashboard's PendingInboxCard drills into "Draft
  /// pengumuman" — e.g., `'draft'` so the list lands pre-scoped instead of
  /// forcing the user to open the filter sheet. Mirrors the announcement
  /// `status` column on the backend (`draft`, `published`, `archived`).
  final String? initialStatusFilter;

  const AdminAnnouncementScreen({super.key, this.initialStatusFilter});

  @override
  AdminAnnouncementScreenState createState() => AdminAnnouncementScreenState();
}

/// The mutable state for [AdminAnnouncementScreen].
///
/// Combines multiple mixins for different concerns:
/// - [PaginationMixin]: Infinite scroll pagination
/// - [AnnouncementStateMixin]: Core state & search controller
/// - [AnnouncementUiMixin]: Color & formatting utilities
/// - [AdminReadTrackingMixin]: Auto-mark-as-read debouncing
/// - [AdminFilterMixin]: Filter state & operations
/// - [AdminDataLoadingMixin]: Data fetching & caching
/// - [AdminDialogMixin]: Dialog interactions (add/edit/delete/detail)
/// - [AdminFileOperationsMixin]: File download & open
/// - [AdminTourMixin]: Onboarding tour logic
class AdminAnnouncementScreenState
    extends ConsumerState<AdminAnnouncementScreen>
    with
        PaginationMixin,
        AnnouncementStateMixin,
        AnnouncementUiMixin,
        AdminReadTrackingMixin,
        AdminFilterMixin,
        AdminDataLoadingMixin,
        AdminDialogMixin,
        AdminFileOperationsMixin,
        AdminTourMixin {
  final GlobalKey _addKey = GlobalKey();
  final GlobalKey _searchKey = GlobalKey();
  final GlobalKey _filterKey = GlobalKey();

  @override
  GlobalKey? get addKey => _addKey;

  @override
  GlobalKey? get searchKey => _searchKey;

  @override
  GlobalKey? get filterKey => _filterKey;

  @override
  void initState() {
    super.initState();
    perPage = 10;
    initPagination();
    initializeState();

    // Seed the status filter before loadData() so the first API request
    // already has the scope applied — avoids a flash of unfiltered content
    // when deep-linked from the admin dashboard inbox.
    final seed = widget.initialStatusFilter;
    if (seed != null && seed.isNotEmpty) {
      selectedStatusFilter = seed;
      hasActiveFilter = true;
    }

    loadFilterOptions();
    loadData();
  }

  @override
  void dispose() {
    disposePagination();
    cleanupState();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          AnnouncementScreenHeader(
            languageProvider: languageProvider,
            primaryColor: getPrimaryColor(),
            cardGradient: getCardGradient(),
            searchController: searchController,
            searchKey: _searchKey,
            filterKey: _filterKey,
            hasActiveFilter: hasActiveFilter,
            filterChips: buildFilterChips(languageProvider),
            onBack: () => AppNavigator.pop(context),
            onRefresh: forceRefresh,
            onFilterTap: showFilterSheet,
            onSearch: handleSearch,
            onClearAllFilters: clearAllFilters,
          ),
          Expanded(
            child: AnnouncementListContent(
              isLoading: isLoading,
              errorMessage: errorMessage,
              announcements: announcements,
              isLoadingMore: isLoadingMore,
              hasMoreData: hasMoreData,
              primaryColor: getPrimaryColor(),
              scrollController: paginationScrollController,
              languageProvider: languageProvider,
              searchText: searchController.text,
              onRetry: loadData,
              onCreateTap: showAddEditDialog,
              onItemVisible: onItemVisible,
              formatDate: formatDate,
              getTargetText: (item) => getTargetText(item, languageProvider),
              importantLabel: languageProvider.getTranslatedText({
                'en': 'Important',
                'id': 'Penting',
              }),
              onItemTap: showAnnouncementDetail,
              onItemEdit: (item) => showAddEditDialog(announcementData: item),
              onItemDelete: deleteAnnouncement,
              onRefresh: loadData,
              onLoadMore: () => loadPage(currentPage + 1),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        key: _addKey,
        onPressed: showAddEditDialog,
        backgroundColor: getPrimaryColor(),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}
