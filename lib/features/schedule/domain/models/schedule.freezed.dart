// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'schedule.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Schedule {

 String get id;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'subject_name') String? get subjectName;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'class_name') String? get className;@JsonKey(name: 'teacher_id') String? get teacherId;@JsonKey(name: 'teacher_name') String? get teacherName;@JsonKey(name: 'day_id') String? get dayId;@JsonKey(name: 'day_name') String? get dayName;@JsonKey(name: 'lesson_hour') int? get lessonHour;@JsonKey(name: 'lesson_hour_id') String? get lessonHourId;@JsonKey(name: 'start_time') String? get startTime;@JsonKey(name: 'end_time') String? get endTime;@JsonKey(name: 'academic_year') String? get academicYear;@JsonKey(name: 'semester_name') String? get semesterName;
/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ScheduleCopyWith<Schedule> get copyWith => _$ScheduleCopyWithImpl<Schedule>(this as Schedule, _$identity);

  /// Serializes this Schedule to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Schedule&&(identical(other.id, id) || other.id == id)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.className, className) || other.className == className)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.dayName, dayName) || other.dayName == dayName)&&(identical(other.lessonHour, lessonHour) || other.lessonHour == lessonHour)&&(identical(other.lessonHourId, lessonHourId) || other.lessonHourId == lessonHourId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.academicYear, academicYear) || other.academicYear == academicYear)&&(identical(other.semesterName, semesterName) || other.semesterName == semesterName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subjectId,subjectName,classId,className,teacherId,teacherName,dayId,dayName,lessonHour,lessonHourId,startTime,endTime,academicYear,semesterName);

@override
String toString() {
  return 'Schedule(id: $id, subjectId: $subjectId, subjectName: $subjectName, classId: $classId, className: $className, teacherId: $teacherId, teacherName: $teacherName, dayId: $dayId, dayName: $dayName, lessonHour: $lessonHour, lessonHourId: $lessonHourId, startTime: $startTime, endTime: $endTime, academicYear: $academicYear, semesterName: $semesterName)';
}


}

/// @nodoc
abstract mixin class $ScheduleCopyWith<$Res>  {
  factory $ScheduleCopyWith(Schedule value, $Res Function(Schedule) _then) = _$ScheduleCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'teacher_id') String? teacherId,@JsonKey(name: 'teacher_name') String? teacherName,@JsonKey(name: 'day_id') String? dayId,@JsonKey(name: 'day_name') String? dayName,@JsonKey(name: 'lesson_hour') int? lessonHour,@JsonKey(name: 'lesson_hour_id') String? lessonHourId,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime,@JsonKey(name: 'academic_year') String? academicYear,@JsonKey(name: 'semester_name') String? semesterName
});




}
/// @nodoc
class _$ScheduleCopyWithImpl<$Res>
    implements $ScheduleCopyWith<$Res> {
  _$ScheduleCopyWithImpl(this._self, this._then);

  final Schedule _self;
  final $Res Function(Schedule) _then;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? subjectId = freezed,Object? subjectName = freezed,Object? classId = freezed,Object? className = freezed,Object? teacherId = freezed,Object? teacherName = freezed,Object? dayId = freezed,Object? dayName = freezed,Object? lessonHour = freezed,Object? lessonHourId = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? academicYear = freezed,Object? semesterName = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,dayId: freezed == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String?,dayName: freezed == dayName ? _self.dayName : dayName // ignore: cast_nullable_to_non_nullable
as String?,lessonHour: freezed == lessonHour ? _self.lessonHour : lessonHour // ignore: cast_nullable_to_non_nullable
as int?,lessonHourId: freezed == lessonHourId ? _self.lessonHourId : lessonHourId // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,academicYear: freezed == academicYear ? _self.academicYear : academicYear // ignore: cast_nullable_to_non_nullable
as String?,semesterName: freezed == semesterName ? _self.semesterName : semesterName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Schedule].
extension SchedulePatterns on Schedule {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Schedule value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Schedule value)  $default,){
final _that = this;
switch (_that) {
case _Schedule():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Schedule value)?  $default,){
final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'day_id')  String? dayId, @JsonKey(name: 'day_name')  String? dayName, @JsonKey(name: 'lesson_hour')  int? lessonHour, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'academic_year')  String? academicYear, @JsonKey(name: 'semester_name')  String? semesterName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that.id,_that.subjectId,_that.subjectName,_that.classId,_that.className,_that.teacherId,_that.teacherName,_that.dayId,_that.dayName,_that.lessonHour,_that.lessonHourId,_that.startTime,_that.endTime,_that.academicYear,_that.semesterName);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'day_id')  String? dayId, @JsonKey(name: 'day_name')  String? dayName, @JsonKey(name: 'lesson_hour')  int? lessonHour, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'academic_year')  String? academicYear, @JsonKey(name: 'semester_name')  String? semesterName)  $default,) {final _that = this;
switch (_that) {
case _Schedule():
return $default(_that.id,_that.subjectId,_that.subjectName,_that.classId,_that.className,_that.teacherId,_that.teacherName,_that.dayId,_that.dayName,_that.lessonHour,_that.lessonHourId,_that.startTime,_that.endTime,_that.academicYear,_that.semesterName);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_id')  String? teacherId, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'day_id')  String? dayId, @JsonKey(name: 'day_name')  String? dayName, @JsonKey(name: 'lesson_hour')  int? lessonHour, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'start_time')  String? startTime, @JsonKey(name: 'end_time')  String? endTime, @JsonKey(name: 'academic_year')  String? academicYear, @JsonKey(name: 'semester_name')  String? semesterName)?  $default,) {final _that = this;
switch (_that) {
case _Schedule() when $default != null:
return $default(_that.id,_that.subjectId,_that.subjectName,_that.classId,_that.className,_that.teacherId,_that.teacherName,_that.dayId,_that.dayName,_that.lessonHour,_that.lessonHourId,_that.startTime,_that.endTime,_that.academicYear,_that.semesterName);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Schedule extends Schedule {
  const _Schedule({required this.id, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'subject_name') this.subjectName, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'class_name') this.className, @JsonKey(name: 'teacher_id') this.teacherId, @JsonKey(name: 'teacher_name') this.teacherName, @JsonKey(name: 'day_id') this.dayId, @JsonKey(name: 'day_name') this.dayName, @JsonKey(name: 'lesson_hour') this.lessonHour, @JsonKey(name: 'lesson_hour_id') this.lessonHourId, @JsonKey(name: 'start_time') this.startTime, @JsonKey(name: 'end_time') this.endTime, @JsonKey(name: 'academic_year') this.academicYear, @JsonKey(name: 'semester_name') this.semesterName}): super._();
  factory _Schedule.fromJson(Map<String, dynamic> json) => _$ScheduleFromJson(json);

@override final  String id;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'subject_name') final  String? subjectName;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'class_name') final  String? className;
@override@JsonKey(name: 'teacher_id') final  String? teacherId;
@override@JsonKey(name: 'teacher_name') final  String? teacherName;
@override@JsonKey(name: 'day_id') final  String? dayId;
@override@JsonKey(name: 'day_name') final  String? dayName;
@override@JsonKey(name: 'lesson_hour') final  int? lessonHour;
@override@JsonKey(name: 'lesson_hour_id') final  String? lessonHourId;
@override@JsonKey(name: 'start_time') final  String? startTime;
@override@JsonKey(name: 'end_time') final  String? endTime;
@override@JsonKey(name: 'academic_year') final  String? academicYear;
@override@JsonKey(name: 'semester_name') final  String? semesterName;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ScheduleCopyWith<_Schedule> get copyWith => __$ScheduleCopyWithImpl<_Schedule>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ScheduleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Schedule&&(identical(other.id, id) || other.id == id)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.className, className) || other.className == className)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.dayId, dayId) || other.dayId == dayId)&&(identical(other.dayName, dayName) || other.dayName == dayName)&&(identical(other.lessonHour, lessonHour) || other.lessonHour == lessonHour)&&(identical(other.lessonHourId, lessonHourId) || other.lessonHourId == lessonHourId)&&(identical(other.startTime, startTime) || other.startTime == startTime)&&(identical(other.endTime, endTime) || other.endTime == endTime)&&(identical(other.academicYear, academicYear) || other.academicYear == academicYear)&&(identical(other.semesterName, semesterName) || other.semesterName == semesterName));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subjectId,subjectName,classId,className,teacherId,teacherName,dayId,dayName,lessonHour,lessonHourId,startTime,endTime,academicYear,semesterName);

