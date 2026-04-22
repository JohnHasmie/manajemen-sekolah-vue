import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/widgets/app_edit_bottom_sheet.dart';

/// Bottom sheet for editing a student's grade description.
///
/// Uses the shared [AppEditBottomSheet] scaffold so the sheet picks up
/// the standard gradient header, Samsung / iPhone safe-area handling,
/// and consistent Simpan/Batal footer across teacher pages.
void showEditDeskripsiDialog({
  required BuildContext context,
  required String currentDescription,
  required String studentName,
  required Color primaryColor,
  required Map<String, String> translations,
  required void Function(String newDescription) onSave,
}) {
  final controller = TextEditingController(text: currentDescription);

  AppEditBottomSheet.show<void>(
    context: context,
    title: translations['editDescTitle'] ?? 'Edit Deskripsi',
    subtitle: studentName,
    icon: Icons.edit_note_rounded,
    primaryColor: primaryColor,
    primaryLabel: translations['save'] ?? 'Simpan',
    cancelLabel: translations['cancel'] ?? 'Batal',
    onPrimary: () {
      onSave(controller.text);
      Navigator.pop(context);
    },
    body: TextField(
      controller: controller,
      maxLines: 5,
      minLines: 3,
      autofocus: true,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: translations['hint'] ?? 'Masukkan deskripsi...',
        hintStyle: TextStyle(
          fontSize: 13,
          color: ColorUtils.slate400,
        ),
        filled: true,
        fillColor: ColorUtils.slate50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: primaryColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    ),
  );
}
