// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'attendance_summary.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$AttendanceSummary {
  String get id => throw _privateConstructorUsedError;
  String get subjectId => throw _privateConstructorUsedError;
  String get subjectName => throw _privateConstructorUsedError;
  DateTime get date => throw _privateConstructorUsedError;
  int get totalStudents => throw _privateConstructorUsedError;
  int get present => throw _privateConstructorUsedError;
  int get absent => throw _privateConstructorUsedError;

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AttendanceSummaryCopyWith<AttendanceSummary> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AttendanceSummaryCopyWith<$Res> {
  factory $AttendanceSummaryCopyWith(
    AttendanceSummary value,
    $Res Function(AttendanceSummary) then,
  ) = _$AttendanceSummaryCopyWithImpl<$Res, AttendanceSummary>;
  @useResult
  $Res call({
    String id,
    String subjectId,
    String subjectName,
    DateTime date,
    int totalStudents,
    int present,
    int absent,
  });
}

/// @nodoc
class _$AttendanceSummaryCopyWithImpl<$Res, $Val extends AttendanceSummary>
    implements $AttendanceSummaryCopyWith<$Res> {
  _$AttendanceSummaryCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subjectId = null,
    Object? subjectName = null,
    Object? date = null,
    Object? totalStudents = null,
    Object? present = null,
    Object? absent = null,
  }) {
    return _then(
      _value.copyWith(
            id: null == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String,
            subjectId: null == subjectId
                ? _value.subjectId
                : subjectId // ignore: cast_nullable_to_non_nullable
                      as String,
            subjectName: null == subjectName
                ? _value.subjectName
                : subjectName // ignore: cast_nullable_to_non_nullable
                      as String,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            totalStudents: null == totalStudents
                ? _value.totalStudents
                : totalStudents // ignore: cast_nullable_to_non_nullable
                      as int,
            present: null == present
                ? _value.present
                : present // ignore: cast_nullable_to_non_nullable
                      as int,
            absent: null == absent
                ? _value.absent
                : absent // ignore: cast_nullable_to_non_nullable
                      as int,
          )
          as $Val,
    );
  }
}

/// @nodoc
abstract class _$$AttendanceSummaryImplCopyWith<$Res>
    implements $AttendanceSummaryCopyWith<$Res> {
  factory _$$AttendanceSummaryImplCopyWith(
    _$AttendanceSummaryImpl value,
    $Res Function(_$AttendanceSummaryImpl) then,
  ) = __$$AttendanceSummaryImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    String id,
    String subjectId,
    String subjectName,
    DateTime date,
    int totalStudents,
    int present,
    int absent,
  });
}

/// @nodoc
class __$$AttendanceSummaryImplCopyWithImpl<$Res>
    extends _$AttendanceSummaryCopyWithImpl<$Res, _$AttendanceSummaryImpl>
    implements _$$AttendanceSummaryImplCopyWith<$Res> {
  __$$AttendanceSummaryImplCopyWithImpl(
    _$AttendanceSummaryImpl _value,
    $Res Function(_$AttendanceSummaryImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? subjectId = null,
    Object? subjectName = null,
    Object? date = null,
    Object? totalStudents = null,
    Object? present = null,
    Object? absent = null,
  }) {
    return _then(
      _$AttendanceSummaryImpl(
        id: null == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String,
        subjectId: null == subjectId
            ? _value.subjectId
            : subjectId // ignore: cast_nullable_to_non_nullable
                  as String,
        subjectName: null == subjectName
            ? _value.subjectName
            : subjectName // ignore: cast_nullable_to_non_nullable
                  as String,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        totalStudents: null == totalStudents
            ? _value.totalStudents
            : totalStudents // ignore: cast_nullable_to_non_nullable
                  as int,
        present: null == present
            ? _value.present
            : present // ignore: cast_nullable_to_non_nullable
                  as int,
        absent: null == absent
            ? _value.absent
            : absent // ignore: cast_nullable_to_non_nullable
                  as int,
      ),
    );
  }
}

/// @nodoc

class _$AttendanceSummaryImpl implements _AttendanceSummary {
  const _$AttendanceSummaryImpl({
    this.id = '',
    this.subjectId = '',
    this.subjectName = '',
    required this.date,
    this.totalStudents = 0,
    this.present = 0,
    this.absent = 0,
  });

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String subjectId;
  @override
  @JsonKey()
  final String subjectName;
  @override
  final DateTime date;
  @override
  @JsonKey()
  final int totalStudents;
  @override
  @JsonKey()
  final int present;
  @override
  @JsonKey()
  final int absent;

  @override
  String toString() {
    return 'AttendanceSummary(id: $id, subjectId: $subjectId, subjectName: $subjectName, date: $date, totalStudents: $totalStudents, present: $present, absent: $absent)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId) &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.present, present) || other.present == present) &&
            (identical(other.absent, absent) || other.absent == absent));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    subjectId,
    subjectName,
    date,
    totalStudents,
    present,
    absent,
  );

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AttendanceSummaryImplCopyWith<_$AttendanceSummaryImpl> get copyWith =>
      __$$AttendanceSummaryImplCopyWithImpl<_$AttendanceSummaryImpl>(
        this,
        _$identity,
      );
}

abstract class _AttendanceSummary implements AttendanceSummary {
  const factory _AttendanceSummary({
    final String id,
    final String subjectId,
    final String subjectName,
    required final DateTime date,
    final int totalStudents,
    final int present,
    final int absent,
  }) = _$AttendanceSummaryImpl;

  @override
  String get id;
  @override
  String get subjectId;
  @override
  String get subjectName;
  @override
  DateTime get date;
  @override
  int get totalStudents;
  @override
  int get present;
  @override
  int get absent;

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceSummaryImplCopyWith<_$AttendanceSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
