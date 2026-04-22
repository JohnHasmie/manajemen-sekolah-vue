// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teacher.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Teacher {

 String get id; String get name; String get email; String get role;@JsonKey(name: 'employee_number') String? get employeeNumber;@JsonKey(name: 'phone_number') String? get phoneNumber; String? get address;@JsonKey(name: 'homeroom_class_id') String? get homeroomClassId;@JsonKey(name: 'homeroom_class_name') String? get homeroomClassName;@JsonKey(name: 'subject_ids') List<String>? get subjectIds;@JsonKey(name: 'subject_names') List<String>? get subjectNames;@JsonKey(name: 'user_id') String? get userId;
/// Create a copy of Teacher
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeacherCopyWith<Teacher> get copyWith => _$TeacherCopyWithImpl<Teacher>(this as Teacher, _$identity);

  /// Serializes this Teacher to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Teacher&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.employeeNumber, employeeNumber) || other.employeeNumber == employeeNumber)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.homeroomClassId, homeroomClassId) || other.homeroomClassId == homeroomClassId)&&(identical(other.homeroomClassName, homeroomClassName) || other.homeroomClassName == homeroomClassName)&&const DeepCollectionEquality().equals(other.subjectIds, subjectIds)&&const DeepCollectionEquality().equals(other.subjectNames, subjectNames)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,role,employeeNumber,phoneNumber,address,homeroomClassId,homeroomClassName,const DeepCollectionEquality().hash(subjectIds),const DeepCollectionEquality().hash(subjectNames),userId);

@override
String toString() {
  return 'Teacher(id: $id, name: $name, email: $email, role: $role, employeeNumber: $employeeNumber, phoneNumber: $phoneNumber, address: $address, homeroomClassId: $homeroomClassId, homeroomClassName: $homeroomClassName, subjectIds: $subjectIds, subjectNames: $subjectNames, userId: $userId)';
}


}

