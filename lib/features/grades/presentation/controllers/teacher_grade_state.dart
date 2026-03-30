import 'package:freezed_annotation/freezed_annotation.dart';

part 'teacher_grade_state.freezed.dart';

@freezed
class TeacherGradeState with _$TeacherGradeState {
  const factory TeacherGradeState({
    @Default(0) int currentStep, // 0: Class List, 1: Subject List
    @Default([]) List<dynamic> classList,
    @Default([]) List<dynamic> subjectList,
    @Default([]) List<dynamic> todaySchedules,
    Map<String, dynamic>? selectedClass,
    Map<String, dynamic>? selectedSubject,
    @Default(true) bool isLoading,
    @Default(false) bool isLoadingMore,
    @Default(true) bool hasMoreData,
    @Default(1) int currentPage,
    @Default('') String searchQuery,
  }) = _TeacherGradeState;
}

class TeacherGradeParams {
  final Map<String, dynamic> teacher;

  TeacherGradeParams({required this.teacher});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TeacherGradeParams && other.teacher['id'] == teacher['id'];
  }

  @override
  int get hashCode => teacher['id'].hashCode;
}
