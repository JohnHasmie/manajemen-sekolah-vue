import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/admin_class_activity_screen.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin providing navigation and filter methods.
mixin ClassActivityNavigationMixin on ConsumerState<AdminClassActivityScreen> {
  List<dynamic> get teacherList;
  List<dynamic> get subjectList;
  List<dynamic> get activityList;

  String? get selectedTeacherId;
  set selectedTeacherId(String? value);

  String? get selectedTeacherName;
  set selectedTeacherName(String? value);

  String? get selectedSubjectId;
  set selectedSubjectId(String? value);

  String? get selectedSubjectName;
  set selectedSubjectName(String? value);

  bool get showTeacherList;
  set showTeacherList(bool value);

  bool get showSubjectList;
  set showSubjectList(bool value);

  TextEditingController get searchController;

  Future<void> loadSubjectsByTeacher(
    String teacherId,
    String teacherName, {
    bool useCache = true,
  });

  Future<void> loadActivitiesBySubject(
    String subjectId,
    String subjectName, {
    bool useCache = true,
  });

  void backToTeacherList() {
    setState(() {
      showTeacherList = true;
      showSubjectList = false;
      selectedTeacherId = null;
      selectedTeacherName = null;
      selectedSubjectId = null;
      selectedSubjectName = null;
      searchController.clear();
    });
  }

  void backToSubjectList() {
    setState(() {
      showTeacherList = false;
      showSubjectList = true;
      selectedSubjectId = null;
      selectedSubjectName = null;
      searchController.clear();
    });
  }

  List<dynamic> getFilteredTeachers() {
    final searchTerm = searchController.text.toLowerCase();
    return teacherList.where((teacher) {
      final model = Teacher.fromJson(teacher as Map<String, dynamic>);
      final teacherName = model.name.toLowerCase();
      final teacherEmail = model.email.toLowerCase();
      final teacherSubject =
          teacher['subject_name']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          teacherName.contains(searchTerm) ||
          teacherEmail.contains(searchTerm) ||
          teacherSubject.contains(searchTerm);
    }).toList();
  }

  List<dynamic> getFilteredSubjects() {
    final searchTerm = searchController.text.toLowerCase();
    return subjectList.where((subject) {
      final name = Subject.fromJson(subject as Map<String, dynamic>)
          .name
          .toLowerCase();
      return searchTerm.isEmpty || name.contains(searchTerm);
    }).toList();
  }

  List<dynamic> getFilteredActivities() {
    final searchTerm = searchController.text.toLowerCase();
    return activityList.where((activity) {
      final title = activity['title']?.toString().toLowerCase() ?? '';
      final subject = activity['subject_name']?.toString().toLowerCase() ?? '';
      final className = activity['class_name']?.toString().toLowerCase() ?? '';
      final description =
          activity['description']?.toString().toLowerCase() ?? '';

      return searchTerm.isEmpty ||
          title.contains(searchTerm) ||
          subject.contains(searchTerm) ||
          className.contains(searchTerm) ||
          description.contains(searchTerm);
    }).toList();
  }
}
