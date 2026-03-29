// Dialog for editing a student's grade description (deskripsi).
// Extracted from `_showEditDeskripsiDialog` in
// `teacher_grade_recap_screen.dart`.
//
// In Vue terms this is a child component that receives the current description
// text as a prop and emits a `@save` event with the new text.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Shows a dialog where the teacher can edit the narrative description for a
/// student's grade recap row.
///
/// [currentDescription] -- the text currently stored in the description field.
/// [studentName] -- displayed in the dialog title.
/// [primaryColor] -- the theme accent colour (from `_getPrimaryColor()`).
/// [translations] -- a map with keys 'editDescTitle', 'hint', 'cancel',
///   'save' so the caller can pass pre-translated strings (avoids needing
///   a Riverpod ref inside this helper).
/// [onSave] -- called with the new description text when the user taps Save.
void showEditDeskripsiDialog({
  required BuildContext context,
  required String currentDescription,
  required String studentName,
  required Color primaryColor,
  required Map<String, String> translations,
  required void Function(String newDescription) onSave,
}) {
  final TextEditingController tempController = TextEditingController(
    text: currentDescription,
  );

  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text(
          translations['editDescTitle'] ?? 'Edit Deskripsi - $studentName',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: tempController,
            maxLines: 5,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              hintText: translations['hint'] ?? 'Masukkan deskripsi...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(context),
            child: Text(translations['cancel'] ?? 'Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              onSave(tempController.text);
              AppNavigator.pop(context);
            },
            child: Text(translations['save'] ?? 'Simpan'),
          ),
        ],
      );
    },
  );
}
