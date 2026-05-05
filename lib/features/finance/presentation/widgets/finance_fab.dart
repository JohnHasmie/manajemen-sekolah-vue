import 'package:flutter/material.dart';

/// Floating action button for finance screen.
class FinanceFab extends StatelessWidget {
  final bool isReadOnly;
  final int currentTabIndex;
  final Color primaryColor;
  final VoidCallback onPressed;

  const FinanceFab({
    required this.isReadOnly,
    required this.currentTabIndex,
    required this.primaryColor,
    required this.onPressed,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    // Only show on the Jenis (Payment Types) tab — index 2 in the
    // v3 layout (Mockup #13: Tagihan / Pembayaran / Jenis). Was
    // index 1 in the legacy 4-tab layout; the constant moved when
    // we folded Dashboard out of the hub.
    if (isReadOnly || currentTabIndex != 2) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
