// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceImpl _$$AttendanceImplFromJson(Map<String, dynamic> json) =>
    _$AttendanceImpl(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      date: DateTime.parse(json['date'] as String),
      status: json['status'] as String,
      isRead: json['is_read'] as bool? ?? false,
      subjectName: json['subject_name'] as String?,
      subjectId: json['subject_id'] as String?,
      lessonHourName: json['lesson_hour_name'] as String?,
      lessonHourId: json['lesson_hour_id'] as String?,
      classId: json['class_id'] as String?,
      teacherId: json['teacher_id'] as String?,
    );

Map<String, dynamic> _$$AttendanceImplToJson(_$AttendanceImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'student_id': instance.studentId,
      'date': instance.date.toIso8601String(),
      'status': instance.status,
      'is_read': instance.isRead,
      'subject_name': instance.subjectName,
      'subject_id': instance.subjectId,
      'lesson_hour_name': instance.lessonHourName,
      'lesson_hour_id': instance.lessonHourId,
      'class_id': instance.classId,
      'teacher_id': instance.teacherId,
    };
