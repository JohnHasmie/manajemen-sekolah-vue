// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'student.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$StudentImpl _$$StudentImplFromJson(Map<String, dynamic> json) =>
    _$StudentImpl(
      id: json['id'] as String,
      name: json['name'] as String,
      className: json['class_name'] as String,
      studentNumber: json['student_number'] as String,
      address: json['address'] as String,
      guardianName: json['guardian_name'] as String,
      phoneNumber: json['phone_number'] as String,
      classId: json['class_id'] as String?,
      studentClassId: json['student_class_id'] as String?,
    );

Map<String, dynamic> _$$StudentImplToJson(_$StudentImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'class_name': instance.className,
      'student_number': instance.studentNumber,
      'address': instance.address,
      'guardian_name': instance.guardianName,
      'phone_number': instance.phoneNumber,
      'class_id': instance.classId,
      'student_class_id': instance.studentClassId,
    };
