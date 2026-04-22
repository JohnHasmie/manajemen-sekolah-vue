import 'package:flutter/material.dart';

/// Mixin for building date picker header UI
mixin DatePickerHeaderMixin {
  /// Builds the header container with gradient and title
  Widget buildHeader({
    required String title,
    required IconData icon,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: _buildHeaderDecoration(primaryColor),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: _onClosePressed,
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  /// Gets the build context
  BuildContext get context;

  /// Builds the header gradient decoration
  BoxDecoration _buildHeaderDecoration(Color primaryColor) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
      ),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
    );
  }

  /// Called when close button is pressed
  void _onClosePressed() {
    Navigator.pop(context);
  }
}
