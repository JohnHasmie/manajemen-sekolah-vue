// Card-list view for the teacher's teaching schedule screen.
// Groups schedule cards by day (Senin → Sabtu) with sticky day dividers.
// Past days/hours are visually dimmed. Auto-scrolls to the current/next
// lesson with a smooth spring-like animation.

import 'package:flutter/material.dart';
import 'package:flutter_sticky_header/flutter_sticky_header.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_item.dart';

const _kDayTranslations = <String, Map<String, String>>{
  'Senin': {'en': 'Monday', 'id': 'Senin'},
  'Selasa': {'en': 'Tuesday', 'id': 'Selasa'},
  'Rabu': {'en': 'Wednesday', 'id': 'Rabu'},
  'Kamis': {'en': 'Thursday', 'id': 'Kamis'},
  'Jumat': {'en': 'Friday', 'id': 'Jumat'},
  'Sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
  'Minggu': {'en': 'Sunday', 'id': 'Minggu'},
};

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
  });

  @override
  State<TeacherScheduleCardView> createState() => _TeacherScheduleCardViewState();
}

class _TeacherScheduleCardViewState extends State<TeacherScheduleCardView> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToTarget = false;

  /// Key attached to the card we want to scroll to (current or next lesson).
  final GlobalKey _scrollTargetKey = GlobalKey();

  static const _dayOrder = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TeacherScheduleCardView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.schedules != widget.schedules) {
      _hasScrolledToTarget = false;
    }
  }

  Color _primaryColor() => ColorUtils.getRoleColor('guru');

  // ── Day / time helpers ──

  String _getDayName(Map<String, dynamic> schedule) {
    final dayId = (schedule['day_id'] ?? schedule['hari_id'])?.toString();
    if (dayId != null) {
      final entry = widget.dayIdMap.entries.firstWhere(
        (e) => e.value.toString() == dayId,
        orElse: () => const MapEntry('', ''),
      );
      if (entry.key.isNotEmpty) return _normalizeDayName(entry.key);
    }
    final rawName = (schedule['hari_nama'] ?? schedule['day_name'] ?? '').toString();
    return rawName.isNotEmpty ? _normalizeDayName(rawName) : 'Senin';
  }

  String _normalizeDayName(String name) {
    name = name.trim().toLowerCase();
    if (name.contains('senin') || name.contains('monday')) return 'Senin';
    if (name.contains('selasa') || name.contains('tuesday')) return 'Selasa';
    if (name.contains('rabu') || name.contains('wednesday')) return 'Rabu';
    if (name.contains('kamis') || name.contains('thursday')) return 'Kamis';
    if (name.contains('jumat') || name.contains('friday')) return 'Jumat';
    if (name.contains('sabtu') || name.contains('saturday')) return 'Sabtu';
    if (name.contains('minggu') || name.contains('sunday')) return 'Minggu';
    return 'Senin';
  }

  int _dayWeekday(String dayName) {
    final idx = _dayOrder.indexOf(dayName);
    return idx >= 0 ? idx + 1 : 1;
  }

  bool _isDayPast(String dayName) => _dayWeekday(dayName) < DateTime.now().weekday;
  bool _isDayToday(String dayName) => _dayWeekday(dayName) == DateTime.now().weekday;

  bool _isHourPast(Map<String, dynamic> schedule) {
    final endTime = (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (endTime == null || endTime.isEmpty) return false;
    final parts = endTime.replaceAll('.', ':').split(':');
    if (parts.length < 2) return false;
    final endHour = int.tryParse(parts[0]) ?? 0;
    final endMinute = int.tryParse(parts[1]) ?? 0;
    final now = DateTime.now();
    return now.hour > endHour || (now.hour == endHour && now.minute >= endMinute);
  }

  bool _isHourCurrent(Map<String, dynamic> schedule) {
    final startTime = (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    final endTime = (schedule['jam_selesai'] ?? schedule['end_time'])?.toString();
    if (startTime == null || endTime == null) return false;

    int toMinutes(String t) {
      final parts = t.replaceAll('.', ':').split(':');
      if (parts.length < 2) return 0;
      return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
    }

    final nowMinutes = DateTime.now().hour * 60 + DateTime.now().minute;
    return nowMinutes >= toMinutes(startTime) && nowMinutes < toMinutes(endTime);
  }

  int _startTimeMinutes(Map<String, dynamic> schedule) {
    final time = (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    if (time == null || time.isEmpty) return 0;
    final parts = time.replaceAll('.', ':').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  // ── Grouping ──

  List<_DayGroup> _groupByDay() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final schedule in widget.schedules) {
      final s = schedule as Map<String, dynamic>;
      final dayName = _getDayName(s);
      grouped.putIfAbsent(dayName, () => []).add(s);
    }
    for (final list in grouped.values) {
      list.sort((a, b) => _startTimeMinutes(a).compareTo(_startTimeMinutes(b)));
    }
    final groups = <_DayGroup>[];
    for (final day in _dayOrder) {
      if (grouped.containsKey(day)) {
        groups.add(_DayGroup(dayName: day, schedules: grouped[day]!));
      }
    }
    return groups;
  }

  // ── Scroll target finder ──

  /// Finds the card that should be scrolled to:
  /// 1. The currently running lesson (if any)
  /// 2. The next upcoming lesson today
  /// 3. The first lesson of the next school day
  _ScrollTarget? _findScrollTarget(List<_DayGroup> groups) {
    // Today: find current or next lesson
    for (int g = 0; g < groups.length; g++) {
      if (!_isDayToday(groups[g].dayName)) continue;
      for (int i = 0; i < groups[g].schedules.length; i++) {
        final schedule = groups[g].schedules[i];
        if (_isHourCurrent(schedule)) {
          return _ScrollTarget(groupIdx: g, scheduleIdx: i, isCurrent: true);
        }
        if (!_isHourPast(schedule)) {
          return _ScrollTarget(groupIdx: g, scheduleIdx: i, isCurrent: false);
        }
      }
    }

    // Today passed entirely — find first lesson of next upcoming day
    for (int g = 0; g < groups.length; g++) {
      if (!_isDayPast(groups[g].dayName) && !_isDayToday(groups[g].dayName)) {
        return _ScrollTarget(groupIdx: g, scheduleIdx: 0, isCurrent: false);
      }
    }

    return null;
  }

  // ── Auto-scroll with ensureVisible ──

  void _autoScroll() {
    if (_hasScrolledToTarget) return;
    _hasScrolledToTarget = true;

    // Wait for layout to complete, then scroll to the keyed widget.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _performScrollToTarget();
    });
  }

  Future<void> _performScrollToTarget() async {
    // Small delay to ensure sticky headers are fully laid out.
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

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay();
    final primary = _primaryColor();
    final scrollTarget = _findScrollTarget(groups);

    if (scrollTarget != null) {
      _autoScroll();
    }

    // Pre-compute card start indices per group
    final startIndices = <int>[];
    int running = 0;
    for (final group in groups) {
      startIndices.add(running);
      running += group.schedules.length;
    }

    final slivers = <Widget>[const SliverPadding(padding: EdgeInsets.only(top: 4))];

    for (int g = 0; g < groups.length; g++) {
      final group = groups[g];
      slivers.add(SliverStickyHeader(
        header: Container(
          color: ColorUtils.slate50,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: _buildDayHeader(group.dayName, group.schedules.length, primary),
        ),
        sliver: SliverList(
          delegate: SliverChildListDelegate(
            _buildCardsForGroup(group, startIndices[g], g, scrollTarget),
          ),
        ),
      ));
    }

    slivers.add(const SliverPadding(padding: EdgeInsets.only(bottom: 16)));

    return CustomScrollView(
      controller: _scrollController,
      slivers: slivers,
    );
  }

  Widget _buildDayHeader(String dayName, int count, Color primary) {
    final isPastDay = _isDayPast(dayName);
    final isToday = _isDayToday(dayName);
    final color = isPastDay ? ColorUtils.slate400 : primary;
    final translations = _kDayTranslations[dayName];
    final label = translations != null
        ? widget.languageProvider.getTranslatedText(translations)
        : dayName;

    return Row(
      children: [
        Icon(isToday ? Icons.today_rounded : Icons.calendar_today_rounded, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
        if (isToday) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
            child: Text(
              widget.languageProvider.getTranslatedText({'en': 'Today', 'id': 'Hari ini'}),
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(child: Divider(height: 1, color: isPastDay ? ColorUtils.slate200 : color.withValues(alpha: 0.3))),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count ${widget.languageProvider.getTranslatedText({'en': count == 1 ? 'session' : 'sessions', 'id': 'sesi'})}',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildCardsForGroup(
    _DayGroup group,
    int startIdx,
    int groupIdx,
    _ScrollTarget? scrollTarget,
  ) {
    final isPastDay = _isDayPast(group.dayName);
    final isToday = _isDayToday(group.dayName);

    return List.generate(group.schedules.length, (i) {
      final schedule = group.schedules[i];
      final isPast = isPastDay || (isToday && _isHourPast(schedule));
      final cardIdx = startIdx + i;
      final isScrollTarget = scrollTarget != null &&
          scrollTarget.groupIdx == groupIdx &&
          scrollTarget.scheduleIdx == i;

      final card = ScheduleCardItem(
        schedule: schedule,
        languageProvider: widget.languageProvider,
        index: cardIdx,
        dayIdMap: widget.dayIdMap,
        dayColorMap: widget.dayColorMap,
        dayOptions: widget.dayOptions,
        selectedAcademicYear: widget.selectedAcademicYear,
        teacherId: widget.teacherId,
        teacherNama: widget.teacherNama,
        firstScheduleKey: cardIdx == 0 ? widget.firstScheduleKey : null,
        actionButtonsKey: cardIdx == 0 ? widget.actionButtonsKey : null,
        isPast: isPast,
        isCurrent: isScrollTarget && scrollTarget.isCurrent,
        isNext: isScrollTarget && !scrollTarget.isCurrent,
        dailySummary: widget.dailySummary,
        onRefresh: widget.onRefresh,
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isScrollTarget ? KeyedSubtree(key: _scrollTargetKey, child: card) : card,
      );
    });
  }
}

// ── Private models ──

class _DayGroup {
  final String dayName;
  final List<Map<String, dynamic>> schedules;
  const _DayGroup({required this.dayName, required this.schedules});
}

class _ScrollTarget {
  final int groupIdx;
  final int scheduleIdx;
  final bool isCurrent;
  const _ScrollTarget({
    required this.groupIdx,
    required this.scheduleIdx,
    required this.isCurrent,
  });
}

/// Overlays a small "Now" / "Next" badge on the top-right of the target card.

