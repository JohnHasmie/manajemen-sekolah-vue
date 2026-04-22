// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'parent_finance_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ParentFinanceState {

 List<Student> get students; Student? get selectedStudent; List<dynamic> get billingItems; bool get isLoading; String get errorMessage; String get searchQuery; String? get statusFilter;// 'unpaid', 'pending', 'verified'
 String? get periodFilter;// 'bulanan', 'tahunan'
 Set<String> get processedReadIds; Set<String> get pendingReadIds;
/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ParentFinanceStateCopyWith<ParentFinanceState> get copyWith => _$ParentFinanceStateCopyWithImpl<ParentFinanceState>(this as ParentFinanceState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ParentFinanceState&&const DeepCollectionEquality().equals(other.students, students)&&(identical(other.selectedStudent, selectedStudent) || other.selectedStudent == selectedStudent)&&const DeepCollectionEquality().equals(other.billingItems, billingItems)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.statusFilter, statusFilter) || other.statusFilter == statusFilter)&&(identical(other.periodFilter, periodFilter) || other.periodFilter == periodFilter)&&const DeepCollectionEquality().equals(other.processedReadIds, processedReadIds)&&const DeepCollectionEquality().equals(other.pendingReadIds, pendingReadIds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(students),selectedStudent,const DeepCollectionEquality().hash(billingItems),isLoading,errorMessage,searchQuery,statusFilter,periodFilter,const DeepCollectionEquality().hash(processedReadIds),const DeepCollectionEquality().hash(pendingReadIds));

@override
String toString() {
  return 'ParentFinanceState(students: $students, selectedStudent: $selectedStudent, billingItems: $billingItems, isLoading: $isLoading, errorMessage: $errorMessage, searchQuery: $searchQuery, statusFilter: $statusFilter, periodFilter: $periodFilter, processedReadIds: $processedReadIds, pendingReadIds: $pendingReadIds)';
}


}

