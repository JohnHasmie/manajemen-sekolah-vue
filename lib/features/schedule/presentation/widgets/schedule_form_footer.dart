import 'package:flutter/material.dart';

import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';

/// Schedule form footer — thin wrapper around shared [AdminFormFooter]
/// so the schedule sheet's bottom row matches every other admin form.
class ScheduleFormFooter extends StatelessWidget {
  final VoidCallback onSave;
  final Color primaryColor;
  final LanguageProvider languageProvider;

  const ScheduleFormFooter({
    super.key,
    required this.onSave,
    required this.primaryColor,
    required this.languageProvider,
  });

  @override
  Widget build(BuildContext context) {
    return AdminFormFooter(
      primaryLabel: languageProvider.getTranslatedText({
        'en': 'Save',
        'id': 'Simpan',
      }),
      cancelLabel: languageProvider.getTranslatedText({
        'en': 'Cancel',
        'id': 'Batal',
      }),
      onPrimary: onSave,
      accent: primaryColor,
    );
  }
}
