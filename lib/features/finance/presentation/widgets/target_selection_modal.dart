// Bottom sheet modal for selecting payment target (classes and students).
//
// Extracted from admin_finance_screen.dart to reduce file size.
// Allows the admin to pick which classes/students a payment type targets.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';

/// A bottom sheet that lets the admin select target classes and students
/// for a payment type.
///
/// Receives class/student data from the parent, and calls [onSave] with
/// the built goal data when the user confirms.
class TargetSelectionModal extends StatefulWidget {
  final Map<String, dynamic>? paymentType;
  final Function(Map<String, dynamic>) onSave;
  final Color primaryColor;
  final List<dynamic> classList;
  final Map<String, List<dynamic>> studentsByClass;

  const TargetSelectionModal({
    super.key,
    this.paymentType,
    required this.onSave,
    required this.primaryColor,
    required this.classList,
    required this.studentsByClass,
  });

  @override
  State<TargetSelectionModal> createState() => _TargetSelectionModalState();
}

class _TargetSelectionModalState extends State<TargetSelectionModal> {
  List<dynamic> _selectedClasses = [];
  Map<String, List<dynamic>> _selectedStudentsByClass = {};
  final TextEditingController _searchStudentController =
      TextEditingController();

  Color get _primaryColor => widget.primaryColor;

  @override
  void initState() {
    super.initState();
    // If editing, load previously selected target data
    if (widget.paymentType?['goal'] != null) {
      _loadExistingGoal(widget.paymentType!['goal']);
    }
  }

