// notification_item.dart - In-app notification inbox entry (Freezed).
//
// Like Laravel's DatabaseNotification model but a slim typed DTO: it
// normalizes the raw paginated `/notifications` API rows into a strongly
// typed entity so presentation code reads `n.title` instead of
// `n['title']`.
//
// In Vue terms, this is the shape you would declare for a notification item
// in a Pinia store / a TypeScript interface for the inbox payload.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_item.freezed.dart';
part 'notification_item.g.dart';

/// A single in-app notification row from the `/notifications` endpoint.
///
/// Field nullability mirrors the pre-existing raw-map access exactly so the
/// UI keeps the same null handling:
/// - [id] is always present (raw rows always carry an id; used via
///   `id.toString()` previously). Coerced to [String].
/// - [type], [title], [body], [createdAt] were read as nullable values with
///   call-site `?? '...'` fallbacks, so they stay nullable [String]s here.
/// - [isUnread] encapsulates the previous heterogeneous `is_read` logic
///   (bool, int, or missing) as a single derived flag — see
///   [_standardizeJson].
@freezed
abstract class NotificationItem with _$NotificationItem {
  const factory NotificationItem({
    /// Notification id, always coerced to a String (raw rows used
    /// `n['id'].toString()`).
    required String id,

    /// Notification category, e.g. 'bill', 'class_activity', 'announcement'.
    /// Nullable: navigation compared the raw value and cards/dialogs applied
    /// their own `?? 'general'` fallback.
    String? type,

    /// Headline text. Nullable; call sites applied `?? '-'` / `?? 'Informasi'`.
    String? title,

    /// Body text. Nullable; call sites applied `?? '-'` / `?? ''`.
    String? body,

    /// ISO timestamp string, passed straight into the date formatter which
    /// already accepts `String?`.
    @JsonKey(name: 'created_at') String? createdAt,

    /// Derived unread flag. True when the source row should be treated as
    /// unread, preserving the original rule: bool → `!is_read`; int →
    /// `is_read != 1`; anything else / missing → unread (true).
    @JsonKey(name: 'is_unread') @Default(true) bool isUnread,
  }) = _NotificationItem;

  /// Normalizes a raw API row into the typed model.
  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      _$NotificationItemFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // id was always consumed via `.toString()`, so coerce here. Falls back to
    // an empty string only if a row somehow lacks an id (previously this would
    // have thrown on a null `.toString()`); empty string keeps the model safe
    // without changing real-data behavior.
    mapped['id'] = (mapped['id'] ?? '').toString();

    // Preserve nullable strings exactly — only stringify when present so a
    // missing key stays null (matching the `?? '...'` fallbacks at call sites).
    if (mapped['type'] != null) mapped['type'] = mapped['type'].toString();
    if (mapped['title'] != null) mapped['title'] = mapped['title'].toString();
    if (mapped['body'] != null) mapped['body'] = mapped['body'].toString();
    if (mapped['created_at'] != null) {
      mapped['created_at'] = mapped['created_at'].toString();
    }

    // Collapse the heterogeneous `is_read` representation into `is_unread`,
    // replicating NotificationReadStateMixin.isUnread byte-for-byte:
    //   - bool  -> unread = !is_read
    //   - int   -> unread = is_read != 1
    //   - else  -> unread = true (missing/null/other treated as unread)
    final rawRead = mapped['is_read'];
    if (rawRead is bool) {
      mapped['is_unread'] = !rawRead;
    } else if (rawRead is int) {
      mapped['is_unread'] = rawRead != 1;
    } else {
      mapped['is_unread'] = true;
    }

    return mapped;
  }
}
