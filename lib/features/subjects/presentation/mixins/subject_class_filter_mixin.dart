// Filtering, sorting and search logic for subject classes.
//
// The screen exposes two filter dimensions plus a sort key:
//   • search    — full-text over name + tingkat + wali kelas
//   • status    — All / Assigned / Unassigned
//   • sort      — assignedFirst (default) / unassignedFirst / nameAsc /
//                 nameDesc / gradeAsc
//
// Default sort puts assigned rows on top so admin sees the existing
// roster + any "wali belum diset" warnings before scrolling into the
// unassigned tail. Match the SubjectClassSort enum used by the
// combined filter sheet.
import 'package:flutter/material.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';

/// Sort key for the subject-class list.
enum SubjectClassSort {
  assignedFirst,
  unassignedFirst,
  nameAsc,
  nameDesc,
  gradeAsc,
}

mixin SubjectClassFilterMixin {
  late TextEditingController searchController;
  late String selectedFilter;
  SubjectClassSort selectedSort = SubjectClassSort.assignedFirst;

  /// Gets the filtered + sorted classes based on the current search /
  /// status filter / sort key.
  List<dynamic> getFilteredClasses(List<dynamic> availableClasses) {
    final searchTerm = searchController.text.toLowerCase();

    // Step 1: filter
    final filtered = availableClasses.where((classItem) {
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

    // Step 2: sort. We never mutate the caller's list — toList() above
    // copies the iterable so the sort below is safe.
    filtered.sort((a, b) {
      final modelA = Classroom.fromJson(a as Map<String, dynamic>);
      final modelB = Classroom.fromJson(b as Map<String, dynamic>);
      final aAssigned = isClassAssigned(modelA.id) ? 1 : 0;
      final bAssigned = isClassAssigned(modelB.id) ? 1 : 0;

      switch (selectedSort) {
        case SubjectClassSort.assignedFirst:
          if (aAssigned != bAssigned) return bAssigned - aAssigned;
          return _gradeThenNameCompare(modelA, modelB);
        case SubjectClassSort.unassignedFirst:
          if (aAssigned != bAssigned) return aAssigned - bAssigned;
          return _gradeThenNameCompare(modelA, modelB);
        case SubjectClassSort.nameAsc:
          return modelA.name.toLowerCase().compareTo(
            modelB.name.toLowerCase(),
          );
        case SubjectClassSort.nameDesc:
          return modelB.name.toLowerCase().compareTo(
            modelA.name.toLowerCase(),
          );
        case SubjectClassSort.gradeAsc:
          return _gradeThenNameCompare(modelA, modelB);
      }
    });

    return filtered;
  }

  /// Secondary tie-breaker: tingkat ascending, then name ascending.
  /// Tingkat is a string (e.g. "7", "VIII", "X") so we sort numerically
  /// when both sides parse and lexically otherwise.
  int _gradeThenNameCompare(Classroom a, Classroom b) {
    final ga = (a.gradeLevel ?? '').trim();
    final gb = (b.gradeLevel ?? '').trim();
    final na = int.tryParse(ga);
    final nb = int.tryParse(gb);
    int gradeCmp;
    if (na != null && nb != null) {
      gradeCmp = na.compareTo(nb);
    } else {
      gradeCmp = ga.toLowerCase().compareTo(gb.toLowerCase());
    }
    if (gradeCmp != 0) return gradeCmp;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  }

  /// Checks if a class is assigned to the subject
  bool isClassAssigned(String classId);
}
