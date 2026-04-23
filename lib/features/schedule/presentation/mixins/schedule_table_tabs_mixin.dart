import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_refresh_indicator.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/teacher_schedule_table_view.dart';

const _kDayTranslations = <String, Map<String, String>>{
  'Senin': {'en': 'Mon', 'id': 'Sen'},
  'Selasa': {'en': 'Tue', 'id': 'Sel'},
  'Rabu': {'en': 'Wed', 'id': 'Rab'},
  'Kamis': {'en': 'Thu', 'id': 'Kam'},
  'Jumat': {'en': 'Fri', 'id': 'Jum'},
  'Sabtu': {'en': 'Sat', 'id': 'Sab'},
};

const _kDayFullTranslations = <String, Map<String, String>>{
  'Senin': {'en': 'Monday', 'id': 'Senin'},
  'Selasa': {'en': 'Tuesday', 'id': 'Selasa'},
  'Rabu': {'en': 'Wednesday', 'id': 'Rabu'},
  'Kamis': {'en': 'Thursday', 'id': 'Kamis'},
  'Jumat': {'en': 'Friday', 'id': 'Jumat'},
  'Sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
};

mixin ScheduleTableTabsMixin on State<TeacherScheduleTableView> {
  Widget buildDayTabBar(
    TabController tabController,
    List<String> availableDays,
  ) {
    final widget = (this as dynamic).widget;
    final primary = widget.primaryColor as Color;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: tabController,
        isScrollable: availableDays.length > 5,
        indicator: _buildTabIndicator(),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: primary,
        unselectedLabelColor: ColorUtils.slate500,
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        tabs: availableDays.map((day) => _buildDayTab(day, primary)).toList(),
      ),
    );
  }

  BoxDecoration _buildTabIndicator() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ],
    );
  }

  Tab _buildDayTab(String day, Color primary) {
    final isToday = (this as dynamic).isDayToday(day) as bool;
    final shortLabel = _kDayTranslations[day];
    final label = shortLabel != null
        ? (this as dynamic).tr(shortLabel) as String
        : day;

    return Tab(
      height: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label),
          if (isToday)
            Container(
              margin: const EdgeInsets.only(top: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: primary, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }

  Widget buildDayPage(
    String dayName,
    List<String> availableDays,
    List<dynamic> schedules,
  ) {
    final daySchedules =
        (this as dynamic).getSchedulesForDay(dayName, schedules)
            as List<Map<String, dynamic>>;
    final isToday = (this as dynamic).isDayToday(dayName) as bool;
    final isPastDay = (this as dynamic).isDayPast(dayName) as bool;
    final widget = (this as dynamic).widget;

    final nextScheduleIdx = daySchedules.indexWhere((s) {
      final isPast = (this as dynamic).isHourPast(dayName, s) as bool;
      final isCurrent = (this as dynamic).isHourCurrent(dayName, s) as bool;
      return !isPast && !isCurrent;
    });

    return AppRefreshIndicator(
      onRefresh: () async => (widget.onRefresh as VoidCallback)(),
      role: 'guru',
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _buildDayHeader(dayName, isToday, isPastDay, daySchedules),
          if (daySchedules.isEmpty)
            _buildEmptyDayMessage()
          else
            ..._buildSessionRows(dayName, daySchedules, nextScheduleIdx),
        ],
      ),
    );
  }

  Widget _buildDayHeader(
    String dayName,
    bool isToday,
    bool isPastDay,
    List<Map<String, dynamic>> daySchedules,
  ) {
    final widget = (this as dynamic).widget;
    final dayLabel = _getDayLabel(dayName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          _buildDayIndicator(isPastDay, widget),
          const SizedBox(width: 10),
          _buildDayLabelText(dayLabel, isPastDay),
          if (isToday) _buildTodayBadge(),
          const Spacer(),
          _buildSessionCountText(daySchedules),
        ],
      ),
    );
  }

  String _getDayLabel(String dayName) {
    final fullLabel = _kDayFullTranslations[dayName];
    return fullLabel != null
        ? (this as dynamic).tr(fullLabel) as String
        : dayName;
  }

  Widget _buildDayIndicator(bool isPastDay, dynamic widget) {
    return Container(
      width: 4,
      height: 24,
      decoration: BoxDecoration(
        color: isPastDay ? ColorUtils.slate300 : (widget.primaryColor as Color),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildDayLabelText(String dayLabel, bool isPastDay) {
    return Text(
      dayLabel,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isPastDay ? ColorUtils.slate400 : ColorUtils.slate800,
      ),
    );
  }

  Widget _buildTodayBadge() {
    final widget = (this as dynamic).widget;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: (widget.primaryColor as Color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        (this as dynamic).tr({'en': 'Today', 'id': 'Hari ini'}) as String,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: widget.primaryColor as Color,
        ),
      ),
    );
  }

  Widget _buildSessionCountText(List<Map<String, dynamic>> daySchedules) {
    return Text(
      '${daySchedules.length} ${(this as dynamic).tr({'en': daySchedules.length == 1 ? 'session' : 'sessions', 'id': 'sesi'}) as String}',
      style: TextStyle(
        fontSize: 11,
        color: ColorUtils.slate500,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildEmptyDayMessage() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          (this as dynamic).tr({
                'en': 'No classes this day',
                'id': 'Tidak ada jadwal hari ini',
              })
              as String,
          style: TextStyle(fontSize: 13, color: ColorUtils.slate400),
        ),
      ),
    );
  }

  List<Widget> _buildSessionRows(
    String dayName,
    List<Map<String, dynamic>> daySchedules,
    int nextScheduleIdx,
  ) {
    return daySchedules.asMap().entries.map((entry) {
      final idx = entry.key;
      final schedule = entry.value;
      final isPast = (this as dynamic).isHourPast(dayName, schedule) as bool;
      final isCurrent =
          (this as dynamic).isHourCurrent(dayName, schedule) as bool;
      final isNext = idx == nextScheduleIdx;

      return (this as dynamic).buildSessionRow(
            schedule: schedule,
            dayName: dayName,
            isPast: isPast,
            isCurrent: isCurrent,
            isNext: isNext,
            isLast: idx == daySchedules.length - 1,
          )
          as Widget;
    }).toList();
  }
}
