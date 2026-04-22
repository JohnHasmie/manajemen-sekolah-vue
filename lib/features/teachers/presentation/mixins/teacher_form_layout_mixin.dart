import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/teachers/presentation/widgets/teacher_form_dialog.dart';

/// Builds header, footer, and layout sections of teacher form
mixin TeacherFormLayoutMixin on ConsumerState<TeacherFormDialog> {
  // Declared and initialized in TeacherFormInitMixin — use abstract to
  // avoid shadowing the initialized value with a late storage slot.
  abstract bool isSaving;

  LinearGradient getCardGradient();

  Widget buildHeader(LanguageProvider languageProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: getCardGradient(),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: 14),
          Expanded(child: _buildHeaderText(languageProvider)),
          _buildCloseButton(),
        ],
      ),
    );
  }

  Widget _buildHeaderIcon() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Icon(
        widget.teacher == null ? Icons.person_add_rounded : Icons.edit_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  Widget _buildHeaderText(LanguageProvider languageProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.teacher == null
              ? languageProvider.getTranslatedText({
                  'en': 'Add Teacher',
                  'id': 'Tambah Guru',
                })
              : languageProvider.getTranslatedText({
                  'en': 'Edit Teacher',
                  'id': 'Edit Guru',
                }),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          widget.teacher == null
              ? languageProvider.getTranslatedText({
                  'en': 'Fill in teacher information',
                  'id': 'Isi data guru baru',
                })
              : languageProvider.getTranslatedText({
                  'en': 'Update teacher information',
                  'id': 'Perbarui data guru',
                }),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildCloseButton() {
    return GestureDetector(
      onTap: () => AppNavigator.pop(context),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
      ),
    );
  }

  Widget buildFooter(VoidCallback onSave) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: ColorUtils.slate200)),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(child: _buildCancelButton()),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildSaveButton(onSave)),
        ],
      ),
    );
  }

  Widget _buildCancelButton() {
    return OutlinedButton(
      onPressed: () => AppNavigator.pop(context),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: ColorUtils.slate300),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      child: Text(
        AppLocalizations.cancel.tr,
        style: TextStyle(
          color: ColorUtils.slate700,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSaveButton(VoidCallback onSave) {
    return ElevatedButton(
      onPressed: isSaving ? null : onSave,
      style: ElevatedButton.styleFrom(
        backgroundColor: ColorUtils.corporateBlue600,
        disabledBackgroundColor: ColorUtils.corporateBlue600.withValues(
          alpha: 0.6,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 13),
        elevation: 2,
        shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
      ),
      child: isSaving
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Text(
              AppLocalizations.save.tr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
    );
  }

  Widget buildFormContent(
    LanguageProvider languageProvider,
    Widget Function(LanguageProvider) formBodyBuilder,
  ) {
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [formBodyBuilder(languageProvider)],
        ),
      ),
    );
  }
}
