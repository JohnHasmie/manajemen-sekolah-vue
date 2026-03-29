// Compact summary header shown after the teacher confirms grade type and date.
// Like a readonly "breadcrumb" bar — tap it to go back and edit the configuration.
// In Laravel terms, this mirrors showing confirmed form data before final submission.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Displays the confirmed [gradeTypeLabel] and [confirmedDate] in a warning-tinted
/// banner. Tapping the label area triggers [onEditConfiguration] so the parent
/// can reset back to the configuration panel.
class GradeAddHeader extends StatelessWidget {
  final String gradeTypeLabel;
  final DateTime confirmedDate;
  final LanguageProvider languageProvider;

  /// Called when the user taps the grade-type label to edit configuration.
  final VoidCallback onEditConfiguration;

  const GradeAddHeader({
    super.key,
    required this.gradeTypeLabel,
    required this.confirmedDate,
    required this.languageProvider,
    required this.onEditConfiguration,
  });

  /// Formats a [DateTime] as Indonesian long date, e.g. "05 Januari 2025".
  String _formatDateIndonesian(DateTime date) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final day = date.day.toString().padLeft(2, '0');
    final month = months[date.month - 1];
    final year = date.year.toString();
    return '$day $month $year';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg),
      color: ColorUtils.warning600.withValues(alpha: 0.08),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: grade-type label with edit icon — tap to re-open configuration
          GestureDetector(
            onTap: onEditConfiguration,
            child: Row(
              children: [
                Text(
                  gradeTypeLabel,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: ColorUtils.warning600,
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Icon(Icons.edit, size: 16, color: ColorUtils.warning600),
              ],
            ),
          ),
          // Right: confirmed date in Indonesian long format
          Text(
            _formatDateIndonesian(confirmedDate),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: ColorUtils.slate700,
            ),
          ),
        ],
      ),
    );
  }
}
