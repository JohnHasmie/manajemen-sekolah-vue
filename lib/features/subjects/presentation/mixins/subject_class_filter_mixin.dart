// Filtering and search logic for subject classes
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

mixin SubjectClassFilterMixin {
  late TextEditingController searchController;
  late String selectedFilter;

  /// Gets filtered classes based on search and filter
  List<dynamic> getFilteredClasses(List<dynamic> availableClasses) {
    final searchTerm = searchController.text.toLowerCase();
    return availableClasses.where((classItem) {
      final model = Classroom.fromJson(classItem as Map<String, dynamic>);
      final className = model.name.toLowerCase();
      final classLevel = (model.gradeLevel ?? '').toLowerCase();
      final homeroomTeacher = (model.homeroomTeacherName ?? '').toLowerCase();

      final matchesSearch =
          searchTerm.isEmpty ||
          className.contains(searchTerm) ||
          classLevel.contains(searchTerm) ||
          homeroomTeacher.contains(searchTerm);

      final isAssigned = isClassAssigned(model.id);

      final matchesFilter =
          selectedFilter == 'All' ||
          (selectedFilter == 'Assigned' && isAssigned) ||
          (selectedFilter == 'Unassigned' && !isAssigned);

      return matchesSearch && matchesFilter;
    }).toList();
  }

  /// Checks if a class is assigned to the subject
  bool isClassAssigned(String classId);
}
