import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
import 'package:manajemensekolah/core/widgets/admin_form_sheet_header.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Builds header, footer, and layout sections of teacher form
mixin TeacherFormLayoutMixin on ConsumerState<TeacherFormDialog> {
  // Declared and initialized in TeacherFormInitMixin — use abstract to
  // avoid shadowing the initialized value with a late storage slot.
  abstract bool isSaving;

  // Note: getCardGradient() used to be required when this mixin owned the
  // gradient header. The header now lives in [AdminFormSheetHeader] and
  // pulls its gradient from `ColorUtils.brandGradient('admin')`, so the
  // dependency is gone. The teacher_form_ui_mixin still defines a
  // getCardGradient() helper for any legacy callers — leave it as-is.

  Widget buildHeader(LanguageProvider languageProvider) {
    final isEdit = widget.teacher != null;
    final ctx = isEdit
        ? AdminFormContext(
            label: () {
              final t = widget.teacher!;
              final name = (t['name'] ?? t['user']?['name'] ?? '').toString();
              final extra = (t['nip'] ?? t['email'] ?? '').toString();
              if (name.isEmpty) return extra;
              return extra.isEmpty ? name : '$name · $extra';
            }(),
            initials: (widget.teacher!['name'] ??
                    widget.teacher!['user']?['name'] ??
                    '?')
                .toString(),
          )
        : null;
    return AdminFormSheetHeader(
      title: isEdit
          ? languageProvider.getTranslatedText(const {
              'en': 'Edit Teacher',
              'id': 'Edit Guru',
            })
          : languageProvider.getTranslatedText(const {
              'en': 'Add Teacher',
              'id': 'Tambah Guru',
            }),
      isEditMode: isEdit,
      kicker: isEdit
          ? languageProvider.getTranslatedText(const {
              'en': 'EDIT DATA',
              'id': 'EDIT DATA',
            })
          : languageProvider.getTranslatedText(const {
              'en': 'NEW ENTRY',
              'id': 'TAMBAH BARU',
            }),
      editingContext: ctx,
    );
  }

  Widget buildFooter(VoidCallback onSave) {
    return AdminFormFooter(
      primaryLabel: AppLocalizations.save.tr,
      cancelLabel: AppLocalizations.cancel.tr,
      onPrimary: onSave,
      isSaving: isSaving,
    );
  }

  Widget buildFormContent(
    LanguageProvider languageProvider,
    Widget Function(LanguageProvider) formBodyBuilder,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        4,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [formBodyBuilder(languageProvider)],
      ),
    );
  }
}
