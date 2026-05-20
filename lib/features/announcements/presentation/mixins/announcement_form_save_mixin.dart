import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';
import 'package:manajemensekolah/features/announcements/presentation/widgets/announcement_form_sheet.dart';

/// Mixin for announcement form save/update logic.
mixin AnnouncementFormSaveMixin on State<AnnouncementFormSheet> {
  TextEditingController get titleController;
  TextEditingController get contentController;
  String? get selectedClassId;
  String? get selectedRole;
  String? get selectedPriority;
  DateTime? get startDate;
  DateTime? get endDate;
  File? get selectedFile;

  @override
  bool get mounted;
  bool get isEdit;

  Map<String, dynamic>? get announcementData;

  void setSaving(bool value);
  void callOnSaved();

  /// Validates form inputs before save.
  bool _validateInputs(LanguageProvider lang) {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      SnackBarUtils.showWarning(
        context,
        lang.getTranslatedText({
          'en': 'Title and content must be filled',
          'id': 'Judul dan konten harus diisi',
        }),
      );
      return false;
    }
    return true;
  }

  /// Builds announcement data map from form fields.
  Map<String, String> _buildAnnouncementData() {
    final data = <String, String>{
      'title': titleController.text,
      'content': contentController.text,
      'role_target': selectedRole ?? 'all',
      'priority': selectedPriority ?? 'normal',
      'type': 'general',
    };

    if (selectedClassId != null) {
      data['class_id'] = selectedClassId!;
    }
    if (startDate != null) {
      data['start_date'] = startDate!.toIso8601String();
    }
    if (endDate != null) {
      data['end_date'] = endDate!.toIso8601String();
    }

    return data;
  }

  /// Performs API call for create or update.
  Future<void> _performSave(
    Map<String, String> data,
    LanguageProvider lang,
  ) async {
    if (isEdit) {
      await getIt<ApiAnnouncementService>().updateAnnouncement(
        announcementData!['id'],
        data,
        selectedFile,
      );
    } else {
      await getIt<ApiAnnouncementService>().createAnnouncement(
        data,
        selectedFile,
      );
    }
  }

  /// Shows success message and closes sheet.
  void _showSuccessAndClose(LanguageProvider lang) {
    if (!mounted) return;

    SnackBarUtils.showSuccess(
      context,
      isEdit
          ? lang.getTranslatedText({
              'en': 'Announcement successfully updated',
              'id': 'Pengumuman berhasil diperbarui',
            })
          : lang.getTranslatedText({
              'en': 'Announcement successfully added',
              'id': 'Pengumuman berhasil ditambahkan',
            }),
    );
    AppNavigator.pop(context);
  }

  /// Shows error message.
  void _showError(String error, LanguageProvider lang) {
    if (!mounted) return;

    SnackBarUtils.showError(
      context,
      lang.getTranslatedText({
        'en': 'Failed to save announcement: $error',
        'id': 'Gagal menyimpan pengumuman: $error',
      }),
    );
  }

  /// Main save handler with validation and error handling.
  Future<void> handleSave(LanguageProvider lang) async {
    if (!_validateInputs(lang)) return;

    setSaving(true);

    try {
      final data = _buildAnnouncementData();
      await _performSave(data, lang);
      _showSuccessAndClose(lang);
      callOnSaved();
    } catch (e) {
      _showError(e.toString(), lang);
    } finally {
      if (mounted) {
        setSaving(false);
      }
    }
  }
}
