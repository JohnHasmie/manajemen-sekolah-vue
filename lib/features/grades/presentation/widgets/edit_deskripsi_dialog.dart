import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Bottom sheet for editing a student's grade description.
void showEditDeskripsiDialog({
  required BuildContext context,
  required String currentDescription,
  required String studentName,
  required Color primaryColor,
  required Map<String, String> translations,
  required void Function(String newDescription) onSave,
}) {
  final controller = TextEditingController(text: currentDescription);
  final p = primaryColor;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p, p.withValues(alpha: 0.85)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(children: [
              Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
              Row(children: [
                Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.edit_note_rounded, color: Colors.white, size: 20)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(translations['editDescTitle'] ?? 'Edit Deskripsi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(studentName, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                ])),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white, size: 20)),
              ]),
            ]),
          ),
          // Text field
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: controller,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: translations['hint'] ?? 'Masukkan deskripsi...',
                hintStyle: TextStyle(fontSize: 13, color: ColorUtils.slate400),
                filled: true, fillColor: ColorUtils.slate50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: p, width: 1.5)),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
          ),
          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SafeArea(top: false, child: Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), side: BorderSide(color: ColorUtils.slate300), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(translations['cancel'] ?? 'Batal', style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton(
                onPressed: () { onSave(controller.text); Navigator.pop(ctx); },
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: Text(translations['save'] ?? 'Simpan', style: const TextStyle(fontWeight: FontWeight.w600)),
              )),
            ])),
          ),
        ]),
      ),
    ),
  );
}
