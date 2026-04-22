// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AttendanceSummary {

@JsonKey(name: 'id') String? get id;@JsonKey(name: 'date') DateTime get date; int get present; int get sick; int get excused; int get absent;@JsonKey(name: 'total_students') int get totalStudents;@JsonKey(name: 'subject_name') String? get subjectName;@JsonKey(name: 'subject_id') String? get subjectId;
/// Create a copy of AttendanceSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AttendanceSummaryCopyWith<AttendanceSummary> get copyWith => _$AttendanceSummaryCopyWithImpl<AttendanceSummary>(this as AttendanceSummary, _$identity);

  /// Serializes this AttendanceSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AttendanceSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.present, present) || other.present == present)&&(identical(other.sick, sick) || other.sick == sick)&&(identical(other.excused, excused) || other.excused == excused)&&(identical(other.absent, absent) || other.absent == absent)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,present,sick,excused,absent,totalStudents,subjectName,subjectId);

@override
String toString() {
  return 'AttendanceSummary(id: $id, date: $date, present: $present, sick: $sick, excused: $excused, absent: $absent, totalStudents: $totalStudents, subjectName: $subjectName, subjectId: $subjectId)';
}


}

/// @nodoc
abstract mixin class $AttendanceSummaryCopyWith<$Res>  {
  factory $AttendanceSummaryCopyWith(AttendanceSummary value, $Res Function(AttendanceSummary) _then) = _$AttendanceSummaryCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'id') String? id,@JsonKey(name: 'date') DateTime date, int present, int sick, int excused, int absent,@JsonKey(name: 'total_students') int totalStudents,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'subject_id') String? subjectId
});




}
/// @nodoc
class _$AttendanceSummaryCopyWithImpl<$Res>
    implements $AttendanceSummaryCopyWith<$Res> {
  _$AttendanceSummaryCopyWithImpl(this._self, this._then);

  final AttendanceSummary _self;
  final $Res Function(AttendanceSummary) _then;

/// Create a copy of AttendanceSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? date = null,Object? present = null,Object? sick = null,Object? excused = null,Object? absent = null,Object? totalStudents = null,Object? subjectName = freezed,Object? subjectId = freezed,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as int,sick: null == sick ? _self.sick : sick // ignore: cast_nullable_to_non_nullable
as int,excused: null == excused ? _self.excused : excused // ignore: cast_nullable_to_non_nullable
as int,absent: null == absent ? _self.absent : absent // ignore: cast_nullable_to_non_nullable
as int,totalStudents: null == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AttendanceSummary].
extension AttendanceSummaryPatterns on AttendanceSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AttendanceSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AttendanceSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AttendanceSummary value)  $default,){
final _that = this;
switch (_that) {
case _AttendanceSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AttendanceSummary value)?  $default,){
final _that = this;
switch (_that) {
case _AttendanceSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'id')  String? id, @JsonKey(name: 'date')  DateTime date,  int present,  int sick,  int excused,  int absent, @JsonKey(name: 'total_students')  int totalStudents, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AttendanceSummary() when $default != null:
return $default(_that.id,_that.date,_that.present,_that.sick,_that.excused,_that.absent,_that.totalStudents,_that.subjectName,_that.subjectId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'id')  String? id, @JsonKey(name: 'date')  DateTime date,  int present,  int sick,  int excused,  int absent, @JsonKey(name: 'total_students')  int totalStudents, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId)  $default,) {final _that = this;
switch (_that) {
case _AttendanceSummary():
return $default(_that.id,_that.date,_that.present,_that.sick,_that.excused,_that.absent,_that.totalStudents,_that.subjectName,_that.subjectId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'id')  String? id, @JsonKey(name: 'date')  DateTime date,  int present,  int sick,  int excused,  int absent, @JsonKey(name: 'total_students')  int totalStudents, @JsonKey(name: 'subject_name')  String? subjectName, @JsonKey(name: 'subject_id')  String? subjectId)?  $default,) {final _that = this;
switch (_that) {
case _AttendanceSummary() when $default != null:
return $default(_that.id,_that.date,_that.present,_that.sick,_that.excused,_that.absent,_that.totalStudents,_that.subjectName,_that.subjectId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AttendanceSummary implements AttendanceSummary {
  const _AttendanceSummary({@JsonKey(name: 'id') this.id, @JsonKey(name: 'date') required this.date, this.present = 0, this.sick = 0, this.excused = 0, this.absent = 0, @JsonKey(name: 'total_students') this.totalStudents = 0, @JsonKey(name: 'subject_name') this.subjectName, @JsonKey(name: 'subject_id') this.subjectId});
  factory _AttendanceSummary.fromJson(Map<String, dynamic> json) => _$AttendanceSummaryFromJson(json);

@override@JsonKey(name: 'id') final  String? id;
@override@JsonKey(name: 'date') final  DateTime date;
@override@JsonKey() final  int present;
@override@JsonKey() final  int sick;
@override@JsonKey() final  int excused;
@override@JsonKey() final  int absent;
@override@JsonKey(name: 'total_students') final  int totalStudents;
@override@JsonKey(name: 'subject_name') final  String? subjectName;
@override@JsonKey(name: 'subject_id') final  String? subjectId;

/// Create a copy of AttendanceSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AttendanceSummaryCopyWith<_AttendanceSummary> get copyWith => __$AttendanceSummaryCopyWithImpl<_AttendanceSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AttendanceSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AttendanceSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.date, date) || other.date == date)&&(identical(other.present, present) || other.present == present)&&(identical(other.sick, sick) || other.sick == sick)&&(identical(other.excused, excused) || other.excused == excused)&&(identical(other.absent, absent) || other.absent == absent)&&(identical(other.totalStudents, totalStudents) || other.totalStudents == totalStudents)&&(identical(other.subjectName, subjectName) || other.subjectName == subjectName)&&(identical(other.subjectId, subjectId) || other.subjectId == subjectId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,date,present,sick,excused,absent,totalStudents,subjectName,subjectId);

@override
String toString() {
  return 'AttendanceSummary(id: $id, date: $date, present: $present, sick: $sick, excused: $excused, absent: $absent, totalStudents: $totalStudents, subjectName: $subjectName, subjectId: $subjectId)';
}


}

/// @nodoc
abstract mixin class _$AttendanceSummaryCopyWith<$Res> implements $AttendanceSummaryCopyWith<$Res> {
  factory _$AttendanceSummaryCopyWith(_AttendanceSummary value, $Res Function(_AttendanceSummary) _then) = __$AttendanceSummaryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'id') String? id,@JsonKey(name: 'date') DateTime date, int present, int sick, int excused, int absent,@JsonKey(name: 'total_students') int totalStudents,@JsonKey(name: 'subject_name') String? subjectName,@JsonKey(name: 'subject_id') String? subjectId
});




}
/// @nodoc
class __$AttendanceSummaryCopyWithImpl<$Res>
    implements _$AttendanceSummaryCopyWith<$Res> {
  __$AttendanceSummaryCopyWithImpl(this._self, this._then);

  final _AttendanceSummary _self;
  final $Res Function(_AttendanceSummary) _then;

/// Create a copy of AttendanceSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? date = null,Object? present = null,Object? sick = null,Object? excused = null,Object? absent = null,Object? totalStudents = null,Object? subjectName = freezed,Object? subjectId = freezed,}) {
  return _then(_AttendanceSummary(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,present: null == present ? _self.present : present // ignore: cast_nullable_to_non_nullable
as int,sick: null == sick ? _self.sick : sick // ignore: cast_nullable_to_non_nullable
as int,excused: null == excused ? _self.excused : excused // ignore: cast_nullable_to_non_nullable
as int,absent: null == absent ? _self.absent : absent // ignore: cast_nullable_to_non_nullable
as int,totalStudents: null == totalStudents ? _self.totalStudents : totalStudents // ignore: cast_nullable_to_non_nullable
as int,subjectName: freezed == subjectName ? _self.subjectName : subjectName // ignore: cast_nullable_to_non_nullable
as String?,subjectId: freezed == subjectId ? _self.subjectId : subjectId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
