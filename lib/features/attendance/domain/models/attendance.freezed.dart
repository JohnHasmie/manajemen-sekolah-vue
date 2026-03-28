// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

Attendance _$AttendanceFromJson(Map<String, dynamic> json) {
  return _Attendance.fromJson(json);
}

/// @nodoc
mixin _$Attendance {
  String get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'student_id')
  String get studentId => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  String get status => throw _privateConstructorUsedError;
  @JsonKey(name: 'is_read')
  bool get isRead => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_name')
  String? get subjectName => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String? get subjectId => throw _privateConstructorUsedError;
  @JsonKey(name: 'lesson_hour_name')
  String? get lessonHourName => throw _privateConstructorUsedError;
  @JsonKey(name: 'lesson_hour_id')
  String? get lessonHourId => throw _privateConstructorUsedError;
  @JsonKey(name: 'class_id')
  String? get classId => throw _privateConstructorUsedError;
  @JsonKey(name: 'teacher_id')
  String? get teacherId => throw _privateConstructorUsedError;

  /// Serializes this Attendance to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceCopyWith<Attendance> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceCopyWith<$Res> {
  factory $AttendanceCopyWith(
    Attendance value,
    $Res Function(Attendance) then,
  ) = _$AttendanceCopyWithImpl<$Res, Attendance>;
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'student_id') String studentId,
    DateTime date,
    String status,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'lesson_hour_name') String? lessonHourName,
    @JsonKey(name: 'lesson_hour_id') String? lessonHourId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'teacher_id') String? teacherId,
  });
}

/// @nodoc
class _$AttendanceCopyWithImpl<$Res, $Val extends Attendance>
    implements $AttendanceCopyWith<$Res> {
  _$AttendanceCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? date = null,
    Object? status = null,
    Object? isRead = null,
    Object? subjectName = freezed,
    Object? subjectId = freezed,
    Object? lessonHourName = freezed,
    Object? lessonHourId = freezed,
    Object? classId = freezed,
    Object? teacherId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            studentId: null == studentId
                ? _value.studentId
                : studentId // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            status: null == status
                ? _value.status
                : status // ignore: cast_nullable_to_non_nullable
                      as String,
            isRead: null == isRead
                ? _value.isRead
                : isRead // ignore: cast_nullable_to_non_nullable
                      as bool,
            subjectName: freezed == subjectName
                ? _value.subjectName
                : subjectName // ignore: cast_nullable_to_non_nullable
                      as String?,
            subjectId: freezed == subjectId
                ? _value.subjectId
                : subjectId // ignore: cast_nullable_to_non_nullable
                      as String?,
            lessonHourName: freezed == lessonHourName
                ? _value.lessonHourName
                : lessonHourName // ignore: cast_nullable_to_non_nullable
                      as String?,
            lessonHourId: freezed == lessonHourId
                ? _value.lessonHourId
                : lessonHourId // ignore: cast_nullable_to_non_nullable
                      as String?,
            classId: freezed == classId
                ? _value.classId
                : classId // ignore: cast_nullable_to_non_nullable
                      as String?,
            teacherId: freezed == teacherId
                ? _value.teacherId
                : teacherId // ignore: cast_nullable_to_non_nullable
                      as String?,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceImplCopyWith<$Res>
    implements $AttendanceCopyWith<$Res> {
  factory _$$AttendanceImplCopyWith(
    _$AttendanceImpl value,
    $Res Function(_$AttendanceImpl) then,
  ) = __$$AttendanceImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    @JsonKey(name: 'student_id') String studentId,
    DateTime date,
    String status,
    @JsonKey(name: 'is_read') bool isRead,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
    @JsonKey(name: 'lesson_hour_name') String? lessonHourName,
    @JsonKey(name: 'lesson_hour_id') String? lessonHourId,
    @JsonKey(name: 'class_id') String? classId,
    @JsonKey(name: 'teacher_id') String? teacherId,
  });
}

