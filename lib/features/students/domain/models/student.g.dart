// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Student _$StudentFromJson(Map<String, dynamic> json) => _Student(
  id: json['id'] as String,
  name: json['name'] as String,
  className: json['class_name'] as String,
  studentNumber: json['student_number'] as String,
  address: json['address'] as String,
  guardianName: json['guardian_name'] as String,
  phoneNumber: json['phone_number'] as String,
  classId: json['class_id'] as String?,
  studentClassId: json['student_class_id'] as String?,
  gender: json['gender'] as String?,
  dateOfBirth: json['date_of_birth'] as String?,
  guardianEmail: json['guardian_email'] as String?,
);

Map<String, dynamic> _$StudentToJson(_Student instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'class_name': instance.className,
  'student_number': instance.studentNumber,
  'address': instance.address,
  'guardian_name': instance.guardianName,
  'phone_number': instance.phoneNumber,
  'class_id': instance.classId,
  'student_class_id': instance.studentClassId,
  'gender': instance.gender,
  'date_of_birth': instance.dateOfBirth,
  'guardian_email': instance.guardianEmail,
};
