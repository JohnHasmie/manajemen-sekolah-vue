// A single schedule entry card shown in the card-list view.
// Extracted from TeachingScheduleScreen._buildScheduleCard().

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_card_color_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_card_data_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_card_action_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/mixins/schedule_card_modal_mixin.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_container.dart';
import 'package:manajemensekolah/features/schedule/presentation/widgets/schedule_card_header.dart';

/// A card displaying one schedule entry with subject, day badge, time/class
/// info tags, and quick-action buttons for Materials and Class Activity.
class ScheduleCardItem extends StatelessWidget
    with
        ScheduleCardColorMixin,
        ScheduleCardActionMixin,
        ScheduleCardModalMixin,
        ScheduleCardDataMixin {
  ScheduleCardItem({
    super.key,
    required this.schedule,
    required this.languageProvider,
    required this.index,
    required this.dayIdMap,
    required this.dayColorMap,
    required this.dayOptions,
    required this.selectedAcademicYear,
    required this.teacherId,
    required this.teacherNama,
    this.firstScheduleKey,
    this.actionButtonsKey,
    this.isPast = false,
    this.isCurrent = false,
    this.isNext = false,
    this.dailySummary,
    this.onRefresh,
    this.dayColor,
    this.isHomeroomView = false,
  });

  @override
  final Map<String, dynamic> schedule;
  @override
  final LanguageProvider languageProvider;
  final int index;
  @override
  final Map<String, String> dayIdMap;
  final Map<String, Color> dayColorMap;
  @override
  final List<String> dayOptions;
  final String selectedAcademicYear;
  @override
  final String teacherId;
  @override
  final String teacherNama;
  final GlobalKey? firstScheduleKey;
  final GlobalKey? actionButtonsKey;
  @override
  final bool isPast;
  @override
  final bool isCurrent;
  @override
  final bool isNext;
  @override
  final Map<String, dynamic>? dailySummary;
  @override
  final VoidCallback? onRefresh;

  /// Day-specific accent color (e.g. indigo for Monday, emerald for Tuesday).
  final Color? dayColor;

  /// Whether the schedule is viewed in wali kelas (homeroom) mode.
  final bool isHomeroomView;

  @override
  Color getPrimaryColor() => ColorUtils.getRoleColor('guru');

  @override
  void setState(VoidCallback fn) {
    // No-op for StatelessWidget.
  }

  @override
  BuildContext get context {
    throw UnsupportedError('context is not available in StatelessWidget');
  }

  @override
  void openMaterial(BuildContext ctx) {
    // Implemented via ScheduleCardModalMixin.
    super.openMaterial(ctx);
  }

  @override
  void openClassActivity(BuildContext ctx) {
    // Implemented via ScheduleCardModalMixin.
    super.openClassActivity(ctx);
  }

  @override
  Widget build(BuildContext context) {
    final primary = getPrimaryColor();
    final summary = getSummary();
    final colors = getCardColors(primary, summary);
    final fillStates = getFillStates(summary);

    return ScheduleCardContainer(
      key: index == 0 ? firstScheduleKey : null,
      cardBg: colors.cardBg,
      cardBorder: colors.cardBorder,
      borderWidth: colors.borderWidth,
      boxShadow: getCardShadow(primary),
      onTap: () {
        showSummarySheet(context, summary);
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScheduleCardHeader(
            schedule: schedule,
            accentColor: colors.accentColor,
            subTextColor: colors.subTextColor,
            selectedAcademicYear: selectedAcademicYear,
            languageProvider: languageProvider,
            dayColor: dayColor,
            isPast: isPast,
            isHomeroomView: isHomeroomView,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              height: 1,
              color: Colors.grey.withValues(alpha: 0.10),
            ),
          ),
          buildActionButtons(
            primary,
            fillStates.attendanceFilled,
            fillStates.activityFilled,
            fillStates.materialFilled,
            ctx: context,
          ),
        ],
      ),
    );
  }
}
