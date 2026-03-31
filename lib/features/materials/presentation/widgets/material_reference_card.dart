// Card widget displaying a single AI-generated reference entry.
// Used inside the "Referensi" tab of [MaterialAiResultScreen].
// Like a Vue `<ReferenceCard :ref="ref" />` presentational component.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Renders a single reference card with type badge, title, and content.
///
/// HTML in [ref]['content'] is pre-stripped by the caller before being
/// passed here, keeping this widget free of HTML-parsing concerns.
/// All data arrives via constructor params — no parent state access.
class MaterialReferenceCard extends StatelessWidget {
  /// Raw reference data map, expected keys: `type`, `title`, `content`.
  final Map<String, dynamic> ref;

  /// Primary accent colour used for the type badge background and text.
  final Color primaryColor;

  /// Pre-stripped plain-text content (HTML already removed by the caller).
  /// Separating stripping from rendering keeps this widget testable.
  final String strippedContent;

  const MaterialReferenceCard({
    super.key,
    required this.ref,
    required this.primaryColor,
    required this.strippedContent,
  });

  @override
  Widget build(BuildContext context) {
    final String refType =
        ref['type']?.toString().replaceAll('_', ' ').toUpperCase() ??
        'REFERENSI';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: ColorUtils.slate200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type badge row
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.1),
                    borderRadius: const BorderRadius.all(Radius.circular(6)),
                  ),
                  child: Text(
                    refType,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Reference title
            Text(
              ref['title'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ColorUtils.slate800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // Reference content (pre-stripped HTML)
            Text(
              strippedContent,
              style: TextStyle(
                color: ColorUtils.slate600,
                height: 1.5,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
