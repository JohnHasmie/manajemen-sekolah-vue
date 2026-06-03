import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';

class ParentRaporSikapCard extends StatelessWidget {
  const ParentRaporSikapCard({super.key, required this.reportCardData});

  final Map<String, dynamic> reportCardData;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row(
            label: 'Spiritual',
            predikat: (reportCardData['spiritual_predicate'] ?? '–').toString(),
            description: (reportCardData['spiritual_description'] ?? '')
                .toString(),
            bg: const Color(0xFFEDE9FE),
            fg: const Color(0xFF7C3AED),
            icon: Icons.auto_awesome_outlined,
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: ColorUtils.slate100),
          const SizedBox(height: 12),
          _row(
            label: 'Sosial',
            predikat: (reportCardData['social_predicate'] ?? '–').toString(),
            description: (reportCardData['social_description'] ?? '')
                .toString(),
            bg: const Color(0xFFDBEAFE),
            fg: const Color(0xFF1D4ED8),
            icon: Icons.people_alt_outlined,
          ),
        ],
      ),
    );
  }

  Widget _row({
    required String label,
    required String predikat,
    required String description,
    required Color bg,
    required Color fg,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(10)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 16, color: fg),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: ColorUtils.slate500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                predikat.isEmpty ? '–' : predikat,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: ColorUtils.slate900,
                ),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  description,
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
}
