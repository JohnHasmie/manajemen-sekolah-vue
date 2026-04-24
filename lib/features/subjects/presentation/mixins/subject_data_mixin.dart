import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/services/fcm_service.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/controllers/admin_subject_controller.dart';
import 'package:manajemensekolah/features/subjects/'
    'presentation/screens/admin_subject_management_screen.dart';

/// Mixin handling subject data loading, caching, and pagination.
mixin SubjectDataMixin on ConsumerState<AdminSubjectManagementScreen> {
  late ScrollController scrollController;
  late TextEditingController searchController;

  int currentPage = 1;
  final int perPage = 10;
  bool hasMoreData = true;
  bool isLoadingMore = false;
  List<dynamic> subjectList = [];
  List<String> availableClassNames = [];
  List<String> availableGradeLevels = [];
  List<dynamic> availableMasterSubjects = [];

  Timer? searchDebounce;

  Future<void> initializeDataLoading() async {
    if (!mounted) return;
    await loadFilterOptions();
    await loadMasterSubjects();
    await loadSubjects();
    if (mounted) {
      FCMService().syncTrigger.addListener(onSyncTriggered);
    }
  }

  void disposeDataLoading() {
    scrollController.dispose();
    searchController.dispose();
    searchDebounce?.cancel();
    FCMService().syncTrigger.removeListener(onSyncTriggered);
  }

  void onSyncTriggered() {
    if (FCMService().syncTrigger.value?['type'] == 'refresh_subjects') {
      AppLogger.debug('subject', 'Refreshing subjects due to FCM sync trigger');
      loadSubjects(resetPage: true, useCache: false);
    }
  }

  Future<void> loadFilterOptions() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.loadFilterOptions();
  }

  Future<void> loadMasterSubjects() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    final data = await ctrl.loadMasterSubjects();
    if (mounted) {
      setState(() {
        availableMasterSubjects = data;
      });
    }
  }

  Future<void> loadSubjects({
    bool resetPage = true,
    bool useCache = true,
  }) async {
    final ctrl = ref.read(adminSubjectControllerProvider);

    if (resetPage) {
      currentPage = 1;
      hasMoreData = true;
      if (subjectList.isEmpty && mounted) {
        setState(() {
          isLoading = true;
          errorMessage = '';
        });
      }
    }

    final result = await ctrl.loadSubjects(
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchController.text,
      perPage: perPage,
      useCache: useCache,
    );

    if (!mounted) return;
    _handleLoadSubjectsResult(result);
  }

  void _handleLoadSubjectsResult(dynamic result) {
    if (result.errorMessage != null && result.subjects.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = result.errorMessage!;
      });
    } else {
      setState(() {
        subjectList = result.subjects;
        hasMoreData = result.hasMoreData;
        isLoading = false;
        errorMessage = '';
        availableClassNames = result.availableClassNames;
        availableGradeLevels = result.availableGradeLevels;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        checkAndShowTour();
      }
    });
  }

  Future<void> loadMoreSubjects() async {
    if (isLoadingMore || !hasMoreData) return;

    setState(() {
      isLoadingMore = true;
    });

    final ctrl = ref.read(adminSubjectControllerProvider);
    final nextPage = currentPage + 1;

    final result = await ctrl.loadMoreSubjects(
      nextPage: nextPage,
      perPage: perPage,
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      searchText: searchController.text,
      existingClassNames: availableClassNames,
      existingGradeLevels: availableGradeLevels,
    );

    if (!mounted) return;
    _handleLoadMoreResult(result, nextPage);
  }

  void _handleLoadMoreResult(dynamic result, int nextPage) {
    if (result.errorMessage != null) {
      AppLogger.error(
        'subject',
        'Error loading more data: '
            '${result.errorMessage}',
      );
      setState(() {
        isLoadingMore = false;
      });
    } else {
      setState(() {
        currentPage = nextPage;
        subjectList.addAll(result.additionalSubjects);
        availableClassNames = result.availableClassNames;
        availableGradeLevels = result.availableGradeLevels;
        hasMoreData = result.hasMoreData;
        isLoadingMore = false;
      });

      AppLogger.info(
        'subject',
        'Loaded more subjects: Page $currentPage, '
            'Total: ${subjectList.length}',
      );
    }
  }

  Future<void> forceRefresh() async {
    final ctrl = ref.read(adminSubjectControllerProvider);
    await ctrl.invalidateSubjectCache(
      selectedStatusFilter: selectedStatusFilter,
      selectedGradeLevelFilter: selectedGradeLevelFilter,
      selectedClassesStatusFilter: selectedClassesStatusFilter,
      selectedClassNameFilter: selectedClassNameFilter,
      searchText: searchController.text,
    );
    await loadSubjects(resetPage: true, useCache: false);
  }

  // Abstract getters/setters for filter state
  String? get selectedStatusFilter;
  String? get selectedClassesStatusFilter;
  String? get selectedGradeLevelFilter;
  String? get selectedClassNameFilter;
  bool get isLoading;
  String get errorMessage;

  set isLoading(bool value);
  set errorMessage(String value);

  // Abstract method
  Future<void> checkAndShowTour();
}
