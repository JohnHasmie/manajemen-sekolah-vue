import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A label–value row used inside payment detail bottom sheets.
///
/// Displays [label] in a fixed-width column and [value] in an expanded
/// column — equivalent to a `<v-row>` description pair in the Vue detail
/// dialog.  Pure [StatelessWidget] with no state.
class FinanceInfoItem extends StatelessWidget {
  /// Short descriptive label shown on the left (fixed 100 px wide).
  final String label;

  /// The value to display on the right (expands to fill remaining space).
  final String value;

  const FinanceInfoItem({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: ColorUtils.slate500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: ColorUtils.slate900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
