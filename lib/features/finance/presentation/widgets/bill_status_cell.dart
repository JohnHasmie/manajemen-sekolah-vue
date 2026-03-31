// Status pill widget for a single bill cell in the class finance report table.
// Like a Vue `<BillStatusCell :bill="bill" @tap="onTap" />` that derives color
// and label from the bill's status and payments list, then fires a tap callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Displays a colored status pill for a single bill cell.
///
/// Determines color and text from [bill]'s `status` and `payments` array —
/// similar to a Vue computed property that maps status to a CSS class.
/// Fires [onTap] when tapped, so the parent screen can show an action sheet.
///
/// Returns an empty [SizedBox] when [bill] is null (empty table cell).
class BillStatusCell extends StatelessWidget {
  final dynamic bill;
  final VoidCallback? onTap;

  const BillStatusCell({
    super.key,
    required this.bill,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (bill == null) return const SizedBox();

    final status = bill['status'];
    Color color;
    String text;

    // 1. Check Verified / Lunas
    if (status == 'verified') {
      color = ColorUtils.success600;
      text = 'Lunas';
    } else {
      // 2. Check Pending Verification (Menunggu)
      bool hasPendingPayment = false;
      if (bill['payments'] != null && bill['payments'] is List) {
        for (var p in bill['payments']) {
          final pStatus = p['status'];
          if (pStatus == 'pending' || pStatus == 'test_status') {
            hasPendingPayment = true;
            break;
          }
        }
      }

      if (hasPendingPayment) {
        color = ColorUtils.warning600;
        text = 'Menunggu';
      } else {
        // 3. Fallback: Not Paid
        color = ColorUtils.error600;
        text = 'Belum';
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
