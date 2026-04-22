import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class CompactTextField extends StatelessWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onChanged;
  final bool isNumber;

  const CompactTextField({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.isNumber = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = ColorUtils.getRoleColor('guru');
    return TextFormField(
      initialValue: initialValue.isNotEmpty && initialValue != '0'
          ? initialValue
          : null,
      maxLines: 1,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 12),
        hintText: isNumber ? '' : label,
        hintStyle: TextStyle(color: ColorUtils.slate300, fontSize: 12),
        isDense: true,
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: p, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
      ),
      onChanged: onChanged,
    );
  }
}
