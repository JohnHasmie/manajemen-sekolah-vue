import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';

/// Footer mixin for [ClassroomAddEditSheet] — delegates to the shared
/// [AdminFormFooter].
mixin ClassroomAddEditFooterMixin {
  BuildContext get context;
  Map<String, dynamic>? get classData;
  bool get isSaving;
  dynamic get languageProvider;
  Future<void> submit();

  Widget buildFooterSection() {
    final isEdit = classData != null;
    final lp = languageProvider;
    return AdminFormFooter(
      primaryLabel: isEdit
          ? lp.getTranslatedText({'en': 'Update', 'id': 'Perbarui'}) as String
          : AppLocalizations.save.tr,
      cancelLabel: AppLocalizations.cancel.tr,
      onPrimary: submit,
      isSaving: isSaving,
    );
  }
}
