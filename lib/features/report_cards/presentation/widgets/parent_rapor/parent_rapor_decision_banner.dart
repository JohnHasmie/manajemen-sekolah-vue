import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRaporDecisionBanner extends StatelessWidget {
  const ParentRaporDecisionBanner({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  @override
  Widget build(BuildContext context) {
    // Backend canonical: `promoted` / `not_promoted` / `graduated` /
    // `not_graduated` (was `Naik Kelas` / `Tidak Naik` / `Lulus`).
    // Map back to the Indonesian display strings the banner expects.
    final rawDecision = (reportCardData['promotion_decision'] ?? '')
        .toString()
        .trim();
    final raw = switch (rawDecision.toLowerCase()) {
      'promoted' => 'Naik Kelas',
      'not_promoted' => 'Tinggal di Kelas',
      'graduated' => 'Lulus',
      'not_graduated' => 'Tidak Lulus',
      _ => rawDecision,
    };
    if (raw.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(16)),
          border: Border.all(color: ColorUtils.slate200, width: 0.75),
        ),
        child: Row(
          children: [
            Icon(
              Icons.hourglass_top_rounded,
              size: 20,
              color: ColorUtils.slate500,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Keputusan kenaikan kelas belum diumumkan oleh sekolah.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final palette = _palette(raw);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: palette.border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: palette.fg, width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(palette.icon, size: 18, color: palette.fg),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KEPUTUSAN KENAIKAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: palette.fg,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  raw,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: palette.titleFg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({Color bg, Color border, Color fg, Color titleFg, IconData icon}) _palette(
    String decision,
  ) {
    final l = decision.toLowerCase();
    if (l.contains('tinggal') || l.contains('tidak naik')) {
      return (
        bg: const Color(0xFFFEE2E2),
        border: const Color(0xFFFCA5A5),
        fg: const Color(0xFFB91C1C),
        titleFg: const Color(0xFF7F1D1D),
        icon: Icons.cancel_outlined,
      );
    }
    if (l.contains('pertimbangan') || l.contains('belum')) {
      return (
        bg: const Color(0xFFFEF3C7),
        border: const Color(0xFFFCD34D),
        fg: const Color(0xFFB45309),
        titleFg: const Color(0xFF78350F),
        icon: Icons.help_outline_rounded,
      );
    }
    return (
      bg: const Color(0xFFDCFCE7),
      border: const Color(0xFF86EFAC),
      fg: const Color(0xFF15803D),
      titleFg: const Color(0xFF14532D),
      icon: Icons.check_rounded,
    );
  }
}
