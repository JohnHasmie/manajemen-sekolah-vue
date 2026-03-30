// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  role: json['role'] as String,
  schoolId: json['school_id'] as String?,
  schoolName: json['school_name'] as String?,
  profilePictureUrl: json['profile_picture_url'] as String?,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
  'school_id': instance.schoolId,
  'school_name': instance.schoolName,
  'profile_picture_url': instance.profilePictureUrl,
};
