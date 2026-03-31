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

AttendanceSummary _$AttendanceSummaryFromJson(Map<String, dynamic> json) {
  return _AttendanceSummary.fromJson(json);
}

/// @nodoc
mixin _$AttendanceSummary {
  @JsonKey(name: 'id')
  String? get id => throw _privateConstructorUsedError;
  @JsonKey(name: 'date')
  DateTime get date => throw _privateConstructorUsedError;
  int get present => throw _privateConstructorUsedError;
  int get sick => throw _privateConstructorUsedError;
  int get excused => throw _privateConstructorUsedError;
  int get absent => throw _privateConstructorUsedError;
  @JsonKey(name: 'total_students')
  int get totalStudents => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_name')
  String? get subjectName => throw _privateConstructorUsedError;
  @JsonKey(name: 'subject_id')
  String? get subjectId => throw _privateConstructorUsedError;

  /// Serializes this AttendanceSummary to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

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
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'date') DateTime date,
    int present,
    int sick,
    int excused,
    int absent,
    @JsonKey(name: 'total_students') int totalStudents,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
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
    Object? id = freezed,
    Object? date = null,
    Object? present = null,
    Object? sick = null,
    Object? excused = null,
    Object? absent = null,
    Object? totalStudents = null,
    Object? subjectName = freezed,
    Object? subjectId = freezed,
  }) {
    return _then(
      _value.copyWith(
            id: freezed == id
                ? _value.id
                : id // ignore: cast_nullable_to_non_nullable
                      as String?,
            date: null == date
                ? _value.date
                : date // ignore: cast_nullable_to_non_nullable
                      as DateTime,
            present: null == present
                ? _value.present
                : present // ignore: cast_nullable_to_non_nullable
                      as int,
            sick: null == sick
                ? _value.sick
                : sick // ignore: cast_nullable_to_non_nullable
                      as int,
            excused: null == excused
                ? _value.excused
                : excused // ignore: cast_nullable_to_non_nullable
                      as int,
            absent: null == absent
                ? _value.absent
                : absent // ignore: cast_nullable_to_non_nullable
                      as int,
            totalStudents: null == totalStudents
                ? _value.totalStudents
                : totalStudents // ignore: cast_nullable_to_non_nullable
                      as int,
            subjectName: freezed == subjectName
                ? _value.subjectName
                : subjectName // ignore: cast_nullable_to_non_nullable
                      as String?,
            subjectId: freezed == subjectId
                ? _value.subjectId
                : subjectId // ignore: cast_nullable_to_non_nullable
                      as String?,
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
    @JsonKey(name: 'id') String? id,
    @JsonKey(name: 'date') DateTime date,
    int present,
    int sick,
    int excused,
    int absent,
    @JsonKey(name: 'total_students') int totalStudents,
    @JsonKey(name: 'subject_name') String? subjectName,
    @JsonKey(name: 'subject_id') String? subjectId,
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
    Object? id = freezed,
    Object? date = null,
    Object? present = null,
    Object? sick = null,
    Object? excused = null,
    Object? absent = null,
    Object? totalStudents = null,
    Object? subjectName = freezed,
    Object? subjectId = freezed,
  }) {
    return _then(
      _$AttendanceSummaryImpl(
        id: freezed == id
            ? _value.id
            : id // ignore: cast_nullable_to_non_nullable
                  as String?,
        date: null == date
            ? _value.date
            : date // ignore: cast_nullable_to_non_nullable
                  as DateTime,
        present: null == present
            ? _value.present
            : present // ignore: cast_nullable_to_non_nullable
                  as int,
        sick: null == sick
            ? _value.sick
            : sick // ignore: cast_nullable_to_non_nullable
                  as int,
        excused: null == excused
            ? _value.excused
            : excused // ignore: cast_nullable_to_non_nullable
                  as int,
        absent: null == absent
            ? _value.absent
            : absent // ignore: cast_nullable_to_non_nullable
                  as int,
        totalStudents: null == totalStudents
            ? _value.totalStudents
            : totalStudents // ignore: cast_nullable_to_non_nullable
                  as int,
        subjectName: freezed == subjectName
            ? _value.subjectName
            : subjectName // ignore: cast_nullable_to_non_nullable
                  as String?,
        subjectId: freezed == subjectId
            ? _value.subjectId
            : subjectId // ignore: cast_nullable_to_non_nullable
                  as String?,
      ),
    );
  }
}

