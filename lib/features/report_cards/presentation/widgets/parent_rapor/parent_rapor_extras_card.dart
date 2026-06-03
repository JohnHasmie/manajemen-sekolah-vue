import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';

class ParentRaporExtrasCard extends StatelessWidget {
  const ParentRaporExtrasCard({super.key, required this.extras});

  final List<dynamic> extras;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Column(
        children: [
          for (var i = 0; i < extras.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: ColorUtils.slate100),
              const SizedBox(height: 10),
            ],
            _row(extras[i] as Map),
          ],
        ],
      ),
    );
  }

  Widget _row(Map ex) {
    final score = (ex['score'] ?? '').toString().trim();
    final palette = score.isEmpty
        ? (bg: ColorUtils.slate100, fg: ColorUtils.slate500)
        : _palette(score);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.bg,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Text(
            score.isEmpty ? '–' : score.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: palette.fg,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (ex['name'] ?? 'Ekstrakurikuler').toString(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if ((ex['description'] ?? '').toString().trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  ex['description'].toString(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: ColorUtils.slate600,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  ({Color bg, Color fg}) _palette(String score) {
    final s = score.toUpperCase();
    if (s.startsWith('A')) {
      return (bg: const Color(0xFFDCFCE7), fg: const Color(0xFF15803D));
    }
    if (s.startsWith('B')) {
      return (bg: const Color(0xFFDBEAFE), fg: const Color(0xFF1D4ED8));
    }
    return (bg: const Color(0xFFFEF3C7), fg: const Color(0xFFB45309));
  }
}
