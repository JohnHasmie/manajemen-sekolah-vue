import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';

/// Handles tab switching and scroll-based pagination.
mixin EmbeddedActivityScrollMixin on ConsumerState<EmbeddedActivityListScreen> {
  // Abstract declarations for fields from state class
  TabController get tabController;

  String? get currentTarget;
  set currentTarget(String? value);

  ScrollController get scrollController;

  bool get isLoadingMore;
  bool get hasMoreData;

  // Abstract methods
  void resetAndLoadActivities();
  Future<void> loadMoreActivities();

  void handleTabSelection() {
    if (tabController.indexIsChanging) return;
    setState(() {
      currentTarget = tabController.index == 0 ? 'umum' : 'khusus';
    });
    resetAndLoadActivities();
  }

  bool get isLoading;

  void onScroll() {
    if (isLoading) return;
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData) {
        loadMoreActivities();
      }
    }
  }
}
