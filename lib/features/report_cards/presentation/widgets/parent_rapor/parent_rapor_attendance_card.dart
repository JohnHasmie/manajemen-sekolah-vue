import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';

class ParentRaporAttendanceCard extends StatelessWidget {
  const ParentRaporAttendanceCard({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final sick = _toInt(reportCardData['attendance_sick']);
    final permit = _toInt(reportCardData['attendance_permit']);
    final absent = _toInt(reportCardData['attendance_absent']);
    final total = _toInt(reportCardData['attendance_total']);
    final presentRaw = _toInt(reportCardData['attendance_present']);
    final present = total > 0 ? (total - sick - permit - absent) : presentRaw;

    return ParentRaporCardShell(
      child: Row(
        children: [
          Expanded(child: _cell('Hadir', present, const Color(0xFF15803D))),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(child: _cell('Sakit', sick, ColorUtils.slate900)),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(child: _cell('Izin', permit, ColorUtils.slate900)),
          Container(width: 1, height: 56, color: ColorUtils.slate100),
          Expanded(
            child: _cell(
              'Alpa',
              absent,
              absent > 0 ? const Color(0xFFB91C1C) : ColorUtils.slate900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String label, int value, Color accent) {
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
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: accent,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'hari',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: ColorUtils.slate400,
          ),
        ),
      ],
    );
  }
}
