import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Widget for the "Show All Teachers" toggle in the filter sheet.
class TeacherShowAllToggle extends StatelessWidget {
  const TeacherShowAllToggle({
    super.key,
    required this.value,
    required this.onChanged,
    required this.languageProvider,
  });

  /// Current toggle value.
  final bool value;

  /// Called when the toggle value changes.
  final ValueChanged<bool> onChanged;

  /// Language/translation provider.
  final dynamic languageProvider;

  Widget _buildLabel() {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            languageProvider.getTranslatedText({
              'en': 'Show All Teachers',
              'id': 'Tampilkan Semua Guru',
            }),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: ColorUtils.slate800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            languageProvider.getTranslatedText({
              'en': 'Include inactive (ignores academic year)',
              'id': 'Termasuk tidak aktif (abaikan tahun ajaran)',
            }),
            style: TextStyle(fontSize: 11, color: ColorUtils.slate500),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Row(
        children: [
          _buildLabel(),
          Switch(
            value: value,
            activeThumbColor: ColorUtils.corporateBlue600,
            activeTrackColor: ColorUtils.corporateBlue600.withValues(
              alpha: 0.4,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
