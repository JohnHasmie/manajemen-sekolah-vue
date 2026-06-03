// Status pill widget for a single bill cell in the class finance report table.
// Like a Vue `<BillStatusCell :bill="bill" @tap="onTap" />` that derives color
// and label from the bill's status and payments list, then fires a tap
// callback.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/status_badge.dart';

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

  const BillStatusCell({super.key, required this.bill, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (bill == null) return const SizedBox();

    final status = bill['status'];
    Color color;
    String text;

    // 1. Check paid / Lunas.
    //
    // Backend status vocabulary diverges across surfaces:
    //   * `CreatePaymentAction` flips the bill row to `'paid'` once the
    //     sum of verified payments equals the bill amount.
    //   * Older admin flows post `payments.status = 'verified'` directly
    //     and the bill keeps `'verified'` as a synonym for paid.
    //   * Some legacy seed rows use `'success'`.
    //
    // All three should read as Lunas. Restricting to `'verified'` was
    // the cause of the "still Belum after successful save" bug — the
    // payment landed, the bill flipped to `'paid'`, the UI didn't.
    if (status == 'paid' || status == 'verified' || status == 'success') {
      color = ColorUtils.success600;
      text = 'Lunas';
    } else {
      // 2. Check Pending Verification (Menunggu)
      bool hasPendingPayment = false;
      if (bill['payments'] != null && bill['payments'] is List) {
        for (final p in bill['payments']) {
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
      child: StatusBadge(
        label: text,
        color: color,
        fontSize: 10,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}
