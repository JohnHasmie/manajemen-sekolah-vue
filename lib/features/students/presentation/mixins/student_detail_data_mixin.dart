import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/data/student_service.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';

/// Handles data loading and state management for student detail.
mixin StudentDetailDataMixin {
  /// Must be implemented by consuming state class
  Map<String, dynamic>? get studentDetail;
  set studentDetail(Map<String, dynamic>? value);

  bool get isLoading;
  set isLoading(bool value);

  String? get errorMessage;
  set errorMessage(String? value);

  void setState(VoidCallback fn);
  BuildContext get context;
  bool get mounted;
  WidgetRef get ref;

  /// Fetches full student details by ID from the API.
  /// Manages loading/error states and handles API responses.
  Future<void> loadStudentDetail({required String studentId}) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final studentDetail = await getIt<ApiStudentService>().getStudentById(
        studentId,
      );

      if (!mounted) return;
      setState(() {
        this.studentDetail = studentDetail is Map<String, dynamic>
            ? studentDetail
            : null;
        isLoading = false;
      });
    } catch (e) {
      AppLogger.error('student', e);
      if (!mounted) return;
      final errorMsg = ErrorUtils.getFriendlyMessage(e);
      setState(() {
        isLoading = false;
        errorMessage = errorMsg;
      });
      if (mounted) {
        SnackBarUtils.showError(
          context,
          'Gagal memuat detail siswa: $errorMsg',
        );
      }
    }
  }
}
