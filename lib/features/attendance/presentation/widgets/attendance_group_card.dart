import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Grouped attendance card — shows class+subject with
/// average-present ring, session count, and latest records.
class AttendanceGroupCard extends StatelessWidget {
  final dynamic group;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onTap;

  /// When true, the card was rendered inside the Wali Kelas tab — we show
  /// the recording teacher's name as an extra row so the homeroom teacher
  /// can see WHO took the attendance across teachers sharing the class.
  final bool isHomeroomView;

  const AttendanceGroupCard({
    super.key,
    required this.group,
    required this.primaryColor,
    required this.languageProvider,
    required this.onTap,
    this.isHomeroomView = false,
  });

  @override
  Widget build(BuildContext context) {
    final cn = group['class_name']?.toString() ?? '-';
    final sn = group['subject_name']?.toString() ?? '-';
    final totalSessions = group['total_sessions'] ?? 0;
    final avgPct = (group['avg_present_pct'] ?? 0).toDouble();
    final latest = (group['latest_records'] as List?) ?? [];
    final pctColor = _pctColor(avgPct);
    final teacherName = group['teacher_name']?.toString() ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ColorUtils.slate200),
              boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _headerRow(cn, sn, totalSessions, avgPct, pctColor),
                if (isHomeroomView && teacherName.isNotEmpty)
                  _teacherRow(teacherName),
                if (latest.isNotEmpty) _latestRecords(latest),
                const SizedBox(height: 8),
                _footerRow(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Teacher name row — matches the Rekomendasi / Materi wali-kelas style.
  Widget _teacherRow(String name) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 56),
      child: Row(
        children: [
          Icon(Icons.person_rounded, size: 13, color: ColorUtils.slate400),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 11.5,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(
    String cn,
    String sn,
    int totalSessions,
    double avgPct,
    Color pctColor,
  ) {
    return Row(
      children: [
        _percentageRing(avgPct, pctColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Kelas: $cn',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                sn,
                style: TextStyle(
                  fontSize: 12,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _sessionBadge(totalSessions),
      ],
    );
  }

  Widget _percentageRing(double avgPct, Color pctColor) {
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
              value: avgPct / 100,
              strokeWidth: 4,
              backgroundColor: ColorUtils.slate100,
              color: pctColor,
            ),
          ),
          Text(
            '${avgPct.toStringAsFixed(0)}%',
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

  Widget _sessionBadge(int totalSessions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$totalSessions',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: primaryColor,
            ),
          ),
          Text(
            languageProvider.getTranslatedText({
              'en': 'meets',
              'id': 'pertemuan',
            }),
            style: TextStyle(
              fontSize: 8,
              color: primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _latestRecords(List<dynamic> latest) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: latest
              .asMap()
              .entries
              .map((e) => _recordRow(e.key, e.value))
              .toList(),
        ),
      ),
    );
  }

  Widget _recordRow(int index, dynamic r) {
    final present = r['present'] ?? 0;
    final total = r['total'] ?? 0;
    return Padding(
      padding: EdgeInsets.only(top: index > 0 ? 6 : 0),
      child: Row(
        children: [
          Icon(
            Icons.calendar_today_rounded,
            size: 12,
            color: ColorUtils.slate400,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              _fmtFullDate(r['date']?.toString()),
              style: TextStyle(
                fontSize: 11,
                color: ColorUtils.slate600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$present/$total',
            style: TextStyle(
              fontSize: 12,
              color: present == total
                  ? ColorUtils.success600
                  : ColorUtils.warning600,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            languageProvider.getTranslatedText({
              'en': 'present',
              'id': 'hadir',
            }),
            style: TextStyle(fontSize: 10, color: ColorUtils.slate400),
          ),
        ],
      ),
    );
  }

  Widget _footerRow() {
    return Row(
      children: [
        Icon(Icons.update_rounded, size: 14, color: ColorUtils.slate400),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${languageProvider.getTranslatedText({'en': 'Latest', 'id': 'Terbaru'})}: ${_fmtFullDate(group['latest_date']?.toString())}',
            style: TextStyle(fontSize: 11, color: ColorUtils.slate400),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                languageProvider.getTranslatedText({
                  'en': 'View All',
                  'id': 'Lihat Semua',
                }),
                style: TextStyle(
                  fontSize: 11,
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 14, color: primaryColor),
            ],
          ),
        ),
      ],
    );
  }

  static Color _pctColor(double pct) {
    if (pct >= 80) return ColorUtils.success600;
    if (pct >= 60) return ColorUtils.warning600;
    return ColorUtils.error600;
  }

  static String _fmtFullDate(String? d) {
    if (d == null) return '-';
    final dt = DateTime.tryParse(d);
    if (dt == null) return d;
    return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dt);
  }
}