/// @nodoc
abstract mixin class $ParentFinanceStateCopyWith<$Res>  {
  factory $ParentFinanceStateCopyWith(ParentFinanceState value, $Res Function(ParentFinanceState) _then) = _$ParentFinanceStateCopyWithImpl;
@useResult
$Res call({
 List<Student> students, Student? selectedStudent, List<dynamic> billingItems, bool isLoading, String errorMessage, String searchQuery, String? statusFilter, String? periodFilter, Set<String> processedReadIds, Set<String> pendingReadIds
});


$StudentCopyWith<$Res>? get selectedStudent;

}
/// @nodoc
class _$ParentFinanceStateCopyWithImpl<$Res>
    implements $ParentFinanceStateCopyWith<$Res> {
  _$ParentFinanceStateCopyWithImpl(this._self, this._then);

  final ParentFinanceState _self;
  final $Res Function(ParentFinanceState) _then;

/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? students = null,Object? selectedStudent = freezed,Object? billingItems = null,Object? isLoading = null,Object? errorMessage = null,Object? searchQuery = null,Object? statusFilter = freezed,Object? periodFilter = freezed,Object? processedReadIds = null,Object? pendingReadIds = null,}) {
  return _then(_self.copyWith(
students: null == students ? _self.students : students // ignore: cast_nullable_to_non_nullable
as List<Student>,selectedStudent: freezed == selectedStudent ? _self.selectedStudent : selectedStudent // ignore: cast_nullable_to_non_nullable
as Student?,billingItems: null == billingItems ? _self.billingItems : billingItems // ignore: cast_nullable_to_non_nullable
as List<dynamic>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,statusFilter: freezed == statusFilter ? _self.statusFilter : statusFilter // ignore: cast_nullable_to_non_nullable
as String?,periodFilter: freezed == periodFilter ? _self.periodFilter : periodFilter // ignore: cast_nullable_to_non_nullable
as String?,processedReadIds: null == processedReadIds ? _self.processedReadIds : processedReadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,pendingReadIds: null == pendingReadIds ? _self.pendingReadIds : pendingReadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}
/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudentCopyWith<$Res>? get selectedStudent {
    if (_self.selectedStudent == null) {
    return null;
  }

  return $StudentCopyWith<$Res>(_self.selectedStudent!, (value) {
    return _then(_self.copyWith(selectedStudent: value));
  });
}
}


/// Adds pattern-matching-related methods to [ParentFinanceState].
extension ParentFinanceStatePatterns on ParentFinanceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ParentFinanceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ParentFinanceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ParentFinanceState value)  $default,){
final _that = this;
switch (_that) {
case _ParentFinanceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ParentFinanceState value)?  $default,){
final _that = this;
switch (_that) {
case _ParentFinanceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Student> students,  Student? selectedStudent,  List<dynamic> billingItems,  bool isLoading,  String errorMessage,  String searchQuery,  String? statusFilter,  String? periodFilter,  Set<String> processedReadIds,  Set<String> pendingReadIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ParentFinanceState() when $default != null:
return $default(_that.students,_that.selectedStudent,_that.billingItems,_that.isLoading,_that.errorMessage,_that.searchQuery,_that.statusFilter,_that.periodFilter,_that.processedReadIds,_that.pendingReadIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Student> students,  Student? selectedStudent,  List<dynamic> billingItems,  bool isLoading,  String errorMessage,  String searchQuery,  String? statusFilter,  String? periodFilter,  Set<String> processedReadIds,  Set<String> pendingReadIds)  $default,) {final _that = this;
switch (_that) {
case _ParentFinanceState():
return $default(_that.students,_that.selectedStudent,_that.billingItems,_that.isLoading,_that.errorMessage,_that.searchQuery,_that.statusFilter,_that.periodFilter,_that.processedReadIds,_that.pendingReadIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Student> students,  Student? selectedStudent,  List<dynamic> billingItems,  bool isLoading,  String errorMessage,  String searchQuery,  String? statusFilter,  String? periodFilter,  Set<String> processedReadIds,  Set<String> pendingReadIds)?  $default,) {final _that = this;
switch (_that) {
case _ParentFinanceState() when $default != null:
return $default(_that.students,_that.selectedStudent,_that.billingItems,_that.isLoading,_that.errorMessage,_that.searchQuery,_that.statusFilter,_that.periodFilter,_that.processedReadIds,_that.pendingReadIds);case _:
  return null;

}
}

}

/// @nodoc


class _ParentFinanceState implements ParentFinanceState {
  const _ParentFinanceState({final  List<Student> students = const [], this.selectedStudent, final  List<dynamic> billingItems = const [], this.isLoading = true, this.errorMessage = '', this.searchQuery = '', this.statusFilter, this.periodFilter, final  Set<String> processedReadIds = const {}, final  Set<String> pendingReadIds = const {}}): _students = students,_billingItems = billingItems,_processedReadIds = processedReadIds,_pendingReadIds = pendingReadIds;
  

 final  List<Student> _students;
@override@JsonKey() List<Student> get students {
  if (_students is EqualUnmodifiableListView) return _students;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_students);
}

@override final  Student? selectedStudent;
 final  List<dynamic> _billingItems;
@override@JsonKey() List<dynamic> get billingItems {
  if (_billingItems is EqualUnmodifiableListView) return _billingItems;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_billingItems);
}

@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  String errorMessage;
@override@JsonKey() final  String searchQuery;
@override final  String? statusFilter;
// 'unpaid', 'pending', 'verified'
@override final  String? periodFilter;
// 'bulanan', 'tahunan'
 final  Set<String> _processedReadIds;
// 'bulanan', 'tahunan'
@override@JsonKey() Set<String> get processedReadIds {
  if (_processedReadIds is EqualUnmodifiableSetView) return _processedReadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_processedReadIds);
}

 final  Set<String> _pendingReadIds;
@override@JsonKey() Set<String> get pendingReadIds {
  if (_pendingReadIds is EqualUnmodifiableSetView) return _pendingReadIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pendingReadIds);
}


