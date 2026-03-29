import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// A compact label–value row used in payment action sheets.
///
/// Similar to [FinanceInfoItem] but uses a narrower label column (80 px)
/// and inserts a `": "` separator — mirrors the `<v-col>` layout in the
/// Vue payment action dialog.  Pure [StatelessWidget] with no state.
class FinanceInfoRow extends StatelessWidget {
  /// Short descriptive label shown on the left (fixed 80 px wide).
  final String label;

  /// The value to display on the right (expands to fill remaining space).
  final String value;

  const FinanceInfoRow({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: ColorUtils.slate500, fontSize: 12),
            ),
          ),
          Text(
            ': ',
            style: TextStyle(color: ColorUtils.slate400, fontSize: 12),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: ColorUtils.slate800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
