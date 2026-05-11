import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// One row in the teacher dashboard's "Perlu Perhatian" card.
///
/// The backend (`DashboardController::getTeacherStats()` →
/// `priority_inbox`) ranks + caps the list server-side. The Flutter
/// renderer treats this as a dumb display payload: render each item
/// in order, hide nothing, do not reorder.
///
/// Schema source: `backendmanajemensekolah_laravel/docs/teacher_priority_inbox.md`.
class PriorityInboxItem {
  /// Stable identifier — `"<type>:<seed>"`. Used as the list key.
  final String id;

  /// Closed enum from the backend. Unknown strings are accepted and
  /// rendered with a neutral icon — the frontend never crashes on
  /// a server emitting a new type.
  final String type;

  final PriorityInboxSeverity severity;

  /// Short Bahasa Indonesia title (≤32 chars). Renders as the row's
  /// primary line.
  final String label;

  /// Bahasa Indonesia context line (≤80 chars). Renders below [label].
  final String subtitle;

  /// Defaults to 1. Renders as a "·N" chip only when >1.
  final int count;

  /// When the actionable event happened (e.g. when the period ended,
  /// when the parent replied). Used to render the relative-time chip.
  final DateTime occurredAt;

  /// Closed enum the frontend resolves to a destination screen via
  /// the [TeacherInboxNavigator] (FF.12). Unknown values render the
  /// row without an onTap.
  final String targetRoute;

  /// Constructor args for the destination screen — pass-through.
  final Map<String, dynamic> targetParams;

  const PriorityInboxItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.label,
    required this.subtitle,
    required this.occurredAt,
    required this.targetRoute,
    required this.targetParams,
    this.count = 1,
  });

  /// Parse a single JSON map. Returns null for malformed input so
  /// the consumer can skip silently rather than blanking the card.
  static PriorityInboxItem? fromJson(Map<String, dynamic> json) {
    try {
      final id = (json['id'] as String?)?.trim();
      final type = (json['type'] as String?)?.trim();
      final severityRaw = (json['severity'] as String?)?.trim();
      final label = (json['label'] as String?)?.trim();
      final subtitle = (json['subtitle'] as String?)?.trim();
      final targetRoute = (json['target_route'] as String?)?.trim();
      final occurredAtRaw = json['occurred_at']?.toString();
      if (id == null ||
          id.isEmpty ||
          type == null ||
          type.isEmpty ||
          label == null ||
          label.isEmpty ||
          subtitle == null ||
          subtitle.isEmpty ||
          targetRoute == null ||
          targetRoute.isEmpty ||
          severityRaw == null ||
          occurredAtRaw == null) {
        return null;
      }

      final occurredAt = DateTime.tryParse(occurredAtRaw);
      if (occurredAt == null) {
        return null;
      }

      final params = json['target_params'];
      final targetParams = params is Map
          ? Map<String, dynamic>.from(params)
          : <String, dynamic>{};

      final count = json['count'];
      final parsedCount = count is int
          ? count
          : (count is num
                ? count.toInt()
                : int.tryParse(count?.toString() ?? '') ?? 1);

      return PriorityInboxItem(
        id: id,
        type: type,
        severity: PriorityInboxSeverity.parse(severityRaw),
        label: label,
        subtitle: subtitle,
        count: parsedCount < 1 ? 1 : parsedCount,
        occurredAt: occurredAt,
        targetRoute: targetRoute,
        targetParams: targetParams,
      );
    } catch (_) {
      return null;
    }
  }

  /// Parse a raw list (typically `stats['priority_inbox']`) into a
  /// typed list, silently dropping any malformed entries.
  static List<PriorityInboxItem> parseList(dynamic raw) {
    if (raw is! List) return const [];
    final out = <PriorityInboxItem>[];
    for (final entry in raw) {
      if (entry is Map) {
        final item = PriorityInboxItem.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (item != null) out.add(item);
      }
    }
    return out;
  }

  /// Relative-time label, Bahasa Indonesia, for the right-side chip.
  /// Granularity matches everywhere else in the app
  /// ("baru saja", "5 menit lalu", "2 jam lalu", "3 hari lalu",
  /// "12/04").
  String relativeTime(DateTime now) {
    final diff = now.difference(occurredAt);
    if (diff.inSeconds < 60) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    // Older than a week — give a stable date.
    final dd = occurredAt.day.toString().padLeft(2, '0');
    final mm = occurredAt.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}

/// Severity scale that mirrors `PriorityInboxItem::SEVERITY_*` in
/// the backend service. The enum is closed; unknown strings from
/// future backend versions fall back to [PriorityInboxSeverity.info]
/// so an older mobile build doesn't crash on a new value.
enum PriorityInboxSeverity {
  critical,
  warning,
  info;

  static PriorityInboxSeverity parse(String raw) {
    switch (raw.toLowerCase()) {
      case 'critical':
        return PriorityInboxSeverity.critical;
      case 'warning':
        return PriorityInboxSeverity.warning;
      case 'info':
      default:
        return PriorityInboxSeverity.info;
    }
  }

  /// Dot / accent colour the row renders. Pulls from ColorUtils so
  /// dark-mode + role-scoped palettes stay consistent.
  Color get color {
    switch (this) {
      case PriorityInboxSeverity.critical:
        return ColorUtils.error600;
      case PriorityInboxSeverity.warning:
        return ColorUtils.warning600;
      case PriorityInboxSeverity.info:
        return ColorUtils.corporateBlue600;
    }
  }
}
