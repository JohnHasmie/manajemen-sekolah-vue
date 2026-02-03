import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:manajemensekolah/services/api_services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LogService {
  static const String _logApiPort = '5009';

  static String get _logApiUrl {
    // Use the same host as the main ApiService but with port 5009
    final apiBase = ApiService.baseUrl;
    final uri = Uri.parse(apiBase);
    return '${uri.scheme}://${uri.host}:$_logApiPort/api/logs';
  }

  static Future<void> sendError(dynamic error, StackTrace? stackTrace) async {
    try {
      if (kDebugMode) {
        print('📤 Sending error log to backend: $error');
      }

      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('user');
      String? userId;
      String? userEmail;

      if (userJson != null) {
        try {
          final user = json.decode(userJson);
          userId = user['id']?.toString();
          userEmail = user['email'];
        } catch (_) {}
      }

      final body = {
        'source': kIsWeb
            ? 'frontend_web'
            : (Platform.isAndroid ? 'frontend_android' : 'frontend_ios'),
        'level': 'error',
        'message': error.toString(),
        'trace': stackTrace?.toString(),
        'user_id': userId,
        'user_email': userEmail,
        'meta': {
          'timestamp': DateTime.now().toIso8601String(),
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      };

      await http
          .post(
            Uri.parse(_logApiUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to send error log: $e');
      }
    }
  }
}
