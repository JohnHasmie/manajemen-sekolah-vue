import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/widgets/stat_summary_card.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/admin_attendance_detail.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for stats card building in AdminAttendanceDetailPage
mixin admin_detail_ui_stats_mixin on ConsumerState<AdminAttendanceDetailPage> {
  Widget buildStatsCards(
    LanguageProvider languageProvider,
    Map<String, int> stats,
  ) {
    final totalAbsent = stats['alpha']!;
    final cards = <StatSummaryCard>[
      StatSummaryCard(
        label: languageProvider.getTranslatedText({
          'en': 'Present',
          'id': 'Hadir',
        }),
        value: stats['hadir']!.toString(),
        color: ColorUtils.success600,
        icon: Icons.check_circle,
      ),
      StatSummaryCard(
        label: languageProvider.getTranslatedText({
          'en': 'Late',
          'id': 'Terlambat',
        }),
        value: stats['terlambat']!.toString(),
        color: ColorUtils.warning600,
        icon: Icons.access_time,
      ),
      StatSummaryCard(
        label: languageProvider.getTranslatedText({
          'en': 'Absent',
          'id': 'Tidak Hadir',
        }),
        value: totalAbsent.toString(),
        color: ColorUtils.error600,
        icon: Icons.cancel,
      ),
    ];

    if (stats['izin']! > 0) {
      cards.add(
        StatSummaryCard(
          label: languageProvider.getTranslatedText({
            'en': 'Permission',
            'id': 'Izin',
          }),
          value: stats['izin']!.toString(),
          color: ColorUtils.info600,
          icon: Icons.event_note,
        ),
      );
    }

    if (stats['sakit']! > 0) {
      cards.add(
        StatSummaryCard(
          label: languageProvider.getTranslatedText({
            'en': 'Sick',
            'id': 'Sakit',
          }),
          value: stats['sakit']!.toString(),
          color: ColorUtils.violet700,
          icon: Icons.medical_services,
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          height: 120,
          child: StatSummaryRow(
            scrollable: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            cards: cards,
          ),
        ),
      ],
    );
  }
}
