import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/report_cards/presentation/widgets/parent_rapor/parent_rapor_card_shell.dart';

class ParentRaporEmptyHint extends StatelessWidget {
  const ParentRaporEmptyHint({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ParentRaporCardShell(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: ColorUtils.slate500,
            ),
          ),
        ),
      ),
    );
  }
}
