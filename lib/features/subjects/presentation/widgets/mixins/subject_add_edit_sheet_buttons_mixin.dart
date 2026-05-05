import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';

mixin SubjectAddEditSheetButtonsMixin on ConsumerState<SubjectAddEditSheet> {
  bool get isSaving;
  Future<void> save(BuildContext context);

  Widget buildFooterButtons(BuildContext context) {
    return AdminFormFooter(
      primaryLabel: AppLocalizations.save.tr,
      cancelLabel: AppLocalizations.cancel.tr,
      onPrimary: () => save(context),
      isSaving: isSaving,
    );
  }
}
