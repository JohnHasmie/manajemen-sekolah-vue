import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/features/grades/presentation/widgets/grade_input_dialog.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin for grade input form submission and state management.
mixin GradeInputFormMixin on State<GradeInputDialog> {
  // Abstract getters/setters that must be implemented by the state
  String get selectedType;
  DateTime get selectedDate;
  TextEditingController get titleController;
  Map<String, TextEditingController> get scoreControllers;
  Map<String, FocusNode> get scoreFocusNodes;
  bool get isSaving;
  List<String> get types;
  Map<String, String> get typeLabels;

  void setSelectedType(String type);
  void setSelectedDate(DateTime date);
  void setIsSaving(bool value);

  String formatDate(DateTime d) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  void focusStudent(int index) {
    if (index >= 0 && index < widget.studentList.length) {
      scoreFocusNodes[widget.studentList[index].id]?.requestFocus();
    }
  }

  Future<void> submit() async {
    final entries = scoreControllers.entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .toList();
    if (entries.isEmpty) return;

    setIsSaving(true);
    try {
      int saved = 0;
      final dateStr =
          '${selectedDate.year}-'
          '${selectedDate.month.toString().padLeft(2, '0')}-'
          '${selectedDate.day.toString().padLeft(2, '0')}';

      for (final entry in entries) {
        final student = widget.studentList.firstWhere((s) => s.id == entry.key);
        final score = int.tryParse(entry.value.text.trim());
        if (score == null) continue;

        await dioClient.post(
          '/grades',
          data: {
            'student_id': student.id,
            'student_class_id': student.studentClassId ?? student.id,
            'teacher_id': Teacher.fromJson(widget.teacher).id,
            'subject_id': widget.subject['id'],
            'type': selectedType,
            'score': score,
            'date': dateStr,
            'title': titleController.text.isNotEmpty
                ? titleController.text
                : null,
          },
        );
        saved++;
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        SnackBarUtils.showSuccess(context, '$saved nilai berhasil disimpan');
      }
    } catch (e) {
      if (mounted) {
        SnackBarUtils.showError(context, ErrorUtils.getFriendlyMessage(e));
      }
    } finally {
      if (mounted) setIsSaving(false);
    }
  }
}
