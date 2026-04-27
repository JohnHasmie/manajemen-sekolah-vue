// Shared scaffold for edit-style bottom sheets used across teacher pages
// (edit grade, edit attendance entry, edit material, etc.).
//
// Why this exists
// ---------------
// The canonical pattern across the app is:
//   drag handle → gradient header → scrollable form body →
//   Samsung-safe footer with a destructive "Hapus" on the left and
//   a primary "Simpan" on the right.
//
// ModernGradeEditorSheet established this pattern; this helper generalizes
// it so other edit flows (attendance, materials, lesson plans) don't
// reinvent the scaffold. Callers still own their form body and save/delete
// logic — this file only handles the shell.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';

/// A pre-composed edit bottom sheet with header, scrollable form body, and a
/// footer that pairs a save action with an optional destructive delete.
///
/// Example — create flow (save only):
/// ```dart
/// AppEditBottomSheet.show(
///   context: context,
///   title: 'Tambah Materi',
///   icon: Icons.library_books_rounded,
///   primaryColor: Colors.teal,
///   body: MyFormBody(),
///   primaryLabel: 'Simpan',
///   onPrimary: () => _save(),
/// );
/// ```
///
/// Example — edit flow (save + delete):
/// ```dart
/// AppEditBottomSheet.show(
///   context: context,
///   title: 'Ubah Nilai',
///   icon: Icons.edit_rounded,
///   primaryColor: Colors.blue,
///   body: MyFormBody(),
///   primaryLabel: 'Simpan Perubahan',
///   onPrimary: () => _save(),
///   destructiveLabel: 'Hapus',
///   onDestructive: () => _delete(),
/// );
/// ```
///
/// Returns whatever the sheet pops (commonly a typed result describing whether
/// data changed so the caller can refresh its list).
class AppEditBottomSheet {
  const AppEditBottomSheet._();

  /// Shows the edit sheet as a modal. Use the same generic as the callers'
  /// expected result type.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required IconData icon,
    required Color primaryColor,
    required Widget body,
    required String primaryLabel,
    required VoidCallback onPrimary,
    bool primaryEnabled = true,
    String? destructiveLabel,
    VoidCallback? onDestructive,
    String cancelLabel = 'Batal',
    double maxHeightFactor = 0.92,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.all(20),
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    // When a destructive action is provided, the left button acts as "Hapus"
    // (red outlined) and the right button is the primary save. Otherwise the
    // left button is a plain "Batal" that dismisses the sheet.
    final hasDestructive = destructiveLabel != null && onDestructive != null;

    return AppBottomSheet.show<T>(
      context: context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      primaryColor: primaryColor,
      content: body,
      contentPadding: contentPadding,
      maxHeightFactor: maxHeightFactor,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      footer: BottomSheetFooter(
        primaryLabel: primaryLabel,
        secondaryLabel: hasDestructive ? destructiveLabel : cancelLabel,
        primaryColor: primaryColor,
        primaryEnabled: primaryEnabled,
        secondaryDestructive: hasDestructive,
        onPrimary: onPrimary,
        onSecondary: hasDestructive
            ? onDestructive
            : () => Navigator.pop(context),
      ),
    );
  }
}
