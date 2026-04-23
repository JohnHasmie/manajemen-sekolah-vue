// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'teacher.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Teacher _$TeacherFromJson(Map<String, dynamic> json) => _Teacher(
  id: json['id'] as String,
  name: json['name'] as String,
  email: json['email'] as String,
  role: json['role'] as String,
  employeeNumber: json['employee_number'] as String?,
  phoneNumber: json['phone_number'] as String?,
  address: json['address'] as String?,
  homeroomClassId: json['homeroom_class_id'] as String?,
  homeroomClassName: json['homeroom_class_name'] as String?,
  subjectIds: (json['subject_ids'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  subjectNames: (json['subject_names'] as List<dynamic>?)
      ?.map((e) => e as String)
      .toList(),
  userId: json['user_id'] as String?,
);

Map<String, dynamic> _$TeacherToJson(_Teacher instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'email': instance.email,
  'role': instance.role,
  'employee_number': instance.employeeNumber,
  'phone_number': instance.phoneNumber,
  'address': instance.address,
  'homeroom_class_id': instance.homeroomClassId,
  'homeroom_class_name': instance.homeroomClassName,
  'subject_ids': instance.subjectIds,
  'subject_names': instance.subjectNames,
  'user_id': instance.userId,
};
