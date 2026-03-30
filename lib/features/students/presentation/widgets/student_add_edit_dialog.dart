// Student add/edit bottom sheet — extracted from _showStudentDialog in
// admin_student_management_screen.dart. Owns all local form state and calls
// [onSave] with raw API data, leaving network calls and reload to the screen.
//
// Like a Vue modal form component: data flows IN via constructor params and
// OUT via callback — identical to how a Laravel FormRequest validates then
// the controller acts. Pass [student] to edit an existing record, omit it
// (or pass null) to add a new one.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_dropdown.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_text_field.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Opens a bottom sheet for adding or editing a student.
///
/// [student]    - pass an existing record map to enter edit mode; null = add mode.
/// [classList]  - list of class maps [{id, name}] used to populate the class dropdown.
/// [primaryColor] - role accent colour forwarded from the screen.
/// [onSave]     - called after a successful API save so the screen can reload.
void showStudentAddEditDialog({
  required BuildContext context,
  required WidgetRef ref,
  required List<dynamic> classList,
  required Color primaryColor,
  Map<String, dynamic>? student,
  required VoidCallback onSave,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StudentAddEditSheetContent(
      student: student,
      classList: classList,
      primaryColor: primaryColor,
      ref: ref,
      onSave: onSave,
    ),
  );
}

/// Internal stateful content widget that owns all form controllers and
/// "isSaving" flag — like a Vue component's local data().
class _StudentAddEditSheetContent extends StatefulWidget {
  final Map<String, dynamic>? student;
  final List<dynamic> classList;
  final Color primaryColor;
  final WidgetRef ref;
  final VoidCallback onSave;

  const _StudentAddEditSheetContent({
    required this.student,
    required this.classList,
    required this.primaryColor,
    required this.ref,
    required this.onSave,
  });

  @override
  State<_StudentAddEditSheetContent> createState() =>
      _StudentAddEditSheetContentState();
}

