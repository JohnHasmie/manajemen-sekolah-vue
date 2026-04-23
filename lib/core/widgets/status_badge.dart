// Small colored badge showing a status label.
//
// Replaces 20+ identical Container + Text + decoration patterns for
// attendance statuses, approval states, and general status indicators.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A small colored badge displaying a status label.
///
/// Provides named constructors for common statuses (attendance, approval)
/// and a generic constructor for custom statuses.
///
/// Example:
/// ```dart
/// StatusBadge.hadir()
/// StatusBadge.alpha()
/// StatusBadge(label: 'Draft', color: Colors.grey)
/// StatusBadge.approved(label: 'Disetujui')
/// ```
class StatusBadge extends StatelessWidget {
  /// The status text to display.
  final String label;

  /// The accent color for background, border, and text.
  final Color color;

  /// Font size of the label. Default: 10.
  final double fontSize;

  /// Padding inside the badge.
  final EdgeInsets padding;

  /// Optional leading icon.
  final IconData? icon;

  /// Icon size. Default: 10.
  final double iconSize;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon,
    this.iconSize = 10,
  });

  // ── Attendance status constructors ──

  /// Green badge for "Present" / "Hadir".
  const StatusBadge.hadir({
    super.key,
    this.label = 'Hadir',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon,
    this.iconSize = 10,
  }) : color = const Color(0xFF16A34A); // success600

  /// Orange badge for "Sick" / "Sakit".
  const StatusBadge.sakit({
    super.key,
    this.label = 'Sakit',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon,
    this.iconSize = 10,
  }) : color = const Color(0xFFEA580C); // warning600

  /// Blue badge for "Excused" / "Izin".
  const StatusBadge.izin({
    super.key,
    this.label = 'Izin',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon,
    this.iconSize = 10,
  }) : color = const Color(0xFF2563EB); // info/blue600

  /// Red badge for "Absent" / "Alpha".
  const StatusBadge.alpha({
    super.key,
    this.label = 'Alpha',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon,
    this.iconSize = 10,
  }) : color = const Color(0xFFDC2626); // error600

  // ── Approval status constructors ──

  /// Yellow badge for "Pending" status.
  const StatusBadge.pending({
    super.key,
    this.label = 'Pending',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon = Icons.schedule,
    this.iconSize = 10,
  }) : color = const Color(0xFFCA8A04); // yellow600

  /// Green badge for "Approved" / "Disetujui".
  const StatusBadge.approved({
    super.key,
    this.label = 'Disetujui',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon = Icons.check_circle_outline,
    this.iconSize = 10,
  }) : color = const Color(0xFF16A34A); // success600

  /// Red badge for "Rejected" / "Ditolak".
  const StatusBadge.rejected({
    super.key,
    this.label = 'Ditolak',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon = Icons.cancel_outlined,
    this.iconSize = 10,
  }) : color = const Color(0xFFDC2626); // error600

  /// Grey badge for "Draft" status.
  const StatusBadge.draft({
    super.key,
    this.label = 'Draft',
    this.fontSize = 10,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    this.icon = Icons.edit_outlined,
    this.iconSize = 10,
  }) : color = const Color(0xFF6B7280); // grey500

  /// Create a StatusBadge from a status string (auto-detects type).
  factory StatusBadge.fromStatus(String status, {String? label}) {
    final normalized = status.toLowerCase().trim();
    switch (normalized) {
      case 'hadir':
      case 'present':
        return StatusBadge.hadir(label: label ?? 'Hadir');
      case 'sakit':
      case 'sick':
        return StatusBadge.sakit(label: label ?? 'Sakit');
      case 'izin':
      case 'excused':
      case 'permission':
        return StatusBadge.izin(label: label ?? 'Izin');
      case 'alpha':
      case 'absent':
        return StatusBadge.alpha(label: label ?? 'Alpha');
      case 'pending':
      case 'menunggu':
        return StatusBadge.pending(label: label ?? 'Pending');
      case 'approved':
      case 'disetujui':
        return StatusBadge.approved(label: label ?? 'Disetujui');
      case 'rejected':
      case 'ditolak':
        return StatusBadge.rejected(label: label ?? 'Ditolak');
      case 'draft':
        return StatusBadge.draft(label: label ?? 'Draft');
      default:
        return StatusBadge(label: label ?? status, color: ColorUtils.slate500);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: iconSize, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