/// @nodoc
class __$$AttendanceImplCopyWithImpl<$Res>
    extends _$AttendanceCopyWithImpl<$Res, _$AttendanceImpl>
    implements _$$AttendanceImplCopyWith<$Res> {
  __$$AttendanceImplCopyWithImpl(
    _$AttendanceImpl _value,
    $Res Function(_$AttendanceImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? studentId = null,
    Object? date = null,
    Object? status = null,
    Object? isRead = null,
    Object? subjectName = freezed,
    Object? subjectId = freezed,
    Object? lessonHourName = freezed,
    Object? lessonHourId = freezed,
    Object? classId = freezed,
    Object? teacherId = freezed,
  }) {
    return _then(
      _$AttendanceImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        studentId: null == studentId
            ? _value.studentId
            : studentId // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        status: null == status
            ? _value.status
            : status // ignore: cast_nullable_to_non_nullable
                  as String,
        isRead: null == isRead
            ? _value.isRead
            : isRead // ignore: cast_nullable_to_non_nullable
                  as bool,
        subjectName: freezed == subjectName
            ? _value.subjectName
            : subjectName // ignore: cast_nullable_to_non_nullable
                  as String?,
        subjectId: freezed == subjectId
            ? _value.subjectId
            : subjectId // ignore: cast_nullable_to_non_nullable
                  as String?,
        lessonHourName: freezed == lessonHourName
            ? _value.lessonHourName
            : lessonHourName // ignore: cast_nullable_to_non_nullable
                  as String?,
        lessonHourId: freezed == lessonHourId
            ? _value.lessonHourId
            : lessonHourId // ignore: cast_nullable_to_non_nullable
                  as String?,
        classId: freezed == classId
            ? _value.classId
            : classId // ignore: cast_nullable_to_non_nullable
                  as String?,
        teacherId: freezed == teacherId
            ? _value.teacherId
            : teacherId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceImpl implements _Attendance {
  const _$AttendanceImpl({
    required this.id,
    @JsonKey(name: 'student_id') required this.studentId,
    required this.date,
    required this.status,
    @JsonKey(name: 'is_read') this.isRead = false,
    @JsonKey(name: 'subject_name') this.subjectName,
    @JsonKey(name: 'subject_id') this.subjectId,
    @JsonKey(name: 'lesson_hour_name') this.lessonHourName,
    @JsonKey(name: 'lesson_hour_id') this.lessonHourId,
    @JsonKey(name: 'class_id') this.classId,
    @JsonKey(name: 'teacher_id') this.teacherId,
  });

  factory _$AttendanceImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceImplFromJson(json);

  @override
  final String id;
  @override
  @JsonKey(name: 'student_id')
  final String studentId;
  @override
  final DateTime date;
  @override
  final String status;
  @override
  @JsonKey(name: 'is_read')
  final bool isRead;
  @override
  @JsonKey(name: 'subject_name')
  final String? subjectName;
  @override
  @JsonKey(name: 'subject_id')
  final String? subjectId;
  @override
  @JsonKey(name: 'lesson_hour_name')
  final String? lessonHourName;
  @override
  @JsonKey(name: 'lesson_hour_id')
  final String? lessonHourId;
  @override
  @JsonKey(name: 'class_id')
  final String? classId;
  @override
  @JsonKey(name: 'teacher_id')
  final String? teacherId;

  @override
  String toString() {
    return 'Attendance(id: $id, studentId: $studentId, date: $date, status: $status, isRead: $isRead, subjectName: $subjectName, subjectId: $subjectId, lessonHourName: $lessonHourName, lessonHourId: $lessonHourId, classId: $classId, teacherId: $teacherId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.studentId, studentId) ||
                other.studentId == studentId) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.lessonHourName, lessonHourName) ||
                other.lessonHourName == lessonHourName) &&
            (identical(other.lessonHourId, lessonHourId) ||
                other.lessonHourId == lessonHourId) &&
            (identical(other.classId, classId) || other.classId == classId) &&
            (identical(other.teacherId, teacherId) ||
                other.teacherId == teacherId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    studentId,
    date,
    status,
    isRead,
    subjectName,
    subjectId,
    lessonHourName,
    lessonHourId,
    classId,
    teacherId,
  );

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceImplCopyWith<_$AttendanceImpl> get copyWith =>
      __$$AttendanceImplCopyWithImpl<_$AttendanceImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceImplToJson(this);
  }
}

abstract class _Attendance implements Attendance {
  const factory _Attendance({
    required final String id,
    @JsonKey(name: 'student_id') required final String studentId,
    required final DateTime date,
    required final String status,
    @JsonKey(name: 'is_read') final bool isRead,
    @JsonKey(name: 'subject_name') final String? subjectName,
    @JsonKey(name: 'subject_id') final String? subjectId,
    @JsonKey(name: 'lesson_hour_name') final String? lessonHourName,
    @JsonKey(name: 'lesson_hour_id') final String? lessonHourId,
    @JsonKey(name: 'class_id') final String? classId,
    @JsonKey(name: 'teacher_id') final String? teacherId,
  }) = _$AttendanceImpl;

  factory _Attendance.fromJson(Map<String, dynamic> json) =
      _$AttendanceImpl.fromJson;

  @override
  String get id;
  @override
  @JsonKey(name: 'student_id')
  String get studentId;
  @override
  DateTime get date;
  @override
  String get status;
  @override
  @JsonKey(name: 'is_read')
  bool get isRead;
  @override
  @JsonKey(name: 'subject_name')
  String? get subjectName;
  @override
  @JsonKey(name: 'subject_id')
  String? get subjectId;
  @override
  @JsonKey(name: 'lesson_hour_name')
  String? get lessonHourName;
  @override
  @JsonKey(name: 'lesson_hour_id')
  String? get lessonHourId;
  @override
  @JsonKey(name: 'class_id')
  String? get classId;
  @override
  @JsonKey(name: 'teacher_id')
  String? get teacherId;

  /// Create a copy of Attendance
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceImplCopyWith<_$AttendanceImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
