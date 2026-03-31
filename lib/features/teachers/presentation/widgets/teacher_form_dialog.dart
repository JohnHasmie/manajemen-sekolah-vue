import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/teachers/data/teacher_service.dart';

/// Standalone dialog for adding or editing a teacher.
/// Extracted from `admin_teacher_management_screen.dart`.
class TeacherFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? teacher;
  final List<dynamic> subjects;
  final List<dynamic> classes;
  final VoidCallback onSaved;

  const TeacherFormDialog({
    super.key,
    this.teacher,
    required this.subjects,
    required this.classes,
    required this.onSaved,
  });

  @override
  ConsumerState<TeacherFormDialog> createState() => _TeacherFormDialogState();
}

class _TeacherFormDialogState extends ConsumerState<TeacherFormDialog> {
  late final TextEditingController nameController;
  late final TextEditingController emailController;
  late final TextEditingController nipController;

  String? selectedGender;
  String? selectedWaliKelasId;
  String? selectedStatus;
  List<String> selectedSubjectIds = [];
  List<String> selectedClassIds = [];
  bool isChangeUserMode = false;
  bool isSaving = false;

  final ApiTeacherService _teacherService = getIt<ApiTeacherService>();

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(
      text: widget.teacher?['name']?.toString() ?? '',
    );
    emailController = TextEditingController(
      text: widget.teacher?['email']?.toString() ??
          widget.teacher?['user']?['email']?.toString() ??
          '',
    );
    nipController = TextEditingController(
      text: widget.teacher?['employee_number']?.toString() ?? '',
    );

    selectedGender = widget.teacher?['gender']?.toString();

    // Homeroom ID logic
    if (widget.teacher != null) {
      if (widget.teacher!['homeroom_class'] != null &&
          widget.teacher!['homeroom_class'] is Map) {
        selectedWaliKelasId = widget.teacher!['homeroom_class']['id']?.toString();
      } else if (widget.teacher!['homeroom_classes'] != null &&
          widget.teacher!['homeroom_classes'] is List &&
          (widget.teacher!['homeroom_classes'] as List).isNotEmpty) {
        selectedWaliKelasId = widget.teacher!['homeroom_classes'][0]['id']?.toString();
      } else {
        selectedWaliKelasId = widget.teacher!['homeroom_class_id']?.toString();
      }
    }

    // Normalize employment_status
    final String? rawStatus = widget.teacher?['employment_status']?.toString();
    if (rawStatus != null) {
      final statusMap = {
        'Tetap': 'permanent',
        'Kontrak': 'contract',
        'Honor': 'temporary',
        'permanent': 'permanent',
        'contract': 'contract',
        'temporary': 'temporary',
      };
      selectedStatus = statusMap[rawStatus] ?? rawStatus;
    }

    // Parse project IDs
    if (widget.teacher != null) {
      if (widget.teacher!['subjects'] != null && widget.teacher!['subjects'] is List) {
        selectedSubjectIds = (widget.teacher!['subjects'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (widget.teacher!['subject_ids'] != null) {
        final idsString = widget.teacher!['subject_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedSubjectIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }

      if (widget.teacher!['classes'] != null && widget.teacher!['classes'] is List) {
        selectedClassIds = (widget.teacher!['classes'] as List)
            .map((e) => e['id'].toString())
            .toList();
      } else if (widget.teacher!['class_ids'] != null) {
        final idsString = widget.teacher!['class_ids'].toString();
        if (idsString.isNotEmpty) {
          selectedClassIds = idsString
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
        }
      }
    }

    // Validate selectedWaliKelasId
    if (selectedWaliKelasId != null) {
      final exists = widget.classes.any(
        (c) => c['id']?.toString() == selectedWaliKelasId && c['name'] != null,
      );
      if (!exists) {
        selectedWaliKelasId = null;
      }
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    nipController.dispose();
    super.dispose();
  }

  Color getPrimaryColor() {
    return ColorUtils.getRoleColor('admin');
  }

  LinearGradient getCardGradient() {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [getPrimaryColor(), getPrimaryColor().withValues(alpha: 0.7)],
    );
  }

  Widget buildDialogTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        ),
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        keyboardType: keyboardType,
      ),
    );
  }

