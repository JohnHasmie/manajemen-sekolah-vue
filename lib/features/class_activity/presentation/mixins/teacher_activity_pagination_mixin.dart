import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/class_activity/data/class_activity_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityPaginationMixin
    on ConsumerState<TeacherClassActivityScreen> {
  late ScrollController _scrollController;
  late ScrollController _timelineScrollController;

  ScrollController get scrollController => _scrollController;
  ScrollController get timelineScrollController => _timelineScrollController;

  void initializeScrollControllers() {
    _scrollController = ScrollController();
    _timelineScrollController = ScrollController();
    _scrollController.addListener(onScroll);
    _timelineScrollController.addListener(onTimelineScroll);
  }

  void disposeScrollControllers() {
    _scrollController.dispose();
    _timelineScrollController.dispose();
  }

  bool _isRefreshing = false;

  void onScroll() {
    if (_isRefreshing) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData) loadMoreGroupedActivities();
    }
  }

  void onTimelineScroll() {
    if (_timelineScrollController.position.pixels >=
        _timelineScrollController.position.maxScrollExtent - 200) {
      if (!timelineLoadingMore && timelineHasMore) {
        loadMoreTimeline();
      }
    }
  }

  Future<void> refreshGroupedActivities() async {
    _isRefreshing = true;
    updateCurrentPage(1);
    updateHasMoreData(true);
    updateGroupedActivities([]);
    await fetchGroupedActivities();
    _isRefreshing = false;
  }

  Future<void> loadMoreGroupedActivities() async {
    if (isLoadingMore || !hasMoreData) return;
    updateCurrentPage(currentPage + 1);
    updateIsLoadingMore(true);
    await fetchGroupedActivities();
  }

  Future<void> fetchGroupedActivities() async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    try {
      final homeroomClassId = selectedHomeroomClass?['id']?.toString();
      final result = await getIt<ApiClassActivityService>()
          .getTeacherActivitySummary(
            teacherId: isHomeroomView ? null : teacherId,
            classId: isHomeroomView ? homeroomClassId : filterClassId,
            academicYearId: ayId,
            subjectId: filterSubjectId,
            search: searchController.text.isNotEmpty
                ? searchController.text
                : null,
            dateFilter: filterDateOption,
            page: currentPage,
            perPage: 20,
            view: isHomeroomView ? 'wali_kelas' : 'mengajar',
          );
      if (!mounted) return;
      final data = (result['data'] as List?) ?? [];
      final pagination = result['pagination'];
      setState(() {
        if (currentPage == 1) {
          updateGroupedActivities(data);
        } else {
          // In wali-kelas mode the backend groups by
          // (class, subject, teacher), so dedup must include teacher_id —
          // otherwise two teachers teaching the same (class, subject) pair
          // would be collapsed into one card during pagination merges.
          String keyOf(dynamic g) {
            final base = '${g['class_id']}__${g['subject_id']}';
            if (isHomeroomView) return '${base}__${g['teacher_id'] ?? ''}';
            return base;
          }

          final existingKeys = groupedActivities.map(keyOf).toSet();
          final newActivities = List<dynamic>.from(groupedActivities);
          for (final g in data) {
            if (!existingKeys.contains(keyOf(g))) {
              newActivities.add(g);
            }
          }
          updateGroupedActivities(newActivities);
        }
        updateHasMoreData(pagination?['has_next_page'] == true);
        updateIsLoadingMore(false);
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error fetching: $e');
      if (mounted) setState(() => updateIsLoadingMore(false));
    }
  }

  Future<void> refreshTimeline() async {
    updateTimelinePage(1);
    updateTimelineHasMore(true);
    updateTimelineActivities([]);
    await fetchTimeline();
  }

  Future<void> loadMoreTimeline() async {
    if (timelineLoadingMore || !timelineHasMore) return;
    updateTimelinePage(timelinePage + 1);
    updateTimelineLoadingMore(true);
    await fetchTimeline();
  }

  Future<void> fetchTimeline() async {
    final ayId = ref
        .read(academicYearRiverpod)
        .selectedAcademicYear?['id']
        ?.toString();
    try {
      final homeroomClassId = selectedHomeroomClass?['id']?.toString();
      final result = await getIt<ApiClassActivityService>()
          .getClassActivityPaginated(
            page: timelinePage,
            limit: 20,
            teacherId: isHomeroomView ? null : teacherId,
            classId: isHomeroomView ? homeroomClassId : filterClassId,
            subjectId: filterSubjectId,
            search: searchController.text.isNotEmpty
                ? searchController.text
                : null,
            academicYearId: ayId,
          );
      if (!mounted) return;
      final data = (result['data'] as List?) ?? [];
      final pagination = result['pagination'];
      setState(() {
        if (timelinePage == 1) {
          updateTimelineActivities(data);
        } else {
          final updated = List<dynamic>.from(timelineActivities);
          updated.addAll(data);
          updateTimelineActivities(updated);
        }
        updateTimelineHasMore(pagination?['has_next_page'] == true);
        updateTimelineLoadingMore(false);
      });
    } catch (e) {
      AppLogger.error('class_activity', 'Error fetching: $e');
      if (mounted) {
        setState(() {
          updateTimelineLoadingMore(false);
        });
      }
    }
  }

  Future<void> forceRefresh() async {
    // Clear class activity caches before refreshing
    await LocalCacheService.clearStartingWith('class_activity_');
    await LocalCacheService.clearStartingWith('tour_class_activity_');
    await LocalCacheService.clearStartingWith('activity_teacher_summary_');

    if (isTimelineView) {
      refreshTimeline();
    } else {
      refreshGroupedActivities();
    }
  }

  void onSearch() {
    isTimelineView ? refreshTimeline() : refreshGroupedActivities();
    FocusScope.of(context).unfocus();
  }

  // Getters to access mixin state
  bool get isLoadingMore;
  bool get hasMoreData;
  bool get timelineLoadingMore;
  bool get timelineHasMore;
  bool get isHomeroomView;
  bool get isTimelineView;
  int get currentPage;
  int get timelinePage;
  String get teacherId;
  String? get filterClassId;
  String? get filterSubjectId;
  String? get filterDateOption;
  Map<String, dynamic>? get selectedHomeroomClass;
  List<dynamic> get groupedActivities;
  List<dynamic> get timelineActivities;
  TextEditingController get searchController;

  void updateGroupedActivities(List activities);
  void updateCurrentPage(int page);
  void updateHasMoreData(bool value);
  void updateIsLoadingMore(bool value);
  void updateTimelineActivities(List activities);
  void updateTimelinePage(int page);
  void updateTimelineHasMore(bool value);
  void updateTimelineLoadingMore(bool value);
}
