import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/features/announcements/presentation/screens/parent_announcement_screen.dart';

/// Mixin for file download and open operations.
mixin FileOperationsMixin on ConsumerState<ParentAnnouncementScreen> {
  String getFileUrl(String path) {
    if (path.startsWith('http')) return path;
    final base = ApiService.baseUrl.replaceAll('/api', '');
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$base/storage/$cleanPath';
  }

  Future<void> openFile(String url, String fileName) async {
    try {
      AppLogger.debug('announcement', 'Downloading file from: $url');

      final dio = Dio();
      final response = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(response.data ?? []);

      final result = await OpenFile.open(file.path);

      if (result.type != ResultType.done) {
        if (mounted) {
          SnackBarUtils.showError(
            context,
            'Could not open file: ${result.message}',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, 'Error opening file: $e');
      }
    }
  }
}
