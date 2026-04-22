// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'schedule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Schedule _$ScheduleFromJson(Map<String, dynamic> json) => _Schedule(
  id: json['id'] as String,
  subjectId: json['subject_id'] as String?,
  subjectName: json['subject_name'] as String?,
  classId: json['class_id'] as String?,
  className: json['class_name'] as String?,
  teacherId: json['teacher_id'] as String?,
  teacherName: json['teacher_name'] as String?,
  dayId: json['day_id'] as String?,
  dayName: json['day_name'] as String?,
  lessonHour: (json['lesson_hour'] as num?)?.toInt(),
  lessonHourId: json['lesson_hour_id'] as String?,
  startTime: json['start_time'] as String?,
  endTime: json['end_time'] as String?,
  academicYear: json['academic_year'] as String?,
  semesterName: json['semester_name'] as String?,
);

Map<String, dynamic> _$ScheduleToJson(_Schedule instance) => <String, dynamic>{
  'id': instance.id,
  'subject_id': instance.subjectId,
  'subject_name': instance.subjectName,
  'class_id': instance.classId,
  'class_name': instance.className,
  'teacher_id': instance.teacherId,
  'teacher_name': instance.teacherName,
  'day_id': instance.dayId,
  'day_name': instance.dayName,
  'lesson_hour': instance.lessonHour,
  'lesson_hour_id': instance.lessonHourId,
  'start_time': instance.startTime,
  'end_time': instance.endTime,
  'academic_year': instance.academicYear,
  'semester_name': instance.semesterName,
};
