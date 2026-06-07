// Grid-view tile for the rekomendasi hub — the 2-column compact
// variant of [RecommendationClassCard]. Shown when the teacher flips
// the header view-toggle to grid mode.
//
// Layout, top to bottom:
//   • Top row — cobalt class icon + total-count badge (or a spinner
//     while the summary is still loading).
//   • Class name + student-count line.
//   • Divider.
//   • Summary block — skeleton lines while loading, status pills +
//     "Terakhir: X" once there's activity, or a tiny "Tap Generate"
//     hint when empty.
//   • Generate CTA — gradient when the class has activity, dashed-tonal
//     when empty, spinner while generating.
//
// Extracted verbatim from `build_mixin.dart` during the Phase 2
// readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

class RecommendationClassGridTile extends StatelessWidget {
  final Color primaryColor;
  final Map<String, dynamic> classData;
  final Map<String, dynamic>? summary;
  final List<Map<String, dynamic>> history;
  final bool isGenerating;
  final bool isLoadingSummary;
  final VoidCallback onTap;
  final VoidCallback onGenerate;

  const RecommendationClassGridTile({
    super.key,
    required this.primaryColor,
    required this.classData,
    required this.summary,
    required this.history,
    required this.isGenerating,
    required this.isLoadingSummary,
    required this.onTap,
    required this.onGenerate,
  });

  /// Normalize a `by_status` / `by_priority` map into an int map.
  /// Summary JSON sometimes comes through as `{completed: "3"}` instead of
  /// `{completed: 3}`, so we parse defensively.
  Map<String, int> _toCountMap(dynamic data) {
    if (data is Map) {
      return data.map(
        (k, v) => MapEntry(
          k.toString(),
          v is int ? v : int.tryParse(v.toString()) ?? 0,
        ),
      );
    }
    return {};
  }

  /// Flattened summary view for the class — drives the grid tile badges.
  ({int total, int completed, int pending, int highPriority}) _summaryFor() {
    final byStatus = _toCountMap(summary?['by_status']);
    final byPriority = _toCountMap(summary?['by_priority']);
    final total = byStatus.values.fold<int>(0, (s, v) => s + v);
    return (
      total: total,
      completed: byStatus['completed'] ?? 0,
      pending: byStatus['pending'] ?? 0,
      highPriority: byPriority['high'] ?? 0,
    );
  }

  /// Most recent generation date for the class, formatted "12 Apr" (id_ID),
  /// or null if there's no history yet.
  String? _latestHistoryLabel() {
    if (history.isEmpty) return null;
    final raw = history.first['date']?.toString();
    if (raw == null || raw.isEmpty) return null;
    try {
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return null;
      // Short form: "12 Apr" fits inside the narrow grid tile.
      return DateFormat('d MMM', 'id_ID').format(parsed);
    } catch (_) {
      return null;
    }
  }

