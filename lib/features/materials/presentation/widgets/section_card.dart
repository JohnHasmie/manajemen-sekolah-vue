// Reusable card container used on the Materi tab.
// Renders a tinted header row (icon + title) above an arbitrary child widget,
// matching the corporate card style used throughout the materials feature.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A titled card with a coloured icon badge in the header row.
///
/// Like a Vue slot-based card component: pass [icon], [iconColor], and
/// [title] as "props", and provide any widget as [child] content.
///
/// When [onEdit] is supplied, a pencil affordance lights up at the
/// top-right of the header — same pattern as the RPP per-section editor.
/// The pencil opens a focused editor sheet for the caller to handle.
class SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget child;

  /// Optional pencil tap handler — surfaces an "edit this section"
  /// affordance in the header row. Mirrors the RPP detail screen's
  /// per-card editor pattern.
  final VoidCallback? onEdit;

  const SectionCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.child,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.04),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    border: Border.all(color: iconColor.withValues(alpha: 0.2)),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate800,
                    ),
                  ),
                ),
                if (onEdit != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.edit_rounded,
                          size: 15,
                          color: ColorUtils.slate400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}
