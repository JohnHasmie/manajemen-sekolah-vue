// ListView with built-in scroll-based pagination, loading footer,
// and empty state handling.
//
// Replaces 10+ identical ScrollController + _isLoadingMore + _hasMoreData
// patterns across teacher, parent, and admin screens.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';

/// A [ListView] with automatic scroll-based pagination.
///
/// Listens for scroll events and triggers [onLoadMore] when the user
/// scrolls near the bottom. Shows a loading indicator footer when
/// additional data is being fetched.
///
/// Example:
/// ```dart
/// PaginatedListView<AttendanceGroup>(
///   items: _groupedAttendance,
///   itemBuilder: (context, item, index) => AttendanceCard(group: item),
///   onLoadMore: _loadMoreAttendance,
///   hasMore: _hasMoreData,
///   isLoadingMore: _isLoadingMore,
///   emptyState: EmptyState(title: 'No attendance records'),
/// )
/// ```
class PaginatedListView<T> extends StatefulWidget {
  /// The list of items to display.
  final List<T> items;

  /// Builder for each item in the list.
  final Widget Function(BuildContext context, T item, int index) itemBuilder;

  /// Called when the user scrolls near the bottom and more data is available.
  final Future<void> Function() onLoadMore;

  /// Whether there are more items to load.
  final bool hasMore;

  /// Whether a load-more request is currently in progress.
  final bool isLoadingMore;

  /// Widget shown when [items] is empty. If null, shows nothing.
  final Widget? emptyState;

  /// Widget shown during initial loading (before any items arrive).
  final Widget? loadingState;

  /// Whether the initial data is still loading.
  final bool isInitialLoading;

  /// Optional separator widget between items.
  final Widget? separator;

  /// Padding around the list.
  final EdgeInsets? padding;

  /// External scroll controller. If null, an internal one is created.
  final ScrollController? controller;

  /// Physics for the scroll view.
  final ScrollPhysics? physics;

  /// Distance from the bottom at which [onLoadMore] is triggered.
  /// Default: 200 pixels.
  final double loadMoreThreshold;

  /// Optional pull-to-refresh callback.
  final Future<void> Function()? onRefresh;

  /// User role for theming the refresh indicator (e.g. 'guru', 'admin',
  /// 'wali').
  final String? refreshRole;

  const PaginatedListView({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.onLoadMore,
    this.hasMore = true,
    this.isLoadingMore = false,
    this.emptyState,
    this.loadingState,
    this.isInitialLoading = false,
    this.separator,
    this.padding,
    this.controller,
    this.physics,
    this.loadMoreThreshold = 200,
    this.onRefresh,
    this.refreshRole,
  });

  @override
  State<PaginatedListView<T>> createState() => _PaginatedListViewState<T>();
}

class _PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  late ScrollController _scrollController;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      _scrollController = widget.controller!;
    } else {
      _scrollController = ScrollController();
      _ownsController = true;
    }
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant PaginatedListView<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _scrollController.removeListener(_onScroll);
      if (_ownsController) _scrollController.dispose();

      if (widget.controller != null) {
        _scrollController = widget.controller!;
        _ownsController = false;
      } else {
        _scrollController = ScrollController();
        _ownsController = true;
      }
      _scrollController.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    if (_ownsController) _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >=
        position.maxScrollExtent - widget.loadMoreThreshold) {
      if (!widget.isLoadingMore && widget.hasMore) {
        widget.onLoadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Initial loading state
    if (widget.isInitialLoading) {
      return widget.loadingState ?? const SizedBox.shrink();
    }

    // Empty state
    if (widget.items.isEmpty) {
      return widget.emptyState ?? const SizedBox.shrink();
    }

    // Total item count: items + optional loading footer
    final itemCount = widget.items.length + (widget.hasMore ? 1 : 0);

    Widget listView = ListView.separated(
      controller: _scrollController,
      physics: widget.physics ?? const AlwaysScrollableScrollPhysics(),
      padding: widget.padding ?? const EdgeInsets.fromLTRB(0, 0, 0, 80),
      itemCount: itemCount,
      separatorBuilder: (_, __) => widget.separator ?? const SizedBox.shrink(),
      itemBuilder: (context, index) {
        // Loading footer
        if (index >= widget.items.length) {
          return _buildLoadingFooter();
        }
        return widget.itemBuilder(context, widget.items[index], index);
      },
    );

    // Wrap with AppRefreshIndicator if onRefresh is provided
    if (widget.onRefresh != null) {
      listView = AppRefreshIndicator(
        onRefresh: widget.onRefresh!,
        role: widget.refreshRole,
        child: listView,
      );
    }

    return listView;
  }

  Widget _buildLoadingFooter() {
    if (!widget.isLoadingMore) {
      return const SizedBox(height: 20);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey.shade400),
          ),
        ),
      ),
    );
  }
}
