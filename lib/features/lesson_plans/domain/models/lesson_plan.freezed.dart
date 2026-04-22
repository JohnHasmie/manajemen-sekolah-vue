// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'lesson_plan.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LessonPlan {

 String get id; String get title; String get status;@JsonKey(name: 'subject_name') String? get subjectName;@JsonKey(name: 'class_name') String? get className;@JsonKey(name: 'teacher_name') String? get teacherName;@JsonKey(name: 'academic_year') String? get academicYear; String? get semester; String? get notes;@JsonKey(name: 'admin_notes') String? get adminNotes;@JsonKey(name: 'created_at') String? get createdAt;
/// Create a copy of LessonPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LessonPlanCopyWith<LessonPlan> get copyWith => _$LessonPlanCopyWithImpl<LessonPlan>(this as LessonPlan, _$identity);

  /// Serializes this LessonPlan to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LessonPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.className, className) || other.className == className)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.academicYear, academicYear) || other.academicYear == academicYear)&&(identical(other.semester, semester) || other.semester == semester)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.adminNotes, adminNotes) || other.adminNotes == adminNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,status,subjectName,className,teacherName,academicYear,semester,notes,adminNotes,createdAt);

@override
String toString() {
  return 'LessonPlan(id: $id, title: $title, status: $status, subjectName: $subjectName, className: $className, teacherName: $teacherName, academicYear: $academicYear, semester: $semester, notes: $notes, adminNotes: $adminNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $LessonPlanCopyWith<$Res>  {
  factory $LessonPlanCopyWith(LessonPlan value, $Res Function(LessonPlan) _then) = _$LessonPlanCopyWithImpl;
@useResult
$Res call({
 String id, String title, String status,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'teacher_name') String? teacherName,@JsonKey(name: 'academic_year') String? academicYear, String? semester, String? notes,@JsonKey(name: 'admin_notes') String? adminNotes,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class _$LessonPlanCopyWithImpl<$Res>
    implements $LessonPlanCopyWith<$Res> {
  _$LessonPlanCopyWithImpl(this._self, this._then);

  final LessonPlan _self;
  final $Res Function(LessonPlan) _then;

/// Create a copy of LessonPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? status = null,Object? subjectName = freezed,Object? className = freezed,Object? teacherName = freezed,Object? academicYear = freezed,Object? semester = freezed,Object? notes = freezed,Object? adminNotes = freezed,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,academicYear: freezed == academicYear ? _self.academicYear : academicYear // ignore: cast_nullable_to_non_nullable
as String?,semester: freezed == semester ? _self.semester : semester // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,adminNotes: freezed == adminNotes ? _self.adminNotes : adminNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LessonPlan].
extension LessonPlanPatterns on LessonPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LessonPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LessonPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LessonPlan value)  $default,){
final _that = this;
switch (_that) {
case _LessonPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LessonPlan value)?  $default,){
final _that = this;
switch (_that) {
case _LessonPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String status, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'academic_year')  String? academicYear,  String? semester,  String? notes, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')  String? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LessonPlan() when $default != null:
return $default(_that.id,_that.title,_that.status,_that.subjectName,_that.className,_that.teacherName,_that.academicYear,_that.semester,_that.notes,_that.adminNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String status, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'academic_year')  String? academicYear,  String? semester,  String? notes, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')  String? createdAt)  $default,) {final _that = this;
switch (_that) {
case _LessonPlan():
return $default(_that.id,_that.title,_that.status,_that.subjectName,_that.className,_that.teacherName,_that.academicYear,_that.semester,_that.notes,_that.adminNotes,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String status, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'class_name')  String? className, @JsonKey(name: 'teacher_name')  String? teacherName, @JsonKey(name: 'academic_year')  String? academicYear,  String? semester,  String? notes, @JsonKey(name: 'admin_notes')  String? adminNotes, @JsonKey(name: 'created_at')  String? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _LessonPlan() when $default != null:
return $default(_that.id,_that.title,_that.status,_that.subjectName,_that.className,_that.teacherName,_that.academicYear,_that.semester,_that.notes,_that.adminNotes,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LessonPlan extends LessonPlan {
  const _LessonPlan({required this.id, required this.title, this.status = '', @JsonKey(name: 'subject_name') this.subjectName, @JsonKey(name: 'class_name') this.className, @JsonKey(name: 'teacher_name') this.teacherName, @JsonKey(name: 'academic_year') this.academicYear, this.semester, this.notes, @JsonKey(name: 'admin_notes') this.adminNotes, @JsonKey(name: 'created_at') this.createdAt}): super._();
  factory _LessonPlan.fromJson(Map<String, dynamic> json) => _$LessonPlanFromJson(json);

@override final  String id;
@override final  String title;
@override@JsonKey() final  String status;
@override@JsonKey(name: 'subject_name') final  String? subjectName;
@override@JsonKey(name: 'class_name') final  String? className;
@override@JsonKey(name: 'teacher_name') final  String? teacherName;
@override@JsonKey(name: 'academic_year') final  String? academicYear;
@override final  String? semester;
@override final  String? notes;
@override@JsonKey(name: 'admin_notes') final  String? adminNotes;
@override@JsonKey(name: 'created_at') final  String? createdAt;

/// Create a copy of LessonPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LessonPlanCopyWith<_LessonPlan> get copyWith => __$LessonPlanCopyWithImpl<_LessonPlan>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LessonPlanToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LessonPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.status, status) || other.status == status)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.className, className) || other.className == className)&&(identical(other.teacherName, teacherName) || other.teacherName == teacherName)&&(identical(other.academicYear, academicYear) || other.academicYear == academicYear)&&(identical(other.semester, semester) || other.semester == semester)&&(identical(other.notes, notes) || other.notes == notes)&&(identical(other.adminNotes, adminNotes) || other.adminNotes == adminNotes)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,status,subjectName,className,teacherName,academicYear,semester,notes,adminNotes,createdAt);

@override
String toString() {
  return 'LessonPlan(id: $id, title: $title, status: $status, subjectName: $subjectName, className: $className, teacherName: $teacherName, academicYear: $academicYear, semester: $semester, notes: $notes, adminNotes: $adminNotes, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$LessonPlanCopyWith<$Res> implements $LessonPlanCopyWith<$Res> {
  factory _$LessonPlanCopyWith(_LessonPlan value, $Res Function(_LessonPlan) _then) = __$LessonPlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String status,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'class_name') String? className,@JsonKey(name: 'teacher_name') String? teacherName,@JsonKey(name: 'academic_year') String? academicYear, String? semester, String? notes,@JsonKey(name: 'admin_notes') String? adminNotes,@JsonKey(name: 'created_at') String? createdAt
});




}
/// @nodoc
class __$LessonPlanCopyWithImpl<$Res>
    implements _$LessonPlanCopyWith<$Res> {
  __$LessonPlanCopyWithImpl(this._self, this._then);

  final _LessonPlan _self;
  final $Res Function(_LessonPlan) _then;

/// Create a copy of LessonPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? status = null,Object? subjectName = freezed,Object? className = freezed,Object? teacherName = freezed,Object? academicYear = freezed,Object? semester = freezed,Object? notes = freezed,Object? adminNotes = freezed,Object? createdAt = freezed,}) {
  return _then(_LessonPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,className: freezed == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String?,teacherName: freezed == teacherName ? _self.teacherName : teacherName // ignore: cast_nullable_to_non_nullable
as String?,academicYear: freezed == academicYear ? _self.academicYear : academicYear // ignore: cast_nullable_to_non_nullable
as String?,semester: freezed == semester ? _self.semester : semester // ignore: cast_nullable_to_non_nullable
as String?,notes: freezed == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String?,adminNotes: freezed == adminNotes ? _self.adminNotes : adminNotes // ignore: cast_nullable_to_non_nullable
as String?,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
