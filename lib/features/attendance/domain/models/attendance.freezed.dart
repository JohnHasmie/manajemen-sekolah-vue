// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Attendance {

 String get id;@JsonKey(name: 'student_id') String get studentId; DateTime get date; String get status;@JsonKey(name: 'is_read') bool get isRead;@JsonKey(name: 'subject_name') String? get subjectName;@JsonKey(name: 'subject_id') String? get subjectId;@JsonKey(name: 'lesson_hour_name') String? get lessonHourName;@JsonKey(name: 'lesson_hour_id') String? get lessonHourId;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'teacher_id') String? get teacherId;
/// Create a copy of Attendance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttendanceCopyWith<Attendance> get copyWith => _$AttendanceCopyWithImpl<Attendance>(this as Attendance, _$identity);

  /// Serializes this Attendance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Attendance&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.date, date) || other.date == date)&&(identical(other.status, status) || other.status == status)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.lessonHourName, lessonHourName) || other.lessonHourName == lessonHourName)&&(identical(other.lessonHourId, lessonHourId) || other.lessonHourId == lessonHourId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,date,status,isRead,subjectName,subjectId,lessonHourName,lessonHourId,classId,teacherId);

@override
String toString() {
  return 'Attendance(id: $id, studentId: $studentId, date: $date, status: $status, isRead: $isRead, subjectName: $subjectName, subjectId: $subjectId, lessonHourName: $lessonHourName, lessonHourId: $lessonHourId, classId: $classId, teacherId: $teacherId)';
}


}

