import 'package:flutter/material.dart';

/// Mixin for navigation-related abstract properties.
mixin NavigationHelperMixin {
  String? get selectedTeacherId;
  String? get selectedTeacherName;
  List<dynamic> get lessonPlanList;
  List<dynamic> get teacherList;

  void setState(VoidCallback fn);

  TextEditingController get searchController;
  int get currentPage;
  set currentPage(int value);
}
