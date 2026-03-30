// Standalone Excel helper functions extracted from TeacherAdminScreenState.
//
// These were instance methods with no internal or external callers — moved here
// so the management screen stays under the line-count budget while keeping the
// code reachable if needed in future.
import 'package:flutter/foundation.dart';
import 'package:manajemensekolah/core/services/api_service.dart';

/// Calls the `/guru/import` API endpoint with a base64-encoded Excel file.
///
/// Kept for parity with the original code; prefer
/// [ApiTeacherService.importTeachersFromExcel] for new call-sites.
Future<Map<String, dynamic>> importTeachersFromExcelAPI(
  String base64File,
) async {
  try {
    if (kDebugMode) {
      debugPrint(
        'Calling /guru/import (API) with base64 size=${base64File.length}',
      );
    }
    final response = await ApiService().post('/guru/import', {
      'file_data': base64File,
    });
    if (kDebugMode) debugPrint('Response from /guru/import: $response');
    return response;
  } catch (e) {
    debugPrint('Error importing teachers from Excel: $e');
    rethrow;
  }
}

/// Downloads the teacher import template via the `/guru/template` endpoint.
///
/// Returns the base64-encoded file data string.
Future<String> downloadTeacherTemplateAPI() async {
  try {
    final response = await ApiService().get('/guru/template');
    return response['file_data'];
  } catch (e) {
    debugPrint('Error downloading teacher template: $e');
    rethrow;
  }
}

/// Helper variant of [importTeachersFromExcelAPI] — identical behaviour,
/// kept for backwards compatibility.
Future<Map<String, dynamic>> importTeachersFromExcel(
  String base64File,
) async {
  try {
    if (kDebugMode) {
      debugPrint(
        'Calling /guru/import (helper) with base64 size=${base64File.length}',
      );
    }
    final response = await ApiService().post('/guru/import', {
      'file_data': base64File,
    });
    if (kDebugMode) {
      debugPrint('Response from /guru/import (helper): $response');
    }
    return response;
  } catch (e) {
    debugPrint('Error importing teachers from Excel: $e');
    rethrow;
  }
}

/// Helper variant of [downloadTeacherTemplateAPI] — identical behaviour,
/// kept for backwards compatibility.
Future<String> downloadTeacherTemplate() async {
  try {
    final response = await ApiService().get('/guru/template');
    return response['file_data'];
  } catch (e) {
    debugPrint('Error downloading teacher template: $e');
    rethrow;
  }
}
