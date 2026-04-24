// Shared async-state wrapper for teacher list pages.
//
// Why this exists
// ---------------
// Every teacher list page (Nilai, Rekap, Materi, Kegiatan, Presensi,
// Jadwal) renders the same 4-state machine:
//   loading  → skeleton
//   error    → AppErrorState with retry
//   empty    → EmptyState (with optional CTA)
//   content  → the actual list, wrapped in pull-to-refresh
//
// Each page was repeating ~50–80 lines of conditional tree + refresh wiring.
// This widget encapsulates it so pages only have to declare their state
// flags and a content builder. Callers can still opt out of any of the
// sub-states by providing their own widget overrides.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/app_error_state.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/core/widgets/empty_state.dart';
import 'package:manajemensekolah/core/widgets/skeleton_loading.dart';

/// A 4-state async view for teacher list pages.
///
/// Flow:
/// 1. If [isLoading] and no data has arrived yet → show [loadingBuilder] (or
///    the default skeleton loader).
/// 2. Else if [errorMessage] is not null → show [AppErrorState] with retry.
/// 3. Else if [isEmpty] → show [EmptyState] with the configured copy/CTA.
/// 4. Else → wrap [childBuilder] in an [AppRefreshIndicator] bound to
///    [onRefresh].
///
/// Example:
/// ```dart
/// TeacherAsyncView(
///   isLoading: _isLoading,
///   errorMessage: _error,
///   isEmpty: _items.isEmpty,
///   onRefresh: () => _load(useCache: false),
///   role: 'guru',
///   emptyTitle: 'Belum ada data',
///   emptySubtitle: 'Tarik ke bawah untuk memuat ulang',
///   emptyIcon: Icons.inbox_outlined,
///   childBuilder: () => ListView(...),
/// )
/// ```
class TeacherAsyncView extends StatelessWidget {
  /// Whether the initial fetch is in flight. While true (and no data yet),
  /// a skeleton loader is shown instead of the child.
  final bool isLoading;

  /// Error message to surface, if any. Presence of a message overrides the
  /// empty state — the retry button calls [onRefresh].
  final String? errorMessage;

  /// Whether the content set is empty. Only consulted when [isLoading] is
  /// false and [errorMessage] is null.
  final bool isEmpty;

  /// Pull-to-refresh callback. Also wired to the error-state retry button.
  final Future<void> Function() onRefresh;

  /// Builder for the main content (typically a scrollable list). The
  /// [AppRefreshIndicator] wraps whatever this returns.
  final Widget Function() childBuilder;

  /// Role key (e.g., 'guru', 'admin') used to theme the refresh indicator
  /// and the error-state retry button.
  final String? role;

  // ── Empty state ──

  /// Copy for the [EmptyState] title.
  final String emptyTitle;

  /// Copy for the [EmptyState] subtitle.
  final String emptySubtitle;

  /// Icon for the [EmptyState].
  final IconData emptyIcon;

  /// Optional CTA label shown on the empty state.
  final String? emptyActionLabel;

  /// Optional CTA callback shown on the empty state.
  final VoidCallback? onEmptyAction;

  // ── Overrides (opt-in) ──

  /// Override the default skeleton loader. Useful when a custom shimmer
  /// layout better matches the final content shape.
  final Widget Function()? loadingBuilder;

  /// Override the default empty state.
  final Widget Function()? emptyBuilder;

  /// Override the default error state.
  final Widget Function(String? message)? errorBuilder;

  /// Skeleton item count when using the default loader.
  final int skeletonItemCount;

  const TeacherAsyncView({
    super.key,
    required this.isLoading,
    required this.errorMessage,
    required this.isEmpty,
    required this.onRefresh,
    required this.childBuilder,
    this.role,
    this.emptyTitle = 'Belum ada data',
    this.emptySubtitle = 'Tarik ke bawah untuk memuat ulang',
    this.emptyIcon = Icons.inbox_outlined,
    this.emptyActionLabel,
    this.onEmptyAction,
    this.loadingBuilder,
    this.emptyBuilder,
    this.errorBuilder,
    this.skeletonItemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && isEmpty && errorMessage == null) {
      return loadingBuilder?.call() ?? _defaultSkeleton();
    }

    if (errorMessage != null) {
      return errorBuilder?.call(errorMessage) ??
          AppErrorState(message: errorMessage, onRetry: onRefresh, role: role);
    }

    if (isEmpty) {
      // Wrap the empty state in a pull-to-refresh so users can still force a
      // reload without any data on screen.
      return AppRefreshIndicator(
        onRefresh: onRefresh,
        role: role,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: SizedBox(
              height: constraints.maxHeight,
              child:
                  emptyBuilder?.call() ??
                  EmptyState(
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                    icon: emptyIcon,
                    buttonText: emptyActionLabel,
                    onPressed: onEmptyAction,
                  ),
            ),
          ),
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: onRefresh,
      role: role,
      child: childBuilder(),
    );
  }

  Widget _defaultSkeleton() {
    return SkeletonListLoading(
      itemCount: skeletonItemCount,
      infoTagCount: 2,
      showActions: false,
    );
  }
}
