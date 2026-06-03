import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/network/api_exceptions.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
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

    // Clear any stale per-field errors (e.g. previous "NIS sudah
    // digunakan") so the user sees the form in a clean state during
    // submit.
    setState(() {
      nisFieldError = null;
    });

    final name = nameController.text.trim();
    final nis = nisController.text.trim();
    final address = addressController.text.trim();
    final birthDate = birthDateController.text.trim();
    final nameParent = parentNameController.text.trim();
    final noPhone = phoneController.text.trim();
    final emailParent = emailParentController.text.trim();

    try {
      final Map<String, dynamic> data = {
        'name': name,
        'student_number': nis,
        'class_id': selectedClassId,
        'address': address,
        'date_of_birth': birthDate,
        'gender': selectedGender,
        'guardian_name': nameParent,
        'phone_number': noPhone,
      };

      // Only include guardian_email in specific cases:
      // 1. When adding a new student (student == null)
      // 2. When explicitly changing the guardian user (isChangeUserMode ==
      // true)
      // 3. When the email has actually changed from the original
      if (student == null) {
        // New student - always include email
        data['guardian_email'] = emailParent;
      } else if (isChangeUserMode) {
        // Explicitly changing guardian - include email and flag
        data['guardian_email'] = emailParent;
        data['use_another_user'] = true;
      } else {
        // Editing existing student - only include email if it changed
        final originalEmail =
            (student!['guardian_email'] ?? student!['parent_email'] ?? '')
                .toString();
        if (emailParent != originalEmail) {
          data['guardian_email'] = emailParent;
        }
      }

      AppLogger.debug(
        'student',
        'Preparing to save student. Is edit: ${student != null}',
      );
      AppLogger.debug('student', 'Student data: $data');

      if (student != null) {
        AppLogger.debug('student', 'Student object: $student');
        final studentId = student!['id']?.toString();
        if (studentId == null || studentId.isEmpty) {
          AppLogger.error(
            'student',
            'Student ID is null or empty. Full student object: $student',
          );
          throw Exception('Student ID is missing or invalid');
        }
        AppLogger.debug('student', 'Calling updateStudent with ID: $studentId');
        await getIt<ApiStudentService>().updateStudent(studentId, data);
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
        _handleSaveError(e);
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

  /// Route save errors: 422 validation errors get surfaced inline on
  /// the offending field (currently NIS / student_number) so the user
  /// can fix the value without losing form context. Anything else falls
  /// back to the friendly snackbar.
  ///
  /// Backend payload shape (Laravel-style):
  /// ```json
  /// {
  ///   "message": "The given data was invalid.",
  ///   "errors": {
  ///     "student_number": ["NIS sudah digunakan oleh siswa lain"]
  ///   }
  /// }
  /// ```
  void _handleSaveError(dynamic error) {
    final ValidationException? validation = _extractValidation(error);
    if (validation != null) {
      final nisMsg = _firstFieldError(validation.errors, const [
        'student_number',
        'nis',
        'nisn',
      ]);
      if (nisMsg != null) {
        // Inline error on NIS field — form stays open with all other
        // values intact.
        setState(() {
          nisFieldError = _humanizeNisError(nisMsg);
        });
        SnackBarUtils.showError(buildContext, nisFieldError!);
        return;
      }
      // Other validation error — surface the first message generically.
      SnackBarUtils.showError(
        buildContext,
        validation.message.isNotEmpty
            ? validation.message
            : t(const {'en': 'Validation failed', 'id': 'Data tidak valid'}),
      );
      return;
    }

    SnackBarUtils.showError(
      buildContext,
      '${t({'en': 'Failed to save: ', 'id': 'Gagal menyimpan: '})}${ErrorUtils.getFriendlyMessage(error)}',
    );
  }

  /// Unwraps the Dio layers to find a `ValidationException`. The error
  /// interceptor wraps 422s as `DioException(error: ValidationException)`.
  ValidationException? _extractValidation(dynamic error) {
    if (error is ValidationException) return error;
    if (error is DioException && error.error is ValidationException) {
      return error.error as ValidationException;
    }
    return null;
  }

  /// Pulls the first error message for any of [keys] from a Laravel
  /// `errors` map shape (each value is a `List<String>` of messages).
  String? _firstFieldError(Map<String, dynamic>? errors, List<String> keys) {
    if (errors == null) return null;
    for (final k in keys) {
      final v = errors[k];
      if (v is List && v.isNotEmpty) return v.first.toString();
      if (v is String && v.isNotEmpty) return v;
    }
    return null;
  }

  /// Normalises common backend phrasings to the user-friendly "NIS
  /// sudah digunakan" wording, regardless of whether the backend says
  /// "has already been taken", "duplicate", "already exists", etc.
  String _humanizeNisError(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('taken') ||
        lower.contains('duplicate') ||
        lower.contains('already') ||
        lower.contains('sudah') ||
        lower.contains('digunakan') ||
        lower.contains('unique')) {
      return t(const {
        'en': 'NIS is already used by another student.',
        'id': 'NIS sudah digunakan oleh siswa lain.',
      });
    }
    return raw;
  }
}
