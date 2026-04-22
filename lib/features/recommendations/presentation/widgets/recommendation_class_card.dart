// Card for a single class in the recommendation class list.
//
// Refinements:
// - Header subtitle composes "{student_count} siswa • {status}"
//   (no more empty placeholder eating vertical space).
// - Empty history branch collapses — no more large lightbulb block.
// - Two-tier CTA: solid gradient when history exists, tonal/outlined
//   when the class has no activity yet.
// - Typography normalized to 3 sizes (15/12/11) and 3 weights
//   (400/600/700) for rhythm consistency.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/recommendation_history_item.dart';

/// A class card widget showing one class with its recommendation summary.
class RecommendationClassCard extends StatelessWidget {
  final String className;
  final String classId;
  final Map<String, dynamic> classData;
  final Map<String, dynamic>? summary;
  final Color primaryColor;
  final bool isLoading;
  final bool isGenerating;
  final bool schedulesLoaded;
  final List<Map<String, dynamic>> history;
  final bool isLoadingHistory;
  final VoidCallback onGenerate;
  final VoidCallback onViewStudents;
  final void Function(Map<String, dynamic> entry) onHistoryItemTap;

  const RecommendationClassCard({
    super.key,
    required this.className,
    required this.classId,
    required this.classData,
    required this.primaryColor,
    required this.onGenerate,
    required this.onViewStudents,
    required this.onHistoryItemTap,
    this.summary,
    this.isLoading = false,
    this.isGenerating = false,
    this.schedulesLoaded = false,
    this.history = const [],
    this.isLoadingHistory = false,
  });

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

  int _readStudentCount() {
    final candidates = [
      classData['student_count'],
      classData['jumlah_siswa'],
      classData['students_count'],
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
    final byStatus = _toCountMap(summary?['by_status']);
    final byPriority = _toCountMap(summary?['by_priority']);
    final totalRec = byStatus.values.fold<int>(0, (sum, v) => sum + v);
    final completedCount = byStatus['completed'] ?? 0;
    final pendingCount = byStatus['pending'] ?? 0;
    final highPriority = byPriority['high'] ?? 0;
    final studentCount = _readStudentCount();
    final hasActivity = history.isNotEmpty || totalRec > 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        // slate200 + a deeper shadow — slate100 was blending into the slate50
        // scaffold background, making adjacent cards look like one continuous
        // surface. slate200 keeps the line quiet but visible.
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Gradient accent strip + class info ──
          _buildHeader(totalRec, studentCount),

          // ── Stats row (only when there are recs to show) ──
          if (!isLoading && totalRec > 0)
            _buildStatsRow(totalRec, completedCount, pendingCount, highPriority),

          // ── History section (collapsed when empty) ──
          if (!isLoading) _buildHistorySection(),

          // ── Action button (tiered by state) ──
          _buildActions(hasActivity: hasActivity),
        ],
      ),
    );
  }

  Widget _buildHeader(int totalRec, int studentCount) {
    final studentLabel = studentCount > 0
        ? '$studentCount siswa'
        : 'Siswa belum tersedia';
    final statusLabel = isLoading
        ? 'Memuat data...'
        : (totalRec > 0
            ? '$totalRec rekomendasi aktif'
            : 'Belum ada rekomendasi');
    final subtitle = '$studentLabel  •  $statusLabel';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor.withValues(alpha: 0.06),
            primaryColor.withValues(alpha: 0.02),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: primaryColor.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          // Class icon with gradient background
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  primaryColor.withValues(alpha: 0.15),
                  primaryColor.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Icon(
              Icons.school_rounded,
              size: 22,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 12),

          // Class name + composed subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  className,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: ColorUtils.slate800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        totalRec > 0 ? FontWeight.w600 : FontWeight.w400,
                    color: totalRec > 0
                        ? primaryColor.withValues(alpha: 0.85)
                        : ColorUtils.slate500,
                  ),
                ),
              ],
            ),
          ),

          // View students button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onViewStudents,
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.08),
                  borderRadius: const BorderRadius.all(Radius.circular(8)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_alt_rounded,
                      size: 14,
                      color: primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Siswa',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(
    int total,
    int completed,
    int pending,
    int highPriority,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _StatBadge(
              icon: Icons.auto_awesome_rounded,
              label: 'Total',
              value: '$total',
              color: primaryColor,
            ),
            const SizedBox(width: 8),
            if (completed > 0) ...[
              _StatBadge(
                icon: Icons.check_circle_outline_rounded,
                label: 'Diterapkan',
                value: '$completed',
                color: ColorUtils.emerald500,
              ),
              const SizedBox(width: 8),
            ],
            if (pending > 0) ...[
              _StatBadge(
                icon: Icons.schedule_rounded,
                label: 'Belum',
                value: '$pending',
                color: ColorUtils.amber500,
              ),
              const SizedBox(width: 8),
            ],
            if (highPriority > 0)
              _StatBadge(
                icon: Icons.priority_high_rounded,
                label: 'Penting',
                value: '$highPriority',
                color: ColorUtils.red500,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (isLoadingHistory) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: primaryColor,
            ),
          ),
        ),
      );
    }

    // Empty history: collapse entirely. The CTA + subtitle already
    // tell the user there's nothing here; no placeholder needed.
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 14,
                  color: ColorUtils.slate400,
                ),
                const SizedBox(width: 4),
                Text(
                  'Riwayat (${history.length} sesi)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: ColorUtils.slate500,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          ...history.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: RecommendationHistoryItem(
                  entry: entry,
                  primaryColor: primaryColor,
                  onTap: () => onHistoryItemTap(entry),
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildActions({required bool hasActivity}) {
    if (!schedulesLoaded) return const SizedBox.shrink();

    // Tonal/outlined CTA for empty classes, solid gradient once
    // there's history or active recs. Reinforces primary action
    // without overwhelming the card when nothing's happened yet.
    return Padding(
      padding: EdgeInsets.fromLTRB(12, hasActivity ? 4 : 12, 12, 12),
      child: hasActivity
          ? _buildPrimaryCta()
          : _buildTonalCta(),
    );
  }

  Widget _buildPrimaryCta() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGenerating ? null : onGenerate,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isGenerating
                  ? [
                      primaryColor.withValues(alpha: 0.85),
                      primaryColor.withValues(alpha: 0.7),
                    ]
                  : [primaryColor, primaryColor.withValues(alpha: 0.9)],
            ),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            boxShadow: isGenerating
                ? []
                : [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isGenerating)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                )
              else
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: Colors.white,
                ),
              const SizedBox(width: 8),
              Text(
                isGenerating
                    ? 'Sedang memproses...'
                    : 'Generate Rekomendasi AI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(
                    alpha: isGenerating ? 0.9 : 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTonalCta() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isGenerating ? null : onGenerate,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(
              color: primaryColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isGenerating)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: primaryColor,
                  ),
                )
              else
                Icon(
                  Icons.auto_awesome_outlined,
                  size: 16,
                  color: primaryColor,
                ),
              const SizedBox(width: 8),
              Text(
                isGenerating
                    ? 'Sedang memproses...'
                    : 'Mulai Generate Rekomendasi',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact stat badge with icon + value + label.
class _StatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
