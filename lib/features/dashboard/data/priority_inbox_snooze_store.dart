// Local snooze for teacher Priority Inbox rows (GG.9).
//
// Phase 2A intentionally keeps snooze state on-device only:
//   • Backend doesn't carry a per-item dismiss column yet (we'd
//     need one per signal source — five aggregators, five different
//     tables — and the cost outweighs the benefit at this stage).
//   • A teacher who snoozes on one device should see the same item
//     on another device — snooze isn't a hide-forever action; it's
//     a "give me an hour of peace" affordance.
//
// Storage shape: a JSON map { itemId -> expiryMillis } persisted
// under `priority_inbox.snooze.v1`. On read we evict expired
// entries so the map doesn't grow forever — even a chatty inbox
// is bounded at ~15 active items, so the working set stays tiny.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Two presets the snooze sheet offers. The exact durations come
/// from the schema doc §13.4 (Phase 2A): "until 6 AM tomorrow"
/// and "8 hours". Both are local-time calculations.
enum SnoozeDuration { untilMorning, eightHours }

extension SnoozeDurationExt on SnoozeDuration {
  /// Bahasa Indonesia label for the sheet button.
  String get label => switch (this) {
    SnoozeDuration.untilMorning => 'Sampai besok pagi (06:00)',
    SnoozeDuration.eightHours => 'Sembunyikan 8 jam',
  };

  /// Compute the expiry timestamp relative to `now`. "Until morning"
  /// resolves to 06:00 the next calendar day in the device's local
  /// timezone — if the user snoozes at 03:00 they still get peace
  /// until 06:00 that same morning (not the next), so the rule is
  /// "next 06:00 strictly after now".
  DateTime expiryFrom(DateTime now) {
    switch (this) {
      case SnoozeDuration.eightHours:
        return now.add(const Duration(hours: 8));
      case SnoozeDuration.untilMorning:
        var morning = DateTime(now.year, now.month, now.day, 6);
        if (!morning.isAfter(now)) {
          morning = morning.add(const Duration(days: 1));
        }
        return morning;
    }
  }
}

class PriorityInboxSnoozeStore {
  static const String _key = 'priority_inbox.snooze.v1';

  /// Singleton — SharedPreferences is itself a singleton-backed
  /// service, but we cache the parsed map in memory so the dashboard
  /// card's render path doesn't go through `jsonDecode` on every
  /// rebuild.
  static final PriorityInboxSnoozeStore instance = PriorityInboxSnoozeStore._();

  PriorityInboxSnoozeStore._();

  /// Cached in-memory copy of the snooze map. `null` until the first
  /// load. After load, mutations write to both this map AND prefs.
  Map<String, int>? _cache;

  /// Hydrate from prefs. Idempotent — safe to call multiple times.
  /// Should be invoked once during app bootstrap; subsequent reads
  /// short-circuit on `_cache`.
  Future<void> load() async {
    if (_cache != null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      _cache = <String, int>{};
      return;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        _cache = decoded.map(
          (k, v) => MapEntry(k.toString(), (v as num).toInt()),
        );
      } else {
        _cache = <String, int>{};
      }
    } catch (_) {
      _cache = <String, int>{};
    }
  }

  /// Returns whether `itemId` is currently snoozed (expiry > now).
  /// Silently evicts the entry if it has expired so future calls
  /// stay cheap.
  bool isSnoozed(String itemId, {DateTime? now}) {
    final map = _cache;
    if (map == null) return false;
    final expiry = map[itemId];
    if (expiry == null) return false;
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (expiry > nowMs) return true;
    // Expired — evict (fire-and-forget; tolerate write failures).
    map.remove(itemId);
    _persist();
    return false;
  }

  /// Snooze an item until [expiry]. Writes through to prefs.
  Future<void> snooze(String itemId, DateTime expiry) async {
    await load();
    _cache![itemId] = expiry.millisecondsSinceEpoch;
    await _persist();
  }

  /// Convenience — snooze with a preset duration computed from now.
  Future<void> snoozeWith(String itemId, SnoozeDuration duration) {
    return snooze(itemId, duration.expiryFrom(DateTime.now()));
  }

  /// Clear a snooze early (e.g. user wants to see the item again).
  Future<void> unsnooze(String itemId) async {
    await load();
    if (_cache!.remove(itemId) != null) {
      await _persist();
    }
  }

  /// Iterate the cache and drop everything that has expired. Cheap
  /// because the working set is bounded, but worth running on
  /// dashboard refresh so the map stays tidy.
  Future<void> evictExpired({DateTime? now}) async {
    await load();
    final nowMs = (now ?? DateTime.now()).millisecondsSinceEpoch;
    final before = _cache!.length;
    _cache!.removeWhere((_, expiry) => expiry <= nowMs);
    if (_cache!.length != before) {
      await _persist();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    if (_cache == null || _cache!.isEmpty) {
      await prefs.remove(_key);
      return;
    }
    await prefs.setString(_key, jsonEncode(_cache));
  }
}
