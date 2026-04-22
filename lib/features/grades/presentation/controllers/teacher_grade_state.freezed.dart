// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'teacher_grade_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TeacherGradeState {

 int get currentStep;// 0: Class List, 1: Subject List
 List<dynamic> get classList; List<dynamic> get subjectList; List<dynamic> get todaySchedules; Map<String, dynamic>? get selectedClass; Map<String, dynamic>? get selectedSubject; bool get isLoading; bool get isLoadingMore; bool get hasMoreData; int get currentPage; String get searchQuery;
/// Create a copy of TeacherGradeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TeacherGradeStateCopyWith<TeacherGradeState> get copyWith => _$TeacherGradeStateCopyWithImpl<TeacherGradeState>(this as TeacherGradeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TeacherGradeState&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&const DeepCollectionEquality().equals(other.classList, classList)&&const DeepCollectionEquality().equals(other.subjectList, subjectList)&&const DeepCollectionEquality().equals(other.todaySchedules, todaySchedules)&&const DeepCollectionEquality().equals(other.selectedClass, selectedClass)&&const DeepCollectionEquality().equals(other.selectedSubject, selectedSubject)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.hasMoreData, hasMoreData) || other.hasMoreData == hasMoreData)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,const DeepCollectionEquality().hash(classList),const DeepCollectionEquality().hash(subjectList),const DeepCollectionEquality().hash(todaySchedules),const DeepCollectionEquality().hash(selectedClass),const DeepCollectionEquality().hash(selectedSubject),isLoading,isLoadingMore,hasMoreData,currentPage,searchQuery);

@override
String toString() {
  return 'TeacherGradeState(currentStep: $currentStep, classList: $classList, subjectList: $subjectList, todaySchedules: $todaySchedules, selectedClass: $selectedClass, selectedSubject: $selectedSubject, isLoading: $isLoading, isLoadingMore: $isLoadingMore, hasMoreData: $hasMoreData, currentPage: $currentPage, searchQuery: $searchQuery)';
}


}

/// @nodoc
abstract mixin class $TeacherGradeStateCopyWith<$Res>  {
  factory $TeacherGradeStateCopyWith(TeacherGradeState value, $Res Function(TeacherGradeState) _then) = _$TeacherGradeStateCopyWithImpl;
@useResult
$Res call({
 int currentStep, List<dynamic> classList, List<dynamic> subjectList, List<dynamic> todaySchedules, Map<String, dynamic>? selectedClass, Map<String, dynamic>? selectedSubject, bool isLoading, bool isLoadingMore, bool hasMoreData, int currentPage, String searchQuery
});




}
/// @nodoc
class _$TeacherGradeStateCopyWithImpl<$Res>
    implements $TeacherGradeStateCopyWith<$Res> {
  _$TeacherGradeStateCopyWithImpl(this._self, this._then);

  final TeacherGradeState _self;
  final $Res Function(TeacherGradeState) _then;

/// Create a copy of TeacherGradeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentStep = null,Object? classList = null,Object? subjectList = null,Object? todaySchedules = null,Object? selectedClass = freezed,Object? selectedSubject = freezed,Object? isLoading = null,Object? isLoadingMore = null,Object? hasMoreData = null,Object? currentPage = null,Object? searchQuery = null,}) {
  return _then(_self.copyWith(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,classList: null == classList ? _self.classList : classList // ignore: cast_nullable_to_non_nullable
as List<dynamic>,subjectList: null == subjectList ? _self.subjectList : subjectList // ignore: cast_nullable_to_non_nullable
as List<dynamic>,todaySchedules: null == todaySchedules ? _self.todaySchedules : todaySchedules // ignore: cast_nullable_to_non_nullable
as List<dynamic>,selectedClass: freezed == selectedClass ? _self.selectedClass : selectedClass // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,selectedSubject: freezed == selectedSubject ? _self.selectedSubject : selectedSubject // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,hasMoreData: null == hasMoreData ? _self.hasMoreData : hasMoreData // ignore: cast_nullable_to_non_nullable
as bool,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TeacherGradeState].
extension TeacherGradeStatePatterns on TeacherGradeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TeacherGradeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TeacherGradeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TeacherGradeState value)  $default,){
final _that = this;
switch (_that) {
case _TeacherGradeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TeacherGradeState value)?  $default,){
final _that = this;
switch (_that) {
case _TeacherGradeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int currentStep,  List<dynamic> classList,  List<dynamic> subjectList,  List<dynamic> todaySchedules,  Map<String, dynamic>? selectedClass,  Map<String, dynamic>? selectedSubject,  bool isLoading,  bool isLoadingMore,  bool hasMoreData,  int currentPage,  String searchQuery)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TeacherGradeState() when $default != null:
return $default(_that.currentStep,_that.classList,_that.subjectList,_that.todaySchedules,_that.selectedClass,_that.selectedSubject,_that.isLoading,_that.isLoadingMore,_that.hasMoreData,_that.currentPage,_that.searchQuery);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int currentStep,  List<dynamic> classList,  List<dynamic> subjectList,  List<dynamic> todaySchedules,  Map<String, dynamic>? selectedClass,  Map<String, dynamic>? selectedSubject,  bool isLoading,  bool isLoadingMore,  bool hasMoreData,  int currentPage,  String searchQuery)  $default,) {final _that = this;
switch (_that) {
case _TeacherGradeState():
return $default(_that.currentStep,_that.classList,_that.subjectList,_that.todaySchedules,_that.selectedClass,_that.selectedSubject,_that.isLoading,_that.isLoadingMore,_that.hasMoreData,_that.currentPage,_that.searchQuery);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int currentStep,  List<dynamic> classList,  List<dynamic> subjectList,  List<dynamic> todaySchedules,  Map<String, dynamic>? selectedClass,  Map<String, dynamic>? selectedSubject,  bool isLoading,  bool isLoadingMore,  bool hasMoreData,  int currentPage,  String searchQuery)?  $default,) {final _that = this;
switch (_that) {
case _TeacherGradeState() when $default != null:
return $default(_that.currentStep,_that.classList,_that.subjectList,_that.todaySchedules,_that.selectedClass,_that.selectedSubject,_that.isLoading,_that.isLoadingMore,_that.hasMoreData,_that.currentPage,_that.searchQuery);case _:
  return null;

}
}

}

