import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/features/lesson_plans/presentation/screens/lesson_plan_admin_detail_page.dart';

mixin FileOperationsMixin on State<LessonPlanAdminDetailPage> {
  Future<void> downloadAndOpenFile(
    BuildContext context,
    String? filePath,
  ) async {
    if (filePath == null) return;

    final messenger = ScaffoldMessenger.of(context);

    try {
      messenger.showSnackBar(
        const SnackBar(content: Text('Mengunduh file...')),
      );

      final fileUrl = buildDownloadUrl(filePath);
      AppLogger.debug('lesson_plan', 'Downloading from: $fileUrl');

      await downloadFile(fileUrl);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text(AppLocalizations.downloadSuccessful.tr)),
      );

      await openDownloadedFile(filePath);
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('${AppLocalizations.failedToDownload.tr}: $e')),
      );
    }
  }

  String buildDownloadUrl(String filePath) {
    final baseUrlBase = ApiService.baseUrl.replaceAll('/api', '');
    if (filePath.startsWith('http')) {
      return filePath;
    }
    return '$baseUrlBase/storage/$filePath';
  }

  Future<void> downloadFile(String fileUrl) async {
    final dio = Dio();
    final response = await dio.get<List<int>>(
      fileUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    final directory = await getApplicationDocumentsDirectory();
    final fileName = fileUrl.split('/').last;
    final file = File('${directory.path}/$fileName');

    await file.writeAsBytes(response.data ?? []);
  }

  Future<void> openDownloadedFile(String filePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = filePath.split('/').last;
    final file = File('${directory.path}/$fileName');

    final messenger = ScaffoldMessenger.of(context);
    final result = await OpenFile.open(file.path);

    if (result.type != ResultType.done) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.failedToOpenFile.tr}: '
            '${result.message}',
          ),
        ),
      );
    }
  }
}
