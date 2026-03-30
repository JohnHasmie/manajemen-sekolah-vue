// A styled plain-text input card used for single-line or multi-line RPP fields.
// Like a Vue <BaseInput> wrapper — takes a controller and maxLines prop,
// applies consistent card decoration without touching parent state.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Decorated plain TextField card for RPP form fields (e.g. "Judul RPP").
///
/// [controller] is the TextEditingController owned by the parent screen.
/// [maxLines] defaults to 4; pass 1 for a single-line title field.
class LessonPlanPlainTextField extends StatelessWidget {
  final TextEditingController controller;
  final int maxLines;

  const LessonPlanPlainTextField({
    super.key,
    required this.controller,
    this.maxLines = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, height: 1.6, color: ColorUtils.slate800),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(AppSpacing.lg),
        ),
      ),
    );
  }
}