/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ParentFinanceStateCopyWith<_ParentFinanceState> get copyWith => __$ParentFinanceStateCopyWithImpl<_ParentFinanceState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ParentFinanceState&&const DeepCollectionEquality().equals(other._students, _students)&&(identical(other.selectedStudent, selectedStudent) || other.selectedStudent == selectedStudent)&&const DeepCollectionEquality().equals(other._billingItems, _billingItems)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery)&&(identical(other.statusFilter, statusFilter) || other.statusFilter == statusFilter)&&(identical(other.periodFilter, periodFilter) || other.periodFilter == periodFilter)&&const DeepCollectionEquality().equals(other._processedReadIds, _processedReadIds)&&const DeepCollectionEquality().equals(other._pendingReadIds, _pendingReadIds));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_students),selectedStudent,const DeepCollectionEquality().hash(_billingItems),isLoading,errorMessage,searchQuery,statusFilter,periodFilter,const DeepCollectionEquality().hash(_processedReadIds),const DeepCollectionEquality().hash(_pendingReadIds));

@override
String toString() {
  return 'ParentFinanceState(students: $students, selectedStudent: $selectedStudent, billingItems: $billingItems, isLoading: $isLoading, errorMessage: $errorMessage, searchQuery: $searchQuery, statusFilter: $statusFilter, periodFilter: $periodFilter, processedReadIds: $processedReadIds, pendingReadIds: $pendingReadIds)';
}


}

/// @nodoc
abstract mixin class _$ParentFinanceStateCopyWith<$Res> implements $ParentFinanceStateCopyWith<$Res> {
  factory _$ParentFinanceStateCopyWith(_ParentFinanceState value, $Res Function(_ParentFinanceState) _then) = __$ParentFinanceStateCopyWithImpl;
@override @useResult
$Res call({
 List<Student> students, Student? selectedStudent, List<dynamic> billingItems, bool isLoading, String errorMessage, String searchQuery, String? statusFilter, String? periodFilter, Set<String> processedReadIds, Set<String> pendingReadIds
});


@override $StudentCopyWith<$Res>? get selectedStudent;

}
/// @nodoc
class __$ParentFinanceStateCopyWithImpl<$Res>
    implements _$ParentFinanceStateCopyWith<$Res> {
  __$ParentFinanceStateCopyWithImpl(this._self, this._then);

  final _ParentFinanceState _self;
  final $Res Function(_ParentFinanceState) _then;

/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? students = null,Object? selectedStudent = freezed,Object? billingItems = null,Object? isLoading = null,Object? errorMessage = null,Object? searchQuery = null,Object? statusFilter = freezed,Object? periodFilter = freezed,Object? processedReadIds = null,Object? pendingReadIds = null,}) {
  return _then(_ParentFinanceState(
students: null == students ? _self._students : students // ignore: cast_nullable_to_non_nullable
as List<Student>,selectedStudent: freezed == selectedStudent ? _self.selectedStudent : selectedStudent // ignore: cast_nullable_to_non_nullable
as Student?,billingItems: null == billingItems ? _self._billingItems : billingItems // ignore: cast_nullable_to_non_nullable
as List<dynamic>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,errorMessage: null == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,statusFilter: freezed == statusFilter ? _self.statusFilter : statusFilter // ignore: cast_nullable_to_non_nullable
as String?,periodFilter: freezed == periodFilter ? _self.periodFilter : periodFilter // ignore: cast_nullable_to_non_nullable
as String?,processedReadIds: null == processedReadIds ? _self._processedReadIds : processedReadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,pendingReadIds: null == pendingReadIds ? _self._pendingReadIds : pendingReadIds // ignore: cast_nullable_to_non_nullable
as Set<String>,
  ));
}

/// Create a copy of ParentFinanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$StudentCopyWith<$Res>? get selectedStudent {
    if (_self.selectedStudent == null) {
    return null;
  }

  return $StudentCopyWith<$Res>(_self.selectedStudent!, (value) {
    return _then(_self.copyWith(selectedStudent: value));
  });
}
}

// dart format on
