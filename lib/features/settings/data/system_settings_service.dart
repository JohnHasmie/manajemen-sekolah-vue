// Flutter wrapper around the Sistem hub's audit-log endpoint
// (Mockup #14). Returns a typed [AuditLogEntry] or null when the
// school has no recorded events yet.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_settings_components.dart';

class SystemSettingsService {
  final ApiService _api;
  SystemSettingsService(this._api);

  /// GET /api/system/audit-log/latest
  ///
  /// Returns the most-recent audit log entry plus a count of entries
  /// recorded today. The count drives the "AUDIT LOG · 14 ENTRI HARI INI"
  /// caption in the mockup.
  Future<LatestAuditLogResult> fetchLatestAuditLog() async {
    final raw = await _api.get('/system/audit-log/latest');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final latestRaw = data['latest'];
    AuditLogEntry? entry;
    if (latestRaw is Map) {
      final m = Map<String, dynamic>.from(latestRaw);
      entry = AuditLogEntry(
        actor: (m['actor'] ?? 'Sistem').toString(),
        action: (m['action'] ?? '').toString(),
        timestamp: m['timestamp']?.toString(),
        ipAddress: m['ip_address']?.toString(),
      );
    }

    return LatestAuditLogResult(
      latest: entry,
      countToday: (data['count_today'] as int?) ?? 0,
    );
  }
}

class LatestAuditLogResult {
  final AuditLogEntry? latest;
  final int countToday;
  const LatestAuditLogResult({
    required this.latest,
    required this.countToday,
  });
}

// =====================================================================
// Riverpod
// =====================================================================

final systemSettingsServiceProvider = Provider<SystemSettingsService>((ref) {
  return SystemSettingsService(ApiService());
});

/// Loads the latest audit log entry for the active school. Used by the
/// admin Sistem hub's [AuditLogPin].
final latestAuditLogProvider =
    FutureProvider.autoDispose<LatestAuditLogResult>((ref) async {
  return ref.read(systemSettingsServiceProvider).fetchLatestAuditLog();
});
