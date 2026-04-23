import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// Mixin providing header and gradient building for verification dialog.
mixin VerificationDialogHeaderMixin {
  /// Abstract: Get primary color from widget.
  Color get primaryColor;

  /// Returns the gradient for the dialog header.
  LinearGradient cardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [primaryColor, primaryColor.withValues(alpha: 0.85)],
    );
  }

  /// Builds the gradient header container with icon and title.
  Widget buildDialogHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: cardGradient(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: AppSpacing.md),
          _buildHeaderTitle(),
        ],
      ),
    );
  }

  /// Helper to build the header icon box.
  Widget _buildHeaderIcon() {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(0x33FFFFFF),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: const Icon(Icons.verified, color: Colors.white, size: 20),
    );
  }

  /// Helper to build the header title text.
  Widget _buildHeaderTitle() {
    return const Expanded(
      child: Text(
        'Verifikasi Pembayaran',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
