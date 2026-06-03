// Type-aware 3-cell KPI overlap card for the teacher activity-detail screen.
//
// Extracted verbatim from `_TeacherActivityDetailScreenState._buildKpiCard`
// (plus its `_fmt` / `_kpiCell` / `_kpiDivider` helpers):
//   tugas / ujian       → Siswa · Submit · Belum  (submission tracking)
//   aktivitas / catatan → Siswa · Target · Hari    (no submissions to track,
//                          so we surface useful context instead of 0/0)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// 3-cell KPI strip that overlaps the bottom of the gradient header.
///
/// Reads its counts/labels from the merged activity map [a] using the
/// same fallback key pairs the original State did.
class ActivityDetailKpiCard extends StatelessWidget {
  final Map<String, dynamic> a;
  final LanguageProvider lp;

  const ActivityDetailKpiCard({super.key, required this.a, required this.lp});

  @override
  Widget build(BuildContext context) {
    final type = (a['type'] ?? a['tipe'] ?? '').toString().toLowerCase();
    final tracksSubmissions =
        type == 'tugas' ||
        type == 'assignment' ||
        type == 'ujian' ||
        type == 'exam' ||
        type == 'kuis' ||
        type == 'quiz';

    final siswa = a['student_count'] ?? a['jumlah_siswa'];

    Widget content;
    if (tracksSubmissions) {
      final submit = a['submission_count'] ?? a['jumlah_submit'];
      final belum = siswa is num && submit is num
          ? (siswa.toInt() - submit.toInt())
          : null;
      content = Row(
        children: [
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
            value: _fmt(siswa),
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Submit', 'id': 'Submit'}),
            value: _fmt(submit),
            color: ColorUtils.info600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Pending', 'id': 'Belum'}),
            value: _fmt(belum),
            color: ColorUtils.warning600,
          ),
        ],
      );
    } else {
      // aktivitas / catatan — surface Siswa · Target · Hari instead.
      final targetRole = (a['target_role'] ?? '').toString().toLowerCase();
      final targetLabel = targetRole == 'khusus'
          ? lp.getTranslatedText({'en': 'Selected', 'id': 'Khusus'})
          : lp.getTranslatedText({'en': 'All', 'id': 'Umum'});
      final dateStr = (a['date'] ?? a['tanggal'] ?? '').toString();
      final d = DateTime.tryParse(dateStr);
      final dayLabel = d != null
          ? DateFormat('EEEE', 'id_ID').format(d)
          : ((a['day'] ?? a['hari'] ?? '—').toString());
      content = Row(
        children: [
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Students', 'id': 'Siswa'}),
            value: _fmt(siswa),
            color: ColorUtils.success600,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Target', 'id': 'Target'}),
            value: targetLabel,
            color: ColorUtils.violet700,
            isText: true,
          ),
          _kpiDivider(),
          _kpiCell(
            label: lp.getTranslatedText({'en': 'Day', 'id': 'Hari'}),
            value: dayLabel,
            color: ColorUtils.info600,
            isText: true,
          ),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: [
            BoxShadow(
              color: ColorUtils.slate900.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        child: content,
      ),
    );
  }

  String _fmt(dynamic v) => v is num ? '${v.toInt()}' : '—';

  Widget _kpiCell({
    required String label,
    required String value,
    required Color color,
    bool isText = false,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              // Numeric KPIs use display sizing; text values (Umum/Senin)
              // use a smaller weight so longer words don't overflow the
              // narrow cell.
              fontSize: isText ? 15 : 22,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
              letterSpacing: isText ? -0.2 : -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: ColorUtils.slate500,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _kpiDivider() =>
      Container(width: 1, height: 28, color: ColorUtils.slate100);
}
