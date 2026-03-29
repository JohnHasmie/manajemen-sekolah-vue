// A single labelled metadata row shown inside the announcement detail dialog.
// Renders an icon, a small label text, and a bold value — like a <dt>/<dd> pair.
// Used in the metadata section of AnnouncementDetailDialog (creator, target, dates).
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Icon + label + value row used inside the announcement detail dialog's metadata box.
///
/// Think of it as a Blade partial:
/// `@include('partials.detail-row', ['icon'=>..., 'label'=>..., 'value'=>...])`
/// — renders one consistent row for things like "Created by", "Target Role", etc.
class AnnouncementDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// The accent colour used for the leading icon (typically the role primary colour).
  final Color primaryColor;

  const AnnouncementDetailRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: primaryColor),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: ColorUtils.slate500),
              ),
              SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
