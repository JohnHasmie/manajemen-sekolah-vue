// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lesson_plan.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LessonPlan _$LessonPlanFromJson(Map<String, dynamic> json) => _LessonPlan(
  id: json['id'] as String,
  title: json['title'] as String,
  status: json['status'] as String? ?? '',
  subjectName: json['subject_name'] as String?,
  className: json['class_name'] as String?,
  teacherName: json['teacher_name'] as String?,
  academicYear: json['academic_year'] as String?,
  semester: json['semester'] as String?,
  notes: json['notes'] as String?,
  adminNotes: json['admin_notes'] as String?,
  createdAt: json['created_at'] as String?,
);

Map<String, dynamic> _$LessonPlanToJson(_LessonPlan instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'status': instance.status,
      'subject_name': instance.subjectName,
      'class_name': instance.className,
      'teacher_name': instance.teacherName,
      'academic_year': instance.academicYear,
      'semester': instance.semester,
      'notes': instance.notes,
      'admin_notes': instance.adminNotes,
      'created_at': instance.createdAt,
    };
