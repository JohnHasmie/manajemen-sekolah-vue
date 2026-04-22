import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/admin_announcement_screen.dart';

/// Mixin for managing core announcement state and lifecycle.
mixin AnnouncementStateMixin on ConsumerState<AdminAnnouncementScreen> {
  // Announcement data
  List<dynamic> announcements = [];
  bool isLoading = true;
  String? errorMessage;

  // Search and filter
  late TextEditingController searchController;
  String? selectedPriorityFilter;
  String? selectedTargetFilter;
  String? selectedStatusFilter;
  bool hasActiveFilter = false;
  Timer? searchDebounce;

  // Read tracking
  final Set<String> processedIds = {};
  final Set<String> pendingReadIds = {};
  Timer? markReadDebounce;

  /// Initialize state controllers and listeners.
  void initializeState() {
    searchController = TextEditingController();
    searchController.addListener(onSearchChanged);
  }

  /// Clean up resources.
  void cleanupState() {
    searchController.removeListener(onSearchChanged);
    searchController.dispose();
    searchDebounce?.cancel();
    markReadDebounce?.cancel();
  }

  /// Handle search text changes.
  void onSearchChanged() {
    // Placeholder for debounced search
  }
}
