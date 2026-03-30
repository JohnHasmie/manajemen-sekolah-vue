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

Student _$StudentFromJson(Map<String, dynamic> json) {
  return _Student.fromJson(json);
}

/// @nodoc
mixin _$Student {
  String get id => throw _privateConstructorUsedError;
  String get name => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_name')
  String get className => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_number')
  String get studentNumber => throw _privateConstructorUsedError;
  String get address => throw _privateConstructorUsedError;
  @JsonKey(name: 'guardian_name')
  String get guardianName => throw _privateConstructorUsedError;
  @JsonKey(name: 'phone_number')
  String get phoneNumber => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String? get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_class_id')
  String? get studentClassId => throw _privateConstructorUsedError;

  /// Serializes this Student to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

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
    @JsonKey(name: 'class_name') String className,
    @JsonKey(name: 'student_number') String studentNumber,
    String address,
    @JsonKey(name: 'guardian_name') String guardianName,
    @JsonKey(name: 'phone_number') String phoneNumber,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'student_class_id') String? studentClassId,
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
    @JsonKey(name: 'class_name') String className,
    @JsonKey(name: 'student_number') String studentNumber,
    String address,
    @JsonKey(name: 'guardian_name') String guardianName,
    @JsonKey(name: 'phone_number') String phoneNumber,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'student_class_id') String? studentClassId,
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
@JsonSerializable()
class _$StudentImpl extends _Student {
  const _$StudentImpl({
    required this.id,
    required this.name,
    @JsonKey(name: 'class_name') required this.className,
    @JsonKey(name: 'student_number') required this.studentNumber,
    required this.address,
    @JsonKey(name: 'guardian_name') required this.guardianName,
    @JsonKey(name: 'phone_number') required this.phoneNumber,
    @JsonKey(name: 'class_id') this.classId,
    @JsonKey(name: 'student_class_id') this.studentClassId,
  }) : super._();

  factory _$StudentImpl.fromJson(Map<String, dynamic> json) =>
      _$$StudentImplFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  @JsonKey(name: 'class_name')
  final String className;
  @override
  @JsonKey(name: 'student_number')
  final String studentNumber;
  @override
  final String address;
  @override
  @JsonKey(name: 'guardian_name')
  final String guardianName;
  @override
  @JsonKey(name: 'phone_number')
  final String phoneNumber;
  @override
  @JsonKey(name: 'class_id')
  final String? classId;
  @override
  @JsonKey(name: 'student_class_id')
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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

  @override
  Map<String, dynamic> toJson() {
    return _$$StudentImplToJson(this);
  }
}

abstract class _Student extends Student {
  const factory _Student({
    required final String id,
    required final String name,
    @JsonKey(name: 'class_name') required final String className,
    @JsonKey(name: 'student_number') required final String studentNumber,
    required final String address,
    @JsonKey(name: 'guardian_name') required final String guardianName,
    @JsonKey(name: 'phone_number') required final String phoneNumber,
    @JsonKey(name: 'class_id') final String? classId,
    @JsonKey(name: 'student_class_id') final String? studentClassId,
  }) = _$StudentImpl;
  const _Student._() : super._();

  factory _Student.fromJson(Map<String, dynamic> json) = _$StudentImpl.fromJson;

  @override
  String get id;
  @override
  String get name;
  @override
  @JsonKey(name: 'class_name')
  String get className;
  @override
  @JsonKey(name: 'student_number')
  String get studentNumber;
  @override
  String get address;
  @override
  @JsonKey(name: 'guardian_name')
  String get guardianName;
  @override
  @JsonKey(name: 'phone_number')
  String get phoneNumber;
  @override
  @JsonKey(name: 'class_id')
  String? get classId;
  @override
  @JsonKey(name: 'student_class_id')
  String? get studentClassId;

  /// Create a copy of Student
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$StudentImplCopyWith<_$StudentImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
