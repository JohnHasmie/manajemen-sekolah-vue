// Bottom sheet form for creating/editing announcements.
//
// Migrated to the shared [AppBottomSheet] + [BottomSheetFooter] scaffold
// during the Admin Refactor · Phase 4 so the compose sheet shares the
// canonical drag-handle → gradient-header → scrollable-body → Samsung-safe
// footer layout with every other admin edit sheet (Kelas, Mapel, Jadwal,
// Keuangan, etc.). The field-level mixins that build form rows, date
// pickers, file picker, and save logic are preserved verbatim; only the
// hand-rolled header/footer containers were retired (see deleted
// `announcement_form_*_header/footer_mixin.dart`).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/app_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/bottom_sheet_footer.dart';
import 'package:manajemensekolah/features/announcements/domain/models/announcement.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_form_date_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_form_fields_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_form_file_mixin.dart';
import 'package:manajemensekolah/features/announcements/presentation/mixins/announcement_form_save_mixin.dart';

/// A bottom sheet form for adding or editing an announcement.
///
/// Receives optional [announcementData] for edit mode, a [primaryColor] for
/// theming, a [languageProvider] for translations, and an [onSaved] callback
/// to notify the parent when a save/update completes successfully.
class AnnouncementFormSheet extends StatefulWidget {
  final Map<String, dynamic>? announcementData;
  final Color primaryColor;
  final LanguageProvider languageProvider;
  final VoidCallback onSaved;

  const AnnouncementFormSheet({
    super.key,
    this.announcementData,
    required this.primaryColor,
    required this.languageProvider,
    required this.onSaved,
  });

  @override
  State<AnnouncementFormSheet> createState() => _AnnouncementFormSheetState();
}