class _StudentAddEditSheetContentState
    extends State<_StudentAddEditSheetContent> {
  // ── Text controllers (like Vue v-model bindings) ──────────────────────────
  late final TextEditingController _nameController;
  late final TextEditingController _nisController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _parentNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailParentController;

  // ── Dropdown values ───────────────────────────────────────────────────────
  String? _selectedClassId;
  String? _selectedGender;

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _isSaving = false;

  /// Toggle: link student to a different guardian user account on save.
  /// Only relevant in edit mode — like a "change user" feature flag.
  bool _isChangeUserMode = false;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _nisController =
        TextEditingController(text: s?['student_number'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _birthDateController = TextEditingController(
      text: s != null && s['date_of_birth'] != null
          ? s['date_of_birth'].toString().substring(0, 10)
          : '',
    );
    _parentNameController =
        TextEditingController(text: s?['guardian_name'] ?? '');
    _phoneController =
        TextEditingController(text: s?['phone_number'] ?? '');
    _emailParentController = TextEditingController(
      text: s?['guardian_email'] ?? s?['parent_email'] ?? '',
    );

    _selectedClassId = s?['class']?['id'] ?? s?['class_id'];
    _selectedGender = s?['gender'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nisController.dispose();
    _addressController.dispose();
    _birthDateController.dispose();
    _parentNameController.dispose();
    _phoneController.dispose();
    _emailParentController.dispose();
    super.dispose();
  }

  // ── Gradient that wraps the sheet header ─────────────────────────────────
  LinearGradient get _headerGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          widget.primaryColor,
          widget.primaryColor.withValues(alpha: 0.85),
        ],
      );

  // ── Validation helpers ────────────────────────────────────────────────────

  /// Returns a translated string for [translations] map. Reads language from
  /// the injected [ref] — equivalent to Vue's `$t()` i18n helper.
  String _t(Map<String, String> translations) =>
      widget.ref.read(languageRiverpod).getTranslatedText(translations);

  bool _validateAndShowError() {
    final name = _nameController.text.trim();
    final nis = _nisController.text.trim();
    final address = _addressController.text.trim();
    final birthDate = _birthDateController.text.trim();
    final nameParent = _parentNameController.text.trim();
    final noPhone = _phoneController.text.trim();
    final emailParent = _emailParentController.text.trim();

    if (name.isEmpty ||
        nis.isEmpty ||
        _selectedClassId == null ||
        address.isEmpty ||
        birthDate.isEmpty ||
        _selectedGender == null ||
        nameParent.isEmpty ||
        noPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _t({'en': 'All fields must be filled', 'id': 'Semua field harus diisi'})),
          backgroundColor: ColorUtils.warning600,
        ),
      );
      return false;
    }

    if (emailParent.isNotEmpty &&
        !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailParent)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _t({'en': 'Invalid email format', 'id': 'Format email tidak valid'})),
          backgroundColor: ColorUtils.warning600,
        ),
      );
      return false;
    }

    return true;
  }

  // ── Save handler (calls API then triggers parent reload via [onSave]) ─────
  Future<void> _handleSave() async {
    if (!_validateAndShowError()) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    final nis = _nisController.text.trim();
    final address = _addressController.text.trim();
    final birthDate = _birthDateController.text.trim();
    final nameParent = _parentNameController.text.trim();
    final noPhone = _phoneController.text.trim();
    final emailParent = _emailParentController.text.trim();

    try {
      final data = {
        'name': name,
        'student_number': nis,
        'class_id': _selectedClassId,
        'address': address,
        'date_of_birth': birthDate,
        'gender': _selectedGender,
        'guardian_name': nameParent,
        'phone_number': noPhone,
        'guardian_email': emailParent,
        if (_isEdit && _isChangeUserMode) 'use_another_user': true,
      };

      if (_isEdit) {
        await getIt<ApiStudentService>()
            .updateStudent(widget.student!['id'], data);
      } else {
        await getIt<ApiStudentService>().addStudent(data);
      }

      // Notify parent to reload BEFORE closing the sheet so the list
      // refreshes as soon as the user sees it — like emitting 'saved' in Vue.
      widget.onSave();

      if (mounted) {
        final successMsg = _isEdit
            ? _t({'en': 'Student successfully updated', 'id': 'Siswa berhasil diperbarui'})
            : _t({'en': 'Student successfully added', 'id': 'Siswa berhasil ditambahkan'});

        final emailNote = emailParent.isNotEmpty
            ? _t({
                'en': '\nParent user linked/created. Default password for new user is password123',
                'id': '\nData wali terkait & Akun wali (User) ikut diperbarui/dibuat. Password akun baru: password123',
              })
            : '';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMsg + emailNote),
            backgroundColor: ColorUtils.success600,
          ),
        );
        AppNavigator.pop(context);
      }
    } catch (e) {
      AppLogger.error('student', 'Save/Update student error: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Icon(Icons.error_outline, color: ColorUtils.error600),
                SizedBox(width: AppSpacing.sm),
                Text(
                  _t({'en': 'Error', 'id': 'Gagal'}),
                  style: TextStyle(color: ColorUtils.error600),
                ),
              ],
            ),
            content: Text(
              '${_t({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(e)}',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () => AppNavigator.pop(ctx),
                child: Text('OK',
                    style: TextStyle(color: widget.primaryColor)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Watch language so the sheet re-renders when locale changes mid-session —
    // same as Vue's reactive computed property reading from Vuex.
    final languageProvider = widget.ref.watch(languageRiverpod);
    String t(Map<String, String> map) =>
        languageProvider.getTranslatedText(map);

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Gradient header ─────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                decoration: BoxDecoration(
                  gradient: _headerGradient,
                  borderRadius: const BorderRadius.only(
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
                            color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      child: Icon(
                        _isEdit
                            ? Icons.edit_rounded
                            : Icons.person_add_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEdit
                                ? t({'en': 'Edit Student', 'id': 'Edit Siswa'})
                                : t({
                                    'en': 'Add Student',
                                    'id': 'Tambah Siswa'
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
                                ? t({
                                    'en': 'Update student information',
                                    'id': 'Perbarui data siswa'
                                  })
                                : t({
                                    'en': 'Fill in student information',
                                    'id': 'Isi data siswa baru'
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
                        child: const Icon(Icons.close_rounded,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Scrollable form body ────────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Name
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _nameController,
                        label: t({'en': 'Name', 'id': 'Nama'}),
                        icon: Icons.person,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // NIS
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _nisController,
                        label: 'NIS',
                        icon: Icons.badge,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Class dropdown
                      StudentDialogDropdown(
                        primaryColor: widget.primaryColor,
                        value: _selectedClassId,
                        label: t({'en': 'Class', 'id': 'Kelas'}),
                        icon: Icons.school,
                        items: widget.classList
                            .where((c) => c['id'] != null)
                            .map((c) => DropdownMenuItem<String>(
                                  value: c['id'].toString(),
                                  child: Text(c['name'] ?? 'Unknown Class'),
                                ))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _selectedClassId = value),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Address
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _addressController,
                        label: t({'en': 'Address', 'id': 'Alamat'}),
                        icon: Icons.location_on,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Birth date (read-only, date picker on tap)
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _birthDateController,
                        label: t({'en': 'Birth Date', 'id': 'Tanggal Lahir'}),
                        icon: Icons.cake,
                        hintText: 'YYYY-MM-DD',
                        readOnly: true,
                        onTap: () async {
                          final s = widget.student;
                          final initialDate =
                              s != null && s['date_of_birth'] != null
                                  ? DateTime.parse(
                                      s['date_of_birth'].toString())
                                  : DateTime.now();
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: initialDate,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                            builder: (ctx, child) => Theme(
                              data: Theme.of(ctx).copyWith(
                                colorScheme: ColorScheme.light(
                                  primary: widget.primaryColor,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.black,
                                ),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            setState(() {
                              _birthDateController.text =
                                  '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Gender dropdown
                      StudentDialogDropdown(
                        primaryColor: widget.primaryColor,
                        value: _selectedGender,
                        label: t({'en': 'Gender', 'id': 'Jenis Kelamin'}),
                        icon: Icons.transgender,
                        items: [
                          DropdownMenuItem(
                            value: 'L',
                            child: Text(
                                t({'en': 'Male', 'id': 'Laki-laki'})),
                          ),
                          DropdownMenuItem(
                            value: 'P',
                            child: Text(
                                t({'en': 'Female', 'id': 'Perempuan'})),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedGender = value),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // "Change guardian user" toggle — edit mode only.
                      // Like a feature flag visible only when editing,
                      // analogous to showing an extra Laravel form field
                      // only on the PUT route.
                      if (_isEdit)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.warning600
                                .withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: ColorUtils.warning600
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              t({
                                'en':
                                    'Use Another User / Change Guardian Account',
                                'id':
                                    'Ganti Akun Wali / Gunakan User Wali Lain',
                              }),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.warning600,
                              ),
                            ),
                            subtitle: Text(
                              t({
                                'en':
                                    'Link this student to a different user account based on the email below (does not edit the current linked user).',
                                'id':
                                    'Pindahkan siswa ini ke akun wali lain berdasarkan email di bawah (tidak merubah data user saat ini).',
                              }),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: ColorUtils.slate600),
                            ),
                            value: _isChangeUserMode,
                            activeThumbColor: ColorUtils.warning600,
                            onChanged: (val) =>
                                setState(() => _isChangeUserMode = val),
                          ),
                        ),

                      // Parent name
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _parentNameController,
                        label: t({
                          'en': 'Parent Name',
                          'id': 'Nama Wali Murid'
                        }),
                        icon: Icons.family_restroom,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Parent email
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _emailParentController,
                        label: t({
                          'en': 'Parent Email',
                          'id': 'Email Wali Murid'
                        }),
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'wali@example.com',
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Phone
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _phoneController,
                        label: t({
                          'en': 'Phone Number',
                          'id': 'No. Telepon'
                        }),
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Sticky footer: Cancel + Save/Update ─────────────────────
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border:
                      Border(top: BorderSide(color: ColorUtils.slate200)),
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
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          side:
                              BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          t({'en': 'Cancel', 'id': 'Batal'}),
                          style: TextStyle(
                              color: ColorUtils.slate700,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _handleSave,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.primaryColor,
                          disabledBackgroundColor:
                              widget.primaryColor.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shadowColor:
                              widget.primaryColor.withValues(alpha: 0.4),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : Text(
                                _isEdit
                                    ? t({'en': 'Update', 'id': 'Perbarui'})
                                    : t({'en': 'Save', 'id': 'Simpan'}),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
