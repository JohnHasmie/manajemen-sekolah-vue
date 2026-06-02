// Standalone activity list screen for a single class + subject.
//
// Extracted from ClassActivityScreen (step 2) so that:
// - The schedule card bottom sheet opens this directly (no wizard overhead).
// - ClassActivityScreen reuses this for its step 2 body.
//
// Owns: activity list, pagination, search/filter, tabs, CRUD dialogs.
// Does NOT own: class selection, subject selection, teacher resolution.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_data_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_delete_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_dialog_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_filter_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_helpers_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/embedded_activity_scroll_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/widgets/activity_list_view.dart';

/// Lightweight activity list screen that only renders the activity list (step 2)
/// without class/subject wizard overhead.
///
/// Used by:
/// - `ScheduleCardItem._openClassActivity()` — opened in a bottom sheet
/// - `ClassActivityScreen` — embedded as step 2 body
class EmbeddedActivityListScreen extends ConsumerStatefulWidget {
  final String teacherId;
  final String teacherName;
  final String classId;
  final String className;
  final String subjectId;
  final String subjectName;
  final bool canEdit;
  final DateTime? initialDate;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  /// When true, wraps itself in a Scaffold with an AppBar and close button.
  /// When false, returns just the body content (for embedding inside another
  /// Scaffold).
  final bool showScaffold;

  /// Called after an activity is added/edited/deleted so the parent can
  /// refresh.
  final VoidCallback? onActivityChanged;

  /// When provided, newly created activities will be tagged with this
  /// lesson-hour so the schedule screen can track per-hour fill state.
  final String? lessonHourId;

  const EmbeddedActivityListScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
    required this.classId,
    required this.className,
    required this.subjectId,
    required this.subjectName,
    this.canEdit = true,
    this.initialDate,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
    this.showScaffold = true,
    this.onActivityChanged,
    this.lessonHourId,
  });

  @override
  EmbeddedActivityListScreenState createState() =>
      EmbeddedActivityListScreenState();
}

class EmbeddedActivityListScreenState
    extends ConsumerState<EmbeddedActivityListScreen>
    with
        TickerProviderStateMixin,
        EmbeddedActivityScrollMixin,
        EmbeddedActivityDataMixin,
        EmbeddedActivityDialogMixin,
        EmbeddedActivityDeleteMixin,
        EmbeddedActivityFilterMixin,
        EmbeddedActivityHelpersMixin {
  // Activity data
  @override
  late List<dynamic> activityList;
  @override
  late bool isLoading;
  @override
  late bool isLoadingMore;

  // Pagination
  @override
  late int currentPage;
  @override
  late int perPage;
  @override
  late bool hasMoreData;

  // Search & filter
  @override
  late TextEditingController searchController;
  @override
  late String? selectedDateFilter;
  @override
  late bool hasActiveFilter;

  // Scroll
  @override
  late ScrollController scrollController;

  // Tabs (umum / khusus)
  @override
  late TabController tabController;
  @override
  late String? currentTarget;

  // Material data (for add/edit dialog)
  @override
  late List<dynamic> chapterList;
  @override
  late List<dynamic> subChapterList;

  // Tour keys
  @override
  late GlobalKey searchFilterKey;
  @override
  late GlobalKey tabSwitcherKey;
  @override
  late GlobalKey fabKey;

  @override
  void initState() {
    super.initState();
    // Initialize activity data
    activityList = [];
    isLoading = true;
    isLoadingMore = false;

    // Initialize pagination
    currentPage = 1;
    perPage = 10;
    hasMoreData = true;

    // Initialize search & filter
    searchController = TextEditingController();
    // Apply initialDate if provided (e.g. from schedule card preselection)
    if (widget.initialDate != null) {
      final d = widget.initialDate!;
      selectedDateFilter =
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
      hasActiveFilter = true;
    } else {
      selectedDateFilter = null;
      hasActiveFilter = false;
    }

    // Initialize scroll
    scrollController = ScrollController();

    // Initialize tabs
    tabController = TabController(length: 2, vsync: this);
    // Backend canonical: `all` (was `umum`).
    currentTarget = 'all';

    // Initialize material data
    chapterList = [];
    subChapterList = [];

    // Initialize tour keys
    searchFilterKey = GlobalKey();
    tabSwitcherKey = GlobalKey();
    fabKey = GlobalKey();

    tabController.addListener(handleTabSelection);
    scrollController.addListener(onScroll);
    loadActivities();
  }

  @override
  void dispose() {
    tabController.dispose();
    searchController.dispose();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = ActivityListView(
      isLoading: isLoading,
      isLoadingMore: isLoadingMore,
      activityList: activityList,
      hasActiveFilter: hasActiveFilter,
      selectedDateFilter: selectedDateFilter,
      searchController: searchController,
      scrollController: scrollController,
      searchFilterKey: searchFilterKey,
      primaryColor: primaryColor,
      canEdit: widget.canEdit,
      selectedSubjectName: widget.subjectName,
      selectedClassName: widget.className,
      onSearchSubmitted: resetAndLoadActivities,
      onFilterPressed: showFilterSheet,
      onRemoveDateFilter: () {
        setState(() {
          selectedDateFilter = null;
          hasActiveFilter = false;
        });
        resetAndLoadActivities();
      },
      onActivityTap: showActivityDetail,
      onActivityEdit: showEditActivityDialog,
      onActivityDelete: (activity) =>
          deleteActivity(activity, ref.read(languageRiverpod)),
    );

    if (!widget.showScaffold) return body;

    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: Column(
        children: [
          // Gradient header with drag handle
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kelas: ${widget.className}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.subjectName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: body),
        ],
      ),
      floatingActionButton: buildFab(),
    );
  }
}
