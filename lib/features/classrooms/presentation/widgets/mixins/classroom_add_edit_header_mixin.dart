import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building the gradient header section of
/// [ClassroomAddEditSheet].
///
/// Provides [buildHeaderSection] to render icon, title,
/// subtitle, and close button.
mixin ClassroomAddEditHeaderMixin {
  /// Provides access to BuildContext for navigation.
  BuildContext get context;

  /// Provides access to class data (null = add mode).
  Map<String, dynamic>? get classData;

  /// Provides access to language provider for translations.
  dynamic get languageProvider;

  /// Builds the gradient header widget with icon, title,
  /// subtitle, and close button.
  ///
  /// Returns a Container with LinearGradient background
  /// and a Row containing icon, text, and close button.
  Widget buildHeaderSection() {
    final isEdit = classData != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            ColorUtils.corporateBlue600,
            ColorUtils.corporateBlue600.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _buildIconBox(isEdit),
          const SizedBox(width: 14),
          Expanded(child: _buildTitleSection(isEdit)),
          _buildCloseButton(),
        ],
      ),
    );
  }

  /// Builds the icon box (edit or add).
  Widget _buildIconBox(bool isEdit) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Icon(
        isEdit ? Icons.edit_rounded : Icons.add_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  /// Builds the title and subtitle section.
  Widget _buildTitleSection(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isEdit
              ? languageProvider.getTranslatedText({
                  'en': 'Edit Class',
                  'id': 'Edit Kelas',
                })
              : languageProvider.getTranslatedText({
                  'en': 'Add Class',
                  'id': 'Tambah Kelas',
                }),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          isEdit
              ? languageProvider.getTranslatedText({
                  'en': 'Update class information',
                  'id': 'Perbarui informasi kelas',
                })
              : languageProvider.getTranslatedText({
                  'en': 'Fill in class information',
                  'id': 'Isi informasi kelas',
                }),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Builds the close button positioned in top-right.
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
}
