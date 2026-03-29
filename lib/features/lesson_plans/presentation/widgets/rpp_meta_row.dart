// A single labelled text-field row inside the RPP meta-info panel.
// Like a Vue <FormRow label="..."> component — receives a label string
// and a TextEditingController; never touches parent state.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One label + text-field row used inside the "Informasi Umum" panel.
///
/// [label] is the left-side column text (e.g. "Satuan Pendidikan").
/// [controller] is the TextEditingController owned by the parent screen.
class RppMetaRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const RppMetaRow({
    super.key,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: ColorUtils.slate700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(' : ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              style: TextStyle(fontSize: 13, color: ColorUtils.slate900),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 10,
                ),
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: ColorUtils.slate300),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
