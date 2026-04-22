import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/summary_item.dart';

mixin CardViewMixin on ConsumerState<ReportCardOverviewPage> {
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  void openClassReport(dynamic classItem);

  Widget buildCardView(List<dynamic> data, List<dynamic> allClassData) {
    final stats = calculateStats(allClassData);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        buildOverallSummaryCard(stats),
        ...data.map((d) => buildClassCard(d)),
      ],
    );
  }

  Map<String, int> calculateStats(List<dynamic> classData) {
    int totalStudents = 0, totalFilled = 0, totalDraft = 0;
    for (final c in classData) {
      totalStudents += (c['student_count'] as num?)?.toInt() ?? 0;
      totalFilled += (c['total_raports'] as num?)?.toInt() ?? 0;
      totalDraft += (c['draft_count'] as num?)?.toInt() ?? 0;
    }
    return {
      'totalStudents': totalStudents,
      'totalFilled': totalFilled,
      'totalDraft': totalDraft,
    };
  }

  Widget buildOverallSummaryCard(Map<String, int> stats) {
    final totalStudents = stats['totalStudents']!;
    final totalFilled = stats['totalFilled']!;
    final totalDraft = stats['totalDraft']!;

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildSummaryHeader(),
          const SizedBox(height: 10),
          buildSummaryStats(totalStudents, totalFilled, totalDraft),
          const SizedBox(height: 10),
          buildProgressSection(totalStudents, totalFilled),
        ],
      ),
    );
  }

  Widget buildSummaryHeader() {
    return Row(
      children: [
        Icon(Icons.analytics_outlined, size: 16, color: primaryColor),
        const SizedBox(width: 6),
        Text(
          'Ringkasan',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
      ],
    );
  }

  Widget buildSummaryStats(int totalStudents, int totalFilled, int totalDraft) {
    return Row(
      children: [
        SummaryItem(
          label: 'Total Siswa',
          value: '$totalStudents',
          color: ColorUtils.slate600,
        ),
        SummaryItem(
          label: 'Terisi',
          value: '$totalFilled',
          color: ColorUtils.success600,
        ),
        SummaryItem(
          label: 'Draft',
          value: '$totalDraft',
          color: ColorUtils.warning600,
        ),
        SummaryItem(
          label: 'Belum',
          value: '${totalStudents - totalFilled}',
          color: ColorUtils.error600,
        ),
      ],
    );
  }

  Widget buildProgressSection(int totalStudents, int totalFilled) {
    return Column(
      children: [
        Row(
          children: [
            Text(
              'Progress Keseluruhan',
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.slate400,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${totalStudents > 0 ? (totalFilled * 100 / totalStudents).round() : 0}%',
              style: TextStyle(
                fontSize: 10,
                color: primaryColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: LinearProgressIndicator(
              value: totalStudents > 0 ? totalFilled / totalStudents : 0,
              backgroundColor: ColorUtils.slate100,
              valueColor: AlwaysStoppedAnimation(primaryColor),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildClassCard(dynamic classData) {
    final className = classData['class_name']?.toString() ?? '-';
    final studentCount = classData['student_count'] ?? 0;
    final totalRaports = classData['total_raports'] ?? 0;
    final draftCount = classData['draft_count'] ?? 0;
    final finalCount = classData['final_count'] ?? 0;
    final publishedCount = classData['published_count'] ?? 0;
    final pctVal = getCompletionPercentage(classData);
    final pctColor = getCompletionColor(pctVal);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => openClassReport(classData),
          borderRadius: BorderRadius.circular(12),
          child: buildClassCardContent(
            pctVal,
            pctColor,
            className,
            totalRaports,
            studentCount,
            draftCount,
            finalCount,
            publishedCount,
          ),
        ),
      ),
    );
  }

  double getCompletionPercentage(dynamic classData) {
    final completionPct = classData['completion_pct'] ?? 0;
    return (completionPct is num) ? completionPct.toDouble() : 0.0;
  }

  Color getCompletionColor(double pctVal) {
    return pctVal >= 80
        ? ColorUtils.success600
        : (pctVal >= 40 ? ColorUtils.warning600 : ColorUtils.slate400);
  }

  Widget buildClassCardContent(
    double pctVal,
    Color pctColor,
    String className,
    int totalRaports,
    int studentCount,
    int draftCount,
    int finalCount,
    int publishedCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        children: [
          buildProgressCircle(pctVal, pctColor),
          const SizedBox(width: 12),
          Expanded(
            child: buildClassInfo(
              className,
              totalRaports,
              studentCount,
              draftCount,
              finalCount,
              publishedCount,
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: ColorUtils.slate300,
          ),
        ],
      ),
    );
  }

  Widget buildProgressCircle(double pctVal, Color pctColor) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              value: pctVal / 100,
              strokeWidth: 3.5,
              backgroundColor: ColorUtils.slate100,
              color: pctColor,
            ),
          ),
          Text(
            '${pctVal.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: pctColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget buildClassInfo(
    String className,
    int totalRaports,
    int studentCount,
    int draftCount,
    int finalCount,
    int publishedCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          className,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            buildMiniChip('$totalRaports/$studentCount', primaryColor),
            if (draftCount > 0)
              buildMiniChip('Draft $draftCount', ColorUtils.warning600),
            if (finalCount > 0)
              buildMiniChip('Final $finalCount', ColorUtils.info600),
            if (publishedCount > 0)
              buildMiniChip('Terbit $publishedCount', ColorUtils.success600),
            if (totalRaports == 0)
              buildMiniChip('Belum ada', ColorUtils.slate400),
          ],
        ),
      ],
    );
  }

  Widget buildMiniChip(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
