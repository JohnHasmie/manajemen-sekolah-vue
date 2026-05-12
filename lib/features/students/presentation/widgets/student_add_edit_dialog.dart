// Student add/edit bottom sheet — extracted from _showStudentDialog in
// admin_student_management_screen.dart. Owns all local form state and calls
// [onSave] with raw API data, leaving network calls and reload to the screen.
//
// Like a Vue modal form component: data flows IN via constructor params and
// OUT via callback — identical to how a Laravel FormRequest validates then
// the controller acts. Pass [student] to edit an existing record, omit it
// (or pass null) to add a new one.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/widgets/admin_form_components.dart';
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

  /// "MENGEDIT: <Nama · Kelas>" context strip — only rendered in edit mode.
  @override
  String? get editingContextLabel {
    if (!_isEdit) return null;
    final s = widget.student;
    if (s == null) return null;
    final name = (s['name'] ?? '').toString();
    final cls = (s['class_name'] ?? '').toString();
    if (name.isEmpty) return null;
    return cls.isEmpty ? name : '$name · $cls';
  }

  @override
  String? get editingContextInitials {
    final s = widget.student;
    if (s == null) return null;
    return (s['name'] ?? '').toString();
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final languageProvider = widget.ref.watch(languageRiverpod);
    String tLocal(Map<String, String> map) =>
        languageProvider.getTranslatedText(map);

    // Sheet sizes naturally to its content (capped at 88 % of screen so
    // the user can still see something behind the modal). The body
    // scrolls when content exceeds the cap.
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: Material(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  const SizedBox(height: 8),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  buildHeaderWidget(),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        4,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── DATA POKOK ─────────────────────────────
                          AdminFormSection(
                            label: tLocal(const {
                              'en': 'BASIC DATA',
                              'id': 'DATA POKOK',
                            }),
                            children: [
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _nameController,
                                label: tLocal(const {
                                  'en': 'Full name',
                                  'id': 'Nama lengkap',
                                }),
                                icon: Icons.person,
                              ),
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _nisController,
                                label: 'NIS',
                                icon: Icons.badge,
                                keyboardType: TextInputType.number,
                              ),
                              StudentDialogDropdown(
                                primaryColor: widget.primaryColor,
                                value: selectedClassId,
                                label: tLocal(const {
                                  'en': 'Class',
                                  'id': 'Kelas',
                                }),
                                icon: Icons.school,
                                items: widget.classList
                                    .where((c) => c['id'] != null)
                                    .map(
                                      (c) => DropdownMenuItem<String>(
                                        value: c['id'].toString(),
                                        child: Text(
                                          c['name'] ?? 'Unknown Class',
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) =>
                                    setState(() => selectedClassId = value),
                              ),
                            ],
                          ),
                          // ── DATA PRIBADI ───────────────────────────
                          AdminFormSection(
                            label: tLocal(const {
                              'en': 'PERSONAL DATA',
                              'id': 'DATA PRIBADI',
                            }),
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AdminFormFieldLabel(
                                    text: tLocal(const {
                                      'en': 'Gender',
                                      'id': 'Jenis kelamin',
                                    }),
                                  ),
                                  AdminFormChoiceChips<String>(
                                    value: selectedGender,
                                    onChanged: (v) =>
                                        setState(() => selectedGender = v),
                                    choices: [
                                      AdminFormChoice(
                                        value: 'L',
                                        label: tLocal(const {
                                          'en': 'Male',
                                          'id': 'Laki-laki',
                                        }),
                                        icon: Icons.male_rounded,
                                      ),
                                      AdminFormChoice(
                                        value: 'P',
                                        label: tLocal(const {
                                          'en': 'Female',
                                          'id': 'Perempuan',
                                        }),
                                        icon: Icons.female_rounded,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _birthDateController,
                                label: tLocal(const {
                                  'en': 'Birth date',
                                  'id': 'Tanggal lahir',
                                }),
                                icon: Icons.cake,
                                hintText: 'YYYY-MM-DD',
                                readOnly: true,
                                onTap: () async {
                                  final s = widget.student;
                                  final initialDate =
                                      s != null && s['date_of_birth'] != null
                                      ? DateTime.parse(
                                          s['date_of_birth'].toString(),
                                        )
                                      : DateTime.now();
                                  final picked = await showModernDatePicker(
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
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _addressController,
                                label: tLocal(const {
                                  'en': 'Address',
                                  'id': 'Alamat',
                                }),
                                icon: Icons.location_on,
                                maxLines: 2,
                              ),
                            ],
                          ),
                          // ── WALI MURID ─────────────────────────────
                          AdminFormSection(
                            label: tLocal(const {
                              'en': 'GUARDIAN',
                              'id': 'WALI MURID',
                            }),
                            bottomGap: 4,
                            children: [
                              if (_isEdit)
                                Container(
                                  decoration: BoxDecoration(
                                    color: ColorUtils.warning600.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: ColorUtils.warning600.withValues(
                                        alpha: 0.25,
                                      ),
                                    ),
                                  ),
                                  child: SwitchListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                    ),
                                    dense: true,
                                    title: Text(
                                      tLocal(const {
                                        'en': 'Change guardian account',
                                        'id': 'Ganti akun wali',
                                      }),
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: ColorUtils.warning600,
                                      ),
                                    ),
                                    subtitle: Text(
                                      tLocal(const {
                                        'en':
                                            'Move this student to a different user account based on the email below.',
                                        'id':
                                            'Pindahkan siswa ke akun wali lain berdasarkan email di bawah.',
                                      }),
                                      style: TextStyle(
                                        fontSize: 10.5,
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
                                label: tLocal(const {
                                  'en': 'Guardian name',
                                  'id': 'Nama wali',
                                }),
                                icon: Icons.family_restroom,
                              ),
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _emailParentController,
                                label: tLocal(const {
                                  'en': 'Guardian email',
                                  'id': 'Email wali',
                                }),
                                icon: Icons.email,
                                keyboardType: TextInputType.emailAddress,
                                hintText: 'wali@example.com',
                              ),
                              StudentDialogTextField(
                                primaryColor: widget.primaryColor,
                                controller: _phoneController,
                                label: tLocal(const {
                                  'en': 'Phone number',
                                  'id': 'No. HP',
                                }),
                                icon: Icons.phone,
                                keyboardType: TextInputType.phone,
                              ),
                            ],
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
        ),
      ),
    );
  }

  @override
  bool get isSaving => _isSaving;
}