/// @nodoc
abstract mixin class $TeacherCopyWith<$Res>  {
  factory $TeacherCopyWith(Teacher value, $Res Function(Teacher) _then) = _$TeacherCopyWithImpl;
@useResult
$Res call({
 String id, String name, String email, String role,@JsonKey(name: 'employee_number') String? employeeNumber,@JsonKey(name: 'phone_number') String? phoneNumber, String? address,@JsonKey(name: 'homeroom_class_id') String? homeroomClassId,@JsonKey(name: 'homeroom_class_name') String? homeroomClassName,@JsonKey(name: 'subject_ids') List<String>? subjectIds,@JsonKey(name: 'subject_names') List<String>? subjectNames,@JsonKey(name: 'user_id') String? userId
});




}
/// @nodoc
class _$TeacherCopyWithImpl<$Res>
    implements $TeacherCopyWith<$Res> {
  _$TeacherCopyWithImpl(this._self, this._then);

  final Teacher _self;
  final $Res Function(Teacher) _then;

/// Create a copy of Teacher
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? email = null,Object? role = null,Object? employeeNumber = freezed,Object? phoneNumber = freezed,Object? address = freezed,Object? homeroomClassId = freezed,Object? homeroomClassName = freezed,Object? subjectIds = freezed,Object? subjectNames = freezed,Object? userId = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,employeeNumber: freezed == employeeNumber ? _self.employeeNumber : employeeNumber // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,homeroomClassId: freezed == homeroomClassId ? _self.homeroomClassId : homeroomClassId // ignore: cast_nullable_to_non_nullable
as String?,homeroomClassName: freezed == homeroomClassName ? _self.homeroomClassName : homeroomClassName // ignore: cast_nullable_to_non_nullable
as String?,subjectIds: freezed == subjectIds ? _self.subjectIds : subjectIds // ignore: cast_nullable_to_non_nullable
as List<String>?,subjectNames: freezed == subjectNames ? _self.subjectNames : subjectNames // ignore: cast_nullable_to_non_nullable
as List<String>?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Teacher].
extension TeacherPatterns on Teacher {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Teacher value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Teacher() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Teacher value)  $default,){
final _that = this;
switch (_that) {
case _Teacher():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Teacher value)?  $default,){
final _that = this;
switch (_that) {
case _Teacher() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String role, @JsonKey(name: 'employee_number')  String? employeeNumber, @JsonKey(name: 'phone_number')  String? phoneNumber,  String? address, @JsonKey(name: 'homeroom_class_id')  String? homeroomClassId, @JsonKey(name: 'homeroom_class_name')  String? homeroomClassName, @JsonKey(name: 'subject_ids')  List<String>? subjectIds, @JsonKey(name: 'subject_names')  List<String>? subjectNames, @JsonKey(name: 'user_id')  String? userId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Teacher() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.role,_that.employeeNumber,_that.phoneNumber,_that.address,_that.homeroomClassId,_that.homeroomClassName,_that.subjectIds,_that.subjectNames,_that.userId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String email,  String role, @JsonKey(name: 'employee_number')  String? employeeNumber, @JsonKey(name: 'phone_number')  String? phoneNumber,  String? address, @JsonKey(name: 'homeroom_class_id')  String? homeroomClassId, @JsonKey(name: 'homeroom_class_name')  String? homeroomClassName, @JsonKey(name: 'subject_ids')  List<String>? subjectIds, @JsonKey(name: 'subject_names')  List<String>? subjectNames, @JsonKey(name: 'user_id')  String? userId)  $default,) {final _that = this;
switch (_that) {
case _Teacher():
return $default(_that.id,_that.name,_that.email,_that.role,_that.employeeNumber,_that.phoneNumber,_that.address,_that.homeroomClassId,_that.homeroomClassName,_that.subjectIds,_that.subjectNames,_that.userId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String email,  String role, @JsonKey(name: 'employee_number')  String? employeeNumber, @JsonKey(name: 'phone_number')  String? phoneNumber,  String? address, @JsonKey(name: 'homeroom_class_id')  String? homeroomClassId, @JsonKey(name: 'homeroom_class_name')  String? homeroomClassName, @JsonKey(name: 'subject_ids')  List<String>? subjectIds, @JsonKey(name: 'subject_names')  List<String>? subjectNames, @JsonKey(name: 'user_id')  String? userId)?  $default,) {final _that = this;
switch (_that) {
case _Teacher() when $default != null:
return $default(_that.id,_that.name,_that.email,_that.role,_that.employeeNumber,_that.phoneNumber,_that.address,_that.homeroomClassId,_that.homeroomClassName,_that.subjectIds,_that.subjectNames,_that.userId);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Teacher extends Teacher {
  const _Teacher({required this.id, required this.name, required this.email, required this.role, @JsonKey(name: 'employee_number') this.employeeNumber, @JsonKey(name: 'phone_number') this.phoneNumber, this.address, @JsonKey(name: 'homeroom_class_id') this.homeroomClassId, @JsonKey(name: 'homeroom_class_name') this.homeroomClassName, @JsonKey(name: 'subject_ids') final  List<String>? subjectIds, @JsonKey(name: 'subject_names') final  List<String>? subjectNames, @JsonKey(name: 'user_id') this.userId}): _subjectIds = subjectIds,_subjectNames = subjectNames,super._();
  factory _Teacher.fromJson(Map<String, dynamic> json) => _$TeacherFromJson(json);

@override final  String id;
@override final  String name;
@override final  String email;
@override final  String role;
@override@JsonKey(name: 'employee_number') final  String? employeeNumber;
@override@JsonKey(name: 'phone_number') final  String? phoneNumber;
@override final  String? address;
@override@JsonKey(name: 'homeroom_class_id') final  String? homeroomClassId;
@override@JsonKey(name: 'homeroom_class_name') final  String? homeroomClassName;
 final  List<String>? _subjectIds;
@override@JsonKey(name: 'subject_ids') List<String>? get subjectIds {
  final value = _subjectIds;
  if (value == null) return null;
  if (_subjectIds is EqualUnmodifiableListView) return _subjectIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

 final  List<String>? _subjectNames;
@override@JsonKey(name: 'subject_names') List<String>? get subjectNames {
  final value = _subjectNames;
  if (value == null) return null;
  if (_subjectNames is EqualUnmodifiableListView) return _subjectNames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override@JsonKey(name: 'user_id') final  String? userId;

/// Create a copy of Teacher
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeacherCopyWith<_Teacher> get copyWith => __$TeacherCopyWithImpl<_Teacher>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TeacherToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Teacher&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.email, email) || other.email == email)&&(identical(other.role, role) || other.role == role)&&(identical(other.employeeNumber, employeeNumber) || other.employeeNumber == employeeNumber)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.homeroomClassId, homeroomClassId) || other.homeroomClassId == homeroomClassId)&&(identical(other.homeroomClassName, homeroomClassName) || other.homeroomClassName == homeroomClassName)&&const DeepCollectionEquality().equals(other._subjectIds, _subjectIds)&&const DeepCollectionEquality().equals(other._subjectNames, _subjectNames)&&(identical(other.userId, userId) || other.userId == userId));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,email,role,employeeNumber,phoneNumber,address,homeroomClassId,homeroomClassName,const DeepCollectionEquality().hash(_subjectIds),const DeepCollectionEquality().hash(_subjectNames),userId);

