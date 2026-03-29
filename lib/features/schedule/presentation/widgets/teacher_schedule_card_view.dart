// Card-list view for the teacher's teaching schedule screen.
// Extracted from TeachingScheduleScreen._buildCardView().
//
// Like a Vue `<ScheduleCardList :schedules="..." />` component.
// Renders a scrollable list of ScheduleCardItem widgets, one per schedule
// entry. All data flows in via constructor params; no state is held here.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_item.dart';

/// Scrollable card-list of schedule entries for the teacher schedule screen.
///
/// Like a Laravel Blade partial `@include('schedule.card-list', [...])`.
/// Receives the filtered schedule list, look-up maps, and GlobalKeys from the
/// parent state; renders each entry as a [ScheduleCardItem].
class TeacherScheduleCardView extends StatelessWidget {
  /// The filtered list of schedule entry maps.
  final List<dynamic> schedules;

  /// Language provider for localised strings inside each card.
  final LanguageProvider languageProvider;

  /// Maps day-name strings to their API IDs, e.g. {'Senin': '1'}.
  final Map<String, String> dayIdMap;

  /// Maps day-name strings to badge colours, e.g. {'Senin': Colors.indigo}.
  final Map<String, Color> dayColorMap;

  /// Ordered list of day-name option strings (first entry is 'Semua Hari').
  final List<String> dayOptions;

  /// Currently selected academic year string, e.g. '2024/2025'.
  final String selectedAcademicYear;

  /// The authenticated teacher's ID, used for navigation targets.
  final String teacherId;

  /// The authenticated teacher's display name.
  final String teacherNama;

  /// GlobalKey for the onboarding tour target on the first schedule card.
  final GlobalKey firstScheduleKey;

  /// GlobalKey for the onboarding tour target on the action buttons row.
  final GlobalKey actionButtonsKey;

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
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: schedules.length,
      itemBuilder: (context, index) {
        return ScheduleCardItem(
          schedule: schedules[index] as Map<String, dynamic>,
          languageProvider: languageProvider,
          index: index,
          dayIdMap: dayIdMap,
          dayColorMap: dayColorMap,
          dayOptions: dayOptions,
          selectedAcademicYear: selectedAcademicYear,
          teacherId: teacherId,
          teacherNama: teacherNama,
          firstScheduleKey: firstScheduleKey,
          actionButtonsKey: actionButtonsKey,
        );
      },
    );
  }
}
