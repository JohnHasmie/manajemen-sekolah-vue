// Displays a single grouped-history row inside an expanded class card.
// Like a Vue list-item component: shows date, period badge, and stat mini-tags.
// Navigation and post-navigation refresh are injected via [onTap] callback.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A tappable history row for one recommendation generation session.
///
/// Constructor params replace all references to parent state:
/// - [entry] -- grouped history map with keys: date, count, trigger_source,
///   by_status, by_priority
/// - [onTap] -- called when the row is tapped; the parent handles navigation
///   and subsequent data refresh (replaces the inline AppNavigator.push + .then)
class RecommendationHistoryItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final VoidCallback onTap;

  const RecommendationHistoryItem({
    super.key,
    required this.entry,
    required this.onTap,
  });

  // ---- helpers ----

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

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMMM yyyy', 'id_ID').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String _getRelativeDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final target = DateTime(date.year, date.month, date.day);
      final diff = today.difference(target).inDays;

      if (diff == 0) return 'Hari ini';
      if (diff == 1) return 'Kemarin';
      if (diff < 7) return '$diff hari lalu';
      return _formatDate(dateStr);
    } catch (_) {
      return dateStr;
    }
  }

  /// Maps trigger_source to display color, label, and icon.
  ({Color color, String label, IconData icon}) _getPeriodInfo(
    String triggerSource,
  ) {
    switch (triggerSource) {
      case 'weekly_review':
        return (
          color: ColorUtils.corporateBlue500,
          label: 'Pekanan',
          icon: Icons.date_range_rounded,
        );
      case 'post_exam':
        return (
          color: ColorUtils.violet500,
          label: 'Bulanan/UTS',
          icon: Icons.calendar_month_rounded,
        );
      case 'attendance_alert':
        return (
          color: ColorUtils.red500,
          label: 'Kehadiran',
          icon: Icons.warning_amber_rounded,
        );
      case 'on_demand':
      default:
        return (
          color: ColorUtils.amber500,
          label: 'Semester',
          icon: Icons.emoji_events_rounded,
        );
    }
  }

  Widget _buildMiniTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final date = entry['date'] as String;
    final count = entry['count'] is int
        ? entry['count'] as int
        : int.tryParse(entry['count'].toString()) ?? 0;
    final triggerSource = entry['trigger_source']?.toString() ?? 'on_demand';
    final byStatus = _toCountMap(entry['by_status']);
    final byPriority = _toCountMap(entry['by_priority']);
    final highCount = byPriority['high'] ?? 0;
    final pendingCount = byStatus['pending'] ?? 0;
    final completedCount = byStatus['completed'] ?? 0;

    final periodInfo = _getPeriodInfo(triggerSource);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: Row(
            children: [
              // Period icon with color
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: periodInfo.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: periodInfo.color.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  periodInfo.icon,
                  size: 18,
                  color: periodInfo.color,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getRelativeDate(date),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ColorUtils.slate800,
                            ),
                          ),
                        ),
                        // Period badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: periodInfo.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: periodInfo.color.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Text(
                            periodInfo.label,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: periodInfo.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        _buildMiniTag(
                          '$count rekomendasi',
                          ColorUtils.slate600,
                        ),
                        if (highCount > 0)
                          _buildMiniTag(
                            '$highCount prioritas tinggi',
                            ColorUtils.red500,
                          ),
                        if (pendingCount > 0)
                          _buildMiniTag(
                            '$pendingCount pending',
                            ColorUtils.amber500,
                          ),
                        if (completedCount > 0)
                          _buildMiniTag(
                            '$completedCount selesai',
                            ColorUtils.emerald500,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: ColorUtils.slate400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
