// Bottom sheet form for creating/editing announcements.
//
// Extracted from admin_announcement_screen.dart to reduce file size.
// Like a Vue component that handles the announcement CRUD form,
// receiving callbacks for save actions.
//
// In Laravel terms, this is the "create/edit form" partial that posts to
// POST /api/announcements or PUT /api/announcements/{id}.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/announcements/data/announcement_service.dart';

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

class _AnnouncementFormSheetState extends State<AnnouncementFormSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final String? _selectedClassId;
  late String? _selectedRole;
  late String? _selectedPriority;
  DateTime? _startDate;
  DateTime? _endDate;
  File? _selectedFile;
  bool _isSaving = false;

  bool get _isEdit => widget.announcementData != null;

  @override
  void initState() {
    super.initState();
    final data = widget.announcementData;

    _titleController = TextEditingController(text: data?['title'] ?? '');
    _contentController = TextEditingController(text: data?['content'] ?? '');
    _selectedClassId = data?['kelas_id'];
    _selectedRole = data?['role_target'] ?? 'all';

    // Normalize priority value from API (biasa->normal, penting->important)
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

  @override
  Widget build(BuildContext context) {
    final lang = widget.languageProvider;
    final primaryColor = widget.primaryColor;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // --- Gradient Header ---
              _buildHeader(lang, primaryColor),

              // --- Scrollable Form Body ---
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogTextField(
                        controller: _titleController,
                        label: lang.getTranslatedText({
                          'en': 'Title',
                          'id': 'Judul',
                        }),
                        icon: Icons.title,
                        primaryColor: primaryColor,
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildDialogTextField(
                        controller: _contentController,
                        label: lang.getTranslatedText({
                          'en': 'Content',
                          'id': 'Konten',
                        }),
                        icon: Icons.description,
                        maxLines: 4,
                        primaryColor: primaryColor,
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildPrioritasDropdown(lang, primaryColor),
                      SizedBox(height: AppSpacing.md),
                      _buildRoleTargetDropdown(lang, primaryColor),
                      SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: lang.getTranslatedText({
                                'en': 'Start Date',
                                'id': 'Tanggal Mulai',
                              }),
                              value: _startDate,
                              onTap: () => _selectDate(
                                context,
                                true,
                                (date) => setState(() => _startDate = date),
                              ),
                              primaryColor: primaryColor,
                            ),
                          ),
                          SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: _buildDateField(
                              label: lang.getTranslatedText({
                                'en': 'End Date',
                                'id': 'Tanggal Berakhir',
                              }),
                              value: _endDate,
                              onTap: () => _selectDate(
                                context,
                                false,
                                (date) => setState(() => _endDate = date),
                              ),
                              primaryColor: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      _buildFilePicker(lang, primaryColor),
                    ],
                  ),
                ),
              ),

              // --- Footer ---
              _buildFooter(lang, primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader(LanguageProvider lang, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primaryColor,
            primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            child: Icon(
              _isEdit ? Icons.edit_rounded : Icons.announcement_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
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
            ),
          ),
          GestureDetector(
            onTap: () => AppNavigator.pop(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Footer with Cancel / Save buttons
  // ---------------------------------------------------------------------------

  Widget _buildFooter(LanguageProvider lang, Color primaryColor) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: ColorUtils.slate200),
        ),
        boxShadow: [
          BoxShadow(
            color: ColorUtils.slate900.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => AppNavigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: ColorUtils.slate300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                lang.getTranslatedText({
                  'en': 'Cancel',
                  'id': 'Batal',
                }),
                style: TextStyle(
                  color: ColorUtils.slate700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : () => _handleSave(lang),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                disabledBackgroundColor: primaryColor.withValues(alpha: 0.6),
                padding: EdgeInsets.symmetric(vertical: 14),
                elevation: 2,
                shadowColor: primaryColor.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _isEdit
                          ? lang.getTranslatedText({
                              'en': 'Update',
                              'id': 'Perbarui',
                            })
                          : lang.getTranslatedText({
                              'en': 'Save',
                              'id': 'Simpan',
                            }),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save handler – calls the API service directly
  // ---------------------------------------------------------------------------

  Future<void> _handleSave(LanguageProvider lang) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            lang.getTranslatedText({
              'en': 'Title and content must be filled',
              'id': 'Judul dan konten harus diisi',
            }),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final Map<String, String> data = {
        'title': _titleController.text,
        'content': _contentController.text,
        'role_target': _selectedRole ?? 'all',
        'priority': _selectedPriority ?? 'normal',
        'type': 'general',
      };

      if (_selectedClassId != null) {
        data['class_id'] = _selectedClassId;
      }
      if (_startDate != null) {
        data['start_date'] = _startDate!.toIso8601String();
      }
      if (_endDate != null) {
        data['end_date'] = _endDate!.toIso8601String();
      }

      if (_isEdit) {
        await getIt<ApiAnnouncementService>().updateAnnouncement(
          widget.announcementData!['id'],
          data,
          _selectedFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.getTranslatedText({
                  'en': 'Announcement successfully updated',
                  'id': 'Pengumuman berhasil diperbarui',
                }),
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
          AppNavigator.pop(context);
        }
      } else {
        await getIt<ApiAnnouncementService>().createAnnouncement(
          data,
          _selectedFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                lang.getTranslatedText({
                  'en': 'Announcement successfully added',
                  'id': 'Pengumuman berhasil ditambahkan',
                }),
              ),
              backgroundColor: ColorUtils.success600,
            ),
          );
          AppNavigator.pop(context);
        }
      }
      widget.onSaved();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lang.getTranslatedText({
                'en': 'Failed to save announcement: $e',
                'id': '${AppLocalizations.failedToSave.tr}: $e',
              }),
            ),
            backgroundColor: ColorUtils.error600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Form field helpers (extracted from parent screen)
  // ---------------------------------------------------------------------------

  /// Styled text field used for title and content inputs.
  /// Like a reusable `<v-text-field>` component in Vuetify.
  Widget _buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color primaryColor,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: primaryColor, size: 20),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: primaryColor, width: 1.5),
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPrioritasDropdown(LanguageProvider lang, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedPriority,
        decoration: InputDecoration(
          labelText: lang.getTranslatedText({
            'en': 'Priority',
            'id': 'Prioritas',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(
            Icons.priority_high,
            color: primaryColor,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'normal',
            child: Row(
              children: [
                Icon(Icons.circle, color: ColorUtils.slate400, size: 16),
                SizedBox(width: AppSpacing.sm),
                Text(
                  lang.getTranslatedText({
                    'en': 'Normal',
                    'id': 'Biasa',
                  }),
                ),
              ],
            ),
          ),
          DropdownMenuItem(
            value: 'important',
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.orange, size: 16),
                SizedBox(width: AppSpacing.sm),
                Text(
                  lang.getTranslatedText({
                    'en': 'Important',
                    'id': 'Penting',
                  }),
                ),
              ],
            ),
          ),
        ],
        onChanged: (value) => setState(() => _selectedPriority = value),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildRoleTargetDropdown(LanguageProvider lang, Color primaryColor) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedRole,
        decoration: InputDecoration(
          labelText: lang.getTranslatedText({
            'en': 'Target Role',
            'id': 'Role Target',
          }),
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(Icons.people, color: primaryColor, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 12),
        ),
        items: [
          DropdownMenuItem(
            value: 'all',
            child: Text(
              lang.getTranslatedText({
                'en': 'All Users',
                'id': 'Semua Pengguna',
              }),
            ),
          ),
          DropdownMenuItem(value: 'admin', child: Text('Admin')),
          DropdownMenuItem(value: 'teacher', child: Text('Guru')),
          DropdownMenuItem(value: 'student', child: Text('Siswa')),
          DropdownMenuItem(value: 'parent', child: Text('Wali')),
        ],
        onChanged: (value) => setState(() => _selectedRole = value),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required Color primaryColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ColorUtils.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: ColorUtils.slate200),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: primaryColor, size: 20),
            SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                value != null
                    ? '${value.day}/${value.month}/${value.year}'
                    : label,
                style: TextStyle(
                  color: value != null
                      ? ColorUtils.slate800
                      : ColorUtils.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    bool isStartDate,
    Function(DateTime) onDateSelected,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      onDateSelected(picked);
    }
  }

  Widget _buildFilePicker(LanguageProvider lang, Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lang.getTranslatedText({
              'en': 'Attachment (Optional)',
              'id': 'Lampiran (Opsional)',
            }),
            style: TextStyle(
              fontSize: 12,
              color: ColorUtils.slate600,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          if (_selectedFile != null)
            Container(
              padding: EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: ColorUtils.slate300),
              ),
              child: Row(
                children: [
                  Icon(Icons.description, color: primaryColor, size: 20),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _selectedFile!.path.split('/').last,
                      style: TextStyle(fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: ColorUtils.error600,
                      size: 20,
                    ),
                    onPressed: () {
                      setState(() {
                        _selectedFile = null;
                      });
                    },
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(),
                  ),
                ],
              ),
            ),
          if (_selectedFile == null)
            InkWell(
              onTap: _pickFile,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.5),
                    style: BorderStyle.solid,
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: primaryColor,
                      size: 24,
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      lang.getTranslatedText({
                        'en': 'Tap to upload file',
                        'id': 'Ketuk untuk unggah file',
                      }),
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'PDF, DOC, DOCX, JPG, PNG (Max 5MB)',
                      style: TextStyle(
                        color: ColorUtils.slate500,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'doc', 'docx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      AppLogger.error('announcement', 'Error picking file: $e');
    }
  }
}
