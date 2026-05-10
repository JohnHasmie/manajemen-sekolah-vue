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
  format: json['format'] as String? ?? 'k13',
  aiGenerated: json['ai_generated'] as bool? ?? false,
  filePath: json['file_path'] as String?,
  fileName: json['file_name'] as String?,
  fileUrl: json['file_url'] as String?,
  fileSize: (json['file_size'] as num?)?.toInt(),
  fileMime: json['file_mime'] as String?,
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
      'format': instance.format,
      'ai_generated': instance.aiGenerated,
      'file_path': instance.filePath,
      'file_name': instance.fileName,
      'file_url': instance.fileUrl,
      'file_size': instance.fileSize,
      'file_mime': instance.fileMime,
    };
