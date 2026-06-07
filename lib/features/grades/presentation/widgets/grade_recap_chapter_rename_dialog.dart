// Rename-chapter dialog for the grade recap screen.
//
// Why this exists
// ---------------
// The recap table's chapter columns can be renamed in place — long-press
// → bottom sheet → "Ubah nama" — and that flow needs a small dialog with
// a single text field, autofocus, and a Simpan / Batal pair. The recap
// screen used to inline the AlertDialog body, but extracting it lets us
// pair it visually with [grade_recap_delete_chapter_dialog.dart] and
// keeps the screen file out of widget-construction territory.
//
// Returns the new name on Simpan, `null` on Batal / dismiss / empty.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// Shows a small AlertDialog for renaming a chapter. Resolves to:
///  • the trimmed new name on Simpan or text-field onSubmitted
///  • `null` on Batal, system dismiss, or unchanged input
Future<String?> showGradeRecapChapterRenameDialog({
  required BuildContext context,
  required String currentName,
}) async {
  final controller = TextEditingController(text: currentName);
  final newName = await showDialog<String>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Text(kGraRenameChapter.tr),
      content: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: kGraChapterName.tr,
          hintText: kGraChapterNameExample.tr,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.of(dialogCtx).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: Text(kCancel.tr),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(dialogCtx).pop(controller.text.trim()),
          child: Text(kSave.tr),
        ),
      ],
    ),
  );
  // Defer disposal — the dialog's close animation may still rebuild
  // the TextField on the next frame and would crash with
  // "TextEditingController used after disposed".
  WidgetsBinding.instance.addPostFrameCallback((_) {
    controller.dispose();
  });
  if (newName == null || newName.isEmpty || newName == currentName) {
    return null;
  }
  return newName;
}
