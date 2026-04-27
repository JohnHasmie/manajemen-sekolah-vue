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
  List<dynamic> activityList = [];
  final List<dynamic> studentList = [];
  String? selectedStudentId;
  final String parentName = '';
  bool isLoading = true;
  bool hasFreshData = false;

  final GlobalKey studentSelectorKey = GlobalKey();
  final GlobalKey activityListKey = GlobalKey();

  // Visibility Tracking
  final Set<String> processedIds = {};
  final Set<String> pendingReadIds = {};
  Timer? markReadDebounce;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  @override
  void dispose() {
    markReadDebounce?.cancel();
    if (pendingReadIds.isNotEmpty) {
      flushMarkReadSilently(List.from(pendingReadIds));
      pendingReadIds.clear();
    }
    super.dispose();
  }

  String get studentsCacheKey =>
      'parent_activity_students_'
      '${widget.academicYearId ?? 'default'}';

  String buildActivitiesCacheKey() {
    return 'parent_activity_list_${selectedStudentId}_'
        '${widget.academicYearId ?? 'default'}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          ParentClassActivityHeader(
            parentName: parentName,
            studentCount: studentList.length,
            gradient: getCardGradient(),
            primaryColor: getPrimaryColor(),
            onRefresh: forceRefresh,
          ),
          ParentStudentSelector(
            studentList: studentList,
            selectedStudentId: selectedStudentId,
            selectorKey: studentSelectorKey,
            onStudentChanged: (value) {
              setState(() {
                selectedStudentId = value;
                activityList = [];
                hasFreshData = false;
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
