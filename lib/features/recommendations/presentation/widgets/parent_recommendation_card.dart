// Frame B parent rec card — one tap-through tile per recommendation
// in the per-child list. Shows the wali-kelas avatar + meta line,
// priority / subject / completed status pills, the rec title +
// HTML description, an optional tenggat (due-date) chip, and a dual
// "Lihat Detail" / "Buka" CTA. Unread rows get an azure ring + dot.
//
// Extracted verbatim from `parent_recommendation_screen.dart` during
// the Phase 2 readability split — behaviour is identical.
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/recommendations/presentation/widgets/parent_recommendation_status_chips.dart';

class ParentRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final Color azure;
  final VoidCallback onTap;

  const ParentRecommendationCard({
    super.key,
    required this.row,
    required this.azure,
    required this.onTap,
  });

  Map<String, dynamic> get _rec {
    final r = row['recommendation'];
    return r is Map ? Map<String, dynamic>.from(r) : <String, dynamic>{};
  }

  String? get _teacherName {
    final t = _rec['teacher'];
    if (t is Map) {
      final n = t['name']?.toString();
      if (n != null && n.isNotEmpty) return n;
    }
    return _rec['teacher_name']?.toString();
  }

  String? get _subjectName {
    final s =
        _rec['subject_school'] ?? _rec['subjectSchool'] ?? _rec['subject'];
    if (s is Map) return s['name']?.toString();
    return _rec['subject_name']?.toString();
  }

  String _fmtAgo(dynamic ts) {
    if (ts == null) return 'baru saja';
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
      if (diff.inHours < 24) return '${diff.inHours}j lalu';
      if (diff.inDays < 7) return '${diff.inDays}h lalu';
      return '${dt.day}/${dt.month}/${dt.year % 100}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUnread = row['read_at'] == null;
    final isCompleted =
        row['parent_completed_at'] != null ||
        _rec['status']?.toString().toLowerCase() == 'completed';
    final priority = _rec['priority']?.toString().toLowerCase() ?? 'low';
    final priorityColor = priority == 'high'
        ? ColorUtils.error600
        : priority == 'medium'
        ? ColorUtils.warning600
        : ColorUtils.slate500;
    final priorityLabel = priority == 'high'
        ? 'PRIORITAS TINGGI'
        : priority == 'medium'
        ? 'PRIORITAS SEDANG'
        : 'PRIORITAS RENDAH';
    final dueDate = _rec['due_date'];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isUnread
                    ? azure.withValues(alpha: 0.30)
                    : ColorUtils.slate200,
                width: isUnread ? 1.5 : 1,
              ),
              boxShadow: isUnread
                  ? [
                      BoxShadow(
                        color: azure.withValues(alpha: 0.10),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: azure.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        parentRecInitials(_teacherName ?? 'WK'),
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: azure,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _teacherName ?? 'Wali Kelas',
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: ColorUtils.slate900,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            [
                              if (_subjectName != null) _subjectName!,
                              'Wali Kelas',
                              _fmtAgo(row['sent_at']),
                            ].join(' · '),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: azure.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'WALI KELAS',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: azure,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5,
                  runSpacing: 4,
                  children: [
                    ParentRecStatusPill(
                      label: priorityLabel,
                      color: priorityColor,
                    ),
                    if (_subjectName != null)
                      ParentRecStatusPill(
                        label: _subjectName!.toUpperCase(),
                        color: ColorUtils.indigo600,
                      ),
                    if (isCompleted)
                      ParentRecStatusPill(
                        label: 'SELESAI',
                        color: ColorUtils.success600,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _rec['title']?.toString() ?? 'Rekomendasi',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isCompleted
                        ? ColorUtils.slate500
                        : ColorUtils.slate900,
                    letterSpacing: -0.2,
                    height: 1.3,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 5),
                HtmlWidget(
                  _rec['description']?.toString() ?? '',
                  textStyle: TextStyle(
                    fontSize: 12,
                    color: ColorUtils.slate600,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
                if (dueDate != null && !isCompleted) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: ColorUtils.warning600.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: ColorUtils.warning600.withValues(alpha: 0.14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: ColorUtils.warning600,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Tenggat ${_fmtDate(dueDate)}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: ColorUtils.warning600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: azure.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'Lihat Detail',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: azure,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: azure,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: azure.withValues(alpha: 0.30),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'Buka',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isUnread)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: azure, shape: BoxShape.circle),
              ),
            ),
        ],
      ),
    );
  }

  String _fmtDate(dynamic ts) {
    try {
      final dt = DateTime.parse(ts.toString()).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'Mei',
        'Jun',
        'Jul',
        'Agu',
        'Sep',
        'Okt',
        'Nov',
        'Des',
      ];
      return '${dt.day} ${months[dt.month - 1]}';
    } catch (_) {
      return ts.toString();
    }
  }
}
