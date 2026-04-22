import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_data_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_day_helpers_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_navigation_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_session_row_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/session_action_buttons_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_tabs_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/mixins/schedule_table_time_helpers_mixin.dart';

class TeacherScheduleTableView extends StatefulWidget {
  final List<dynamic> schedules;
  final Map<String, String> dayIdMap;
  final Map<String, Color> dayColorMap;
  final Color primaryColor;
  final List<String> dayOptions;
  final String teacherId;
  final String teacherNama;
  final Map<String, dynamic>? dailySummary;
  final VoidCallback onRefresh;
  final LanguageProvider? languageProvider;
  final bool isHomeroomView;

  const TeacherScheduleTableView({
    super.key,
    required this.schedules,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.primaryColor,
    required this.dayOptions,
    required this.teacherId,
    required this.teacherNama,
    required this.onRefresh,
    this.dailySummary,
    this.languageProvider,
    this.isHomeroomView = false,
  });

  @override
  State<TeacherScheduleTableView> createState() =>
      _TeacherScheduleTableViewState();
}

class _TeacherScheduleTableViewState extends State<TeacherScheduleTableView>
    with
        TickerProviderStateMixin,
        ScheduleTableDayHelpersMixin,
        ScheduleTableTimeHelpersMixin,
        ScheduleTableDataMixin,
        ScheduleTableNavigationMixin,
        ScheduleTableTabsMixin,
        SessionRowBuildingMixin,
        SessionActionButtonsMixin {
  TabController? _tabController;
  List<String> _availableDays = [];

  @override
  void initState() {
    super.initState();
    _rebuildTabs();
  }

  @override
  void didUpdateWidget(TeacherScheduleTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) {
      _rebuildTabs();
    }
  }

  void _rebuildTabs() {
    // Use mixin's computeAvailableDays which normalizes day names
    // to Indonesian (Senin, Selasa, etc.) and sorts by day order
    final newDays = computeAvailableDays(widget.schedules);
    if (newDays.length == _availableDays.length && _tabController != null) {
      _availableDays = newDays;
      return;
    }
    _availableDays = newDays;
    _tabController?.dispose();
    if (_availableDays.isEmpty) {
      _tabController = null;
      return;
    }
    _tabController = TabController(
      length: _availableDays.length,
      vsync: this,
      initialIndex: _findTodayIndex(),
    );
  }

  int _findTodayIndex() {
    for (int i = 0; i < _availableDays.length; i++) {
      if (isDayToday(_availableDays[i])) return i;
    }
    // If today not found, find the next upcoming day
    for (int i = 0; i < _availableDays.length; i++) {
      if (!isDayPast(_availableDays[i])) return i;
    }
    return 0;
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_availableDays.isEmpty || _tabController == null) {
      return Center(
        child: Text(
          (this as ScheduleTableDataMixin).tr({
            'en': 'No schedule data',
            'id': 'Tidak ada data jadwal',
          }),
        ),
      );
    }

    return Column(
      children: [
        (this as ScheduleTableTabsMixin).buildDayTabBar(
          _tabController!,
          _availableDays,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _availableDays
                .map(
                  (day) => (this as ScheduleTableTabsMixin).buildDayPage(
                    day,
                    _availableDays,
                    widget.schedules,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
