import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for announcement form header widget building.
mixin AnnouncementFormHeaderMixin on State<AnnouncementFormSheet> {
  bool get _isEdit;

  /// Builds header icon box.
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
        _isEdit ? Icons.edit_rounded : Icons.announcement_rounded,
        color: Colors.white,
        size: 22,
      ),
    );
  }

  /// Builds header title and subtitle.
  Widget _buildHeaderText(LanguageProvider lang) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isEdit
              ? lang.getTranslatedText({
                  'en': 'Edit Announcement',
                  'id': 'Edit Pengumuman',
                })
              : lang.getTranslatedText({
                  'en': 'Add Announcement',
                  'id': 'Tambah Pengumuman',
                }),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          _isEdit
              ? lang.getTranslatedText({
                  'en': 'Update announcement information',
                  'id': 'Perbarui informasi pengumuman',
                })
              : lang.getTranslatedText({
                  'en': 'Fill in announcement details',
                  'id': 'Isi detail pengumuman',
                }),
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  /// Builds close button.
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

  /// Builds gradient header with title and close button.
  Widget buildHeader(LanguageProvider lang, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          _buildHeaderIcon(),
          const SizedBox(width: 14),
          Expanded(child: _buildHeaderText(lang)),
          _buildCloseButton(),
        ],
      ),
    );
  }
}
