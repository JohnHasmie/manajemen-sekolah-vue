import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Timeline-view attendance card — a compact row
/// showing date, class+subject badge, and present/total.
class AttendanceTimelineCard extends StatelessWidget {
  final dynamic record;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  const AttendanceTimelineCard({
    super.key,
    required this.record,
    required this.primaryColor,
    required this.languageProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final classObj = record['class'];
    final subjectObj = record['subject'];
    final lhObj = record['lesson_hour'] ?? record['lessonHour'];
    final cn =
        record['class_name']?.toString() ??
        (classObj is Map ? classObj['name']?.toString() : null) ??
        record['kelas_nama']?.toString() ??
        '-';
    final sn =
        record['subject_name']?.toString() ??
        (subjectObj is Map ? subjectObj['name']?.toString() : null) ??
        record['mata_pelajaran_nama']?.toString() ??
        '-';
    final dateStr = _fmtFullDate(record['date']?.toString());
    final present = _parseInt(record['present'] ?? record['present_count']);
    final total = _parseInt(record['total_students']);
    final lhName =
        record['lesson_hour_name']?.toString() ??
        (lhObj is Map ? lhObj['name']?.toString() : null);
    final pctColor = _resolveColor(present, total);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorUtils.slate200),
            ),
            child: Row(
              children: [
                _ring(present, total, pctColor),
                const SizedBox(width: 12),
                Expanded(
                  child: _content(
                    dateStr,
                    cn,
                    sn,
                    present,
                    total,
                    pctColor,
                    lhName,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _ring(int present, int total, Color pctColor) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: total > 0 ? present / total : 0,
              strokeWidth: 3.5,
              backgroundColor: ColorUtils.slate100,
              color: pctColor,
            ),
          ),
          Text(
            total > 0 ? '${(present / total * 100).toStringAsFixed(0)}%' : '-',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: pctColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _content(
    String dateStr,
    String cn,
    String sn,
    int present,
    int total,
    Color pctColor,
    String? lhName,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                dateStr,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate800,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$present/$total',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: pctColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '$cn · $sn',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lhName != null && lhName.isNotEmpty) ...[
              const SizedBox(width: 6),
              Icon(
                Icons.access_time_rounded,
                size: 10,
                color: ColorUtils.slate400,
              ),
              const SizedBox(width: 2),
              Text(
                lhName,
                style: TextStyle(fontSize: 10, color: ColorUtils.slate500),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // ── Helpers ──

  static int _parseInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

  static Color _resolveColor(int present, int total) {
    if (total <= 0) return ColorUtils.error600;
    final ratio = present / total;
    if (ratio >= 0.8) return ColorUtils.success600;
    if (ratio >= 0.6) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  static String _fmtFullDate(String? d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
  }
}
