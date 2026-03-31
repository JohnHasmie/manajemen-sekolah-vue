// Generic labelled dropdown widget for the class promotion wizard.
// Wraps a Flutter DropdownButton with a label, optional leading icon, and hint.
// Used in Step 3 (target configuration) for academic-year and class selection.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A styled dropdown with a text [label] above it and an optional leading [icon].
///
/// Like a `<labeled-select>` Vue component — stateless, fires [onChanged].
/// [primaryColor] is the brand colour used for the leading icon tint.
class PromotionDropdown extends StatelessWidget {
  final String label;
  final String? value;
  final List<DropdownMenuItem<String>>? items;
  final ValueChanged<String?> onChanged;
  final String? hint;
  final IconData? icon;
  final Color primaryColor;

  const PromotionDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    required this.primaryColor,
    this.hint,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: ColorUtils.slate600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: ColorUtils.slate50,
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            border: Border.all(color: ColorUtils.slate200),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: primaryColor),
                const SizedBox(width: AppSpacing.sm),
              ],
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: ColorUtils.slate500,
                    ),
                    items: items,
                    onChanged: onChanged,
                    hint: hint != null
                        ? Text(
                            hint!,
                            style: TextStyle(
                              color: ColorUtils.slate400,
                              fontSize: 14,
                            ),
                          )
                        : null,
                    style: TextStyle(color: ColorUtils.slate800, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
