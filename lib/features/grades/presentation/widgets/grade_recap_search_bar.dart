// Search bar used on the class-selection and subject-selection steps of the
// grade recap wizard. Like a Vue <SearchInput> component — purely presentational,
// all state (setText, rebuild) stays in the parent via [onChanged]/[onClear].

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Reusable animated search bar for the grade recap wizard steps 0 and 1.
///
/// Receives a [TextEditingController] from the parent (like passing `v-model`
/// in Vue) so the parent owns the value. The parent's [onChanged] triggers
/// a `setState` rebuild — this widget never calls setState itself.
class GradeRecapSearchBar extends StatelessWidget {
  /// Controller owned by the parent screen.
  final TextEditingController controller;

  /// Translated hint text (e.g. "Search classes..." or "Cari kelas...").
  final String hintText;

  /// Called with the new text whenever the user types.
  final ValueChanged<String> onChanged;

  /// Called when the user taps the clear (×) button.
  final VoidCallback onClear;

  const GradeRecapSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
          boxShadow: ColorUtils.corporateShadow(elevation: 0.5),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: TextStyle(color: ColorUtils.slate900),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 14),
            prefixIcon: Icon(
              Icons.search,
              color: ColorUtils.slate400,
              size: 20,
            ),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: 18,
                      color: ColorUtils.slate400,
                    ),
                    onPressed: onClear,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
      ),
    );
  }
}
