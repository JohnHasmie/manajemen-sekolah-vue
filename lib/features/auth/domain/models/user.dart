import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User model representing a profile with specific roles and school
/// assignments.
@freezed
abstract class User with _$User {
  const factory User({
    required String id,
    required String name,
    required String email,
    required String role,
    @JsonKey(name: 'school_id') String? schoolId,
    @JsonKey(name: 'school_name') String? schoolName,
    @JsonKey(name: 'profile_picture_url') String? profilePictureUrl,
  }) = _User;

  /// Custom fromJson to handle Indonesian key variations by standardizing them
  /// into the backend-expected English snake_case keys before generation.
  factory User.fromJson(Map<String, dynamic> json) =>
      _$UserFromJson(_standardizeJson(json));

  static Map<String, dynamic> _standardizeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> mapped = Map<String, dynamic>.from(json);

    // Force string types and provide fallbacks to prevent type cast crashes
    mapped['id'] = (mapped['id'] ?? mapped['user_id'] ?? '').toString();
    mapped['name'] = (mapped['name'] ?? mapped['nama'] ?? 'User').toString();
    mapped['email'] = (mapped['email'] ?? '').toString();
    mapped['role'] = (mapped['role'] ?? mapped['peran'] ?? '').toString();

    mapped['school_id'] =
        mapped['school_id']?.toString() ?? mapped['sekolah_id']?.toString();
    // Backend renamed `schools.school_name` → `schools.name`. Auth payloads
    // still expose the flat `school_name` (or legacy `nama_sekolah`).
    mapped['school_name'] = (mapped['school_name'] ?? mapped['nama_sekolah'])
        ?.toString();
    mapped['profile_picture_url'] =
        (mapped['profile_picture_url'] ?? mapped['foto_profil'])?.toString();

    return mapped;
  }
}
