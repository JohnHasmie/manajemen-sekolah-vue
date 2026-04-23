import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/target_selection_modal.dart';

/// Mixin for managing selection state and building goal data.
///
/// Handles loading existing selections, parsing goal data, and
/// building the final goal map to be saved.
mixin SelectionLogicMixin on State<TargetSelectionModal> {
  // Abstract getters - implement in the state
  List<dynamic> get selectedClasses;
  Map<String, List<dynamic>> get selectedStudentsByClass;
  List<dynamic> get classList => widget.classList;
  Map<String, List<dynamic>> get studentsByClass => widget.studentsByClass;

  Map<String, dynamic> parseGoal(dynamic goalData) {
    if (goalData == null) return {};
    if (goalData is Map<String, dynamic>) return goalData;
    if (goalData is String) {
      try {
        return json.decode(goalData) as Map<String, dynamic>;
      } catch (e) {
        AppLogger.error('finance', e);
        return {};
      }
    }
    return {};
  }

  void loadExistingGoal(dynamic goalData) {
    final goal = parseGoal(goalData);

    if (goal['type'] == 'all') {
      _loadAllSelection(goal);
    } else if (goal['type'] == 'custom') {
      _loadCustomSelection(goal);
    }
  }

  void _loadAllSelection(Map<String, dynamic> goal) {
    selectedClasses.clear();
    selectedClasses.addAll(classList);
    for (final classItem in classList) {
      final classId = classItem['id'].toString();
      selectedStudentsByClass[classId] = List.from(
        studentsByClass[classId] ?? [],
      );
    }
  }

  void _loadCustomSelection(Map<String, dynamic> goal) {
    selectedClasses.clear();
    selectedClasses.addAll(
      classList.where((classItem) {
        return goal['classes']?.contains(classItem['id'].toString()) == true;
      }),
    );

    for (final classId in goal['classes'] ?? []) {
      selectedStudentsByClass[classId] = (goal['students']?[classId] ?? [])
          .map((id) => _findStudentById(id.toString()))
          .where((student) => student != null)
          .cast<Map<String, dynamic>>()
          .toList();
    }
  }

  dynamic _findStudentById(String studentId) {
    for (final studentList in studentsByClass.values) {
      for (final student in studentList) {
        if (student['id'].toString() == studentId) {
          return student;
        }
      }
    }
    return null;
  }

  int getTotalStudents() {
    return studentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );
  }

  Map<String, dynamic> buildGoalData() {
    final totalClasses = selectedClasses.length;
    final totalStudents = getTotalStudents();
    final selectedStudentCount = selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );

    if (totalClasses == classList.length &&
        selectedStudentCount == totalStudents) {
      return {'type': 'all', 'description': 'Semua siswa di semua kelas'};
    }

    final classIds = selectedClasses.map((k) => k['id'].toString()).toList();
    final studentMap = <String, List<String>>{};

    selectedStudentsByClass.forEach((classId, studentList) {
      studentMap[classId] = studentList.map((s) => s['id'].toString()).toList();
    });

    return {
      'type': 'custom',
      'classes': classIds,
      'students': studentMap,
      'description': '$selectedStudentCount siswa di $totalClasses kelas',
    };
  }
}
