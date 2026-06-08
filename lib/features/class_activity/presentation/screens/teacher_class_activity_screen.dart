import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/brand_page_layout.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_body_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_data_loading_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_filter_dialog_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_filter_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_header_builder_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_navigation_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_ui_helpers_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_pagination_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_schedule_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_state_mixin.dart';
import 'package:manajemensekolah/features/class_activity/presentation/mixins/teacher_activity_ui_builder_mixin.dart';

class TeacherClassActivityScreen extends ConsumerStatefulWidget {
  final DateTime? initialDate;
  final String? initialSubjectId;
  final String? initialSubjectName;
  final String? initialClassId;
  final String? initialClassName;
  final String? initialChapterId;
  final String? initialSubChapterId;
  final List<Map<String, dynamic>>? initialAdditionalMaterials;
  final List<Map<String, dynamic>>? materialsToMarkAsGenerated;
  final bool autoShowActivityDialog;

  /// Exact `lesson_hour_id` UUID of a chosen jam-pelajaran slot. Set
  /// when entering from a Jadwal session card's "Kegiatan" button so
  /// the auto-opened add form prefills the right "Jam ke-N".
  final String? initialLessonHourId;

  /// When true the screen, once its schedule data has loaded, opens the
  /// "Tambah Kegiatan" add form prefilled from the
  /// `initialClassId` / `initialSubjectId` / `initialDate` /
  /// `initialLessonHourId` params — the Jadwal "Kegiatan" entry flow
  /// (Bug 2). Distinct from [autoShowActivityDialog], which instead
  /// auto-detects the NOW-ongoing slot.
  final bool autoOpenPrefilledForm;

  const TeacherClassActivityScreen({
    super.key,
    this.initialDate,
    this.initialSubjectId,
    this.initialSubjectName,
    this.initialClassId,
    this.initialClassName,
    this.initialChapterId,
    this.initialSubChapterId,
    this.initialAdditionalMaterials,
    this.materialsToMarkAsGenerated,
    this.autoShowActivityDialog = false,
    this.initialLessonHourId,
    this.autoOpenPrefilledForm = false,
  });

  @override
  ConsumerState<TeacherClassActivityScreen> createState() =>
      _TeacherClassActivityScreenState();
}

class _TeacherClassActivityScreenState
    extends ConsumerState<TeacherClassActivityScreen>
    with
        TeacherActivityStateMixin,
        TeacherActivityUIHelpersMixin,
        TeacherActivityDataLoadingMixin,
        TeacherActivityPaginationMixin,
        TeacherActivityNavigationMixin,
        TeacherActivityFilterBuilderMixin,
        TeacherActivityFilterDialogMixin,
        TeacherActivityScheduleMixin,
        TeacherActivityHeaderBuilderMixin,
        TeacherActivityBodyBuilderMixin,
        TeacherActivityUIBuilderMixin {
  @override
  void initState() {
    super.initState();
    initializeState();
    initializeScrollControllers();
    loadViewPreference();
    loadUserData();
  }

  @override
  void dispose() {
    disposeControllers();
    disposeScrollControllers();
    super.dispose();
  }

  @override
  void onInitialDataLoaded(
    List classes,
    List schedules,
    Map<String, dynamic> summaryResult,
    List homerooms,
  ) {
    setState(() {
      updateClassList(classes);
      updateSchedules(schedules);
      updateGroupedActivities((summaryResult['data'] as List?) ?? []);
      updateHasMoreData(summaryResult['pagination']?['has_next_page'] == true);
      updateHomeroomClassList(homerooms);
      if (homerooms.isNotEmpty) {
        updateSelectedHomeroomClass(homerooms.first);
      }
    });
  }

  @override
  void toggleViewMode() {
    updateTimeline(!isTimelineView);
    if (isTimelineView && timelineActivities.isEmpty) {
      refreshTimeline();
    }
  }

  @override
  Widget build(BuildContext context) {
    final lp = ref.watch(languageRiverpod);
    // Brand-migrated scaffold — same pattern as Presensi.
    // BrandPageLayout owns the gradient header + KPI overlap card +
    // pull-to-refresh + scrollable body. The list / timeline body
    // collapses into a single Column inside `bodyChildren`.
    return Scaffold(
      backgroundColor: ColorUtils.slate50,
      body: BrandPageLayout(
        role: 'guru',
        onRefresh: forceRefresh,
        header: buildBrandHeader(lp),
        kpiCard: buildBrandKpiCard(lp),
        bodyChildren: [isTimelineView ? buildTimelineBody(lp) : buildBody(lp)],
      ),
      floatingActionButton: !isHomeroomView
          ? FloatingActionButton(
              onPressed: () => showAddActivityFlow(lp),
              backgroundColor: primaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }
}
