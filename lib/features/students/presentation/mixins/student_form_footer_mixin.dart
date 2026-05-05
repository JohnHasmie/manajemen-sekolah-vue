import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/widgets/admin_form_components.dart';

/// Footer mixin for the student add/edit sheet — delegates to the
/// shared [AdminFormFooter] so every admin form lays out its bottom
/// row identically (Batal outline + accent primary, Samsung-safe).
mixin StudentFormFooterMixin {
  String t(Map<String, String> translations);
  bool get isEditMode;
  bool get isSaving;
  Future<void> handleSave();

  Widget buildFooterWidget() {
    return AdminFormFooter(
      primaryLabel: isEditMode
          ? t({'en': 'Update', 'id': 'Perbarui'})
          : t({'en': 'Save', 'id': 'Simpan'}),
      cancelLabel: t({'en': 'Cancel', 'id': 'Batal'}),
      onPrimary: handleSave,
      isSaving: isSaving,
    );
  }
}