/// @nodoc


class _TeacherGradeState implements TeacherGradeState {
  const _TeacherGradeState({this.currentStep = 0, final  List<dynamic> classList = const [], final  List<dynamic> subjectList = const [], final  List<dynamic> todaySchedules = const [], final  Map<String, dynamic>? selectedClass, final  Map<String, dynamic>? selectedSubject, this.isLoading = true, this.isLoadingMore = false, this.hasMoreData = true, this.currentPage = 1, this.searchQuery = ''}): _classList = classList,_subjectList = subjectList,_todaySchedules = todaySchedules,_selectedClass = selectedClass,_selectedSubject = selectedSubject;
  

@override@JsonKey() final  int currentStep;
// 0: Class List, 1: Subject List
 final  List<dynamic> _classList;
// 0: Class List, 1: Subject List
@override@JsonKey() List<dynamic> get classList {
  if (_classList is EqualUnmodifiableListView) return _classList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_classList);
}

 final  List<dynamic> _subjectList;
@override@JsonKey() List<dynamic> get subjectList {
  if (_subjectList is EqualUnmodifiableListView) return _subjectList;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_subjectList);
}

 final  List<dynamic> _todaySchedules;
@override@JsonKey() List<dynamic> get todaySchedules {
  if (_todaySchedules is EqualUnmodifiableListView) return _todaySchedules;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_todaySchedules);
}

 final  Map<String, dynamic>? _selectedClass;
