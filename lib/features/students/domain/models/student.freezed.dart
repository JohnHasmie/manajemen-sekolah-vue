// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'student.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$Student {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  String get className => throw _privateConstructorUsedError;
  String get studentNumber => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  String get guardianName => throw _privateConstructorUsedError;
  String get phoneNumber => throw _privateConstructorUsedError;
  String? get classId => throw _privateConstructorUsedError;
  String? get studentClassId => throw _privateConstructorUsedError;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $StudentCopyWith<Student> get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $StudentCopyWith<$Res> {
  factory $StudentCopyWith(Student value, $Res Function(Student) then) =
      _$StudentCopyWithImpl<$Res, Student>;
  @useResult
  $Res call({
    String id,
    String name,
    String className,
    String studentNumber,
    String address,
    String guardianName,
    String phoneNumber,
    String? classId,
    String? studentClassId,
  });
}

/// @nodoc
class _$StudentCopyWithImpl<$Res, $Val extends Student>
    implements $StudentCopyWith<$Res> {
  _$StudentCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? className = null,
    Object? studentNumber = null,
    Object? address = null,
    Object? guardianName = null,
    Object? phoneNumber = null,
    Object? classId = freezed,
    Object? studentClassId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            name: null == name
                ? _value.name
                : name // ignore: cast_nullable_to_non_nullable
                      as String,
            className: null == className
                ? _value.className
                : className // ignore: cast_nullable_to_non_nullable
                      as String,
            studentNumber: null == studentNumber
                ? _value.studentNumber
                : studentNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            address: null == address
                ? _value.address
                : address // ignore: cast_nullable_to_non_nullable
                      as String,
            guardianName: null == guardianName
                ? _value.guardianName
                : guardianName // ignore: cast_nullable_to_non_nullable
                      as String,
            phoneNumber: null == phoneNumber
                ? _value.phoneNumber
                : phoneNumber // ignore: cast_nullable_to_non_nullable
                      as String,
            classId: freezed == classId
                ? _value.classId
                : classId // ignore: cast_nullable_to_non_nullable
                      as String?,
            studentClassId: freezed == studentClassId
                ? _value.studentClassId
                : studentClassId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$StudentImplCopyWith<$Res> implements $StudentCopyWith<$Res> {
  factory _$$StudentImplCopyWith(
    _$StudentImpl value,
    $Res Function(_$StudentImpl) then,
  ) = __$$StudentImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String name,
    String className,
    String studentNumber,
    String address,
    String guardianName,
    String phoneNumber,
    String? classId,
    String? studentClassId,
  });
}

/// @nodoc
class __$$StudentImplCopyWithImpl<$Res>
    extends _$StudentCopyWithImpl<$Res, _$StudentImpl>
    implements _$$StudentImplCopyWith<$Res> {
  __$$StudentImplCopyWithImpl(
    _$StudentImpl _value,
    $Res Function(_$StudentImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? className = null,
    Object? studentNumber = null,
    Object? address = null,
    Object? guardianName = null,
    Object? phoneNumber = null,
    Object? classId = freezed,
    Object? studentClassId = freezed,
  }) {
    return _then(
      _$StudentImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        name: null == name
            ? _value.name
            : name // ignore: cast_nullable_to_non_nullable
                  as String,
        className: null == className
            ? _value.className
            : className // ignore: cast_nullable_to_non_nullable
                  as String,
        studentNumber: null == studentNumber
            ? _value.studentNumber
            : studentNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        address: null == address
            ? _value.address
            : address // ignore: cast_nullable_to_non_nullable
                  as String,
        guardianName: null == guardianName
            ? _value.guardianName
            : guardianName // ignore: cast_nullable_to_non_nullable
                  as String,
        phoneNumber: null == phoneNumber
            ? _value.phoneNumber
            : phoneNumber // ignore: cast_nullable_to_non_nullable
                  as String,
        classId: freezed == classId
            ? _value.classId
            : classId // ignore: cast_nullable_to_non_nullable
                  as String?,
        studentClassId: freezed == studentClassId
            ? _value.studentClassId
            : studentClassId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc

class _$StudentImpl extends _Student {
  const _$StudentImpl({
    required this.id,
    this.name = '',
    this.className = '',
    this.studentNumber = '',
    this.address = '',
    this.guardianName = '',
    this.phoneNumber = '',
    this.classId,
    this.studentClassId,
  }) : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String className;
  @override
  @JsonKey()
  final String studentNumber;
  @override
  @JsonKey()
  final String address;
  @override
  @JsonKey()
  final String guardianName;
  @override
  @JsonKey()
  final String phoneNumber;
  @override
  final String? classId;
  @override
  final String? studentClassId;

  @override
  String toString() {
    return 'Student(id: $id, name: $name, className: $className, studentNumber: $studentNumber, address: $address, guardianName: $guardianName, phoneNumber: $phoneNumber, classId: $classId, studentClassId: $studentClassId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$StudentImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.className, className) ||
                other.className == className) &&
            (identical(other.studentNumber, studentNumber) ||
                other.studentNumber == studentNumber) &&
            (identical(other.address, address) || other.address == address) &&
            (identical(other.guardianName, guardianName) ||
                other.guardianName == guardianName) &&
            (identical(other.phoneNumber, phoneNumber) ||
                other.phoneNumber == phoneNumber) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.studentClassId, studentClassId) ||
                other.studentClassId == studentClassId));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    name,
    className,
    studentNumber,
    address,
    guardianName,
    phoneNumber,
    classId,
    studentClassId,
  );

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$StudentImplCopyWith<_$StudentImpl> get copyWith =>
      __$$StudentImplCopyWithImpl<_$StudentImpl>(this, _$identity);
}

abstract class _Student extends Student {
  const factory _Student({
    required final String id,
    final String name,
    final String className,
    final String studentNumber,
    final String address,
    final String guardianName,
    final String phoneNumber,
    final String? classId,
    final String? studentClassId,
  }) = _$StudentImpl;
  const _Student._() : super._();

  @override
  String get id;
  @override
  String get name;
  @override
  String get className;
  @override
  String get studentNumber;
  @override
  String get address;
  @override
  String get guardianName;
  @override
  String get phoneNumber;
  @override
  String? get classId;
  @override
  String? get studentClassId;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentImplCopyWith<_$StudentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
