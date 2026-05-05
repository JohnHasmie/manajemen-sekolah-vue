import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_sheet_header.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';

mixin SubjectAddEditSheetHeaderMixin on ConsumerState<SubjectAddEditSheet> {
  /// Build the v3 header. The third argument is preserved for API
  /// compatibility but no longer used (the visual is locked by
  /// [AdminFormSheetHeader]).
  Widget buildHeader(
    BuildContext context,
    String titleKey,
    String subtitleKey,
    bool isEditing,
  ) {
    final lang = ref.watch(languageRiverpod);
    final ctx = isEditing && widget.subject != null
        ? AdminFormContext(
            label: () {
              final s = widget.subject!;
              final name = (s['name'] ?? '').toString();
              final code = (s['code'] ?? '').toString();
              if (name.isEmpty) return code;
              return code.isEmpty ? name : '$name · $code';
            }(),
            initials: (widget.subject!['name'] ?? '?').toString(),
          )
        : null;
    return AdminFormSheetHeader(
      title: isEditing
          ? lang.getTranslatedText(const {
              'en': 'Edit Subject',
              'id': 'Edit Mapel',
            })
          : lang.getTranslatedText(const {
              'en': 'Add Subject',
              'id': 'Tambah Mapel',
            }),
      isEditMode: isEditing,
      kicker: isEditing ? 'EDIT DATA' : 'TAMBAH BARU',
      editingContext: ctx,
    );
  }
}
