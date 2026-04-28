// Parent view of class activities — Phase 3 brand-aligned redesign.
//
// The data layer (5 mixins: data loading / read tracking / tour / UI
// builder / list builder) is unchanged. Only the screen's `build()`
// presentation moved over to the canonical Phase-3 stack:
//
//   • BrandPageHeader (role 'wali') with the kicker-subtitle pattern,
//     a tune-icon action that opens the (currently no-op) filter sheet,
//     a BrandRealtimePill, and a ChildSelectorChipRow as the
//     childSelector slot.
//   • Body wrapped in RefreshIndicator so the manual "Refresh data"
//     overflow item from the old header is gone.
//
// Replaces the old `ParentClassActivityHeader` + `ParentStudentSelector`
// pair (both now orphan widgets) with the shared widgets that every
// other parent deep-tab screen uses, so brand changes flow through one
// codepath instead of five.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider, Consumer;

import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_header.dart';
import 'package:manajemensekolah/core/widgets/brand_realtime_pill.dart';
import 'package:manajemensekolah/core/widgets/child_selector_chip_row.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_data_loading_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_list_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_read_tracking_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_tour_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/parent_activity_ui_builder_mixin.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

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
/// Key state: activity list, child selector, visibility tracking for
/// auto-marking read items.
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

  // Drives the realtime pill — bumped after every successful refresh.
  DateTime _lastSync = DateTime.now();

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
    final lang = ref.watch(languageRiverpod);
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          _buildHeader(lang),
          Expanded(
            child: RefreshIndicator(
              color: ColorUtils.brandAzureDeep,
              onRefresh: () async {
                await forceRefresh();
                if (mounted) setState(() => _lastSync = DateTime.now());
              },
              child: KeyedSubtree(
                key: activityListKey,
                child: buildActivityList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(LanguageProvider lang) {
    final children = _buildChildSummaries();
    return BrandPageHeader(
      role: 'wali',
      subtitle: lang.getTranslatedText({
        'en': 'Academic · Child',
        'id': 'Akademik · Anak',
      }),
      title: lang.getTranslatedText({
        'en': 'Class Activity',
        'id': 'Aktivitas Kelas',
      }),
      realtimeIndicator: BrandRealtimePill(
        isFresh: !isLoading,
        lastSync: _lastSync,
      ),
      childSelector: children.isEmpty
          ? null
          : ChildSelectorChipRow(
              key: studentSelectorKey,
              children: children,
              selectedChildId: selectedStudentId ?? children.first.id,
              onSelected: (id) {
                setState(() {
                  selectedStudentId = id;
                  activityList = [];
                  hasFreshData = false;
                });
                loadActivities();
              },
              accentColor: ColorUtils.brandAzureDeep,
            ),
    );
  }

  List<ChildSummary> _buildChildSummaries() {
    return studentList.map<ChildSummary>((raw) {
      final model = Student.fromJson(raw as Map<String, dynamic>);
      return ChildSummary(
        id: model.id,
        shortName: model.name.isEmpty
            ? '?'
            : model.name.split(RegExp(r'\s+')).first,
        klass: model.className.isEmpty
            ? '-'
            : 'Kelas ${model.className}',
      );
    }).toList();
  }
}
