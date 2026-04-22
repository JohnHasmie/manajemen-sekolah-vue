/// guardian_helper.dart - Parent/guardian lookup operations.
library;

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Helper for guardian/parent operations.
class GuardianHelper {
  /// Fetches the parent/guardian user account linked to a student.
  /// Returns null if no parent account is linked.
  static Future<Map<String, dynamic>?> getParentUser(String studentId) async {
    try {
      final response = await ApiService().get('users?student_id=$studentId');
      if (response != null && response is List && response.isNotEmpty) {
        return response.first;
      }
      return null;
    } catch (e) {
      AppLogger.error('student', e);
      return null;
    }
  }

  /// Searches guardian names for autocomplete suggestions.
  /// [query] - Search term for guardian name lookup.
  static Future<List<String>> getGuardians(String query) async {
    try {
      final response = await ApiService().get(
        '/student/guardians?search='
        '${Uri.encodeComponent(query)}',
      );
      if (response['success'] == true && response['data'] != null) {
        return List<String>.from(response['data']);
      }
      return [];
    } catch (e) {
      AppLogger.error('student', e);
      return [];
    }
  }
}
