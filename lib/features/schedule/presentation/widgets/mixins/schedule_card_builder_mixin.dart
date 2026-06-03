// Mixin for building schedule cards and day headers.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_grouping_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_item.dart';

/// Mixin providing UI builders for schedule cards and headers.
mixin ScheduleCardBuilderMixin {
  // Required abstract members from State.
  void setState(VoidCallback fn);
  BuildContext get context;

  // State access for building.
  List<String> get dayOptions => [];
  Map<String, String> get dayIdMap => {};
  Map<String, Color> get dayColorMap => {};
  String get selectedAcademicYear => '';
  String get teacherId => '';
  String get teacherNama => '';
  // Subclasses MUST override these with stable references.
  // Never create GlobalKey() in a getter — it causes infinite rebuilds.
  GlobalKey get firstScheduleKey;
  GlobalKey get actionButtonsKey;
  GlobalKey get scrollTargetKey;
  Map<String, dynamic>? get dailySummary => null;
  VoidCallback? get onRefresh => null;
  dynamic get languageProvider => null;
  bool get isHomeroomView => false;

  // Abstract methods from timing mixin.
  bool isDayPastCheck(String dayName);
  bool isDayTodayCheck(String dayName);
  bool isHourPastCheck(Map<String, dynamic> schedule);

  // Day translations (matching original constants).
  Map<String, Map<String, String>> get dayTranslations =>
      <String, Map<String, String>>{
        'Senin': {'en': 'Monday', 'id': 'Senin'},
        'Selasa': {'en': 'Tuesday', 'id': 'Selasa'},
        'Rabu': {'en': 'Wednesday', 'id': 'Rabu'},
        'Kamis': {'en': 'Thursday', 'id': 'Kamis'},
        'Jumat': {'en': 'Friday', 'id': 'Jumat'},
        'Sabtu': {'en': 'Saturday', 'id': 'Sabtu'},
        'Minggu': {'en': 'Sunday', 'id': 'Minggu'},
      };

  /// Builds the day header widget with icon, name, and count.
  Widget buildDayHeader(String dayName, int count, Color primary) {
    final isPastDay = isDayPastCheck(dayName);
    final isToday = isDayTodayCheck(dayName);
    final color = isPastDay ? ColorUtils.slate400 : primary;
    final sessionWord = languageProvider.getTranslatedText({
      'en': count == 1 ? 'session' : 'sessions',
      'id': 'sesi',
    });
    final translations = dayTranslations[dayName];
    final label = translations != null
        ? languageProvider.getTranslatedText(translations)
        : dayName;

    return Row(
      children: [
        Icon(
          isToday ? Icons.today_rounded : Icons.calendar_today_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        if (isToday) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              languageProvider.getTranslatedText({
                'en': 'Today',
                'id': 'Hari ini',
              }),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            height: 1,
            color: isPastDay
                ? ColorUtils.slate200
                : color.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '$count $sessionWord',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  /// Builds a list of schedule cards for a day group.
  List<Widget> buildCardsForGroup(
    DayGroup group,
    int startIdx,
    int groupIdx,
    ScrollTarget? scrollTarget,
  ) {
    final isPastDay = isDayPastCheck(group.dayName);
    final isToday = isDayTodayCheck(group.dayName);
    // Resolve day color from the color map (same as table/calendar view).
    final dayColor = dayColorMap[group.dayName];

    return List.generate(group.schedules.length, (i) {
      final schedule = group.schedules[i];
      final isPast = isPastDay || (isToday && isHourPastCheck(schedule));
      final cardIdx = startIdx + i;
      final isScrollTarget =
          scrollTarget != null &&
          scrollTarget.groupIdx == groupIdx &&
          scrollTarget.scheduleIdx == i;

      final card = ScheduleCardItem(
        schedule: schedule,
        languageProvider: languageProvider,
        index: cardIdx,
        dayIdMap: dayIdMap,
        dayColorMap: dayColorMap,
        dayOptions: dayOptions,
        selectedAcademicYear: selectedAcademicYear,
        teacherId: teacherId,
        teacherNama: teacherNama,
        firstScheduleKey: cardIdx == 0 ? firstScheduleKey : null,
        actionButtonsKey: cardIdx == 0 ? actionButtonsKey : null,
        isPast: isPast,
        isCurrent: isScrollTarget && scrollTarget.isCurrent,
        isNext: isScrollTarget && !scrollTarget.isCurrent,
        dailySummary: dailySummary,
        onRefresh: onRefresh,
        dayColor: dayColor,
        isHomeroomView: isHomeroomView,
      );

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: isScrollTarget
            ? KeyedSubtree(key: scrollTargetKey, child: card)
            : card,
      );
    });
  }
}
