// Schedule list component that renders a scrollable list of schedule cards.
//
// Like a Vue component `<ScheduleList>` that uses `v-for` to iterate over
// schedules and render `<ScheduleCard>` for each item. Similar to a Blade
// `@foreach($schedules as $schedule)` loop rendering partials.
import 'package:flutter/material.dart';
import 'schedule_card.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A scrollable list of [ScheduleCard] widgets.
///
/// Like a Vue `<ScheduleList>` component with props:
/// - [schedules] - list of schedule data maps (like `:items` on a list)
/// - [onEditSchedule] - callback when edit is tapped on a card
/// - [onDeleteSchedule] - callback with schedule ID when delete is tapped
///
/// Uses Flutter's `ListView.builder` for lazy rendering (like Vue's virtual scroll).
class ScheduleList extends StatelessWidget {
  final List<dynamic> schedules;
  final Function(dynamic) onEditSchedule;
  final Function(String) onDeleteSchedule;

  const ScheduleList({
    super.key,
    required this.schedules,
    required this.onEditSchedule,
    required this.onDeleteSchedule,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.all(AppSpacing.lg),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        final schedule = schedules[index];
        return ScheduleCard(
          schedule: schedule,
          onEdit: () => onEditSchedule(schedule),
          onDelete: () => onDeleteSchedule(schedule['id']),
        );
      },
    );
  }
}