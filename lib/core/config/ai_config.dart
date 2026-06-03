/// Shared AI microservice configuration.
///
/// Provides the base URL for the KamillLabs Edu AI API, resolved from:
/// 1. `--dart-define=AI_API_BASE_URL=...` (compile-time, CI/CD)
/// 2. `.env` file `AI_API_BASE_URL` (local development)
/// 3. Production fallback URL
///
/// Used by SubjectAiService, RecommendationService, and RPP generation.
library;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Central configuration for the AI microservice URL.
class AiConfig {
  AiConfig._();

  /// Resolved AI API base URL. Call [init] before using.
  static late final String baseUrl;

  /// Whether [init] has been called.
  static bool _initialized = false;

  /// Initializes the AI base URL. Safe to call multiple times (no-op after
  /// first).
  ///
  /// Resolution order:
  /// 1. `--dart-define=AI_API_BASE_URL=...` (compile-time)
  /// 2. `.env` file `AI_API_BASE_URL` (development)
  /// 3. Production fallback: `https://edu-ai-api.kamillabs.com/api`
  static void init() {
    if (_initialized) return;

    const defineUrl = String.fromEnvironment('AI_API_BASE_URL');
    if (defineUrl.isNotEmpty) {
      baseUrl = defineUrl;
      AppLogger.debug('ai_config', 'AI Base URL from --dart-define: $baseUrl');
      _initialized = true;
      return;
    }

    try {
      final envUrl = dotenv.env['AI_API_BASE_URL'];
      if (envUrl != null && envUrl.isNotEmpty) {
        baseUrl = envUrl;
        AppLogger.debug('ai_config', 'AI Base URL from .env: $baseUrl');
        _initialized = true;
        return;
      }
    } catch (_) {}

    baseUrl = 'https://edu-ai-api.kamillabs.com/api';
    AppLogger.debug('ai_config', 'AI Base URL fallback: $baseUrl');
    _initialized = true;
  }
}
