import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/payment_type_form_sheet.dart';

/// Mixin for building UI widgets used in payment type form.
mixin PaymentFormBuildersMixin on ConsumerState<PaymentTypeFormSheet> {
  /// Builds an animated period chip with icon and label.
  /// Toggles selected state based on controller value.
  Widget buildPeriodChip(
    String value,
    String label,
    IconData icon,
    TextEditingController periodController,
    Color primaryColor,
  ) {
    final isSelected = periodController.text == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          periodController.text = value;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: 0.12)
              : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isSelected ? primaryColor : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? primaryColor : ColorUtils.slate500,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : ColorUtils.slate600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an animated status chip with icon and label.
  /// Toggles selected state based on status value.
  Widget buildStatusChip(
    String value,
    String label,
    Color color,
    IconData icon,
    String currentStatus,
  ) {
    final isSelected = currentStatus == value;
    return GestureDetector(
      onTap: () => setState(() {
        // Status update handled by caller
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : ColorUtils.slate50,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
          border: Border.all(
            color: isSelected ? color : ColorUtils.slate200,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? color : ColorUtils.slate400,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? color : ColorUtils.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a styled text field with label and icon.
  /// Supports custom keyboard type and input formatters.
  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
