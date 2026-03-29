// Dialog for selecting one or more grade items (from history) and computing
// their average.  Extracted from `_showGradeSelectionDialog` in
// `teacher_grade_recap_screen.dart`.
//
// Think of it like a Vue child component that receives props (`rawGrades`,
// `studentClassId`, `type`) and emits an event (`onAverageSelected`) with
// the computed average value.

import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/router/app_navigator.dart';

/// Shows a dialog that lets the user pick grade items and returns the average.
///
/// [rawGrades] -- full list of raw grade records (from the API).
/// [studentClassId] -- which student-class row we are editing.
/// [type] -- column type: 'bab', 'uts', 'uas', 'skill_score', etc.
/// [chapterIndex] -- only needed when [type] == 'bab'.
/// [onAverageSelected] -- called with the computed average when the user
///   confirms.  The caller is responsible for writing the value into its own
///   state (like `_updateTableValue`).
void showGradeSelectionDialog({
  required BuildContext context,
  required List<dynamic> rawGrades,
  required String studentClassId,
  required String type,
  int? chapterIndex,
  required void Function(double average) onAverageSelected,
}) {
  // ---------- Filter grades that belong to this student + type ----------
  final studentGrades = rawGrades.where((g) {
    final gStudentClassId =
        (g['student_class_id'] ?? g['siswa_kelas_id'])?.toString();
    return gStudentClassId == studentClassId;
  }).toList();

  List<dynamic> options = [];
  if (type == 'bab') {
    options = studentGrades.where((g) {
      final typeStr =
          (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
      return [
        'uh',
        'tugas',
        'praktek',
        'formatif',
        'sumatif',
      ].contains(typeStr);
    }).toList();
  } else {
    options = studentGrades.where((g) {
      final typeStr =
          (g['type'] ?? g['jenis'])?.toString().toLowerCase() ?? '';
      if (type.toLowerCase() == 'uts') {
        return typeStr == 'uts' || typeStr == 'pts';
      } else if (type.toLowerCase() == 'uas') {
        return typeStr == 'uas' || typeStr == 'pas';
      }
      return typeStr == type.toLowerCase();
    }).toList();
  }

  // ---------- Show the dialog ----------
  showDialog(
    context: context,
    builder: (context) {
      final List<dynamic> selectedItems = [];
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(
              type == 'bab'
                  ? 'Pilih Nilai Harian/UH'
                  : 'Pilih Nilai ${type.toUpperCase()}',
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: options.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(AppLocalizations.noGradeDataFound.tr),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(
                            'Pilih satu atau lebih nilai untuk dirata-ratakan.',
                            style: TextStyle(
                              fontSize: 12,
                              color: ColorUtils.slate500,
                            ),
                          ),
                        ),
                        Flexible(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: options.length,
                            itemBuilder: (context, index) {
                              final g = options[index];
                              final score =
                                  (g['score'] ?? g['nilai'] ?? '0').toString();
                              final title =
                                  g['assessment']?['title'] ??
                                  g['title'] ??
                                  g['judul'] ??
                                  'Nilai';
                              final date =
                                  g['assessment']?['date'] ??
                                  g['date'] ??
                                  g['tanggal'] ??
                                  '';
                              final isSelected = selectedItems.contains(g);

                              return CheckboxListTile(
                                title: Text('$title ($score)'),
                                subtitle: Text(date),
                                value: isSelected,
                                activeColor: ColorUtils.primary,
                                onChanged: (val) {
                                  setDialogState(() {
                                    if (val == true) {
                                      selectedItems.add(g);
                                    } else {
                                      selectedItems.remove(g);
                                    }
                                  });
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => AppNavigator.pop(context),
                child: Text(AppLocalizations.cancel.tr),
              ),
              ElevatedButton(
                onPressed: selectedItems.isEmpty
                    ? null
                    : () {
                        double sum = 0;
                        for (var item in selectedItems) {
                          final s =
                              (item['score'] ?? item['nilai'] ?? '0')
                                  .toString();
                          sum += double.tryParse(s) ?? 0;
                        }
                        final average = sum / selectedItems.length;
                        onAverageSelected(average);
                        AppNavigator.pop(context);
                      },
                child: Text('Gunakan Rata-rata'),
              ),
            ],
          );
        },
      );
    },
  );
}
