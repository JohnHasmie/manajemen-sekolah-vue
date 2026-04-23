// Student add/edit bottom sheet — extracted from _showStudentDialog in
// admin_student_management_screen.dart. Owns all local form state and calls
// [onSave] with raw API data, leaving network calls and reload to the screen.
//
// Like a Vue modal form component: data flows IN via constructor params and
// OUT via callback — identical to how a Laravel FormRequest validates then
// the controller acts. Pass [student] to edit an existing record, omit it
// (or pass null) to add a new one.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/modern_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_dropdown.dart';
import 'package:manajemensekolah/features/students/presentation/widgets/student_dialog_text_field.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_form_validation_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_form_save_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_form_header_mixin.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_form_footer_mixin.dart';

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
    extends State<_StudentAddEditSheetContent>
    with
        StudentFormValidationMixin,
        StudentFormSaveMixin,
        StudentFormHeaderMixin,
        StudentFormFooterMixin {
  // ── Text controllers (like Vue v-model bindings) ──────────────────────────
  late final TextEditingController _nameController;
  late final TextEditingController _nisController;
  late final TextEditingController _addressController;
  late final TextEditingController _birthDateController;
  late final TextEditingController _parentNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailParentController;

  // ── UI state ──────────────────────────────────────────────────────────────
  final bool _isSaving = false;

  bool get _isEdit => widget.student != null;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?['name'] ?? '');
    _nisController = TextEditingController(text: s?['student_number'] ?? '');
    _addressController = TextEditingController(text: s?['address'] ?? '');
    _birthDateController = TextEditingController(
      text: s != null && s['date_of_birth'] != null
          ? s['date_of_birth'].toString().substring(0, 10)
          : '',
    );
    _parentNameController = TextEditingController(
      text: s?['guardian_name'] ?? '',
    );
    _phoneController = TextEditingController(text: s?['phone_number'] ?? '');
    _emailParentController = TextEditingController(
      text: s?['guardian_email'] ?? s?['parent_email'] ?? '',
    );

    nameController = _nameController;
    nisController = _nisController;
    addressController = _addressController;
    birthDateController = _birthDateController;
    parentNameController = _parentNameController;
    phoneController = _phoneController;
    emailParentController = _emailParentController;

    selectedClassId = s?['class']?['id'] ?? s?['class_id'];
    selectedGender = s?['gender'];
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

  // ── Translation helper ────────────────────────────────────────────────────
  @override
  String t(Map<String, String> translations) =>
      widget.ref.read(languageRiverpod).getTranslatedText(translations);

  @override
  BuildContext get buildContext => context;

  @override
  bool get isMounted => mounted;

  @override
  Map<String, dynamic>? get student => widget.student;

  @override
  void onSaveSuccess() => widget.onSave();

  @override
  Color get primaryColor => widget.primaryColor;

  @override
  bool get isEditMode => _isEdit;

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.ref.watch(languageRiverpod);
    String tLocal(Map<String, String> map) =>
        languageProvider.getTranslatedText(map);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        // SafeArea(top: false) so the gradient header can draw flush to
        // the sheet's rounded top without an extra top inset, while the
        // bottom inset keeps the footer clear of the Samsung nav bar.
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildHeaderWidget(),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _nameController,
                        label: tLocal({'en': 'Name', 'id': 'Nama'}),
                        icon: Icons.person,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _nisController,
                        label: 'NIS',
                        icon: Icons.badge,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogDropdown(
                        primaryColor: widget.primaryColor,
                        value: selectedClassId,
                        label: tLocal({'en': 'Class', 'id': 'Kelas'}),
                        icon: Icons.school,
                        items: widget.classList
                            .where((c) => c['id'] != null)
                            .map(
                              (c) => DropdownMenuItem<String>(
                                value: c['id'].toString(),
                                child: Text(c['name'] ?? 'Unknown Class'),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedClassId = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _addressController,
                        label: tLocal({'en': 'Address', 'id': 'Alamat'}),
                        icon: Icons.location_on,
                        maxLines: 2,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _birthDateController,
                        label: tLocal({
                          'en': 'Birth Date',
                          'id': 'Tanggal Lahir',
                        }),
                        icon: Icons.cake,
                        hintText: 'YYYY-MM-DD',
                        readOnly: true,
                        onTap: () async {
                          final s = widget.student;
                          final initialDate =
                              s != null && s['date_of_birth'] != null
                              ? DateTime.parse(s['date_of_birth'].toString())
                              : DateTime.now();
                          final DateTime? picked = await showModernDatePicker(
                            context: context,
                            initialDate: initialDate,
                            title: 'Pilih Tanggal Lahir',
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
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
                      StudentDialogDropdown(
                        primaryColor: widget.primaryColor,
                        value: selectedGender,
                        label: tLocal({'en': 'Gender', 'id': 'Jenis Kelamin'}),
                        icon: Icons.transgender,
                        items: [
                          DropdownMenuItem(
                            value: 'L',
                            child: Text(
                              tLocal({'en': 'Male', 'id': 'Laki-laki'}),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'P',
                            child: Text(
                              tLocal({'en': 'Female', 'id': 'Perempuan'}),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => selectedGender = value),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (_isEdit)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.warning600.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: const BorderRadius.all(
                              Radius.circular(12),
                            ),
                            border: Border.all(
                              color: ColorUtils.warning600.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              tLocal({
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
                              tLocal({
                                'en':
                                    'Link this student to a different user account based on the email below (does not edit the current linked user).',
                                'id':
                                    'Pindahkan siswa ini ke akun wali lain berdasarkan email di bawah (tidak merubah data user saat ini).',
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.slate600,
                              ),
                            ),
                            value: isChangeUserMode,
                            activeThumbColor: ColorUtils.warning600,
                            onChanged: (val) =>
                                setState(() => isChangeUserMode = val),
                          ),
                        ),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _parentNameController,
                        label: tLocal({
                          'en': 'Parent Name',
                          'id': 'Nama Wali Murid',
                        }),
                        icon: Icons.family_restroom,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _emailParentController,
                        label: tLocal({
                          'en': 'Parent Email',
                          'id': 'Email Wali Murid',
                        }),
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        hintText: 'wali@example.com',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StudentDialogTextField(
                        primaryColor: widget.primaryColor,
                        controller: _phoneController,
                        label: tLocal({
                          'en': 'Phone Number',
                          'id': 'No. Telepon',
                        }),
                        icon: Icons.phone,
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              buildFooterWidget(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool get isSaving => _isSaving;
}