class _AnnouncementFormSheetState extends State<AnnouncementFormSheet>
    with
        AnnouncementFormSaveMixin,
        AnnouncementFormFieldsMixin,
        AnnouncementFormDateMixin,
        AnnouncementFormFileMixin {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final String? _selectedClassId;
  late String? _selectedRole;
  late String? _selectedPriority;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedFile;
  bool _isSaving = false;

  @override
  bool get _isEdit => widget.announcementData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.announcementData;
    final model = data != null ? Announcement.fromJson(data) : null;

    _titleController = TextEditingController(text: model?.title ?? '');
    _contentController = TextEditingController(text: model?.content ?? '');
    _selectedClassId = data?['kelas_id'];
    _selectedRole = data?['role_target'] ?? 'all';

    // Normalize priority value from API
    final String? rawPriority = data?['priority'];
    if (rawPriority != null) {
      if (rawPriority.toLowerCase() == 'biasa') {
        _selectedPriority = 'normal';
      } else if (rawPriority.toLowerCase() == 'penting') {
        _selectedPriority = 'important';
      } else {
        _selectedPriority = rawPriority.toLowerCase();
      }
    } else {
      _selectedPriority = 'normal';
    }

    _startDate = data?['start_date'] != null
        ? DateTime.parse(data!['start_date'])
        : null;
    _endDate = data?['end_date'] != null
        ? DateTime.parse(data!['end_date'])
        : null;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  /// Builds form fields column (title, content, dropdowns, dates, file).
  Widget _buildFormFields(LanguageProvider lang, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        buildDialogTextField(
          controller: _titleController,
          label: lang.getTranslatedText({'en': 'Title', 'id': 'Judul'}),
          icon: Icons.title,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.md),
        buildDialogTextField(
          controller: _contentController,
          label: lang.getTranslatedText({'en': 'Content', 'id': 'Konten'}),
          icon: Icons.description,
          maxLines: 4,
          primaryColor: primaryColor,
        ),
        const SizedBox(height: AppSpacing.md),
        buildPrioritasDropdown(
          lang,
          primaryColor,
          _selectedPriority,
          (value) => setState(() => _selectedPriority = value),
        ),
        const SizedBox(height: AppSpacing.md),
        buildRoleTargetDropdown(
          lang,
          primaryColor,
          _selectedRole,
          (value) => setState(() => _selectedRole = value),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildDateRow(lang, primaryColor),
        const SizedBox(height: AppSpacing.md),
        buildFilePicker(lang, primaryColor),
      ],
    );
  }

  /// Builds date fields row (Start Date / End Date).
  Widget _buildDateRow(LanguageProvider lang, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: buildDateField(
            label: lang.getTranslatedText({
              'en': 'Start Date',
              'id': 'Tanggal Mulai',
            }),
            value: _startDate,
            onTap: () => selectDate(
              context,
              true,
              (date) => setState(() => _startDate = date),
            ),
            primaryColor: primaryColor,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: buildDateField(
            label: lang.getTranslatedText({
              'en': 'End Date',
              'id': 'Tanggal Berakhir',
            }),
            value: _endDate,
            onTap: () => selectDate(
              context,
              false,
              (date) => setState(() => _endDate = date),
            ),
            primaryColor: primaryColor,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;
    final primaryColor = widget.primaryColor;

    return Padding(
      // MediaQuery viewInsets handling — keep the sheet lifted above the
      // on-screen keyboard when a text field is focused. AppBottomSheet
      // sets maxHeightFactor internally so we don't need an outer SizedBox.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: AppBottomSheet(
        title: _isEdit
            ? lang.getTranslatedText({
                'en': 'Edit Announcement',
                'id': 'Edit Pengumuman',
              })
            : lang.getTranslatedText({
                'en': 'Add Announcement',
                'id': 'Tambah Pengumuman',
              }),
        subtitle: _isEdit
            ? lang.getTranslatedText({
                'en': 'Update announcement information',
                'id': 'Perbarui informasi pengumuman',
              })
            : lang.getTranslatedText({
                'en': 'Fill in announcement details',
                'id': 'Isi detail pengumuman',
              }),
        icon: _isEdit ? Icons.edit_rounded : Icons.announcement_rounded,
        primaryColor: primaryColor,
        maxHeightFactor: 0.92,
        contentPadding: const EdgeInsets.all(AppSpacing.xl),
        content: _buildFormFields(lang, primaryColor),
        footer: BottomSheetFooter(
          primaryLabel: _isSaving
              ? lang.getTranslatedText({'en': 'Saving…', 'id': 'Menyimpan…'})
              : (_isEdit
                    ? lang.getTranslatedText({'en': 'Update', 'id': 'Perbarui'})
                    : lang.getTranslatedText({'en': 'Save', 'id': 'Simpan'})),
          secondaryLabel: lang.getTranslatedText({
            'en': 'Cancel',
            'id': 'Batal',
          }),
          primaryColor: primaryColor,
          primaryEnabled: !_isSaving,
          onPrimary: () => handleSave(lang),
          onSecondary: () => AppNavigator.pop(context),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Mixin support methods
  // ---------------------------------------------------------------------------

  @override
  TextEditingController get titleController => _titleController;

  @override
  TextEditingController get contentController => _contentController;

  @override
  String? get selectedClassId => _selectedClassId;

  @override
  String? get selectedRole => _selectedRole;

  @override
  String? get selectedPriority => _selectedPriority;

  @override
  DateTime? get startDate => _startDate;

  @override
  DateTime? get endDate => _endDate;

  @override
  File? get selectedFile => _selectedFile;

  @override
  Map<String, dynamic>? get announcementData => widget.announcementData;

  @override
  void setSaving(bool value) {
    setState(() => _isSaving = value);
  }

  @override
  void callOnSaved() {
    widget.onSaved();
  }

  @override
  File? getSelectedFile() => _selectedFile;

  @override
  void setSelectedFile(File file) {
    setState(() => _selectedFile = file);
  }

  @override
  void clearFile() {
    setState(() => _selectedFile = null);
  }
}