/// @nodoc
@JsonSerializable()
class _$AttendanceSummaryImpl implements _AttendanceSummary {
  const _$AttendanceSummaryImpl({
    @JsonKey(name: 'id') this.id,
    @JsonKey(name: 'date') required this.date,
    this.present = 0,
    this.sick = 0,
    this.excused = 0,
    this.absent = 0,
    @JsonKey(name: 'total_students') this.totalStudents = 0,
    @JsonKey(name: 'subject_name') this.subjectName,
    @JsonKey(name: 'subject_id') this.subjectId,
  });

  factory _$AttendanceSummaryImpl.fromJson(Map<String, dynamic> json) =>
      _$$AttendanceSummaryImplFromJson(json);

  @override
  @JsonKey(name: 'id')
  final String? id;
  @override
  @JsonKey(name: 'date')
  final DateTime date;
  @override
  @JsonKey()
  final int present;
  @override
  @JsonKey()
  final int sick;
  @override
  @JsonKey()
  final int excused;
  @override
  @JsonKey()
  final int absent;
  @override
  @JsonKey(name: 'total_students')
  final int totalStudents;
  @override
  @JsonKey(name: 'subject_name')
  final String? subjectName;
  @override
  @JsonKey(name: 'subject_id')
  final String? subjectId;

  @override
  String toString() {
    return 'AttendanceSummary(id: $id, date: $date, present: $present, sick: $sick, excused: $excused, absent: $absent, totalStudents: $totalStudents, subjectName: $subjectName, subjectId: $subjectId)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AttendanceSummaryImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.date, date) || other.date == date) &&
            (identical(other.present, present) || other.present == present) &&
            (identical(other.sick, sick) || other.sick == sick) &&
            (identical(other.excused, excused) || other.excused == excused) &&
            (identical(other.absent, absent) || other.absent == absent) &&
            (identical(other.totalStudents, totalStudents) ||
                other.totalStudents == totalStudents) &&
            (identical(other.subjectName, subjectName) ||
                other.subjectName == subjectName) &&
            (identical(other.subjectId, subjectId) ||
                other.subjectId == subjectId));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
    runtimeType,
    id,
    date,
    present,
    sick,
    excused,
    absent,
    totalStudents,
    subjectName,
    subjectId,
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

  @override
  Map<String, dynamic> toJson() {
    return _$$AttendanceSummaryImplToJson(this);
  }
}

abstract class _AttendanceSummary implements AttendanceSummary {
  const factory _AttendanceSummary({
    @JsonKey(name: 'id') final String? id,
    @JsonKey(name: 'date') required final DateTime date,
    final int present,
    final int sick,
    final int excused,
    final int absent,
    @JsonKey(name: 'total_students') final int totalStudents,
    @JsonKey(name: 'subject_name') final String? subjectName,
    @JsonKey(name: 'subject_id') final String? subjectId,
  }) = _$AttendanceSummaryImpl;

  factory _AttendanceSummary.fromJson(Map<String, dynamic> json) =
      _$AttendanceSummaryImpl.fromJson;

  @override
  @JsonKey(name: 'id')
  String? get id;
  @override
  @JsonKey(name: 'date')
  DateTime get date;
  @override
  int get present;
  @override
  int get sick;
  @override
  int get excused;
  @override
  int get absent;
  @override
  @JsonKey(name: 'total_students')
  int get totalStudents;
  @override
  @JsonKey(name: 'subject_name')
  String? get subjectName;
  @override
  @JsonKey(name: 'subject_id')
  String? get subjectId;

  /// Create a copy of AttendanceSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AttendanceSummaryImplCopyWith<_$AttendanceSummaryImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