  int _readStudentCount() {
    final candidates = [
      classData['students_count'],
      classData['student_count'],
      classData['jumlah_siswa'],
    ];
    for (final c in candidates) {
      if (c is int) return c;
      if (c != null) {
        final parsed = int.tryParse(c.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final className = (classData['name'] ?? classData['nama'] ?? 'Kelas')
        .toString();
    final studentCount = _readStudentCount();

    final s = _summaryFor();
    final hasActivity = s.total > 0;
    final lastRun = _latestHistoryLabel();

    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.all(Radius.circular(16)),
            // Stronger border + shadow: slate100 on white cards over a
            // slate50 scaffold blends nearly invisibly. slate200 + a deeper
            // shadow clearly separates each tile.
            border: Border.all(
              color: hasActivity
                  ? primaryColor.withValues(alpha: 0.22)
                  : ColorUtils.slate200,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGridTopRow(
                  primaryColor: primaryColor,
                  total: s.total,
                  hasActivity: hasActivity,
                  isLoadingSummary: isLoadingSummary,
                ),
                const SizedBox(height: 12),
                Text(
                  className,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  studentCount > 0
                      ? '$studentCount siswa'
                      : 'Siswa belum tersedia',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
                const SizedBox(height: 10),
                Divider(height: 1, thickness: 1, color: ColorUtils.slate100),
                const SizedBox(height: 10),
                Expanded(
                  child: _buildGridSummaryBlock(
                    primaryColor: primaryColor,
                    isLoadingSummary: isLoadingSummary,
                    hasActivity: hasActivity,
                    completed: s.completed,
                    pending: s.pending,
                    highPriority: s.highPriority,
                    lastRun: lastRun,
                  ),
                ),
                const SizedBox(height: 10),
                _buildGridCta(
                  primaryColor: primaryColor,
                  hasActivity: hasActivity,
                  isGenerating: isGenerating,
                  onTap: isGenerating ? null : onGenerate,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Top row: class icon + total-count badge (or "AI" hint when loading).
  Widget _buildGridTopRow({
    required Color primaryColor,
    required int total,
    required bool hasActivity,
    required bool isLoadingSummary,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryColor.withValues(alpha: 0.15),
                primaryColor.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          child: Icon(Icons.school_rounded, size: 18, color: primaryColor),
        ),
        const Spacer(),
        if (isLoadingSummary)
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 1.6,
              color: primaryColor.withValues(alpha: 0.6),
            ),
          )
        else if (hasActivity)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 10, color: primaryColor),
                const SizedBox(width: 4),
                Text(
                  '$total',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Summary block (between divider and CTA).
  /// - While the summary is still loading: skeleton lines so users know data
  ///   is coming.
  /// - When the class has activity: status pills + "Terakhir: X" row.
  /// - When empty: tiny encouragement copy instead of blank space.
  Widget _buildGridSummaryBlock({
    required Color primaryColor,
    required bool isLoadingSummary,
    required bool hasActivity,
    required int completed,
    required int pending,
    required int highPriority,
    required String? lastRun,
  }) {
    if (isLoadingSummary) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _gridSkeletonLine(width: 90),
          const SizedBox(height: 6),
          _gridSkeletonLine(width: 60),
        ],
      );
    }

    if (!hasActivity) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                Icons.insights_rounded,
                size: 14,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Belum ada rekomendasi',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'Tap Generate untuk mulai',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w400,
              color: ColorUtils.slate400,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status pills row: Diterapkan / Pending / High-priority flag.
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _gridStatusPill(
              icon: Icons.check_circle_rounded,
              label: '$completed ${kRecApplied.tr}',
              color: const Color(0xFF16A34A), // green-600
            ),
            if (pending > 0)
              _gridStatusPill(
                icon: Icons.schedule_rounded,
                label: '$pending ${kRecPendingLower.tr}',
                color: const Color(0xFFD97706), // amber-600
              ),
            if (highPriority > 0)
              _gridStatusPill(
                icon: Icons.priority_high_rounded,
                label: '$highPriority ${kRecImportant.tr}',
                color: const Color(0xFFDC2626), // red-600
              ),
          ],
        ),
        const Spacer(),
        if (lastRun != null)
          Row(
            children: [
              Icon(Icons.event_rounded, size: 11, color: ColorUtils.slate400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Terakhir: $lastRun',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate500,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _gridStatusPill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: const BorderRadius.all(Radius.circular(6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridSkeletonLine({required double width}) {
    return Container(
      width: width,
      height: 10,
      decoration: BoxDecoration(
        color: ColorUtils.slate100,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
    );
  }

  Widget _buildGridCta({
    required Color primaryColor,
    required bool hasActivity,
    required bool isGenerating,
    required VoidCallback? onTap,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isGenerating)
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: hasActivity ? Colors.white : primaryColor,
            ),
          )
        else
          Icon(
            hasActivity
                ? Icons.auto_awesome_rounded
                : Icons.auto_awesome_outlined,
            size: 13,
            color: hasActivity ? Colors.white : primaryColor,
          ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            isGenerating ? kRecProcessing.tr : 'Generate',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: hasActivity ? Colors.white : primaryColor,
            ),
          ),
        ),
      ],
    );

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: hasActivity
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [primaryColor, primaryColor.withValues(alpha: 0.9)],
                )
              : null,
          color: hasActivity ? null : primaryColor.withValues(alpha: 0.08),
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: hasActivity
              ? null
              : Border.all(color: primaryColor.withValues(alpha: 0.25)),
        ),
        child: child,
      ),
    );
  }
}
