// Parent view of class activities (teaching journal entries).
// Like `pages/parent/ClassActivity.vue` in a Vue app.
//
// Read-only view of class activities for the parent's children.
// Supports student selector (for parents with multiple kids),
// auto-marking activities as read when scrolled into view, and caching.
// In Laravel terms: `ClassActivityController@parentIndex`.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_data_loading_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_tour_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_list_builder_mixin.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/parent_class_activity_header.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/parent_student_selector.dart';

/// Parent's read-only view of class activities with read tracking.
///
/// Uses the same debounced visibility-based "mark as read" pattern as
/// [AnnouncementScreen]. Props: optional [academicYearId].
class ParentClassActivityScreen extends ConsumerStatefulWidget {
  final String? academicYearId;

  const ParentClassActivityScreen({super.key, this.academicYearId});

  @override
  ParentClassActivityScreenState createState() =>
      ParentClassActivityScreenState();
}

/// State for [ParentClassActivityScreen].
///
/// Like a Vue page component with `data() { return {...} }`.
/// Key state: activity list, student selector, visibility tracking for
/// auto-marking read items. Uses the same pattern as announcements.
class ParentClassActivityScreenState
    extends ConsumerState<ParentClassActivityScreen>
    with
        ParentActivityDataLoadingMixin,
        ParentActivityReadTrackingMixin,
        ParentActivityTourMixin,
        ParentActivityUIBuilderMixin,
        ParentActivityListBuilderMixin {
  // State
  List<dynamic> _activityList = [];
  final List<dynamic> _studentList = [];
  String? _selectedStudentId;
  final String _parentName = '';
  final bool _isLoading = true;
  bool _hasFreshData = false;

  final GlobalKey _studentSelectorKey = GlobalKey();
  final GlobalKey _activityListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> _processedIds = {};
  final Set<String> _pendingReadIds = {};
  Timer? _markReadDebounce;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    _markReadDebounce?.cancel();
    if (_pendingReadIds.isNotEmpty) {
      flushMarkReadSilently(List.from(_pendingReadIds));
      _pendingReadIds.clear();
    }
    super.dispose();
  }

  String get _studentsCacheKey =>
      'parent_activity_students_'
      '${widget.academicYearId ?? 'default'}';

  String buildActivitiesCacheKey() {
    return 'parent_activity_list_${_selectedStudentId}_'
        '${widget.academicYearId ?? 'default'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ParentClassActivityHeader(
            parentName: _parentName,
            studentCount: _studentList.length,
            gradient: getCardGradient(),
            primaryColor: getPrimaryColor(),
            onRefresh: forceRefresh,
          ),
          ParentStudentSelector(
            studentList: _studentList,
            selectedStudentId: _selectedStudentId,
            selectorKey: _studentSelectorKey,
            onStudentChanged: (value) {
              setState(() {
                _selectedStudentId = value;
                _activityList = [];
                _hasFreshData = false;
              });
              loadActivities();
            },
          ),
          Expanded(child: buildActivityList()),
        ],
      ),
    );
  }
}