@override Map<String, dynamic>? get selectedClass {
  final value = _selectedClass;
  if (value == null) return null;
  if (_selectedClass is EqualUnmodifiableMapView) return _selectedClass;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

 final  Map<String, dynamic>? _selectedSubject;
@override Map<String, dynamic>? get selectedSubject {
  final value = _selectedSubject;
  if (value == null) return null;
  if (_selectedSubject is EqualUnmodifiableMapView) return _selectedSubject;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool isLoadingMore;
@override@JsonKey() final  bool hasMoreData;
@override@JsonKey() final  int currentPage;
@override@JsonKey() final  String searchQuery;

/// Create a copy of TeacherGradeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TeacherGradeStateCopyWith<_TeacherGradeState> get copyWith => __$TeacherGradeStateCopyWithImpl<_TeacherGradeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TeacherGradeState&&(identical(other.currentStep, currentStep) || other.currentStep == currentStep)&&const DeepCollectionEquality().equals(other._classList, _classList)&&const DeepCollectionEquality().equals(other._subjectList, _subjectList)&&const DeepCollectionEquality().equals(other._todaySchedules, _todaySchedules)&&const DeepCollectionEquality().equals(other._selectedClass, _selectedClass)&&const DeepCollectionEquality().equals(other._selectedSubject, _selectedSubject)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.hasMoreData, hasMoreData) || other.hasMoreData == hasMoreData)&&(identical(other.currentPage, currentPage) || other.currentPage == currentPage)&&(identical(other.searchQuery, searchQuery) || other.searchQuery == searchQuery));
}


@override
int get hashCode => Object.hash(runtimeType,currentStep,const DeepCollectionEquality().hash(_classList),const DeepCollectionEquality().hash(_subjectList),const DeepCollectionEquality().hash(_todaySchedules),const DeepCollectionEquality().hash(_selectedClass),const DeepCollectionEquality().hash(_selectedSubject),isLoading,isLoadingMore,hasMoreData,currentPage,searchQuery);

@override
String toString() {
  return 'TeacherGradeState(currentStep: $currentStep, classList: $classList, subjectList: $subjectList, todaySchedules: $todaySchedules, selectedClass: $selectedClass, selectedSubject: $selectedSubject, isLoading: $isLoading, isLoadingMore: $isLoadingMore, hasMoreData: $hasMoreData, currentPage: $currentPage, searchQuery: $searchQuery)';
}


}

/// @nodoc
abstract mixin class _$TeacherGradeStateCopyWith<$Res> implements $TeacherGradeStateCopyWith<$Res> {
  factory _$TeacherGradeStateCopyWith(_TeacherGradeState value, $Res Function(_TeacherGradeState) _then) = __$TeacherGradeStateCopyWithImpl;
@override @useResult
$Res call({
 int currentStep, List<dynamic> classList, List<dynamic> subjectList, List<dynamic> todaySchedules, Map<String, dynamic>? selectedClass, Map<String, dynamic>? selectedSubject, bool isLoading, bool isLoadingMore, bool hasMoreData, int currentPage, String searchQuery
});




}
/// @nodoc
class __$TeacherGradeStateCopyWithImpl<$Res>
    implements _$TeacherGradeStateCopyWith<$Res> {
  __$TeacherGradeStateCopyWithImpl(this._self, this._then);

  final _TeacherGradeState _self;
  final $Res Function(_TeacherGradeState) _then;

/// Create a copy of TeacherGradeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentStep = null,Object? classList = null,Object? subjectList = null,Object? todaySchedules = null,Object? selectedClass = freezed,Object? selectedSubject = freezed,Object? isLoading = null,Object? isLoadingMore = null,Object? hasMoreData = null,Object? currentPage = null,Object? searchQuery = null,}) {
  return _then(_TeacherGradeState(
currentStep: null == currentStep ? _self.currentStep : currentStep // ignore: cast_nullable_to_non_nullable
as int,classList: null == classList ? _self._classList : classList // ignore: cast_nullable_to_non_nullable
as List<dynamic>,subjectList: null == subjectList ? _self._subjectList : subjectList // ignore: cast_nullable_to_non_nullable
as List<dynamic>,todaySchedules: null == todaySchedules ? _self._todaySchedules : todaySchedules // ignore: cast_nullable_to_non_nullable
as List<dynamic>,selectedClass: freezed == selectedClass ? _self._selectedClass : selectedClass // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,selectedSubject: freezed == selectedSubject ? _self._selectedSubject : selectedSubject // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,hasMoreData: null == hasMoreData ? _self.hasMoreData : hasMoreData // ignore: cast_nullable_to_non_nullable
as bool,currentPage: null == currentPage ? _self.currentPage : currentPage // ignore: cast_nullable_to_non_nullable
as int,searchQuery: null == searchQuery ? _self.searchQuery : searchQuery // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
