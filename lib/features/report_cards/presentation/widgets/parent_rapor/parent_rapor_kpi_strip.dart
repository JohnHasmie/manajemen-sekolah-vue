import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';

class ParentRaporKpiStrip extends StatelessWidget {
  const ParentRaporKpiStrip({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  double? _avg() {
    // Backend rename: `raport_subjects` → `report_card_subjects`.
    final subjects =
        (reportCardData['reportCardSubjects'] ??
                reportCardData['report_card_subjects'] ??
                reportCardData['raportSubjects'] ??
                reportCardData['raport_subjects'] ??
                const [])
            as List<dynamic>;
    if (subjects.isEmpty) return null;
    var sum = 0.0;
    var count = 0;
    for (final raw in subjects) {
      final s = raw as Map;
      final k = _toDouble(s['knowledge_score']);
      final sk = _toDouble(s['skill_score']);
      if (k != null && sk != null) {
        sum += (k + sk) / 2;
        count++;
      } else if (k != null) {
        sum += k;
        count++;
      } else if (sk != null) {
        sum += sk;
        count++;
      }
    }
    return count == 0 ? null : sum / count;
  }

  double? _attendance() {
    int toInt(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString()) ?? 0;
    }

    final total = toInt(reportCardData['attendance_total']);
    final sick = toInt(reportCardData['attendance_sick']);
    final permit = toInt(reportCardData['attendance_permit']);
    final absent = toInt(reportCardData['attendance_absent']);
    final present = toInt(reportCardData['attendance_present']);
    final denom = total > 0 ? total : (present + sick + permit + absent);
    if (denom == 0) return null;
    return ((denom - sick - permit - absent) / denom) * 100;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String _avgPredikat(double? avg) {
    if (avg == null) return '–';
    if (avg >= 85) return 'Sangat Baik';
    if (avg >= 75) return 'Baik';
    if (avg >= 65) return 'Cukup';
    return 'Perlu Dukungan';
  }

  Color _avgFg(double? avg) {
    if (avg == null) return ColorUtils.slate500;
    if (avg >= 85) return const Color(0xFF15803D);
    if (avg >= 75) return const Color(0xFF1D4ED8);
    if (avg >= 65) return const Color(0xFFB45309);
    return const Color(0xFFB91C1C);
  }

  Color _avgBg(double? avg) {
    if (avg == null) return ColorUtils.slate100;
    if (avg >= 85) return const Color(0xFFDCFCE7);
    if (avg >= 75) return const Color(0xFFDBEAFE);
    if (avg >= 65) return const Color(0xFFFEF3C7);
    return const Color(0xFFFEE2E2);
  }

  @override
  Widget build(BuildContext context) {
    final avg = _avg();
    final att = _attendance();
    final sikap =
        (reportCardData['social_predicate'] ??
                reportCardData['spiritual_predicate'] ??
                '')
            .toString();

    return ParentRaporCardShell(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: _kpiCell(
              label: 'Rata-rata',
              value: avg == null
                  ? '–'
                  : avg.toStringAsFixed(1).replaceAll('.', ','),
              accent: _avgFg(avg),
              pillBg: _avgBg(avg),
              pillFg: _avgFg(avg),
              pillText: _avgPredikat(avg),
            ),
          ),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _kpiCell(
              label: 'Sikap',
              value: _sikapLetter(sikap),
              accent: _sikapAccent(sikap),
              pillBg: _sikapBg(sikap),
              pillFg: _sikapAccent(sikap),
              pillText: sikap.isEmpty ? '–' : sikap,
            ),
          ),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _kpiCell(
              label: 'Kehadiran',
              value: att == null ? '–' : '${att.toStringAsFixed(0)}%',
              accent: att == null
                  ? ColorUtils.slate500
                  : (att >= 90
                        ? const Color(0xFF15803D)
                        : (att >= 80
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFB45309))),
              pillBg: att == null
                  ? ColorUtils.slate100
                  : (att >= 90
                        ? const Color(0xFFDCFCE7)
                        : (att >= 80
                              ? const Color(0xFFDBEAFE)
                              : const Color(0xFFFEF3C7))),
              pillFg: att == null
                  ? ColorUtils.slate500
                  : (att >= 90
                        ? const Color(0xFF15803D)
                        : (att >= 80
                              ? const Color(0xFF1D4ED8)
                              : const Color(0xFFB45309))),
              pillText: att == null ? '–' : 'Hadir reguler',
            ),
          ),
        ],
      ),
    );
  }

  String _sikapLetter(String pred) {
    if (pred.isEmpty) return '–';
    final p = pred.toLowerCase();
    if (p.contains('sangat baik')) return 'A';
    if (p.contains('baik')) return 'B';
    if (p.contains('cukup')) return 'C';
    return 'D';
  }

  Color _sikapAccent(String pred) {
    final l = _sikapLetter(pred);
    if (l == 'A') return const Color(0xFF15803D);
    if (l == 'B') return const Color(0xFF1D4ED8);
    if (l == 'C') return const Color(0xFFB45309);
    return ColorUtils.slate500;
  }

  Color _sikapBg(String pred) {
    final l = _sikapLetter(pred);
    if (l == 'A') return const Color(0xFFDCFCE7);
    if (l == 'B') return const Color(0xFFDBEAFE);
    if (l == 'C') return const Color(0xFFFEF3C7);
    return ColorUtils.slate100;
  }

  Widget _kpiCell({
    required String label,
    required String value,
    required Color accent,
    required Color pillBg,
    required Color pillFg,
    required String pillText,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: ColorUtils.slate900,
            height: 1.1,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: pillBg,
            borderRadius: const BorderRadius.all(Radius.circular(9)),
          ),
          child: Text(
            pillText,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: pillFg,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
