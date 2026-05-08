// Stateless leaf widgets for the parent bill checkout screen.
//
// Why this exists
// ---------------
// `parent_bill_checkout_screen.dart` was carrying four small
// presentation-only widgets inline (the QRIS / VA method tab, the
// expiry countdown chip, the copy-value pill, and the bank-account
// row). None of them touch the screen state — they're all driven by
// primitives + callbacks. Pulling them into a co-located widgets file
// drops the screen by ~230 lines and makes each shape easier to
// audit on its own.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One of the two top-level method tabs (QRIS / Virtual Account)
/// inside the payment-method picker. Tab is "active" when its
/// border + bg are tinted with the brand colour.
class ParentCheckoutMethodTab extends StatelessWidget {
  final String label;
  final String caption;
  final bool active;
  final VoidCallback onTap;

  const ParentCheckoutMethodTab({
    super.key,
    required this.label,
    required this.caption,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: active
                ? Border.all(color: ColorUtils.brandAzureDeep, width: 1.2)
                : null,
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: active
                      ? ColorUtils.brandAzureDeep
                      : ColorUtils.slate600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                caption,
                style: TextStyle(
                  fontSize: 9,
                  color: active
                      ? ColorUtils.brandAzureDeep
                      : ColorUtils.slate400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact countdown chip shown next to the expiry hint. Re-renders
/// every tick from a periodic `setState` upstream — no animation,
/// just static text.
class ParentCheckoutCountdownChip extends StatelessWidget {
  final DateTime expires;

  const ParentCheckoutCountdownChip({super.key, required this.expires});

  @override
  Widget build(BuildContext context) {
    final remaining = expires.difference(DateTime.now());
    final hours = remaining.inHours.toString().padLeft(2, '0');
    final minutes = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        '⏱ $hours:$minutes:$seconds',
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Color(0xFFB45309),
        ),
      ),
    );
  }
}

/// "Tap to copy" pill — used for VA numbers and the gateway-issued
/// reference code. With a `label` it shows `Label · value · 📋 Salin`,
/// without it just `📋 value`.
class ParentCheckoutCopyPill extends StatelessWidget {
  final String? label;
  final String value;
  final VoidCallback onCopy;

  const ParentCheckoutCopyPill({
    super.key,
    this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onCopy,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F9FF),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFBAE6FD), width: 0.75),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (label != null) ...[
              Text(
                label!,
                style: TextStyle(
                  fontSize: 10,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.slate900,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '📋 ${label == null ? value : 'Salin'}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: ColorUtils.brandAzureDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bank-account row inside the manual-transfer panel. Shows the bank
/// short code, account number, and account holder, with a copy
/// button on the right.
class ParentCheckoutBankRow extends StatelessWidget {
  final String bank;
  final String account;
  final String owner;
  final VoidCallback onCopy;

  const ParentCheckoutBankRow({
    super.key,
    required this.bank,
    required this.account,
    required this.owner,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bank,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate500,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: ColorUtils.slate900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'a.n. $owner',
                  style: TextStyle(fontSize: 9.5, color: ColorUtils.slate500),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                '📋 Salin',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: ColorUtils.brandAzureDeep,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
