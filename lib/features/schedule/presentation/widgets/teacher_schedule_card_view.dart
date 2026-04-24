// Card-list view for the teacher's teaching schedule screen.
// Groups schedule cards by day (Senin → Sabtu) with sticky day dividers.
// Past days/hours are visually dimmed. Auto-scrolls to the current/next
// lesson with a smooth spring-like animation.

import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_card_builder_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_grouping_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_timing_mixin.dart';

class TeacherScheduleCardView extends StatefulWidget {
  final List<dynamic> schedules;
  final LanguageProvider languageProvider;
  final Map<String, String> dayIdMap;
  final Map<String, Color> dayColorMap;
  final List<String> dayOptions;
  final String selectedAcademicYear;
  final String teacherId;
  final String teacherNama;
  final GlobalKey firstScheduleKey;
  final GlobalKey actionButtonsKey;
  final Map<String, dynamic>? dailySummary;
  final VoidCallback? onRefresh;
  final bool isHomeroomView;

  /// When true, the card view auto-scrolls to the current/next schedule
  /// on first build. Should only be true on initial screen open.
  final bool autoScroll;

  const TeacherScheduleCardView({
    super.key,
    required this.schedules,
    required this.languageProvider,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.dayOptions,
    required this.selectedAcademicYear,
    required this.teacherId,
    required this.teacherNama,
    required this.firstScheduleKey,
    required this.actionButtonsKey,
    this.dailySummary,
    this.onRefresh,
    this.isHomeroomView = false,
    this.autoScroll = true,
  });

  @override
  State<TeacherScheduleCardView> createState() =>
      _TeacherScheduleCardViewState();
}

class _TeacherScheduleCardViewState extends State<TeacherScheduleCardView>
    with ScheduleTimingMixin, ScheduleGroupingMixin, ScheduleCardBuilderMixin {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToTarget = false;
  final GlobalKey _scrollTargetKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ── Mixin state accessors ──

  @override
  List<dynamic> get schedules => widget.schedules;

  @override
  Map<String, String> get dayIdMap => widget.dayIdMap;

  @override
  Map<String, Color> get dayColorMap => widget.dayColorMap;

  @override
  List<String> get dayOptions => widget.dayOptions;

  @override
  String get selectedAcademicYear => widget.selectedAcademicYear;

  @override
  String get teacherId => widget.teacherId;

  @override
  String get teacherNama => widget.teacherNama;

  @override
  GlobalKey get firstScheduleKey => widget.firstScheduleKey;

  @override
  GlobalKey get actionButtonsKey => widget.actionButtonsKey;

  @override
  GlobalKey get scrollTargetKey => _scrollTargetKey;

  @override
  Map<String, dynamic>? get dailySummary => widget.dailySummary;

  @override
  VoidCallback? get onRefresh => widget.onRefresh;

  @override
  dynamic get languageProvider => widget.languageProvider;

  @override
  bool get isHomeroomView => widget.isHomeroomView;

  // ── Bridge methods to mixins (ScheduleTimingMixin) ──

  @override
  String getDayName(Map<String, dynamic> schedule) =>
      getDayNameFromSchedule(schedule);

  @override
  bool isDayPast(String dayName) => isDayPastCheck(dayName);

  @override
  bool isDayToday(String dayName) => isDayTodayCheck(dayName);

  @override
  bool isHourPast(Map<String, dynamic> schedule) => isHourPastCheck(schedule);

  @override
  bool isHourCurrent(Map<String, dynamic> schedule) =>
      isHourCurrentCheck(schedule);

  @override
  int startTimeMinutes(Map<String, dynamic> schedule) =>
      startTimeMinutesValue(schedule);

  Color _primaryColor() => ColorUtils.getRoleColor('guru');

  void _autoScroll() {
    if (_hasScrolledToTarget || !widget.autoScroll) return;
    _hasScrolledToTarget = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _performScrollToTarget();
    });
  }

  Future<void> _performScrollToTarget() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    final targetContext = _scrollTargetKey.currentContext;
    if (targetContext == null || !targetContext.mounted) return;

    Scrollable.ensureVisible(
      targetContext,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
      alignment: 0.15,
    );
  }

  List<int> _computeStartIndices(List<DayGroup> groups) {
    final startIndices = <int>[];
    int running = 0;
    for (final group in groups) {
      startIndices.add(running);
      running += group.schedules.length;
    }
    return startIndices;
  }

  List<Widget> _buildSlivers(
    List<DayGroup> groups,
    List<int> startIndices,
    Color primary,
    ScrollTarget? scrollTarget,
  ) {
    final slivers = <Widget>[
      const SliverPadding(padding: EdgeInsets.only(top: 4)),
    ];

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      // Make headers non-sticky for day groups that appear before the
      // scroll target. This prevents the confusing state where a
      // day header is pinned at the top but its cards are scrolled
      // above the viewport (e.g. Senin header sticks when all its
      // lessons are past and auto-scroll targets Selasa).
      final stickyHeader = scrollTarget == null || g >= scrollTarget.groupIdx;
      slivers.add(
        SliverStickyHeader(
          sticky: stickyHeader,
          header: Container(
            color: ColorUtils.slate50,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: buildDayHeader(
              group.dayName,
              group.schedules.length,
              primary,
            ),
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate(
              buildCardsForGroup(group, startIndices[g], g, scrollTarget),
            ),
          ),
        ),
      );
    }

    // Extra bottom padding for Samsung/Android software nav bar
    final bottomSafe = MediaQuery.of(context).padding.bottom;
    slivers.add(SliverPadding(
      padding: EdgeInsets.only(bottom: 16 + bottomSafe),
    ));

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    final groups = groupByDay();
    final primary = _primaryColor();
    final scrollTarget = findScrollTarget(groups);

    if (scrollTarget != null) {
      _autoScroll();
    }

    final startIndices = _computeStartIndices(groups);
    final slivers = _buildSlivers(groups, startIndices, primary, scrollTarget);

    return CustomScrollView(controller: _scrollController, slivers: slivers);
  }
}
