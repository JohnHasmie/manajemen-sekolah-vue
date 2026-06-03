import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/widgets/admin_form_sheet_header.dart';

/// Header UI mixin for the student add/edit bottom sheet.
///
/// Delegates to the shared [AdminFormSheetHeader] so the visual matches
/// the v3 actions mockup across every admin entity (Siswa, Guru, Kelas,
/// Mapel, Jadwal). Edit mode also surfaces the "MENGEDIT: `<name>`"
/// context strip when [editingContextLabel] is provided.
mixin StudentFormHeaderMixin {
  /// Translation helper — must be implemented by consuming class.
  String t(Map<String, String> translations);

  /// Is edit mode.
  bool get isEditMode;

  /// Optional name + class summary surfaced in the amber "MENGEDIT" strip.
  String? get editingContextLabel => null;

  /// Optional initials for the small avatar in the "MENGEDIT" strip.
  String? get editingContextInitials => null;

  /// Build the v3 header.
  Widget buildHeaderWidget() {
    final ctx =
        (isEditMode &&
            editingContextLabel != null &&
            editingContextLabel!.isNotEmpty)
        ? AdminFormContext(
            label: editingContextLabel!,
            initials: editingContextInitials ?? editingContextLabel!,
          )
        : null;
    return AdminFormSheetHeader(
      title: isEditMode
          ? t({'en': 'Edit Student', 'id': 'Edit Siswa'})
          : t({'en': 'Add Student', 'id': 'Tambah Siswa'}),
      isEditMode: isEditMode,
      kicker: isEditMode
          ? t({'en': 'EDIT DATA', 'id': 'EDIT DATA'})
          : t({'en': 'NEW ENTRY', 'id': 'TAMBAH BARU'}),
      editingContext: ctx,
    );
  }
}
