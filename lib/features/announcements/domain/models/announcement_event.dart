// Pengumuman + Acara — typed event payload.
//
// The existing Announcement Freezed model is intentionally minimal
// (id/title/content/category). Pengumuman+Acara adds five new fields
// on the backend (event_at, event_end_at, event_has_time,
// event_location, reminder_offsets) plus a derived has_event boolean.
//
// Instead of regenerating the Freezed model — which requires a
// build_runner invocation we can't do from every dev machine — we
// add a plain companion class that parses the raw API map and
// surfaces the event payload with helpful getters (countdown,
// isLive, isPastEvent). Screens that need event info call
// AnnouncementEvent.fromJson(rawMap) once and use the typed object.
library;

import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Lifecycle-ish state for the event card.
enum AnnouncementEventState {
  /// Future event — show countdown.
  upcoming,

  /// Event is currently happening (start ≤ now ≤ end OR within
  /// 1 hour of start when end is null).
  live,

  /// Event ended.
  past,
}

class AnnouncementEvent {
  const AnnouncementEvent({
    required this.announcementId,
    required this.eventAt,
    this.eventEndAt,
    this.eventHasTime = true,
    this.eventLocation,
    this.reminderOffsetMinutes = const [],
  });

  /// The announcement this event belongs to. Same id as the
  /// announcement row — convenience for deep links.
  final String announcementId;

  /// When the event happens. The single field that distinguishes a
  /// plain pengumuman from a peringatan/acara — null = no event.
  final DateTime eventAt;

  /// Optional end. Drives "Sepanjang hari" / range display.
  final DateTime? eventEndAt;

  /// When false, hide the jam pill and write "Sepanjang hari".
  final bool eventHasTime;

  /// Free-text venue ("Aula Lt. 2"). Trimmed empty → null.
  final String? eventLocation;

  /// Minutes-before-event when reminders fire. Mirrors what admin
  /// configured on backend. [-1440 ≤ value ≤ 43200]. UI surfaces
  /// these as chips ("1 hari sblm · 1 jam sblm · saat mulai").
  final List<int> reminderOffsetMinutes;

  /// Returns null when the raw map has no event_at — call sites
  /// should null-check and skip rendering the event block.
  static AnnouncementEvent? fromJson(Map<String, dynamic> json) {
    final raw = json['event_at'];
    if (raw == null || raw.toString().trim().isEmpty) {
      return null;
    }
    try {
      final eventAt = DateTime.parse(raw.toString()).toLocal();
      DateTime? eventEndAt;
      final rawEnd = json['event_end_at'];
      if (rawEnd != null && rawEnd.toString().trim().isNotEmpty) {
        eventEndAt = DateTime.parse(rawEnd.toString()).toLocal();
      }

      // `event_has_time` defaults to true server-side. UI shows
      // "Sepanjang hari" only when explicitly false.
      final rawHasTime = json['event_has_time'];
      final hasTime = rawHasTime == null
          ? true
          : (rawHasTime is bool
                ? rawHasTime
                : (rawHasTime is num
                      ? rawHasTime != 0
                      : rawHasTime.toString() == '1' ||
                            rawHasTime.toString().toLowerCase() == 'true'));

      final rawLoc = json['event_location']?.toString().trim();

      final rawOffsets = json['reminder_offsets'];
      final offsets = <int>[];
      if (rawOffsets is List) {
        for (final o in rawOffsets) {
          final n = int.tryParse(o.toString());
          if (n != null) offsets.add(n);
        }
      }

      return AnnouncementEvent(
        announcementId: (json['id'] ?? '').toString(),
        eventAt: eventAt,
        eventEndAt: eventEndAt,
        eventHasTime: hasTime,
        eventLocation: (rawLoc?.isEmpty ?? true) ? null : rawLoc,
        reminderOffsetMinutes: offsets,
      );
    } catch (e) {
      AppLogger.warning('AnnouncementEvent', 'parse failed: $e');
      return null;
    }
  }

  /// JSON shape compatible with the backend's
  /// `event_at / event_has_time / event_location / reminder_offsets`
  /// payload — used by the compose sheet.
  Map<String, dynamic> toJson() => {
    'event_at': eventAt.toIso8601String(),
    if (eventEndAt != null) 'event_end_at': eventEndAt!.toIso8601String(),
    'event_has_time': eventHasTime,
    if (eventLocation != null) 'event_location': eventLocation,
    'reminder_offsets': reminderOffsetMinutes,
  };

  /// Lifecycle helper — drives the colour variant on EventBlock.
  AnnouncementEventState get state {
    final now = DateTime.now();
    final end = eventEndAt;
    if (end != null) {
      if (now.isBefore(eventAt)) return AnnouncementEventState.upcoming;
      if (now.isAfter(end)) return AnnouncementEventState.past;
      return AnnouncementEventState.live;
    }
    // No explicit end — treat the first hour after start as live
    // for short ad-hoc rapats. Past after that.
    if (now.isBefore(eventAt)) return AnnouncementEventState.upcoming;
    if (now.isBefore(eventAt.add(const Duration(hours: 1)))) {
      return AnnouncementEventState.live;
    }
    return AnnouncementEventState.past;
  }

  bool get isUpcoming => state == AnnouncementEventState.upcoming;
  bool get isLive => state == AnnouncementEventState.live;
  bool get isPast => state == AnnouncementEventState.past;

  /// Time until event_at, clamped to zero when past. Drives the
  /// 4-cell countdown on detail screens.
  Duration get timeUntilStart {
    final diff = eventAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// Short label like "7 hari lagi" / "BESOK" / "Sekarang" /
  /// "Berlangsung". Used by the EventBlock chip.
  String get countdownLabel {
    if (isPast) return 'Selesai';
    if (isLive) return 'Berlangsung';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(eventAt.year, eventAt.month, eventAt.day);
    final days = eventDay.difference(today).inDays;
    if (days == 0) return 'HARI INI';
    if (days == 1) return 'BESOK';
    if (days < 7) return '$days HARI LAGI';
    if (days < 30) return '${(days / 7).floor()} PEKAN LAGI';
    return '${(days / 30).floor()} BULAN LAGI';
  }
}
