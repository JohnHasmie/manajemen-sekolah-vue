import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// User model representing a profile with specific roles and school assignments.
@freezed
class User with _$User {
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
    
    // Fallback for Indonesian keys to standard English keys
    mapped['name'] ??= mapped['nama'];
    mapped['school_id'] ??= mapped['sekolah_id'] ?? mapped['school_id'];
    mapped['school_name'] ??= mapped['nama_sekolah'] ?? mapped['school_name'];
    mapped['profile_picture_url'] ??= mapped['foto_profil'] ?? mapped['profile_picture_url'];
    
    // Force string types for IDs to avoid type cast errors
    if (mapped['id'] != null) mapped['id'] = mapped['id'].toString();
    if (mapped['school_id'] != null) mapped['school_id'] = mapped['school_id'].toString();
    
    return mapped;
  }
}
