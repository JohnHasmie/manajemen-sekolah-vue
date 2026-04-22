import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/dashboard/presentation/providers/academic_year_provider.dart';
import 'package:manajemensekolah/features/schedule/presentation/screens/admin_schedule_management_screen.dart';

/// Mixin for lifecycle and event handler management.
///
/// Owns initialization, disposal, and all event listeners including:
/// - FCM sync triggers
/// - Academic year provider changes
/// - Scroll controller listeners
mixin AdminScheduleEventsMixin
    on ConsumerState<TeachingScheduleManagementScreen> {
  late ScrollController _scrollController;
  AcademicYearProvider? _academicYearProvider;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _academicYearProvider = ref.read(academicYearRiverpod);

    if (_academicYearProvider?.selectedAcademicYear != null) {
      updateSelectedAcademicYear(
        _academicYearProvider!.selectedAcademicYear!['id'].toString(),
      );
    } else {
      setDefaultAcademicPeriod();
    }

    _academicYearProvider?.addListener(_onAcademicYearProviderChanged);
    loadCachedScheduleData();
    loadFilterOptions();
    loadData(
      resetPage: true,
      useCache: true,
      searchText: '',
      showTableView: false,
    );
    FCMService().syncTrigger.addListener(_onSyncTriggered);
  }

  /// Handle FCM sync triggers.
  void _onSyncTriggered() {
    if (FCMService().syncTrigger.value?['type'] == 'refresh_schedules' &&
        mounted) {
      AppLogger.debug('schedule', 'Sync triggered: refresh_schedules');
      loadData(
        resetPage: true,
        useCache: false,
        searchText: searchController.text,
        showTableView: showTableView,
      );
    }
  }

  /// Handle academic year provider changes.
  void _onAcademicYearProviderChanged() {
    if (mounted && _academicYearProvider?.selectedAcademicYear != null) {
      setState(
        () => updateSelectedAcademicYear(
          _academicYearProvider!.selectedAcademicYear!['id'].toString(),
        ),
      );
      loadFilterOptions();
      loadData(
        resetPage: true,
        useCache: true,
        searchText: searchController.text,
        showTableView: showTableView,
      );
    }
  }

  /// Handle scroll to load more data.
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !isLoadingMore &&
        hasMoreData &&
        !isLoading) {
      loadMoreData(searchText: searchController.text);
    }
  }

  @override
  void dispose() {
    FCMService().syncTrigger.removeListener(_onSyncTriggered);
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _academicYearProvider?.removeListener(_onAcademicYearProviderChanged);
    super.dispose();
  }

  /// Accessor for scroll controller.
  ScrollController get scrollController => _scrollController;

  /// Methods that must be implemented or available in state.
  TextEditingController get searchController;
  bool get showTableView;
  bool get isLoading;
  bool get isLoadingMore;
  bool get hasMoreData;

  void updateSelectedAcademicYear(String v);
  Future<void> loadCachedScheduleData();
  Future<void> loadFilterOptions();
  Future<void> loadData({
    bool resetPage,
    bool useCache,
    required String searchText,
    required bool showTableView,
  });
  Future<void> loadMoreData({required String searchText});
  void setDefaultAcademicPeriod();
}
