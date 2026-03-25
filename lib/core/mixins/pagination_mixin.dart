/// pagination_mixin.dart - Reusable pagination logic for scrollable lists.
/// Like a Laravel trait (`HasPagination`) that can be mixed into any controller.
///
/// Replaces the pagination boilerplate duplicated in 30+ screens:
/// - ScrollController setup + listener
/// - currentPage / hasMore / isLoadingMore state
/// - Scroll position detection for infinite scroll
///
/// Usage:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with PaginationMixin {
///   @override
///   Future<void> loadPage(int page) async {
///     final result = await ApiService.getPaginated(page: page);
///     addItems(result['data']);
///     updatePagination(result['pagination']);
///   }
/// }
/// ```
library;

import 'package:flutter/material.dart';

/// Mixin providing standard pagination behavior for StatefulWidget screens.
/// Manages scroll detection, page tracking, and loading state.
mixin PaginationMixin<T extends StatefulWidget> on State<T> {
  /// Scroll controller — attach to your ListView/GridView.
  final ScrollController paginationScrollController = ScrollController();

  /// Current page number (1-based).
  int currentPage = 1;

  /// Items per page.
  int perPage = 20;

  /// Whether more pages are available.
  bool hasMoreData = true;

  /// Whether a page load is in progress.
  bool isLoadingMore = false;

  /// Pixel threshold before reaching the bottom to trigger next page load.
  double scrollThreshold = 200.0;

  /// Override this to implement your page loading logic.
  /// Called when a new page needs to be loaded.
  Future<void> loadPage(int page);

  /// Call in initState to set up the scroll listener.
  void initPagination() {
    paginationScrollController.addListener(_onScroll);
  }

  /// Call in dispose to clean up the scroll controller.
  void disposePagination() {
    paginationScrollController.removeListener(_onScroll);
    paginationScrollController.dispose();
  }

  /// Resets pagination to page 1. Call when filters change.
  void resetPagination() {
    currentPage = 1;
    hasMoreData = true;
    isLoadingMore = false;
  }

  /// Updates pagination state from a backend response's pagination metadata.
  /// Expected keys: `current_page`, `last_page` or `has_next_page`.
  void updatePaginationFromMeta(Map<String, dynamic>? meta) {
    if (meta == null) {
      hasMoreData = false;
      return;
    }

    final lastPage = meta['last_page'] ?? meta['total_pages'];
    if (lastPage != null) {
      hasMoreData = currentPage < (lastPage is int ? lastPage : int.tryParse(lastPage.toString()) ?? 1);
    } else {
      hasMoreData = meta['has_next_page'] == true;
    }
  }

  void _onScroll() {
    if (!paginationScrollController.hasClients) return;
    if (isLoadingMore || !hasMoreData) return;

    final maxScroll = paginationScrollController.position.maxScrollExtent;
    final currentScroll = paginationScrollController.position.pixels;

    if (currentScroll >= maxScroll - scrollThreshold) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (isLoadingMore || !hasMoreData) return;

    setState(() => isLoadingMore = true);

    try {
      currentPage++;
      await loadPage(currentPage);
    } finally {
      if (mounted) {
        setState(() => isLoadingMore = false);
      }
    }
  }
}
