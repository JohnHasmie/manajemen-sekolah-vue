// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$AttendanceSummaryImpl _$$AttendanceSummaryImplFromJson(
  Map<String, dynamic> json,
) => _$AttendanceSummaryImpl(
  id: json['id'] as String?,
  date: DateTime.parse(json['date'] as String),
  present: (json['present'] as num?)?.toInt() ?? 0,
  sick: (json['sick'] as num?)?.toInt() ?? 0,
  excused: (json['excused'] as num?)?.toInt() ?? 0,
  absent: (json['absent'] as num?)?.toInt() ?? 0,
  totalStudents: (json['total_students'] as num?)?.toInt() ?? 0,
  subjectName: json['subject_name'] as String?,
  subjectId: json['subject_id'] as String?,
);

Map<String, dynamic> _$$AttendanceSummaryImplToJson(
  _$AttendanceSummaryImpl instance,
) => <String, dynamic>{
  'id': instance.id,
  'date': instance.date.toIso8601String(),
  'present': instance.present,
  'sick': instance.sick,
  'excused': instance.excused,
  'absent': instance.absent,
  'total_students': instance.totalStudents,
  'subject_name': instance.subjectName,
  'subject_id': instance.subjectId,
};