@override
String toString() {
  return 'Schedule(id: $id, subjectId: $subjectId, subjectName: $subjectName, classId: $classId, className: $className, teacherId: $teacherId, teacherName: $teacherName, dayId: $dayId, dayName: $dayName, lessonHour: $lessonHour, lessonHourId: $lessonHourId, startTime: $startTime, endTime: $endTime, academicYear: $academicYear, semesterName: $semesterName)';
}


}

/// @nodoc
abstract mixin class _$ScheduleCopyWith<$Res> implements $ScheduleCopyWith<$Res> {
  factory _$ScheduleCopyWith(_Schedule value, $Res Function(_Schedule) _then) = __$ScheduleCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'teacher_id') String? teacherId,@JsonKey(name: 'teacher_name') String? teacherName,@JsonKey(name: 'day_id') String? dayId,@JsonKey(name: 'day_name') String? dayName,@JsonKey(name: 'lesson_hour') int? lessonHour,@JsonKey(name: 'lesson_hour_id') String? lessonHourId,@JsonKey(name: 'start_time') String? startTime,@JsonKey(name: 'end_time') String? endTime,@JsonKey(name: 'academic_year') String? academicYear,@JsonKey(name: 'semester_name') String? semesterName
});




}
/// @nodoc
class __$ScheduleCopyWithImpl<$Res>
    implements _$ScheduleCopyWith<$Res> {
  __$ScheduleCopyWithImpl(this._self, this._then);

  final _Schedule _self;
  final $Res Function(_Schedule) _then;

/// Create a copy of Schedule
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? subjectId = freezed,Object? subjectName = freezed,Object? classId = freezed,Object? className = freezed,Object? teacherId = freezed,Object? teacherName = freezed,Object? dayId = freezed,Object? dayName = freezed,Object? lessonHour = freezed,Object? lessonHourId = freezed,Object? startTime = freezed,Object? endTime = freezed,Object? academicYear = freezed,Object? semesterName = freezed,}) {
  return _then(_Schedule(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,dayId: freezed == dayId ? _self.dayId : dayId // ignore: cast_nullable_to_non_nullable
as String?,dayName: freezed == dayName ? _self.dayName : dayName // ignore: cast_nullable_to_non_nullable
as String?,lessonHour: freezed == lessonHour ? _self.lessonHour : lessonHour // ignore: cast_nullable_to_non_nullable
as int?,lessonHourId: freezed == lessonHourId ? _self.lessonHourId : lessonHourId // ignore: cast_nullable_to_non_nullable
as String?,startTime: freezed == startTime ? _self.startTime : startTime // ignore: cast_nullable_to_non_nullable
as String?,endTime: freezed == endTime ? _self.endTime : endTime // ignore: cast_nullable_to_non_nullable
as String?,academicYear: freezed == academicYear ? _self.academicYear : academicYear // ignore: cast_nullable_to_non_nullable
as String?,semesterName: freezed == semesterName ? _self.semesterName : semesterName // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
