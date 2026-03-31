// Status badge chip for a student's report card entry state.
// Replaces _buildStatusBadge() from teacher_report_card_screen.dart.
// Like a Vue <StatusBadge> pure presentational component with no side-effects.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A small coloured pill that communicates a student's raport filing status.
///
/// Receives [hasReportCard] and [status] as props (like Vue props) and renders
/// the correct colour + label with zero side-effects — purely presentational.
class ReportCardStatusBadge extends StatelessWidget {
  /// Whether the student already has a report card entry at all.
  final bool hasReportCard;

  /// The raw status string from the API (e.g. 'draft', 'final', 'published').
  final String status;

  const ReportCardStatusBadge({
    super.key,
    required this.hasReportCard,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve colours and label based on filing state.
    // Think of this as a computed property in Vue: `get badgeStyle() { ... }`
    final Color bgColor;
    final Color textColor;
    final String label;

    if (!hasReportCard) {
      bgColor = Colors.grey.shade100;
      textColor = Colors.grey.shade600;
      label = 'Belum Isi';
    } else if (status.toLowerCase() == 'draft') {
      bgColor = Colors.orange.shade50;
      textColor = ColorUtils.warning600;
      label = 'Draft';
    } else {
      bgColor = Colors.green.shade50;
      textColor = ColorUtils.success600;
      label = 'Selesai';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
