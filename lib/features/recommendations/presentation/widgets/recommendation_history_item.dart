// Displays a single grouped-history row inside a class card.
// Redesigned with a sleek horizontal layout: colored left dot indicator,
// relative date, period pill, and inline stat chips.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A tappable history row for one recommendation generation session.
class RecommendationHistoryItem extends StatelessWidget {
  final Map<String, dynamic> entry;
  final Color primaryColor;
  final VoidCallback onTap;

  const RecommendationHistoryItem({
    super.key,
    required this.entry,
    required this.primaryColor,
    required this.onTap,
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
      return DateFormat('d MMM yyyy', 'id').format(date);
    } catch (_) {
      return dateStr;
    }
  }

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
          label: 'UTS/UAS',
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
          label: 'On Demand',
          icon: Icons.auto_awesome_rounded,
        );
    }
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
    final completedCount = byStatus['completed'] ?? 0;

    final periodInfo = _getPeriodInfo(triggerSource);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
            border: Border.all(color: ColorUtils.slate100),
          ),
          child: Row(
            children: [
              // Colored dot indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: periodInfo.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),

              // Date + period
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          _getRelativeDate(date),
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: ColorUtils.slate700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _PeriodPill(
                          label: periodInfo.label,
                          color: periodInfo.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Inline stats
                    Row(
                      children: [
                        _InlineStat('$count rekomendasi', ColorUtils.slate500),
                        if (highCount > 0) ...[
                          _dot(),
                          _InlineStat('$highCount penting', ColorUtils.red500),
                        ],
                        if (completedCount > 0) ...[
                          _dot(),
                          _InlineStat(
                            '$completedCount diterapkan',
                            ColorUtils.emerald500,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: ColorUtils.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dot() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Container(
        width: 3,
        height: 3,
        decoration: BoxDecoration(
          color: ColorUtils.slate300,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PeriodPill extends StatelessWidget {
  final String label;
  final Color color;

  const _PeriodPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _InlineStat extends StatelessWidget {
  final String text;
  final Color color;

  const _InlineStat(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }
}