  @override
  void dispose() {
    _searchStudentController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _parseGoal(dynamic goalData) {
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

  void _loadExistingGoal(dynamic goalData) {
    final goal = _parseGoal(goalData);

    if (goal['type'] == 'all') {
      _selectedClasses = List.from(widget.classList);
      for (var classItem in widget.classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          widget.studentsByClass[classId] ?? [],
        );
      }
    } else if (goal['type'] == 'custom') {
      _selectedClasses = widget.classList.where((classItem) {
        return goal['kelas']?.contains(classItem['id'].toString()) == true;
      }).toList();

      for (var classId in goal['kelas'] ?? []) {
        _selectedStudentsByClass[classId] = (goal['siswa']?[classId] ?? [])
            .map(_findStudentById)
            .where((student) => student != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
    }
  }

  dynamic _findStudentById(String studentId) {
    for (var studentList in widget.studentsByClass.values) {
      for (var student in studentList) {
        if (student['id'].toString() == studentId) {
          return student;
        }
      }
    }
    return null;
  }

  int _getTotalStudents() {
    return widget.studentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );
  }

  void _selectAllKelas() {
    setState(() {
      _selectedClasses = List.from(widget.classList);
      for (var classItem in widget.classList) {
        final classId = classItem['id'].toString();
        _selectedStudentsByClass[classId] = List.from(
          widget.studentsByClass[classId] ?? [],
        );
      }
    });
  }

  void _clearAllSelection() {
    setState(() {
      _selectedClasses.clear();
      _selectedStudentsByClass.clear();
    });
  }

  Map<String, dynamic> _buildGoalData() {
    final totalClasses = _selectedClasses.length;
    final totalStudents = _getTotalStudents();
    final selectedStudentCount = _selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );

    if (totalClasses == widget.classList.length &&
        selectedStudentCount == totalStudents) {
      return {'type': 'all', 'description': 'Semua siswa di semua kelas'};
    }

    final classIds = _selectedClasses.map((k) => k['id'].toString()).toList();
    final studentMap = <String, List<String>>{};

    _selectedStudentsByClass.forEach((classId, studentList) {
      studentMap[classId] =
          studentList.map((s) => s['id'].toString()).toList();
    });

    return {
      'type': 'custom',
      'kelas': classIds,
      'siswa': studentMap,
      'description': '$selectedStudentCount siswa di $totalClasses kelas',
    };
  }

  Widget _buildClassListForSelection() {
    final searchTerm = _searchStudentController.text.toLowerCase();

    return ListView.builder(
      itemCount: widget.classList.length,
      itemBuilder: (context, index) {
        final classItem = widget.classList[index];
        final classId = classItem['id'].toString();
        final isClassSelected = _selectedClasses.any(
          (k) => k['id'].toString() == classId,
        );
        final studentList = widget.studentsByClass[classId] ?? [];

        final filteredStudents = studentList.where((student) {
          final nama = student['name']?.toString().toLowerCase() ?? '';
          final nis = student['student_number']?.toString().toLowerCase() ?? '';
          return searchTerm.isEmpty ||
              nama.contains(searchTerm) ||
              nis.contains(searchTerm);
        }).toList();

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: ColorUtils.slate200),
          ),
          child: ExpansionTile(
            leading: Checkbox(
              value: isClassSelected,
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedClasses.add(classItem);
                    _selectedStudentsByClass[classId] =
                        List.from(studentList);
                  } else {
                    _selectedClasses.removeWhere(
                      (k) => k['id'].toString() == classId,
                    );
                    _selectedStudentsByClass.remove(classId);
                  }
                });
              },
            ),
            title: Text(
              classItem['name'] ?? 'Kelas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isClassSelected ? _primaryColor : ColorUtils.slate900,
              ),
            ),
            subtitle: Text(
              '${studentList.length} ${languageProvider.getTranslatedText(AppLocalizations.students)}',
              style: TextStyle(fontSize: 12),
            ),
            trailing: isClassSelected
                ? Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedStudentsByClass[classId]?.length ?? 0}/${studentList.length}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : null,
            children: [
              if (filteredStudents.isEmpty)
                Padding(
                  padding: EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    AppLocalizations.noStudentsMatchSearch.tr,
                    style: TextStyle(
                      color: ColorUtils.slate400,
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                )
              else
                ...filteredStudents.map(
                  (student) => _buildStudentCheckbox(
                    student: student,
                    classId: classId,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentCheckbox({
    required Map<String, dynamic> student,
    required String classId,
  }) {
    final isSelected =
        _selectedStudentsByClass[classId]?.any(
              (s) => s['id'].toString() == student['id'].toString(),
            ) ==
            true;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColorUtils.slate50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (value) {
          setState(() {
            final studentList = _selectedStudentsByClass[classId] ?? [];
            if (value == true) {
              studentList.add(student);
            } else {
              studentList.removeWhere(
                (s) => s['id'].toString() == student['id'].toString(),
              );
            }
            _selectedStudentsByClass[classId] = studentList;

            if (studentList.isEmpty) {
              _selectedClasses.removeWhere(
                (k) => k['id'].toString() == classId,
              );
            } else if (!_selectedClasses.any(
              (k) => k['id'].toString() == classId,
            )) {
              _selectedClasses.add(
                widget.classList
                    .firstWhere((k) => k['id'].toString() == classId),
              );
            }
          });
        },
        title:
            Text(student['name'] ?? 'Siswa', style: TextStyle(fontSize: 14)),
        subtitle: Text(
          'NIS: ${student['student_number'] ?? '-'}',
          style: TextStyle(fontSize: 11, color: ColorUtils.slate600),
        ),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }

  Widget _buildSelectionSummary() {
    final int totalClasses = _selectedClasses.length;
    final int totalStudents = _selectedStudentsByClass.values.fold(
      0,
      (sum, studentList) => sum + studentList.length,
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Terpilih:',
              style: TextStyle(fontSize: 12, color: ColorUtils.slate600),
            ),
            Text(
              '$totalClasses Kelas • $totalStudents Siswa',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _primaryColor,
              ),
            ),
          ],
        ),
        if (totalClasses == widget.classList.length &&
            totalStudents == _getTotalStudents())
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: ColorUtils.success600.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Semua Siswa',
              style: TextStyle(
                fontSize: 10,
                color: ColorUtils.success600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: _primaryColor,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.groups, color: Colors.white, size: 24),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Pilih Tujuan Pembayaran',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: Colors.white),
                  onPressed: () => AppNavigator.pop(context),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: Container(
              decoration: BoxDecoration(
                color: ColorUtils.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: ColorUtils.slate200),
              ),
              child: TextField(
                controller: _searchStudentController,
                decoration: InputDecoration(
                  hintText: 'Cari siswa...',
                  prefixIcon: Icon(Icons.search, color: ColorUtils.slate400),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
          ),

          // Quick Actions
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _selectAllKelas,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: _primaryColor),
                    ),
                    child: Text(
                      'Pilih Semua Kelas',
                      style: TextStyle(fontSize: 12, color: _primaryColor),
                    ),
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: _clearAllSelection,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      side: BorderSide(color: ColorUtils.error600),
                    ),
                    child: Text(
                      'Hapus Semua',
                      style:
                          TextStyle(fontSize: 12, color: ColorUtils.error600),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Class list
          Expanded(child: _buildClassListForSelection()),

          // Footer with summary
          Container(
            padding: EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: ColorUtils.slate50,
              border: Border(top: BorderSide(color: ColorUtils.slate200)),
            ),
            child: Column(
              children: [
                _buildSelectionSummary(),
                SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => AppNavigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(AppLocalizations.cancel.tr),
                      ),
                    ),
                    SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final goal = _buildGoalData();
                          widget.onSave(goal);
                          AppNavigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          AppLocalizations.save.tr,
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
