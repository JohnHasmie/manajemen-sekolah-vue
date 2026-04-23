import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/students/presentation/controllers/admin_student_controller.dart';
import 'package:manajemensekolah/features/students/presentation/screens/admin_student_management_screen.dart';

/// Handles infinite scroll pagination for [StudentManagementScreenState].
mixin ScrollMixin on ConsumerState<StudentManagementScreen> {
  ScrollController get scrollController;
  int get currentPage;
  set currentPage(int value);
  int get perPage;
  bool get isLoadingMore;
  set isLoadingMore(bool value);
  bool get hasMoreData;
  set hasMoreData(bool value);
  List<dynamic> get students;
  set students(List<dynamic> value);
  List<String> get selectedClassIds;
  String? get selectedGradeLevel;
  String? get selectedGenderFilter;
  String? get selectedGuardian;
  String? get selectedStatusFilter;
  String get searchText;
  bool get isLoading;

  void _onScroll() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      if (!isLoadingMore && hasMoreData && !isLoading) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadMoreData() async {
    if (isLoadingMore || !hasMoreData) return;
    setState(() => isLoadingMore = true);

    final result = await ref
        .read(adminStudentControllerProvider)
        .loadMoreData(
          nextPage: currentPage + 1,
          perPage: perPage,
          selectedClassIds: selectedClassIds,
          selectedGradeLevel: selectedGradeLevel,
          selectedGenderFilter: selectedGenderFilter,
          selectedGuardian: selectedGuardian,
          selectedStatusFilter: selectedStatusFilter,
          searchText: searchText,
        );

    if (!mounted) return;

    if (result == null) {
      setState(() => isLoadingMore = false);
    } else {
      currentPage++;
      setState(() {
        students = [...students, ...result.additionalStudents];
        hasMoreData = result.hasMoreData;
        isLoadingMore = false;
      });
    }
  }
}
