import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/widgets/admin_form_sheet_header.dart';

/// Header mixin for [ClassroomAddEditSheet] — delegates to the shared
/// [AdminFormSheetHeader] so the visual matches the v3 actions mockup.
mixin ClassroomAddEditHeaderMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to class data (null = add mode).
  Map<String, dynamic>? get classData;

  /// Provides access to language provider for translations.
  dynamic get languageProvider;

  Widget buildHeaderSection() {
    final isEdit = classData != null;
    final lp = languageProvider;
    final ctx = isEdit
        ? AdminFormContext(
            label: () {
              final c = classData!;
              final name = (c['name'] ?? '').toString();
              final grade = (c['grade_level'] ?? '').toString();
              if (name.isEmpty) return grade;
              return grade.isEmpty ? name : 'Tingkat $grade · $name';
            }(),
            initials: (classData!['name'] ?? '?').toString(),
          )
        : null;
    return AdminFormSheetHeader(
      title: isEdit
          ? lp.getTranslatedText({'en': 'Edit Class', 'id': 'Edit Kelas'})
              as String
          : lp.getTranslatedText({'en': 'Add Class', 'id': 'Tambah Kelas'})
              as String,
      isEditMode: isEdit,
      kicker: isEdit ? 'EDIT DATA' : 'TAMBAH BARU',
      editingContext: ctx,
    );
  }
}