  Widget buildDialogDropdown({
    required String? value,
    required String label,
    required IconData icon,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        border: Border.all(color: ColorUtils.slate200),
      ),
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
          prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
          border: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            borderSide: BorderSide(
              color: ColorUtils.corporateBlue600,
              width: 1.5,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        items: items,
        onChanged: onChanged,
        style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
        dropdownColor: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: ColorUtils.slate500,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = ref.watch(languageRiverpod);

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
              // Header with gradient
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 20),
                decoration: BoxDecoration(
                  gradient: getCardGradient(),
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
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(
                        widget.teacher == null
                            ? Icons.person_add_rounded
                            : Icons.edit_rounded,
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
                            widget.teacher == null
                                ? languageProvider.getTranslatedText({
                                    'en': 'Add Teacher',
                                    'id': 'Tambah Guru',
                                  })
                                : languageProvider.getTranslatedText({
                                    'en': 'Edit Teacher',
                                    'id': 'Edit Guru',
                                  }),
                            style: TextStyle(
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
                              color: Colors.white.withValues(
                                alpha: 0.8,
                              ),
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
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      buildDialogTextField(
                        controller: nameController,
                        label: languageProvider.getTranslatedText({
                          'en': 'Teacher Name',
                          'id': 'Nama Guru',
                        }),
                        icon: Icons.person,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (widget.teacher != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: ColorUtils.warning600.withValues(
                              alpha: 0.05,
                            ),
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                            border: Border.all(
                              color: ColorUtils.warning600.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: SwitchListTile(
                            title: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Use Another User / Change Account',
                                'id': 'Ganti Akun / Gunakan User Lain',
                              }),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: ColorUtils.warning600,
                              ),
                            ),
                            subtitle: Text(
                              languageProvider.getTranslatedText({
                                'en':
                                    'Link this teacher to a different user account based on the email below (does not edit the current linked user).',
                                'id':
                                    'Pindahkan guru ini ke akun user lain berdasarkan email di bawah (tidak merubah data user saat ini).',
                              }),
                              style: TextStyle(
                                fontSize: 11,
                                color: ColorUtils.slate600,
                              ),
                            ),
                            value: isChangeUserMode,
                            activeThumbColor: ColorUtils.warning600,
                            onChanged: (val) {
                              setState(() {
                                isChangeUserMode = val;
                              });
                            },
                          ),
                        ),
                      buildDialogTextField(
                        controller: emailController,
                        label: languageProvider.getTranslatedText({
                          'en': 'Email',
                          'id': 'Email',
                        }),
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      buildDialogTextField(
                        controller: nipController,
                        label: 'NIP',
                        icon: Icons.badge,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Gender Dropdown
                      buildDialogDropdown(
                        value: selectedGender,
                        label: languageProvider.getTranslatedText({
                          'en': 'Gender*',
                          'id': 'Jenis Kelamin*',
                        }),
                        icon: Icons.person_outline,
                        items: [
                          DropdownMenuItem(
                            value: 'L',
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Male',
                                'id': 'Laki-laki',
                              }),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'P',
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Female',
                                'id': 'Perempuan',
                              }),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedGender = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Subjects Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: const BorderRadius.all(Radius.circular(12)),
                          border: Border.all(
                            color: Colors.grey.shade200,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              languageProvider.getTranslatedText({
                                'en': 'Subjects:',
                                'id': 'Mata Pelajaran:',
                              }),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            ...widget.subjects
                                .where(
                                  (subject) =>
                                      subject['id'] != null &&
                                      subject['name'] != null,
                                )
                                .map(
                                  (subject) => CheckboxListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      subject['name']?.toString() ??
                                          'Unknown Subject',
                                      style: TextStyle(fontSize: 14),
                                    ),
                                    value: selectedSubjectIds.contains(
                                      subject['id']?.toString(),
                                    ),
                                    onChanged: (value) {
                                      final subjectId = subject['id']?.toString();
                                      if (subjectId == null) return;

                                      setState(() {
                                        if (value == true) {
                                          selectedSubjectIds.add(subjectId);
                                        } else {
                                          selectedSubjectIds.remove(subjectId);
                                        }
                                      });
                                    },
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Homeroom Class Dropdown
                      buildDialogDropdown(
                        value: selectedWaliKelasId,
                        label: languageProvider.getTranslatedText({
                          'en': 'Homeroom Class (Optional)',
                          'id': 'Wali Kelas (Opsional)',
                        }),
                        icon: Icons.class_,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'None',
                                'id': 'Tidak ada',
                              }),
                            ),
                          ),
                          ...widget.classes
                              .where(
                                (classItem) =>
                                    classItem['id'] != null &&
                                    classItem['name'] != null,
                              )
                              .fold<Map<String, Map<String, dynamic>>>(
                                {}, (map, item) {
                                  map[item['id'].toString()] = item;
                                  return map;
                                },
                              )
                              .values
                              .map(
                                (classItem) => DropdownMenuItem<String>(
                                  value: classItem['id'].toString(),
                                  child: Text(
                                    classItem['name']?.toString() ??
                                        'Unknown Class',
                                  ),
                                ),
                              ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedWaliKelasId = value);
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Employment Status Dropdown
                      buildDialogDropdown(
                        value: selectedStatus,
                        label: languageProvider.getTranslatedText({
                          'en': 'Employment Status (Optional)',
                          'id': 'Status Kepegawaian (Opsional)',
                        }),
                        icon: Icons.work_outline,
                        items: [
                          DropdownMenuItem(
                            value: null,
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'None',
                                'id': 'Tidak ada',
                              }),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'permanent',
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Permanent',
                                'id': 'Tetap',
                              }),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'contract',
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Contract',
                                'id': 'Kontrak',
                              }),
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'temporary',
                            child: Text(
                              languageProvider.getTranslatedText({
                                'en': 'Temporary/Honorary',
                                'id': 'Honor',
                              }),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedStatus = value);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(AppSpacing.xl),
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: ColorUtils.slate300),
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                        ),
                        child: Text(
                          AppLocalizations.cancel.tr,
                          style: TextStyle(
                            color: ColorUtils.slate700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving ? null : _saveTeacher,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ColorUtils.corporateBlue600,
                          disabledBackgroundColor:
                              ColorUtils.corporateBlue600.withValues(alpha: 0.6),
                          shape: RoundedRectangleBorder(
                            borderRadius: const BorderRadius.all(Radius.circular(12)),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          elevation: 2,
                          shadowColor:
                              ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                        ),
                        child: isSaving
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                AppLocalizations.save.tr,
                                style: TextStyle(
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

  Future<void> _saveTeacher() async {
    final languageProvider = ref.read(languageRiverpod);
    final name = nameController.text.trim();
    final email = emailController.text.trim();

    if (name.isEmpty || email.isEmpty || selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            languageProvider.getTranslatedText({
              'en': 'Name, email, and gender are required',
              'id': 'Nama, email, dan jenis kelamin wajib diisi',
            }),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final academicYearProvider = ref.read(academicYearRiverpod);
      final selectedYearId =
          academicYearProvider.selectedAcademicYear?['id']?.toString();

      final data = {
        'name': name,
        'email': email,
        'employee_number': nipController.text.isNotEmpty ? nipController.text : null,
        'gender': selectedGender,
        'homeroom_class_id': selectedWaliKelasId,
        'employment_status': selectedStatus,
        'subject_ids': selectedSubjectIds,
        'class_ids': selectedClassIds,
        'academic_year_id': selectedYearId,
        if (widget.teacher != null && isChangeUserMode) 'use_another_user': true,
      };

      if (widget.teacher == null) {
        await _teacherService.addTeacher(data);
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            languageProvider.getTranslatedText({
              'en': 'Teacher added successfully. Default password: password123',
              'id': 'Guru berhasil ditambahkan. Password default: password123',
            }),
          );
        }
      } else {
        await _teacherService.updateTeacher(
          widget.teacher!['id'].toString(),
          data,
        );
        if (mounted) {
          SnackBarUtils.showInfo(
            context,
            languageProvider.getTranslatedText({
              'en': 'Teacher updated successfully',
              'id': 'Guru berhasil diupdate',
            }),
          );
        }
      }

      if (mounted) {
        widget.onSaved();
        AppNavigator.pop(context);
      }
    } catch (error) {
      AppLogger.error('teacher', 'Save/Update teacher error: $error');
      if (mounted) {
        SnackBarUtils.showError(
          context,
          '${languageProvider.getTranslatedText({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }
}
