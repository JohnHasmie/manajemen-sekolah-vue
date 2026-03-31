// Reusable info row widget for the teacher detail screen.
// Like a Vue component `<InfoRow>` that shows a labeled value with an icon.
// Extracted from TeacherDetailScreen to keep the screen lean and focused.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A single labeled row used inside teacher detail info cards.
///
/// Displays an icon on the left, a small label above, and either a plain text
/// value or a [Wrap] of tag chips when [value] is a [List<String>].
/// Like a Vue functional component — pure props in, no state.
class TeacherInfoRow extends StatelessWidget {
  final String label;

  /// Accepts either a plain [String] or a [List<String>] for multi-tag display.
  final dynamic value;
  final bool isMultiline;

  const TeacherInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isMultiline = false,
  });

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Nama':
        return Icons.person;
      case 'NIP':
        return Icons.badge;
      case 'Email':
        return Icons.email;
      case 'Kelas':
        return Icons.school;
      case 'Mata Pelajaran':
        return Icons.menu_book;
      case 'Role':
        return Icons.work;
      case 'Status Wali Kelas':
        return Icons.groups;
      case 'ID':
        return Icons.fingerprint;
      case 'Tanggal Dibuat':
        return Icons.calendar_today;
      case 'Terakhir Diupdate':
        return Icons.update;
      default:
        return Icons.info;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(10)),
        border: Border.all(color: ColorUtils.slate100),
      ),
      child: Row(
        crossAxisAlignment: isMultiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(
                color: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              _getIconForLabel(label),
              size: 18,
              color: ColorUtils.corporateBlue600,
            ),
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
                    color: ColorUtils.slate500,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 3),
                if (value is List<String>)
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: (value as List<String>).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: ColorUtils.corporateBlue600.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: const BorderRadius.all(Radius.circular(6)),
                          border: Border.all(
                            color: ColorUtils.corporateBlue600.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            color: ColorUtils.corporateBlue600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Text(
                    value.toString().isNotEmpty
                        ? value.toString()
                        : 'Tidak ada',
                    style: TextStyle(
                      fontSize: 14,
                      color: ColorUtils.slate800,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: isMultiline ? 3 : 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
