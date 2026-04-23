import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/subjects/presentation/widgets/subject_add_edit_sheet.dart';

mixin SubjectAddEditSheetHeaderMixin on ConsumerState<SubjectAddEditSheet> {
  /// Build the gradient header with title and close button
  Widget buildHeader(
    BuildContext context,
    String titleKey,
    String subtitleKey,
    bool isEditing,
  ) {
    final lang = ref.watch(languageRiverpod);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderIcon(isEditing),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: _buildHeaderText(lang, titleKey, subtitleKey)),
          _buildCloseButton(context),
        ],
      ),
    );
  }

  /// Icon container for header
  Widget _buildHeaderIcon(bool isEditing) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Icon(
        isEditing ? Icons.edit_rounded : Icons.add_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  /// Header title and subtitle text
  Widget _buildHeaderText(dynamic lang, String titleKey, String subtitleKey) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeaderTitle(lang, titleKey),
        const SizedBox(height: 2),
        _buildHeaderSubtitle(lang, subtitleKey),
      ],
    );
  }

  /// Header title text
  Widget _buildHeaderTitle(dynamic lang, String key) {
    return Text(
      lang.getTranslatedText({
        'en': key == 'edit' ? 'Edit Subject' : 'Add Subject',
        'id': key == 'edit' ? 'Edit Mata Pelajaran' : 'Tambah Mata Pelajaran',
      }),
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  /// Header subtitle text
  Widget _buildHeaderSubtitle(dynamic lang, String key) {
    return Text(
      lang.getTranslatedText({
        'en': key == 'edit'
            ? 'Update subject information'
            : 'Fill in subject details',
        'id': key == 'edit'
            ? 'Perbarui informasi mata pelajaran'
            : 'Isi detail mata pelajaran',
      }),
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }

  /// Close button in header
  Widget _buildCloseButton(BuildContext context) {
    return InkWell(
      onTap: () => AppNavigator.pop(context),
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 18),
      ),
    );
  }
}
