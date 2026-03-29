// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'parent_finance_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
  'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models',
);

/// @nodoc
mixin _$ParentFinanceState {
  List<Student> get students => throw _privateConstructorUsedError;
  Student? get selectedStudent => throw _privateConstructorUsedError;
  List<dynamic> get billingItems => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String get errorMessage => throw _privateConstructorUsedError;
  String get searchQuery => throw _privateConstructorUsedError;
  String? get statusFilter =>
      throw _privateConstructorUsedError; // 'unpaid', 'pending', 'verified'
  String? get periodeFilter =>
      throw _privateConstructorUsedError; // 'bulanan', 'tahunan'
  Set<String> get processedReadIds => throw _privateConstructorUsedError;
  Set<String> get pendingReadIds => throw _privateConstructorUsedError;

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $ParentFinanceStateCopyWith<ParentFinanceState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $ParentFinanceStateCopyWith<$Res> {
  factory $ParentFinanceStateCopyWith(
    ParentFinanceState value,
    $Res Function(ParentFinanceState) then,
  ) = _$ParentFinanceStateCopyWithImpl<$Res, ParentFinanceState>;
  @useResult
  $Res call({
    List<Student> students,
    Student? selectedStudent,
    List<dynamic> billingItems,
    bool isLoading,
    String errorMessage,
    String searchQuery,
    String? statusFilter,
    String? periodeFilter,
    Set<String> processedReadIds,
    Set<String> pendingReadIds,
  });

  $StudentCopyWith<$Res>? get selectedStudent;
}

/// @nodoc
class _$ParentFinanceStateCopyWithImpl<$Res, $Val extends ParentFinanceState>
    implements $ParentFinanceStateCopyWith<$Res> {
  _$ParentFinanceStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? students = null,
    Object? selectedStudent = freezed,
    Object? billingItems = null,
    Object? isLoading = null,
    Object? errorMessage = null,
    Object? searchQuery = null,
    Object? statusFilter = freezed,
    Object? periodeFilter = freezed,
    Object? processedReadIds = null,
    Object? pendingReadIds = null,
  }) {
    return _then(
      _value.copyWith(
            students: null == students
                ? _value.students
                : students // ignore: cast_nullable_to_non_nullable
                      as List<Student>,
            selectedStudent: freezed == selectedStudent
                ? _value.selectedStudent
                : selectedStudent // ignore: cast_nullable_to_non_nullable
                      as Student?,
            billingItems: null == billingItems
                ? _value.billingItems
                : billingItems // ignore: cast_nullable_to_non_nullable
                      as List<dynamic>,
            isLoading: null == isLoading
                ? _value.isLoading
                : isLoading // ignore: cast_nullable_to_non_nullable
                      as bool,
            errorMessage: null == errorMessage
                ? _value.errorMessage
                : errorMessage // ignore: cast_nullable_to_non_nullable
                      as String,
            searchQuery: null == searchQuery
                ? _value.searchQuery
                : searchQuery // ignore: cast_nullable_to_non_nullable
                      as String,
            statusFilter: freezed == statusFilter
                ? _value.statusFilter
                : statusFilter // ignore: cast_nullable_to_non_nullable
                      as String?,
            periodeFilter: freezed == periodeFilter
                ? _value.periodeFilter
                : periodeFilter // ignore: cast_nullable_to_non_nullable
                      as String?,
            processedReadIds: null == processedReadIds
                ? _value.processedReadIds
                : processedReadIds // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
            pendingReadIds: null == pendingReadIds
                ? _value.pendingReadIds
                : pendingReadIds // ignore: cast_nullable_to_non_nullable
                      as Set<String>,
          )
          as $Val,
    );
  }

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $StudentCopyWith<$Res>? get selectedStudent {
    if (_value.selectedStudent == null) {
      return null;
    }

    return $StudentCopyWith<$Res>(_value.selectedStudent!, (value) {
      return _then(_value.copyWith(selectedStudent: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$ParentFinanceStateImplCopyWith<$Res>
    implements $ParentFinanceStateCopyWith<$Res> {
  factory _$$ParentFinanceStateImplCopyWith(
    _$ParentFinanceStateImpl value,
    $Res Function(_$ParentFinanceStateImpl) then,
  ) = __$$ParentFinanceStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({
    List<Student> students,
    Student? selectedStudent,
    List<dynamic> billingItems,
    bool isLoading,
    String errorMessage,
    String searchQuery,
    String? statusFilter,
    String? periodeFilter,
    Set<String> processedReadIds,
    Set<String> pendingReadIds,
  });

  @override
  $StudentCopyWith<$Res>? get selectedStudent;
}

/// @nodoc
class __$$ParentFinanceStateImplCopyWithImpl<$Res>
    extends _$ParentFinanceStateCopyWithImpl<$Res, _$ParentFinanceStateImpl>
    implements _$$ParentFinanceStateImplCopyWith<$Res> {
  __$$ParentFinanceStateImplCopyWithImpl(
    _$ParentFinanceStateImpl _value,
    $Res Function(_$ParentFinanceStateImpl) _then,
  ) : super(_value, _then);

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? students = null,
    Object? selectedStudent = freezed,
    Object? billingItems = null,
    Object? isLoading = null,
    Object? errorMessage = null,
    Object? searchQuery = null,
    Object? statusFilter = freezed,
    Object? periodeFilter = freezed,
    Object? processedReadIds = null,
    Object? pendingReadIds = null,
  }) {
    return _then(
      _$ParentFinanceStateImpl(
        students: null == students
            ? _value._students
            : students // ignore: cast_nullable_to_non_nullable
                  as List<Student>,
        selectedStudent: freezed == selectedStudent
            ? _value.selectedStudent
            : selectedStudent // ignore: cast_nullable_to_non_nullable
                  as Student?,
        billingItems: null == billingItems
            ? _value._billingItems
            : billingItems // ignore: cast_nullable_to_non_nullable
                  as List<dynamic>,
        isLoading: null == isLoading
            ? _value.isLoading
            : isLoading // ignore: cast_nullable_to_non_nullable
                  as bool,
        errorMessage: null == errorMessage
            ? _value.errorMessage
            : errorMessage // ignore: cast_nullable_to_non_nullable
                  as String,
        searchQuery: null == searchQuery
            ? _value.searchQuery
            : searchQuery // ignore: cast_nullable_to_non_nullable
                  as String,
        statusFilter: freezed == statusFilter
            ? _value.statusFilter
            : statusFilter // ignore: cast_nullable_to_non_nullable
                  as String?,
        periodeFilter: freezed == periodeFilter
            ? _value.periodeFilter
            : periodeFilter // ignore: cast_nullable_to_non_nullable
                  as String?,
        processedReadIds: null == processedReadIds
            ? _value._processedReadIds
            : processedReadIds // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
        pendingReadIds: null == pendingReadIds
            ? _value._pendingReadIds
            : pendingReadIds // ignore: cast_nullable_to_non_nullable
                  as Set<String>,
      ),
    );
  }
}

/// @nodoc

class _$ParentFinanceStateImpl implements _ParentFinanceState {
  const _$ParentFinanceStateImpl({
    final List<Student> students = const [],
    this.selectedStudent,
    final List<dynamic> billingItems = const [],
    this.isLoading = true,
    this.errorMessage = '',
    this.searchQuery = '',
    this.statusFilter,
    this.periodeFilter,
    final Set<String> processedReadIds = const {},
    final Set<String> pendingReadIds = const {},
  }) : _students = students,
       _billingItems = billingItems,
       _processedReadIds = processedReadIds,
       _pendingReadIds = pendingReadIds;

  final List<Student> _students;
  @override
  @JsonKey()
  List<Student> get students {
    if (_students is EqualUnmodifiableListView) return _students;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_students);
  }

  @override
  final Student? selectedStudent;
  final List<dynamic> _billingItems;
  @override
  @JsonKey()
  List<dynamic> get billingItems {
    if (_billingItems is EqualUnmodifiableListView) return _billingItems;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_billingItems);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final String errorMessage;
  @override
  @JsonKey()
  final String searchQuery;
  @override
  final String? statusFilter;
  // 'unpaid', 'pending', 'verified'
  @override
  final String? periodeFilter;
  // 'bulanan', 'tahunan'
  final Set<String> _processedReadIds;
  // 'bulanan', 'tahunan'
  @override
  @JsonKey()
  Set<String> get processedReadIds {
    if (_processedReadIds is EqualUnmodifiableSetView) return _processedReadIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_processedReadIds);
  }

  final Set<String> _pendingReadIds;
  @override
  @JsonKey()
  Set<String> get pendingReadIds {
    if (_pendingReadIds is EqualUnmodifiableSetView) return _pendingReadIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_pendingReadIds);
  }

  @override
  String toString() {
    return 'ParentFinanceState(students: $students, selectedStudent: $selectedStudent, billingItems: $billingItems, isLoading: $isLoading, errorMessage: $errorMessage, searchQuery: $searchQuery, statusFilter: $statusFilter, periodeFilter: $periodeFilter, processedReadIds: $processedReadIds, pendingReadIds: $pendingReadIds)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$ParentFinanceStateImpl &&
            const DeepCollectionEquality().equals(other._students, _students) &&
            (identical(other.selectedStudent, selectedStudent) ||
                other.selectedStudent == selectedStudent) &&
            const DeepCollectionEquality().equals(
              other._billingItems,
              _billingItems,
            ) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.searchQuery, searchQuery) ||
                other.searchQuery == searchQuery) &&
            (identical(other.statusFilter, statusFilter) ||
                other.statusFilter == statusFilter) &&
            (identical(other.periodeFilter, periodeFilter) ||
                other.periodeFilter == periodeFilter) &&
            const DeepCollectionEquality().equals(
              other._processedReadIds,
              _processedReadIds,
            ) &&
            const DeepCollectionEquality().equals(
              other._pendingReadIds,
              _pendingReadIds,
            ));
  }

  @override
  int get hashCode => Object.hash(
    runtimeType,
    const DeepCollectionEquality().hash(_students),
    selectedStudent,
    const DeepCollectionEquality().hash(_billingItems),
    isLoading,
    errorMessage,
    searchQuery,
    statusFilter,
    periodeFilter,
    const DeepCollectionEquality().hash(_processedReadIds),
    const DeepCollectionEquality().hash(_pendingReadIds),
  );

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$ParentFinanceStateImplCopyWith<_$ParentFinanceStateImpl> get copyWith =>
      __$$ParentFinanceStateImplCopyWithImpl<_$ParentFinanceStateImpl>(
        this,
        _$identity,
      );
}

abstract class _ParentFinanceState implements ParentFinanceState {
  const factory _ParentFinanceState({
    final List<Student> students,
    final Student? selectedStudent,
    final List<dynamic> billingItems,
    final bool isLoading,
    final String errorMessage,
    final String searchQuery,
    final String? statusFilter,
    final String? periodeFilter,
    final Set<String> processedReadIds,
    final Set<String> pendingReadIds,
  }) = _$ParentFinanceStateImpl;

  @override
  List<Student> get students;
  @override
  Student? get selectedStudent;
  @override
  List<dynamic> get billingItems;
  @override
  bool get isLoading;
  @override
  String get errorMessage;
  @override
  String get searchQuery;
  @override
  String? get statusFilter; // 'unpaid', 'pending', 'verified'
  @override
  String? get periodeFilter; // 'bulanan', 'tahunan'
  @override
  Set<String> get processedReadIds;
  @override
  Set<String> get pendingReadIds;

  /// Create a copy of ParentFinanceState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$ParentFinanceStateImplCopyWith<_$ParentFinanceStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
