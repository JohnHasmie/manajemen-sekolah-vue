import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/teacher_class_activity_screen.dart';

mixin TeacherActivityStateMixin on ConsumerState<TeacherClassActivityScreen> {
  late bool _isLoading;
  late bool _isHomeroomView;
  late List<dynamic> _homeroomClassesList;
  late Map<String, dynamic>? _selectedHomeroomClass;
  late List<dynamic> _classList;
  late bool _isTimelineView;
  late List<dynamic> _groupedActivities;
  late List<dynamic> _schedules;
  late int _currentPage;
  late bool _hasMoreData;
  late bool _isLoadingMore;
  late List<dynamic> _timelineActivities;
  late int _timelinePage;
  late bool _timelineHasMore;
  late bool _timelineLoadingMore;
  late String? _filterClassId;
  late String? _filterSubjectId;
  late String? _filterDateOption;
  late List<dynamic> _filterSubjectList;
  late TextEditingController _searchController;
  String? _activityErrorMessage;

  bool get isLoading => _isLoading;
  bool get isHomeroomView => _isHomeroomView;
  List<dynamic> get homeroomClassesList => _homeroomClassesList;
  Map<String, dynamic>? get selectedHomeroomClass => _selectedHomeroomClass;
  List<dynamic> get classList => _classList;
  bool get isTimelineView => _isTimelineView;
  List<dynamic> get groupedActivities => _groupedActivities;
  List<dynamic> get schedules => _schedules;
  int get currentPage => _currentPage;
  bool get hasMoreData => _hasMoreData;
  bool get isLoadingMore => _isLoadingMore;
  List<dynamic> get timelineActivities => _timelineActivities;
  int get timelinePage => _timelinePage;
  bool get timelineHasMore => _timelineHasMore;
  bool get timelineLoadingMore => _timelineLoadingMore;
  String? get filterClassId => _filterClassId;
  String? get filterSubjectId => _filterSubjectId;
  String? get filterDateOption => _filterDateOption;
  List<dynamic> get filterSubjectList => _filterSubjectList;
  TextEditingController get searchController => _searchController;
  String? get activityErrorMessage => _activityErrorMessage;

  void initializeState() {
    _isLoading = true;
    _isHomeroomView = false;
    _homeroomClassesList = [];
    _selectedHomeroomClass = null;
    _classList = [];
    _isTimelineView = false;
    _groupedActivities = [];
    _schedules = [];
    _currentPage = 1;
    _hasMoreData = true;
    _isLoadingMore = false;
    _timelineActivities = [];
    _timelinePage = 1;
    _timelineHasMore = true;
    _timelineLoadingMore = false;
    _filterClassId = null;
    _filterSubjectId = null;
    _filterDateOption = null;
    _filterSubjectList = [];
    _searchController = TextEditingController();
  }

  Future<void> loadViewPreference() async {
    try {
      final c = await LocalCacheService.load('kegiatan_view_preference');
      if (c is Map && mounted) {
        setState(() => _isTimelineView = c['is_timeline'] ?? false);
      }
    } catch (_) {}
  }

  void setLoading(bool value) {
    setState(() => _isLoading = value);
  }

  void setActivityError(String? message) {
    setState(() => _activityErrorMessage = message);
  }

  void clearActivityError() {
    setState(() => _activityErrorMessage = null);
  }

  void disposeControllers() {
    _searchController.dispose();
  }

  void updateHomeroomView(bool value) {
    setState(() => _isHomeroomView = value);
  }

  void updateSelectedHomeroomClass(dynamic homeroomClass) {
    setState(() => _selectedHomeroomClass = homeroomClass);
  }

  void updateTimeline(bool value) {
    setState(() => _isTimelineView = value);
    LocalCacheService.save('kegiatan_view_preference', {
      'is_timeline': _isTimelineView,
    });
  }

  void updateClassList(List classes) {
    setState(() => _classList = classes);
  }

  void updateGroupedActivities(List activities) {
    setState(() => _groupedActivities = activities);
  }

  void updateSchedules(List schedules) {
    setState(() => _schedules = schedules);
  }

  void updateHomeroomClassList(List classes) {
    setState(() => _homeroomClassesList = classes);
  }

  void updateCurrentPage(int page) {
    setState(() => _currentPage = page);
  }

  void updateHasMoreData(bool value) {
    setState(() => _hasMoreData = value);
  }

  void updateIsLoadingMore(bool value) {
    setState(() => _isLoadingMore = value);
  }

  void updateTimelineActivities(List activities) {
    setState(() => _timelineActivities = activities);
  }

  void updateTimelinePage(int page) {
    setState(() => _timelinePage = page);
  }

  void updateTimelineHasMore(bool value) {
    setState(() => _timelineHasMore = value);
  }

  void updateTimelineLoadingMore(bool value) {
    setState(() => _timelineLoadingMore = value);
  }

  void updateFilters({
    String? classId,
    String? subjectId,
    String? dateOption,
    List<dynamic>? subjectList,
  }) {
    setState(() {
      if (classId != null) _filterClassId = classId;
      if (subjectId != null) _filterSubjectId = subjectId;
      if (dateOption != null) _filterDateOption = dateOption;
      if (subjectList != null) _filterSubjectList = subjectList;
    });
  }

  void clearFilters() {
    setState(() {
      _filterClassId = null;
      _filterSubjectId = null;
      _filterDateOption = null;
      _filterSubjectList = [];
    });
  }

  bool get hasActiveFilter =>
      _filterClassId != null ||
      _filterSubjectId != null ||
      _filterDateOption != null;
}
