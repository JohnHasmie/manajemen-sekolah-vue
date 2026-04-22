import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/target_selection_modal.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for building student-related UI
/// components.
///
/// Handles rendering of student checkboxes and
/// student list building.
mixin StudentUiBuilderMixin on State<TargetSelectionModal> {
  // Abstract getters
  Map<String, List<dynamic>> get selectedStudentsByClass;

  void _onStudentToggled(
    bool? value,
    Map<String, dynamic> student,
    String classId,
  ) {
    setState(() {
      final studentList = selectedStudentsByClass[classId] ?? [];
      if (value == true) {
        studentList.add(student);
      } else {
        studentList.removeWhere(
          (s) => s['id'].toString() == student['id'].toString(),
        );
      }
      selectedStudentsByClass[classId] = studentList;

      _syncClassSelection(classId);
    });
  }

  void _syncClassSelection(String classId) {
    final studentList = selectedStudentsByClass[classId];

    if (studentList?.isEmpty ?? true) {
      selectedClasses.removeWhere((k) => k['id'].toString() == classId);
    } else if (!selectedClasses.any((k) => k['id'].toString() == classId)) {
      selectedClasses.add(
        classList.firstWhere((k) => k['id'].toString() == classId),
      );
    }
  }

  // Abstract properties
  List<dynamic> get selectedClasses;
  List<dynamic> get classList => widget.classList;

  List<Widget> _buildStudentList(
    List<dynamic> filteredStudents,
    String classId,
  ) {
    if (filteredStudents.isEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Tidak ada siswa yang cocok',
            style: TextStyle(
              color: ColorUtils.slate400,
              fontStyle: FontStyle.italic,
              fontSize: 12,
            ),
          ),
        ),
      ];
    }
    return filteredStudents
        .map(
          (student) => buildStudentCheckbox(
            student: student as Map<String, dynamic>,
            classId: classId,
          ),
        )
        .toList();
  }

  Widget buildStudentCheckbox({
    required Map<String, dynamic> student,
    required String classId,
  }) {
    final isSelected = _isStudentSelected(student, classId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) => _onStudentToggled(value, student, classId),
        title: _buildStudentName(student),
        subtitle: _buildStudentNIS(student),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  bool _isStudentSelected(Map<String, dynamic> student, String classId) {
    return selectedStudentsByClass[classId]?.any(
          (s) => s['id'].toString() == student['id'].toString(),
        ) ==
        true;
  }

  Widget _buildStudentName(Map<String, dynamic> student) {
    final model = Student.fromJson(student);
    return Text(
      model.name.isNotEmpty ? model.name : 'Siswa',
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _buildStudentNIS(Map<String, dynamic> student) {
    final model = Student.fromJson(student);
    return Text(
      'NIS: ${model.studentNumber.isNotEmpty ? model.studentNumber : '-'}',
      style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
    );
  }
}
