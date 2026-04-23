// Footer button row for modal bottom sheets.
//
// Replaces 25+ identical Cancel/Apply button pairs with consistent
// styling, padding, safe-area handling, and top border/shadow.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

/// A footer row with a secondary (outlined) button and a primary
/// (elevated) button, separated by a top border with shadow.
///
/// Handles safe-area bottom padding automatically.
///
/// Example:
/// ```dart
/// BottomSheetFooter(
///   primaryLabel: 'Terapkan',
///   secondaryLabel: 'Reset',
///   primaryColor: Colors.blue,
///   onPrimary: () => _applyFilters(),
///   onSecondary: () => _resetFilters(),
/// )
/// ```
class BottomSheetFooter extends StatelessWidget {
  /// Label for the primary (right) button.
  final String primaryLabel;

  /// Label for the secondary (left) button.
  final String secondaryLabel;

  /// Background color for the primary button.
  final Color primaryColor;

  /// Called when the primary button is tapped.
  final VoidCallback onPrimary;

  /// Called when the secondary button is tapped.
  final VoidCallback onSecondary;

  /// Flex ratio for the primary button. Default: 2.
  final int primaryFlex;

  /// Whether the primary button is enabled. Default: true.
  final bool primaryEnabled;

  /// When true, the secondary button is styled as destructive (red outline).
  /// Use for edit sheets that pair "Hapus" (delete) with "Simpan" (save).
  final bool secondaryDestructive;

  const BottomSheetFooter({
    super.key,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.secondaryLabel = 'Batal',
    this.primaryColor = Colors.blue,
    this.primaryFlex = 2,
    this.primaryEnabled = true,
    this.secondaryDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    // Tight vertical footer padding — 8 px top + 8 px bottom — so the
    // button row sits close to the last content row instead of floating
    // 30+ px below it. The surrounding sheet (e.g. [AppFilterBottomSheet])
    // wraps this footer in a `SafeArea(top: false)` so the home indicator
    // on iPhone still clears the buttons without us double-padding here.
    //
    // Earlier revisions used 12 px vertical padding + a boxShadow; the
    // combination visually exaggerated the gap between the last filter
    // chip and the Apply button, which users consistently flagged as
    // "too much bottom margin" (see screenshots in #129 / #133). The
    // buttons themselves still have 14 px internal vertical padding,
    // which is enough to keep the 48 px Material tap target.
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      decoration: _footerDecoration(),
      child: Row(
        children: [
          Expanded(child: _secondaryButton()),
          const SizedBox(width: AppSpacing.md),
          Expanded(flex: primaryFlex, child: _primaryButton()),
        ],
      ),
    );
  }

  BoxDecoration _footerDecoration() {
    // Hairline top border only — no boxShadow. The shadow (blurRadius 8,
    // offset (0,-2)) used to bleed ~10 px of darkening up into the
    // content region above the footer, which visually widened the
    // chip→button gap. A flat 1 px divider separates footer from
    // content cleanly without that optical expansion.
    return BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Colors.grey.shade200)),
    );
  }

  Widget _secondaryButton() {
    final borderColor =
        secondaryDestructive ? Colors.red.shade300 : Colors.grey.shade300;
    final textColor =
        secondaryDestructive ? Colors.red.shade700 : Colors.grey.shade700;
    return OutlinedButton(
      onPressed: onSecondary,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: borderColor),
      ),
      child: Text(
        secondaryLabel,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _primaryButton() {
    return ElevatedButton(
      onPressed: primaryEnabled ? onPrimary : null,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        disabledBackgroundColor: primaryColor.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Text(
        primaryLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
