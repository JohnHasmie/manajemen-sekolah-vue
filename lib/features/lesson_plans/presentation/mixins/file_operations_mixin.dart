import 'dart:io';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

/// File-operations mixin for the admin RPP detail sheet.
///
/// Routes through the same `GET /rpp/{id}/download` proxy endpoint
/// that the teacher detail screen uses (per RPP J.J fix), so the
/// download flow stays consistent and works against both local-disk
/// + S3/Minio storage. The earlier "build `<baseUrl>/storage/<fp>`
/// and Dio.get" path bypassed auth + the disk fallback chain, which
/// is why admin downloads silently failed in production.
mixin FileOperationsMixin on State<LessonPlanAdminDetailPage> {
  /// Reads the lesson-plan map owned by the consuming State. Lets us
  /// pull `id` + `file_name` without an extra parameter.
  Map<String, dynamic> get lessonPlan;

  /// Downloads the attached file via the backend proxy and opens it
  /// with the device's native viewer. [filePath] is only used as a
  /// fallback filename source when `lesson_plan.file_name` is null.
  Future<void> downloadAndOpenFile(
    BuildContext context,
    String? filePath,
  ) async {
    final id = lessonPlan['id']?.toString();
    if (id == null || id.isEmpty) {
      SnackBarUtils.showError(context, 'RPP belum tersinkron — coba lagi.');
      return;
    }
    if (filePath == null || filePath.toString().trim().isEmpty) {
      SnackBarUtils.showError(context, 'File RPP belum diunggah.');
      return;
    }

    SnackBarUtils.showInfo(context, 'Mengunduh file…');
    try {
      // Backend proxy handles auth (bearer token), disk lookup, and
      // S3/Minio streaming. Returns the raw bytes.
      final bytes = await ApiService.downloadFile('/rpp/$id/download');

      // Prefer the persisted original filename so the local copy
      // matches what the teacher uploaded. Fall back to the storage
      // path's basename for legacy rows without file_name.
      final originalName = lessonPlan['file_name']?.toString().trim();
      final fileName = (originalName != null && originalName.isNotEmpty)
          ? originalName
          : Uri.parse(filePath).pathSegments.last;

      final dir = await getTemporaryDirectory();
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(bytes, flush: true);

      if (!context.mounted) return;
      SnackBarUtils.showSuccess(
        context,
        AppLocalizations.downloadSuccessful.tr,
      );

      final result = await OpenFile.open(localFile.path);
      if (result.type != ResultType.done && context.mounted) {
        SnackBarUtils.showError(
          context,
          '${AppLocalizations.failedToOpenFile.tr}: ${result.message}',
        );
      }
    } catch (e) {
      AppLogger.error('lesson_plan', e);
      if (!context.mounted) return;
      SnackBarUtils.showError(
        context,
        '${AppLocalizations.failedToDownload.tr}: '
        '${ErrorUtils.getFriendlyMessage(e)}',
      );
    }
  }
}
