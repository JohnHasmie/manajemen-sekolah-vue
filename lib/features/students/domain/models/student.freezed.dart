// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'student.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Student {

 String get id; String get name;@JsonKey(name: 'class_name') String get className;@JsonKey(name: 'student_number') String get studentNumber; String get address;@JsonKey(name: 'guardian_name') String get guardianName;@JsonKey(name: 'phone_number') String get phoneNumber;@JsonKey(name: 'class_id') String? get classId;@JsonKey(name: 'student_class_id') String? get studentClassId;
/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StudentCopyWith<Student> get copyWith => _$StudentCopyWithImpl<Student>(this as Student, _$identity);

  /// Serializes this Student to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Student&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.className, className) || other.className == className)&&(identical(other.studentNumber, studentNumber) || other.studentNumber == studentNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.guardianName, guardianName) || other.guardianName == guardianName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.studentClassId, studentClassId) || other.studentClassId == studentClassId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,className,studentNumber,address,guardianName,phoneNumber,classId,studentClassId);

@override
String toString() {
  return 'Student(id: $id, name: $name, className: $className, studentNumber: $studentNumber, address: $address, guardianName: $guardianName, phoneNumber: $phoneNumber, classId: $classId, studentClassId: $studentClassId)';
}


}

/// @nodoc
abstract mixin class $StudentCopyWith<$Res>  {
  factory $StudentCopyWith(Student value, $Res Function(Student) _then) = _$StudentCopyWithImpl;
@useResult
$Res call({
 String id, String name,@JsonKey(name: 'class_name') String className,@JsonKey(name: 'student_number') String studentNumber, String address,@JsonKey(name: 'guardian_name') String guardianName,@JsonKey(name: 'phone_number') String phoneNumber,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'student_class_id') String? studentClassId
});




}
/// @nodoc
class _$StudentCopyWithImpl<$Res>
    implements $StudentCopyWith<$Res> {
  _$StudentCopyWithImpl(this._self, this._then);

  final Student _self;
  final $Res Function(Student) _then;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? className = null,Object? studentNumber = null,Object? address = null,Object? guardianName = null,Object? phoneNumber = null,Object? classId = freezed,Object? studentClassId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,className: null == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String,studentNumber: null == studentNumber ? _self.studentNumber : studentNumber // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,guardianName: null == guardianName ? _self.guardianName : guardianName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,studentClassId: freezed == studentClassId ? _self.studentClassId : studentClassId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Student].
extension StudentPatterns on Student {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Student value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Student() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Student value)  $default,){
final _that = this;
switch (_that) {
case _Student():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Student value)?  $default,){
final _that = this;
switch (_that) {
case _Student() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'class_name')  String className, @JsonKey(name: 'student_number')  String studentNumber,  String address, @JsonKey(name: 'guardian_name')  String guardianName, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'student_class_id')  String? studentClassId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Student() when $default != null:
return $default(_that.id,_that.name,_that.className,_that.studentNumber,_that.address,_that.guardianName,_that.phoneNumber,_that.classId,_that.studentClassId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name, @JsonKey(name: 'class_name')  String className, @JsonKey(name: 'student_number')  String studentNumber,  String address, @JsonKey(name: 'guardian_name')  String guardianName, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'student_class_id')  String? studentClassId)  $default,) {final _that = this;
switch (_that) {
case _Student():
return $default(_that.id,_that.name,_that.className,_that.studentNumber,_that.address,_that.guardianName,_that.phoneNumber,_that.classId,_that.studentClassId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name, @JsonKey(name: 'class_name')  String className, @JsonKey(name: 'student_number')  String studentNumber,  String address, @JsonKey(name: 'guardian_name')  String guardianName, @JsonKey(name: 'phone_number')  String phoneNumber, @JsonKey(name: 'class_id')  String? classId, @JsonKey(name: 'student_class_id')  String? studentClassId)?  $default,) {final _that = this;
switch (_that) {
case _Student() when $default != null:
return $default(_that.id,_that.name,_that.className,_that.studentNumber,_that.address,_that.guardianName,_that.phoneNumber,_that.classId,_that.studentClassId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Student extends Student {
  const _Student({required this.id, required this.name, @JsonKey(name: 'class_name') required this.className, @JsonKey(name: 'student_number') required this.studentNumber, required this.address, @JsonKey(name: 'guardian_name') required this.guardianName, @JsonKey(name: 'phone_number') required this.phoneNumber, @JsonKey(name: 'class_id') this.classId, @JsonKey(name: 'student_class_id') this.studentClassId}): super._();
  factory _Student.fromJson(Map<String, dynamic> json) => _$StudentFromJson(json);

@override final  String id;
@override final  String name;
@override@JsonKey(name: 'class_name') final  String className;
@override@JsonKey(name: 'student_number') final  String studentNumber;
@override final  String address;
@override@JsonKey(name: 'guardian_name') final  String guardianName;
@override@JsonKey(name: 'phone_number') final  String phoneNumber;
@override@JsonKey(name: 'class_id') final  String? classId;
@override@JsonKey(name: 'student_class_id') final  String? studentClassId;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StudentCopyWith<_Student> get copyWith => __$StudentCopyWithImpl<_Student>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StudentToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Student&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.className, className) || other.className == className)&&(identical(other.studentNumber, studentNumber) || other.studentNumber == studentNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.guardianName, guardianName) || other.guardianName == guardianName)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.classId, classId) || other.classId == classId)&&(identical(other.studentClassId, studentClassId) || other.studentClassId == studentClassId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,className,studentNumber,address,guardianName,phoneNumber,classId,studentClassId);

@override
String toString() {
  return 'Student(id: $id, name: $name, className: $className, studentNumber: $studentNumber, address: $address, guardianName: $guardianName, phoneNumber: $phoneNumber, classId: $classId, studentClassId: $studentClassId)';
}


}

/// @nodoc
abstract mixin class _$StudentCopyWith<$Res> implements $StudentCopyWith<$Res> {
  factory _$StudentCopyWith(_Student value, $Res Function(_Student) _then) = __$StudentCopyWithImpl;
@override @useResult
$Res call({
 String id, String name,@JsonKey(name: 'class_name') String className,@JsonKey(name: 'student_number') String studentNumber, String address,@JsonKey(name: 'guardian_name') String guardianName,@JsonKey(name: 'phone_number') String phoneNumber,@JsonKey(name: 'class_id') String? classId,@JsonKey(name: 'student_class_id') String? studentClassId
});




}
/// @nodoc
class __$StudentCopyWithImpl<$Res>
    implements _$StudentCopyWith<$Res> {
  __$StudentCopyWithImpl(this._self, this._then);

  final _Student _self;
  final $Res Function(_Student) _then;

/// Create a copy of Student
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? className = null,Object? studentNumber = null,Object? address = null,Object? guardianName = null,Object? phoneNumber = null,Object? classId = freezed,Object? studentClassId = freezed,}) {
  return _then(_Student(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,className: null == className ? _self.className : className // ignore: cast_nullable_to_non_nullable
as String,studentNumber: null == studentNumber ? _self.studentNumber : studentNumber // ignore: cast_nullable_to_non_nullable
as String,address: null == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String,guardianName: null == guardianName ? _self.guardianName : guardianName // ignore: cast_nullable_to_non_nullable
as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String,classId: freezed == classId ? _self.classId : classId // ignore: cast_nullable_to_non_nullable
as String?,studentClassId: freezed == studentClassId ? _self.studentClassId : studentClassId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
