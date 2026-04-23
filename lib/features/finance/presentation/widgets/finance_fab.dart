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
    if (isReadOnly || currentTabIndex != 1) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: onPressed,
      backgroundColor: primaryColor,
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