@override
String toString() {
  return 'Teacher(id: $id, name: $name, email: $email, role: $role, employeeNumber: $employeeNumber, phoneNumber: $phoneNumber, address: $address, homeroomClassId: $homeroomClassId, homeroomClassName: $homeroomClassName, subjectIds: $subjectIds, subjectNames: $subjectNames, userId: $userId)';
}


}

/// @nodoc
abstract mixin class _$TeacherCopyWith<$Res> implements $TeacherCopyWith<$Res> {
  factory _$TeacherCopyWith(_Teacher value, $Res Function(_Teacher) _then) = __$TeacherCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String email, String role,@JsonKey(name: 'employee_number') String? employeeNumber,@JsonKey(name: 'phone_number') String? phoneNumber, String? address,@JsonKey(name: 'homeroom_class_id') String? homeroomClassId,@JsonKey(name: 'homeroom_class_name') String? homeroomClassName,@JsonKey(name: 'subject_ids') List<String>? subjectIds,@JsonKey(name: 'subject_names') List<String>? subjectNames,@JsonKey(name: 'user_id') String? userId
});




}
/// @nodoc
class __$TeacherCopyWithImpl<$Res>
    implements _$TeacherCopyWith<$Res> {
  __$TeacherCopyWithImpl(this._self, this._then);

  final _Teacher _self;
  final $Res Function(_Teacher) _then;

/// Create a copy of Teacher
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? email = null,Object? role = null,Object? employeeNumber = freezed,Object? phoneNumber = freezed,Object? address = freezed,Object? homeroomClassId = freezed,Object? homeroomClassName = freezed,Object? subjectIds = freezed,Object? subjectNames = freezed,Object? userId = freezed,}) {
  return _then(_Teacher(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,employeeNumber: freezed == employeeNumber ? _self.employeeNumber : employeeNumber // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
as String?,homeroomClassId: freezed == homeroomClassId ? _self.homeroomClassId : homeroomClassId // ignore: cast_nullable_to_non_nullable
as String?,homeroomClassName: freezed == homeroomClassName ? _self.homeroomClassName : homeroomClassName // ignore: cast_nullable_to_non_nullable
as String?,subjectIds: freezed == subjectIds ? _self._subjectIds : subjectIds // ignore: cast_nullable_to_non_nullable
as List<String>?,subjectNames: freezed == subjectNames ? _self._subjectNames : subjectNames // ignore: cast_nullable_to_non_nullable
as List<String>?,userId: freezed == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
