// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Classroom _$ClassroomFromJson(Map<String, dynamic> json) => _Classroom(
  id: json['id'] as String,
  name: json['name'] as String,
  homeroomTeacherName: json['homeroom_teacher_name'] as String?,
  homeroomTeacherId: json['homeroom_teacher_id'] as String?,
  studentCount: (json['student_count'] as num?)?.toInt() ?? 0,
  gradeLevel: json['grade_level'] as String?,
  academicYearId: json['academic_year_id'] as String?,
);

Map<String, dynamic> _$ClassroomToJson(_Classroom instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'homeroom_teacher_name': instance.homeroomTeacherName,
      'homeroom_teacher_id': instance.homeroomTeacherId,
      'student_count': instance.studentCount,
      'grade_level': instance.gradeLevel,
      'academic_year_id': instance.academicYearId,
    };
