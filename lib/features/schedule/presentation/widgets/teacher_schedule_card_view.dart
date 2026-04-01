// Card-list view for the teacher's teaching schedule screen.
// Groups schedule cards by day (Senin → Sabtu) with sticky day dividers.
// Past days/hours are visually dimmed. Auto-scrolls to today's section.

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
  });

  @override
  State<TeacherScheduleCardView> createState() => _TeacherScheduleCardViewState();
}

class _TeacherScheduleCardViewState extends State<TeacherScheduleCardView> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolledToToday = false;

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
      _hasScrolledToToday = false;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }
  }

  Color _primaryColor() => ColorUtils.getRoleColor('guru');

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

  int _startTimeMinutes(Map<String, dynamic> schedule) {
    final time = (schedule['jam_mulai'] ?? schedule['start_time'])?.toString();
    if (time == null || time.isEmpty) return 0;
    final parts = time.replaceAll('.', ':').split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

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

  void _autoScroll(List<_DayGroup> groups) {
    if (_hasScrolledToToday) return;
    _hasScrolledToToday = true;

    int? targetGroupIdx;
    for (int i = 0; i < groups.length; i++) {
      if (_isDayToday(groups[i].dayName)) { targetGroupIdx = i; break; }
      if (!_isDayPast(groups[i].dayName) && targetGroupIdx == null) targetGroupIdx = i;
    }

    if (targetGroupIdx == null || targetGroupIdx == 0) return;

    final target = targetGroupIdx;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      double offset = 0;
      for (int i = 0; i < target; i++) {
        offset += 44 + groups[i].schedules.length * 200;
      }
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (offset > 0 && maxScroll > 0) {
        _scrollController.animateTo(offset.clamp(0, maxScroll), duration: const Duration(milliseconds: 400), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final groups = _groupByDay();
    final primary = _primaryColor();

    _autoScroll(groups);

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
            _buildCardsForGroup(group, startIndices[g]),
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
        Text('$count', style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500)),
      ],
    );
  }

  List<Widget> _buildCardsForGroup(_DayGroup group, int startIdx) {
    final isPastDay = _isDayPast(group.dayName);
    final isToday = _isDayToday(group.dayName);

    return List.generate(group.schedules.length, (i) {
      final schedule = group.schedules[i];
      final isPast = isPastDay || (isToday && _isHourPast(schedule));
      final cardIdx = startIdx + i;

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: ScheduleCardItem(
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
          dailySummary: widget.dailySummary,
        ),
      );
    });
  }
}

class _DayGroup {
  final String dayName;
  final List<Map<String, dynamic>> schedules;
  const _DayGroup({required this.dayName, required this.schedules});
}
