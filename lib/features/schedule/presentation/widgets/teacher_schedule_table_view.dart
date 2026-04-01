// Mobile-optimized weekly timetable for the teacher schedule screen.
// Replaces the old Excel-like grid (too wide for phones) with a
// day-tab + session-row layout that fits any screen width.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

const _kDayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu'];

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

class TeacherScheduleTableView extends StatefulWidget {
  const TeacherScheduleTableView({
    super.key,
    required this.schedules,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.primaryColor,
    this.languageProvider,
  });

  final List<dynamic> schedules;
  final Map<String, String> dayIdMap;
  final Map<String, Color> dayColorMap;
  final Color primaryColor;
  final LanguageProvider? languageProvider;

  @override
  State<TeacherScheduleTableView> createState() =>
      _TeacherScheduleTableViewState();
}

class _TeacherScheduleTableViewState extends State<TeacherScheduleTableView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<String> _availableDays;

  @override
  void initState() {
    super.initState();
    _availableDays = _computeAvailableDays();
    _tabController = TabController(
      length: _availableDays.length,
      vsync: this,
      initialIndex: _findTodayTabIndex(),
    );
  }

  @override
  void didUpdateWidget(TeacherScheduleTableView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) {
      final newDays = _computeAvailableDays();
      if (newDays.length != _availableDays.length) {
        _availableDays = newDays;
        _tabController.dispose();
        _tabController = TabController(
          length: _availableDays.length,
          vsync: this,
          initialIndex: _findTodayTabIndex(),
        );
      } else {
        _availableDays = newDays;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Day helpers ──

  List<String> _computeAvailableDays() {
    final daySet = <String>{};
    for (final schedule in widget.schedules) {
      final dayName = _resolveDayName(schedule);
      if (dayName != null) daySet.add(dayName);
    }
    return _kDayOrder.where(daySet.contains).toList();
  }

  String? _resolveDayName(dynamic schedule) {
    final dayId = (schedule['day_id'] ?? schedule['hari_id'])?.toString();
    if (dayId != null) {
      final entry = widget.dayIdMap.entries.firstWhere(
        (e) => e.value.toString() == dayId,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isNotEmpty) return _normalizeDayName(entry.key);
    }
    final rawName =
        (schedule['hari_nama'] ?? schedule['day_name'] ?? '').toString();
    return rawName.isNotEmpty ? _normalizeDayName(rawName) : null;
  }

  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    return 'Senin';
  }

  int _dayWeekday(String dayName) {
    final idx = _kDayOrder.indexOf(dayName);
    return idx >= 0 ? idx + 1 : 1;
  }

  bool _isDayPast(String dayName) =>
      _dayWeekday(dayName) < DateTime.now().weekday;
  bool _isDayToday(String dayName) =>
      _dayWeekday(dayName) == DateTime.now().weekday;

  int _findTodayTabIndex() {
    for (int i = 0; i < _availableDays.length; i++) {
      if (_isDayToday(_availableDays[i])) return i;
    }
    // If today has no schedule, find the next upcoming day
    for (int i = 0; i < _availableDays.length; i++) {
      if (!_isDayPast(_availableDays[i])) return i;
    }
    return 0;
  }

  // ── Time helpers ──

  String _formatTime(String? time) {
    if (time == null || time.isEmpty) return '--:--';
    final cleaned = time.replaceAll('.', ':');
    final parts = cleaned.split(':');
    if (parts.length >= 2) {
      return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
    }
    return time.length >= 5 ? time.substring(0, 5) : time;
  }

  int _startTimeMinutes(Map<String, dynamic> schedule) {
    final time =
        (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    if (time == null || time.isEmpty) return 0;
    final parts = time.replaceAll('.', ':').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 +
        (int.tryParse(parts[1]) ?? 0);
  }

  bool _isHourPast(String dayName, Map<String, dynamic> schedule) {
    if (!_isDayToday(dayName)) return _isDayPast(dayName);
    final endTime =
        (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (endTime == null || endTime.isEmpty) return false;
    final parts = endTime.replaceAll('.', ':').split(':');
    if (parts.length < 2) return false;
    final endHour = int.tryParse(parts[0]) ?? 0;
    final endMinute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return now.hour > endHour ||
        (now.hour == endHour && now.minute >= endMinute);
  }

  bool _isHourCurrent(String dayName, Map<String, dynamic> schedule) {
    if (!_isDayToday(dayName)) return false;
    final startTime =
        (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    final endTime =
        (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (startTime == null || endTime == null) return false;

    int toMinutes(String t) {
      final parts = t.replaceAll('.', ':').split(':');
      if (parts.length < 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 +
          (int.tryParse(parts[1]) ?? 0);
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMinutes >= toMinutes(startTime) &&
        nowMinutes < toMinutes(endTime);
  }

  Color _getDayColor(String day) =>
      widget.dayColorMap[day] ?? const Color(0xFF6B7280);

  // ── Data grouping ──

  List<Map<String, dynamic>> _getSchedulesForDay(String dayName) {
    final result = <Map<String, dynamic>>[];
    for (final schedule in widget.schedules) {
      final resolved = _resolveDayName(schedule);
      if (resolved == dayName) {
        result.add(schedule as Map<String, dynamic>);
      }
    }
    result.sort(
        (a, b) => _startTimeMinutes(a).compareTo(_startTimeMinutes(b)));
    return result;
  }

  String _tr(Map<String, String> map) {
    return widget.languageProvider?.getTranslatedText(map) ?? map['id'] ?? '';
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    if (_availableDays.isEmpty) {
      return const Center(child: Text('No schedule data'));
    }

    return Column(
      children: [
        // Day tabs
        _buildDayTabBar(),
        // Session rows for selected day
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _availableDays.map(_buildDayPage).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDayTabBar() {
    final primary = widget.primaryColor;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(3),
      child: TabBar(
        controller: _tabController,
        isScrollable: _availableDays.length > 5,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerHeight: 0,
        labelColor: primary,
        unselectedLabelColor: ColorUtils.slate500,
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
        tabs: _availableDays.map((day) {
          final isToday = _isDayToday(day);
          final shortLabel = _kDayTranslations[day];
          final label = shortLabel != null ? _tr(shortLabel) : day;

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
                    decoration: BoxDecoration(
                      color: primary,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayPage(String dayName) {
    final schedules = _getSchedulesForDay(dayName);
    final isToday = _isDayToday(dayName);
    final isPastDay = _isDayPast(dayName);
    final dayColor = _getDayColor(dayName);
    final fullLabel = _kDayFullTranslations[dayName];
    final dayLabel = fullLabel != null ? _tr(fullLabel) : dayName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        // Day header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 24,
                decoration: BoxDecoration(
                  color: isPastDay ? ColorUtils.slate300 : dayColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dayLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isPastDay ? ColorUtils.slate400 : ColorUtils.slate800,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: dayColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _tr({'en': 'Today', 'id': 'Hari ini'}),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: dayColor,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Text(
                '${schedules.length} ${_tr({'en': schedules.length == 1 ? 'session' : 'sessions', 'id': 'sesi'})}',
                style: TextStyle(
                  fontSize: 11,
                  color: ColorUtils.slate500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        // Session rows
        if (schedules.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                _tr({
                  'en': 'No classes this day',
                  'id': 'Tidak ada jadwal hari ini',
                }),
                style: TextStyle(
                  fontSize: 13,
                  color: ColorUtils.slate400,
                ),
              ),
            ),
          )
        else
          ...schedules.asMap().entries.map((entry) {
            final idx = entry.key;
            final schedule = entry.value;
            final isPast = _isHourPast(dayName, schedule);
            final isCurrent = _isHourCurrent(dayName, schedule);

            return _buildSessionRow(
              schedule: schedule,
              dayName: dayName,
              dayColor: dayColor,
              isPast: isPast,
              isCurrent: isCurrent,
              isLast: idx == schedules.length - 1,
            );
          }),
      ],
    );
  }

  Widget _buildSessionRow({
    required Map<String, dynamic> schedule,
    required String dayName,
    required Color dayColor,
    required bool isPast,
    required bool isCurrent,
    required bool isLast,
  }) {
    final sessionNum = schedule['jam_ke']?.toString() ?? '-';
    final startTime = _formatTime(
        (schedule['jam_mulai'] ?? schedule['start_time'])?.toString());
    final endTime = _formatTime(
        (schedule['jam_selesai'] ?? schedule['end_time'])?.toString());
    final subjectName =
        schedule['mata_pelajaran_nama']?.toString() ?? '-';
    final className = schedule['kelas_nama']?.toString() ?? '-';

    final opacity = isPast ? 0.5 : 1.0;
    final bgColor = isCurrent
        ? dayColor.withValues(alpha: 0.06)
        : Colors.white;
    final borderColor = isCurrent
        ? dayColor.withValues(alpha: 0.3)
        : ColorUtils.slate200;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: EdgeInsets.only(bottom: isLast ? 0 : 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: isPast
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Session number + time column
            SizedBox(
              width: 56,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? dayColor
                          : dayColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      sessionNum,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isCurrent ? Colors.white : dayColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    startTime,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: ColorUtils.slate600,
                    ),
                  ),
                  Text(
                    endTime,
                    style: TextStyle(
                      fontSize: 9,
                      color: ColorUtils.slate400,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // Divider line
            Container(
              width: 1,
              height: 48,
              color: isCurrent
                  ? dayColor.withValues(alpha: 0.3)
                  : ColorUtils.slate200,
            ),

            const SizedBox(width: 12),

            // Subject + class info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    subjectName,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isCurrent ? dayColor : ColorUtils.slate800,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: dayColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      className,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: dayColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Current indicator
            if (isCurrent)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: dayColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _tr({'en': 'Now', 'id': 'Now'}),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
