// Card view for the teacher Raport hub — Frame A of the
// `_design/teacher_raport_redesign.html` mockup.
//
// Each class card carries:
//   • 50dp circular progress ring (color-coded — green ≥80%, cobalt
//     40-79%, amber 1-39%, slate 0%) with `<n>%` text.
//   • Cobalt class kicker (`VII A · WALI`).
//   • Bold class name + slate `<n> siswa · <m> raport siap` meta.
//   • Slate chevron-right.
//   • 3-cell stats grid: Terbit (green) / Draft (amber) / Belum (red).
//   • Gradient progress bar at the bottom matching the ring colour.
//
// The KPI strip in the brand header carries the totals across all
// classes; this card focuses on per-class drill-down.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/screens/teacher_report_card_overview.dart';

mixin CardViewMixin on ConsumerState<ReportCardOverviewPage> {
  Color get primaryColor => ColorUtils.getRoleColor('guru');

  void openClassReport(dynamic classItem);

  Widget buildCardView(List<dynamic> data, List<dynamic> allClassData) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
      children: [_buildSectionHead(allClassData), ...data.map(_buildClassCard)],
    );
  }

  Widget _buildSectionHead(List<dynamic> allClassData) {
    final classCount = allClassData.length;
    var students = 0;
    var filled = 0;
    for (final c in allClassData) {
      if (c is! Map) continue;
      students += (c['student_count'] is num)
          ? (c['student_count'] as num).toInt()
          : 0;
      // Backend rename: `total_raports` → `total_report_cards`. Accept
      // both so older API responses still feed the wali-kelas summary.
      final totalKey = c['total_report_cards'] ?? c['total_raports'];
      filled += (totalKey is num) ? totalKey.toInt() : 0;
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'KELAS WALI · $classCount KELAS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.5,
            ),
          ),
          const Spacer(),
          Text(
            '$filled / $students raport',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: ColorUtils.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(dynamic classData) {
    final className = classData['class_name']?.toString() ?? '-';
    final studentCount = (classData['student_count'] is num)
        ? (classData['student_count'] as num).toInt()
        : 0;
    // Backend rename: `total_raports` → `total_report_cards`.
    final totalRaportsRaw =
        classData['total_report_cards'] ?? classData['total_raports'];
    final totalRaports = totalRaportsRaw is num ? totalRaportsRaw.toInt() : 0;
    final draftCount = (classData['draft_count'] is num)
        ? (classData['draft_count'] as num).toInt()
        : 0;
    final publishedCount = (classData['published_count'] is num)
        ? (classData['published_count'] as num).toInt()
        : 0;
    final pctVal = _completionPct(classData);
    final belumCount = (studentCount - totalRaports).clamp(0, 1 << 31);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => openClassReport(classData),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderRow(
                  className: className,
                  pctVal: pctVal,
                  studentCount: studentCount,
                  totalRaports: totalRaports,
                ),
                const SizedBox(height: 10),
                _buildStatsRow(publishedCount, draftCount, belumCount),
                const SizedBox(height: 10),
                _buildProgressBar(pctVal),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow({
    required String className,
    required double pctVal,
    required int studentCount,
    required int totalRaports,
  }) {
    final cobalt = ColorUtils.brandCobalt;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _ProgressRing(pctVal: pctVal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${className.toUpperCase()} · WALI',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: cobalt,
                  letterSpacing: 0.4,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Kelas $className',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                  letterSpacing: -0.2,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                '$studentCount siswa · $totalRaports raport siap',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate500,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, size: 18, color: ColorUtils.slate400),
      ],
    );
  }

  Widget _buildStatsRow(int published, int draft, int belum) {
    return Row(
      children: [
        Expanded(
          child: _StatCell(
            value: '$published',
            label: 'TERBIT',
            color: ColorUtils.success600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '$draft',
            label: 'DRAFT',
            color: ColorUtils.warning600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _StatCell(
            value: '$belum',
            label: 'BELUM',
            color: belum > 0 ? ColorUtils.error600 : ColorUtils.slate500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(double pctVal) {
    final color = completionColor(pctVal);
    return SizedBox(
      height: 5,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(
          children: [
            Container(color: ColorUtils.slate100),
            FractionallySizedBox(
              widthFactor: (pctVal / 100).clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: pctVal >= 40 && pctVal < 80
                      ? LinearGradient(
                          colors: [
                            ColorUtils.brandCobalt,
                            ColorUtils.brandAzure,
                          ],
                        )
                      : null,
                  color: pctVal >= 40 && pctVal < 80 ? null : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────

  double _completionPct(dynamic classData) {
    final pct = classData['completion_pct'] ?? 0;
    return pct is num ? pct.toDouble() : 0.0;
  }

  /// Resolves the ring + bar colour for a given percent. Public so
  /// the table-view mixin can stay in sync with the same palette.
  static Color completionColor(double pctVal) {
    if (pctVal >= 80) return ColorUtils.success600;
    if (pctVal >= 40) return ColorUtils.brandCobalt;
    if (pctVal >= 1) return ColorUtils.warning600;
    return ColorUtils.slate400;
  }
}

class _ProgressRing extends StatelessWidget {
  final double pctVal;

  const _ProgressRing({required this.pctVal});

  @override
  Widget build(BuildContext context) {
    final color = CardViewMixin.completionColor(pctVal);
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 50,
            height: 50,
            child: CircularProgressIndicator(
              value: (pctVal / 100).clamp(0.0, 1.0),
              strokeWidth: 4,
              backgroundColor: ColorUtils.slate100,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          Text(
            '${pctVal.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _StatCell({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}
