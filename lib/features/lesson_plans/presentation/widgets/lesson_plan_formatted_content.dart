// RPP plain-text content renderer. Extracted from lesson_plan_detail_screen.dart.
// Formats a structured plain-text RPP string into styled Flutter widgets line-by-line.
// Like a `<RppContentRenderer>` Vue component — purely display, no state or callbacks.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Renders a pre-formatted RPP plain-text string as styled Flutter widgets.
///
/// Constructor params:
/// - [content]      — the full RPP text (newline-delimited, may contain pipe-table rows)
/// - [primaryColor] — brand colour for section headings and the title line
class LessonPlanFormattedContent extends StatelessWidget {
  final String content;
  final Color primaryColor;

  const LessonPlanFormattedContent({
    super.key,
    required this.content,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: lines.map((line) {
        // Blank line → vertical gap
        if (line.trim().isEmpty) {
          return const SizedBox(height: AppSpacing.lg);
        }

        // Main title line
        if (line.startsWith('RENCANA PELAKSANAAN PEMBELAJARAN')) {
          return Column(
            children: [
              Text(
                line,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          );
        }

        // Horizontal rule
        if (line.startsWith('=')) {
          return Container(
            height: 2,
            color: ColorUtils.slate200,
            margin: const EdgeInsets.symmetric(vertical: 8),
          );
        }

        // Pipe-delimited table row
        if (line.startsWith('|')) {
          return _buildTableRow(line);
        }

        // Section heading (A. / B. / C.)
        if (line.startsWith('A.') ||
            line.startsWith('B.') ||
            line.startsWith('C.')) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                line,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          );
        }

        // Media/tools label lines
        if (line.contains('Media :') || line.contains('Alat/Bahan :')) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: ColorUtils.slate700,
              ),
            ),
          );
        }

        // Bullet / numbered list items — indented
        if (line.startsWith('•') ||
            line.startsWith('1.') ||
            line.startsWith('2.')) {
          return Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              line,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          );
        }

        // Signature section labels — slightly bold
        if (line.contains('Mengetahui') ||
            line.contains('Kepala Sekolah') ||
            line.contains('Guru Mata Pelajaran')) {
          return Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              line,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          );
        }

        // Default body text
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(line, style: const TextStyle(fontSize: 14, height: 1.5)),
        );
      }).toList(),
    );
  }

  /// Renders a single pipe-delimited row as a bordered table row.
  Widget _buildTableRow(String line) {
    final cells = line
        .split('|')
        .where((cell) => cell.trim().isNotEmpty)
        .toList();

    return Container(
      decoration: BoxDecoration(border: Border.all(color: ColorUtils.slate200)),
      child: Row(
        children: cells.map((cell) {
          return Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: Text(
                cell.trim(),
                style: TextStyle(fontSize: 12, color: ColorUtils.slate700),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
