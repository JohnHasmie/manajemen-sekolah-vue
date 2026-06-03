// Thin service over the existing [ApiService] that wraps the
// /profile/security-status endpoint introduced for Mockup #15.
//
// The endpoint returns {data: {items: [...], computed_at: '...'}} where
// each item carries a key, label, state in {ok,warn,fail}, and an
// optional inline action. This service flattens that into a typed
// [SecurityCheck] list consumable by the SecurityChecklistCard widget.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_profile_components.dart';

class ProfileService {
  final ApiService _api;
  ProfileService(this._api);

  /// GET /api/profile/security-status
  ///
  /// Returns the parsed list of [SecurityCheck]s. The optional inline
  /// action is left as a `null` callback at the service boundary —
  /// the screen wires the navigation target based on `actionRoute`.
  Future<SecurityStatusResult> fetchSecurityStatus() async {
    final raw = await _api.get('/profile/security-status');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};
    final items = (data['items'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(_parseItem)
        .toList();
    return SecurityStatusResult(
      items: items,
      computedAt: data['computed_at']?.toString(),
    );
  }

  /// GET /api/profile/managed-schools
  ///
  /// Returns the schools the current user can switch between, plus
  /// the id of the school they're operating against right now.
  Future<ManagedSchoolsResult> fetchManagedSchools() async {
    final raw = await _api.get('/profile/managed-schools');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};
    final activeId = (data['active_school_id'] ?? '').toString();
    final list = (data['schools'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(
          (m) => SchoolScope(
            id: (m['id'] ?? '').toString(),
            shortName: (m['short_name'] ?? '').toString(),
            fullName: (m['full_name'] ?? '').toString(),
            badgeLabel: m['badge_label']?.toString(),
          ),
        )
        .toList();
    return ManagedSchoolsResult(activeSchoolId: activeId, schools: list);
  }

  ParsedItem _parseItem(Map<String, dynamic> m) {
    final state = switch ((m['state'] ?? '').toString()) {
      'ok' => SecurityState.ok,
      'warn' => SecurityState.warn,
      'fail' => SecurityState.fail,
      _ => SecurityState.warn,
    };
    return ParsedItem(
      key: (m['key'] ?? '').toString(),
      label: (m['label'] ?? '').toString(),
      state: state,
      actionLabel: m['action_label']?.toString(),
      actionRoute: m['action_route']?.toString(),
    );
  }
}

class SecurityStatusResult {
  final List<ParsedItem> items;
  final String? computedAt;
  const SecurityStatusResult({required this.items, this.computedAt});

  /// Convert to [SecurityCheck] list, attaching navigation callbacks.
  List<SecurityCheck> toChecks(void Function(String route) onAction) {
    return items.map((p) {
      return SecurityCheck(
        label: p.label,
        state: p.state,
        actionLabel: p.actionLabel,
        onAction: p.actionRoute == null ? null : () => onAction(p.actionRoute!),
      );
    }).toList();
  }
}

class ParsedItem {
  final String key;
  final String label;
  final SecurityState state;
  final String? actionLabel;
  final String? actionRoute;
  const ParsedItem({
    required this.key,
    required this.label,
    required this.state,
    this.actionLabel,
    this.actionRoute,
  });
}

// =====================================================================
// Riverpod provider
// =====================================================================

final profileServiceProvider = Provider<ProfileService>((ref) {
  return ProfileService(ApiService());
});

/// Loads the security checklist for the currently signed-in admin.
///
/// Use as `ref.watch(securityStatusProvider)` from the profile screen
/// — `AsyncValue<SecurityStatusResult>` lets the screen render
/// loading / error / data states identically to the rest of the app.
final securityStatusProvider = FutureProvider.autoDispose<SecurityStatusResult>(
  (ref) async {
    return ref.read(profileServiceProvider).fetchSecurityStatus();
  },
);

/// Result of [ProfileService.fetchManagedSchools]. Always non-null
/// fields so the UI doesn't have to defend against nulls.
class ManagedSchoolsResult {
  final String activeSchoolId;
  final List<SchoolScope> schools;
  const ManagedSchoolsResult({
    required this.activeSchoolId,
    required this.schools,
  });

  bool get hasMultiple => schools.length > 1;
}

/// Loads schools the current user can switch into. Used by the
/// account-sheet's [RoleScopeChips] (Mockup #15).
final managedSchoolsProvider = FutureProvider.autoDispose<ManagedSchoolsResult>(
  (ref) async {
    return ref.read(profileServiceProvider).fetchManagedSchools();
  },
);
