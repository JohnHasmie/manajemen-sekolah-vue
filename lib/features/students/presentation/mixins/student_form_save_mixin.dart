import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/features/students/presentation/mixins/student_form_validation_mixin.dart';

/// Save/update mixin for student form data.
///
/// Provides methods to handle form submission, API calls, and error handling.
mixin StudentFormSaveMixin on StudentFormValidationMixin {
  @override
  late final TextEditingController nameController;
  @override
  late final TextEditingController nisController;
  @override
  late final TextEditingController addressController;
  @override
  late final TextEditingController birthDateController;
  @override
  late final TextEditingController parentNameController;
  @override
  late final TextEditingController phoneController;
  @override
  late final TextEditingController emailParentController;

  @override
  String? selectedClassId;
  @override
  String? selectedGender;
  bool isChangeUserMode = false;

  /// Must access student data — implement in consuming class.
  Map<String, dynamic>? get student;

  /// Must perform setState — implement in consuming class.
  void setState(VoidCallback fn);

  /// Translation helper — must be implemented by consuming class.
  @override
  String t(Map<String, String> translations);

  /// Access to BuildContext — must be implemented by consuming class.
  @override
  BuildContext get buildContext;

  /// Access to mounted flag — must be implemented by consuming class.
  bool get isMounted;

  /// Callback when save succeeds — implement in consuming class.
  void onSaveSuccess();

  /// Validate form and save/update student data.
  Future<void> handleSave() async {
    if (!validateAndShowError()) return;

    setState(() {});

    final name = nameController.text.trim();
    final nis = nisController.text.trim();
    final address = addressController.text.trim();
    final birthDate = birthDateController.text.trim();
    final nameParent = parentNameController.text.trim();
    final noPhone = phoneController.text.trim();
    final emailParent = emailParentController.text.trim();

    try {
      final data = {
        'name': name,
        'student_number': nis,
        'class_id': selectedClassId,
        'address': address,
        'date_of_birth': birthDate,
        'gender': selectedGender,
        'guardian_name': nameParent,
        'phone_number': noPhone,
        'guardian_email': emailParent,
        if (student != null && isChangeUserMode) 'use_another_user': true,
      };

      if (student != null) {
        await getIt<ApiStudentService>().updateStudent(student!['id'], data);
      } else {
        await getIt<ApiStudentService>().addStudent(data);
      }

      onSaveSuccess();

      if (isMounted) {
        _showSuccessMessage(emailParent);
      }
    } catch (e) {
      AppLogger.error('student', 'Save/Update student error: $e');
      if (isMounted) {
        _showErrorDialog(e);
      }
    } finally {
      if (isMounted) {
        setState(() {});
      }
    }
  }

  /// Display success message.
  void _showSuccessMessage(String emailParent) {
    final isEdit = student != null;
    final successMsg = isEdit
        ? t({
            'en': 'Student successfully updated',
            'id': 'Siswa berhasil diperbarui',
          })
        : t({
            'en': 'Student successfully added',
            'id': 'Siswa berhasil ditambahkan',
          });

    final emailNote = emailParent.isNotEmpty
        ? t({
            'en':
                '\nParent user linked/created. Default password for new user is password123',
            'id':
                '\nData wali terkait & Akun wali (User) ikut diperbarui/dibuat. Password akun baru: password123',
          })
        : '';

    ScaffoldMessenger.of(buildContext).showSnackBar(
      SnackBar(
        content: Text(successMsg + emailNote),
        backgroundColor: ColorUtils.success600,
      ),
    );
    AppNavigator.pop(buildContext);
  }

  /// Display error dialog.
  void _showErrorDialog(dynamic error) {
    showDialog(
      context: buildContext,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: ColorUtils.error600),
            const SizedBox(width: AppSpacing.sm),
            Text(
              t({'en': 'Error', 'id': 'Gagal'}),
              style: TextStyle(color: ColorUtils.error600),
            ),
          ],
        ),
        content: Text(
          '${t({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => AppNavigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