/// @nodoc
abstract mixin class $AttendanceCopyWith<$Res>  {
  factory $AttendanceCopyWith(Attendance value, $Res Function(Attendance) _then) = _$AttendanceCopyWithImpl;
@useResult
$Res call({
 String id,@JsonKey(name: 'student_id') String studentId, DateTime date, String status,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'lesson_hour_name') String? lessonHourName,@JsonKey(name: 'lesson_hour_id') String? lessonHourId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'teacher_id') String? teacherId
});




}
/// @nodoc
class _$AttendanceCopyWithImpl<$Res>
    implements $AttendanceCopyWith<$Res> {
  _$AttendanceCopyWithImpl(this._self, this._then);

  final Attendance _self;
  final $Res Function(Attendance) _then;

/// Create a copy of Attendance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? studentId = null,Object? date = null,Object? status = null,Object? isRead = null,Object? subjectName = freezed,Object? subjectId = freezed,Object? lessonHourName = freezed,Object? lessonHourId = freezed,Object? classId = freezed,Object? teacherId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,lessonHourName: freezed == lessonHourName ? _self.lessonHourName : lessonHourName // ignore: cast_nullable_to_non_nullable
as String?,lessonHourId: freezed == lessonHourId ? _self.lessonHourId : lessonHourId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Attendance].
extension AttendancePatterns on Attendance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Attendance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Attendance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Attendance value)  $default,){
final _that = this;
switch (_that) {
case _Attendance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Attendance value)?  $default,){
final _that = this;
switch (_that) {
case _Attendance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'student_id')  String studentId,  DateTime date,  String status, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'lesson_hour_name')  String? lessonHourName, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'teacher_id')  String? teacherId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Attendance() when $default != null:
return $default(_that.id,_that.studentId,_that.date,_that.status,_that.isRead,_that.subjectName,_that.subjectId,_that.lessonHourName,_that.lessonHourId,_that.classId,_that.teacherId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id, @JsonKey(name: 'student_id')  String studentId,  DateTime date,  String status, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'lesson_hour_name')  String? lessonHourName, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'teacher_id')  String? teacherId)  $default,) {final _that = this;
switch (_that) {
case _Attendance():
return $default(_that.id,_that.studentId,_that.date,_that.status,_that.isRead,_that.subjectName,_that.subjectId,_that.lessonHourName,_that.lessonHourId,_that.classId,_that.teacherId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id, @JsonKey(name: 'student_id')  String studentId,  DateTime date,  String status, @JsonKey(name: 'is_read')  bool isRead, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId, @JsonKey(name: 'lesson_hour_name')  String? lessonHourName, @JsonKey(name: 'lesson_hour_id')  String? lessonHourId, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'teacher_id')  String? teacherId)?  $default,) {final _that = this;
switch (_that) {
case _Attendance() when $default != null:
return $default(_that.id,_that.studentId,_that.date,_that.status,_that.isRead,_that.subjectName,_that.subjectId,_that.lessonHourName,_that.lessonHourId,_that.classId,_that.teacherId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Attendance implements Attendance {
  const _Attendance({required this.id, @JsonKey(name: 'student_id') required this.studentId, required this.date, required this.status, @JsonKey(name: 'is_read') this.isRead = false, @JsonKey(name: 'subject_name') this.subjectName, @JsonKey(name: 'subject_id') this.subjectId, @JsonKey(name: 'lesson_hour_name') this.lessonHourName, @JsonKey(name: 'lesson_hour_id') this.lessonHourId, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'teacher_id') this.teacherId});
  factory _Attendance.fromJson(Map<String, dynamic> json) => _$AttendanceFromJson(json);

@override final  String id;
@override@JsonKey(name: 'student_id') final  String studentId;
@override final  DateTime date;
@override final  String status;
@override@JsonKey(name: 'is_read') final  bool isRead;
@override@JsonKey(name: 'subject_name') final  String? subjectName;
@override@JsonKey(name: 'subject_id') final  String? subjectId;
@override@JsonKey(name: 'lesson_hour_name') final  String? lessonHourName;
@override@JsonKey(name: 'lesson_hour_id') final  String? lessonHourId;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'teacher_id') final  String? teacherId;

/// Create a copy of Attendance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttendanceCopyWith<_Attendance> get copyWith => __$AttendanceCopyWithImpl<_Attendance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttendanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Attendance&&(identical(other.id, id) || other.id == id)&&(identical(other.studentId, studentId) || other.studentId == studentId)&&(identical(other.date, date) || other.date == date)&&(identical(other.status, status) || other.status == status)&&(identical(other.isRead, isRead) || other.isRead == isRead)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId)&&(identical(other.lessonHourName, lessonHourName) || other.lessonHourName == lessonHourName)&&(identical(other.lessonHourId, lessonHourId) || other.lessonHourId == lessonHourId)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.teacherId, teacherId) || other.teacherId == teacherId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,studentId,date,status,isRead,subjectName,subjectId,lessonHourName,lessonHourId,classId,teacherId);

@override
String toString() {
  return 'Attendance(id: $id, studentId: $studentId, date: $date, status: $status, isRead: $isRead, subjectName: $subjectName, subjectId: $subjectId, lessonHourName: $lessonHourName, lessonHourId: $lessonHourId, classId: $classId, teacherId: $teacherId)';
}


}

/// @nodoc
abstract mixin class _$AttendanceCopyWith<$Res> implements $AttendanceCopyWith<$Res> {
  factory _$AttendanceCopyWith(_Attendance value, $Res Function(_Attendance) _then) = __$AttendanceCopyWithImpl;
@override @useResult
$Res call({
 String id,@JsonKey(name: 'student_id') String studentId, DateTime date, String status,@JsonKey(name: 'is_read') bool isRead,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'subject_id') String? subjectId,@JsonKey(name: 'lesson_hour_name') String? lessonHourName,@JsonKey(name: 'lesson_hour_id') String? lessonHourId,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'teacher_id') String? teacherId
});




}
/// @nodoc
class __$AttendanceCopyWithImpl<$Res>
    implements _$AttendanceCopyWith<$Res> {
  __$AttendanceCopyWithImpl(this._self, this._then);

  final _Attendance _self;
  final $Res Function(_Attendance) _then;

/// Create a copy of Attendance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? studentId = null,Object? date = null,Object? status = null,Object? isRead = null,Object? subjectName = freezed,Object? subjectId = freezed,Object? lessonHourName = freezed,Object? lessonHourId = freezed,Object? classId = freezed,Object? teacherId = freezed,}) {
  return _then(_Attendance(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,studentId: null == studentId ? _self.studentId : studentId // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,isRead: null == isRead ? _self.isRead : isRead // ignore: cast_nullable_to_non_nullable
as bool,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,lessonHourName: freezed == lessonHourName ? _self.lessonHourName : lessonHourName // ignore: cast_nullable_to_non_nullable
as String?,lessonHourId: freezed == lessonHourId ? _self.lessonHourId : lessonHourId // ignore: cast_nullable_to_non_nullable
as String?,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,teacherId: freezed == teacherId ? _self.teacherId : teacherId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
