import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/features/classrooms/domain/models/classroom.dart';
import 'package:manajemensekolah/features/finance/presentation/widgets/target_selection_modal.dart';
import 'package:manajemensekolah/features/students/domain/models/student.dart';

/// Mixin for building class selection UI
/// components.
///
/// Handles rendering of class list, class tiles,
/// and selection summary.
mixin UiBuilderMixin on State<TargetSelectionModal> {
  // Abstract getters and methods
  List<dynamic> get selectedClasses;
  Map<String, List<dynamic>> get selectedStudentsByClass;
  TextEditingController get searchStudentController;
  Color get primaryColor;
  LanguageProvider get languageProvider;
  List<dynamic> get classList => widget.classList;
  Map<String, List<dynamic>> get studentsByClass => widget.studentsByClass;

  int getTotalStudents();

  List<Widget> _buildStudentList(
    List<dynamic> filteredStudents,
    String classId,
  );

  Widget buildStudentCheckbox({
    required Map<String, dynamic> student,
    required String classId,
  });

  Widget buildClassListForSelection() {
    final searchTerm = searchStudentController.text.toLowerCase();

    return ListView.builder(
      itemCount: classList.length,
      itemBuilder: (context, index) {
        final classItem = classList[index];
        return _buildClassListItem(classItem, searchTerm);
      },
    );
  }

  Widget _buildClassListItem(
    Map<String, dynamic> classItem,
    String searchTerm,
  ) {
    final classId = classItem['id'].toString();
    final isClassSelected = selectedClasses.any(
      (k) => k['id'].toString() == classId,
    );
    final studentList = studentsByClass[classId] ?? [];

    final filteredStudents = _filterStudents(studentList, searchTerm);

    return _buildClassTile(
      classItem: classItem,
      classId: classId,
      isSelected: isClassSelected,
      studentList: studentList,
      filteredStudents: filteredStudents,
    );
  }

  List<dynamic> _filterStudents(List<dynamic> studentList, String searchTerm) {
    return studentList.where((student) {
      final model = Student.fromJson(student as Map<String, dynamic>);
      final name = model.name.toLowerCase();
      final nis = model.studentNumber.toLowerCase();
      return searchTerm.isEmpty ||
          name.contains(searchTerm) ||
          nis.contains(searchTerm);
    }).toList();
  }

  Widget _buildClassTile({
    required Map<String, dynamic> classItem,
    required String classId,
    required bool isSelected,
    required List<dynamic> studentList,
    required List<dynamic> filteredStudents,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: _buildTileDecoration(),
      child: ExpansionTile(
        leading: _buildClassCheckbox(
          isSelected,
          classItem,
          classId,
          studentList,
        ),
        title: _buildClassTitle(classItem, isSelected),
        subtitle: _buildClassSubtitle(studentList),
        trailing: isSelected
            ? _buildStudentCountBadge(classId, studentList.length)
            : null,
        children: _buildStudentList(filteredStudents, classId),
      ),
    );
  }

  BoxDecoration _buildTileDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.all(Radius.circular(12)),
      border: Border.all(color: ColorUtils.slate200),
    );
  }

  Widget _buildClassCheckbox(
    bool isSelected,
    Map<String, dynamic> classItem,
    String classId,
    List<dynamic> studentList,
  ) {
    return Checkbox(
      value: isSelected,
      onChanged: (value) =>
          _onClassToggled(value, classItem, classId, studentList),
    );
  }

  Widget _buildClassTitle(Map<String, dynamic> classItem, bool isSelected) {
    return Text(
      Classroom.fromJson(classItem).name,
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: isSelected ? primaryColor : ColorUtils.slate900,
      ),
    );
  }

  Widget _buildClassSubtitle(List<dynamic> studentList) {
    return Text(
      '${studentList.length} '
      '${languageProvider.getTranslatedText(AppLocalizations.students)}',
      style: const TextStyle(fontSize: 12),
    );
  }

  Widget _buildStudentCountBadge(String classId, int totalCount) {
    final selectedCount = selectedStudentsByClass[classId]?.length ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        '$selectedCount/$totalCount',
        style: TextStyle(
          fontSize: 10,
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _onClassToggled(
    bool? value,
    Map<String, dynamic> classItem,
    String classId,
    List<dynamic> studentList,
  ) {
    setState(() {
      if (value == true) {
        selectedClasses.add(classItem);
        selectedStudentsByClass[classId] = List.from(studentList);
      } else {
        selectedClasses.removeWhere((k) => k['id'].toString() == classId);
        selectedStudentsByClass.remove(classId);
      }
    });
  }

  Widget buildSelectionSummary() {
    final int totalClasses = selectedClasses.length;
    final int totalStudents = _calculateTotalSelected();

    final isAllSelected = _isAllSelected(totalClasses, totalStudents);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSummaryColumn(totalClasses, totalStudents),
        if (isAllSelected) _buildAllSelectedBadge(),
      ],
    );
  }

  int _calculateTotalSelected() {
    return selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );
  }

  bool _isAllSelected(int totalClasses, int totalStudents) {
    return totalClasses == classList.length &&
        totalStudents == getTotalStudents();
  }

  Widget _buildSummaryColumn(int totalClasses, int totalStudents) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Total Terpilih:',
          style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
        ),
        Text(
          '$totalClasses Kelas • '
          '$totalStudents Siswa',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildAllSelectedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: ColorUtils.success600.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.all(Radius.circular(8)),
      ),
      child: Text(
        'Semua Siswa',
        style: TextStyle(
          fontSize: 10,
          color: ColorUtils.success600,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
