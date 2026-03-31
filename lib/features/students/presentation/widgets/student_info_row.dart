// Reusable info row widget for the student detail screen.
// Like a Vue component `<InfoRow>` that shows a labeled value with an icon.
// Extracted from StudentDetailScreen to keep the screen lean and focused.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A single labeled row used inside student detail info cards.
///
/// Displays an icon on the left, a small label above, and a value below.
/// Pass [primaryColor] from the parent so this widget stays stateless.
/// Like a Vue functional component — receives all data as props.
class StudentInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color primaryColor;
  final IconData? icon;
  final bool isMultiline;

  const StudentInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.primaryColor,
    this.icon,
    this.isMultiline = false,
  });

  IconData _getIconForLabel(String label) {
    switch (label) {
      case 'Kelas':
      case 'Class':
        return Icons.school;
      case 'Jenis Kelamin':
      case 'Gender':
        return Icons.transgender;
      case 'Tanggal Lahir':
      case 'Birth Date':
        return Icons.cake;
      case 'Alamat':
      case 'Address':
        return Icons.location_on;
      case 'Nama Wali':
      case 'Parent Name':
        return Icons.person;
      case 'No. Telepon':
      case 'Phone Number':
        return Icons.phone;
      case 'Email Wali':
      case 'Parent Email':
        return Icons.email;
      case 'NIS':
        return Icons.badge;
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
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              border: Border.all(
                color: primaryColor.withValues(alpha: 0.15),
              ),
            ),
            child: Icon(
              icon ?? _getIconForLabel(label),
              size: 18,
              color: primaryColor,
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
                Text(
                  value.isNotEmpty ? value : 'Tidak ada',
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
