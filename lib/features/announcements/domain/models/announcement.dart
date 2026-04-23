// announcement.dart - School announcement data model (Freezed).
// Like Laravel's Announcement Eloquent Model but simpler — typed DTO with
// JSON normalization built in.
import 'package:freezed_annotation/freezed_annotation.dart';

part 'announcement.freezed.dart';
part 'announcement.g.dart';

/// Represents a school announcement/notification entry.
///
/// Normalizes varied API shapes (English/Indonesian keys, heterogeneous
/// boolean representations for `is_read`) into a typed DTO.
@freezed
abstract class Announcement with _$Announcement {
  const Announcement._();

  const factory Announcement({
    required String id,
    required String title,
    required String content,
    required String category,
    @JsonKey(name: 'created_at') String? createdAt,
    // Default true — treats missing `is_read` as read/unknown,
    // matching existing UI semantics (unread requires explicit false/0).
    @JsonKey(name: 'is_read') @Default(true) bool isRead,
  }) = _Announcement;

  /// Custom fromJson to handle various API shapes (English/Indonesian keys,
  /// heterogeneous boolean representations for is_read).
  factory Announcement.fromJson(Map<String, dynamic> json) =>
      _$AnnouncementFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // 1. Resolve common Indonesian keys
    mapped['title'] ??= mapped['judul'];
    mapped['content'] ??= mapped['isi'] ?? mapped['konten'];
    mapped['category'] ??= mapped['kategori'];
    mapped['created_at'] ??= mapped['tanggal'] ?? mapped['date'];

    // 2. Normalize is_read — API can return: null, true, false, 1, 0, '1', '0'
    // Null is treated as "read" (default true) to match pre-existing UI semantics.
    final rawRead = mapped['is_read'];
    if (rawRead == null) {
      mapped['is_read'] = true;
    } else if (rawRead is bool) {
      mapped['is_read'] = rawRead;
    } else if (rawRead is num) {
      mapped['is_read'] = rawRead != 0;
    } else {
      mapped['is_read'] = rawRead.toString() == '1' ||
          rawRead.toString().toLowerCase() == 'true';
    }

    // 3. Force String types — provide defaults for required fields
    mapped['id'] = (mapped['id'] ?? '').toString();
    mapped['title'] = (mapped['title'] ?? '').toString();
    mapped['content'] = (mapped['content'] ?? '').toString();
    mapped['category'] = (mapped['category'] ?? '').toString();
    if (mapped['created_at'] != null) {
      mapped['created_at'] = mapped['created_at'].toString();
    }

    return mapped;
  }
}
