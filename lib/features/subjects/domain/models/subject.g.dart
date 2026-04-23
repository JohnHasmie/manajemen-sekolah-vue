// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subject.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subject _$SubjectFromJson(Map<String, dynamic> json) => _Subject(
  id: json['id'] as String,
  name: json['name'] as String,
  code: json['code'] as String?,
  classCount: (json['class_count'] as num?)?.toInt() ?? 0,
  isActive: json['is_active'] as bool? ?? true,
  classNames: json['class_names'] as String?,
);

Map<String, dynamic> _$SubjectToJson(_Subject instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'code': instance.code,
  'class_count': instance.classCount,
  'is_active': instance.isActive,
  'class_names': instance.classNames,
};
