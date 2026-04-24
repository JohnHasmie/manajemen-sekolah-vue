import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/attendance/presentation/screens/teacher_attendance_screen.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_data_mixin.dart';
import 'package:manajemensekolah/features/attendance/presentation/mixins/attendance_dialog_shared_mixin.dart';

/// Handles the "Add Attendance" bottom-sheet dialog flow
mixin AttendanceDialogAddMixin
    on
        ConsumerState<AttendancePage>,
        AttendanceDataMixin,
        AttendanceDialogSharedMixin {
  // ── Abstract state accessors ──

  @override
  Color get primaryColor;

  void openInputSheet({
    required String classId,
    required String className,
    required String subjectId,
    required String subjectName,
  });

  /// Fetches only subjects the current teacher teaches for the given class.
  /// `/teacher/:id/subjects?class_id=` merges assignments + teaching
  /// schedule; see TeacherController@getSubjects.
  Future<List<dynamic>> _fetchTeacherSubjectsForClass(String classId) async {
    try {
      final r = await dioClient.get(
        '/teacher/$teacherId/subjects',
        queryParameters: {'class_id': classId},
      );
      final raw = r.data;
      if (raw is List) return raw;
      if (raw is Map && raw['data'] is List) return raw['data'] as List;
      return [];
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════════
  // ADD ATTENDANCE FLOW
  // ═══════════════════════════════════════════

  void showAddAttendanceFlow(LanguageProvider lp) {
    String? pickClassId;
    String? pickClassName;
    String? pickSubjectId;
    String? pickSubjectName;
    List<dynamic> pickSubjectList = [];

    showFilterSheet(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Take Attendance',
        'id': 'Ambil Presensi',
      }),
      primaryColor: primaryColor,
      onApply: () {
        Navigator.pop(context);
        if (pickClassId != null && pickSubjectId != null) {
          openInputSheet(
            classId: pickClassId!,
            className: pickClassName ?? '',
            subjectId: pickSubjectId!,
            subjectName: pickSubjectName ?? '',
          );
        }
      },
      onReset: () {
        // Not typically used for add flow, but keeps API consistent
      },
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          final classes = classList
              .map(
                (c) => FilterOption<String>(
                  value: c['id']?.toString() ?? '',
                  label: c['name']?.toString() ?? c['nama']?.toString() ?? '-',
                ),
              )
              .toList();

          final subjects = pickSubjectList.isNotEmpty
              ? pickSubjectList
                    .map(
                      (s) => FilterOption<String>(
                        value: s['id']?.toString() ?? '',
                        label:
                            s['name']?.toString() ??
                            s['nama']?.toString() ??
                            '-',
                      ),
                    )
                    .toList()
              : <FilterOption<String>>[];

          return TeacherFilterContent(
            sections: [
              FilterChipGrid<String>(
                title: lp.getTranslatedText({
                  'en': 'Select Class',
                  'id': 'Pilih Kelas',
                }),
                options: classes,
                selectedValue: pickClassId,
                onSelected: (v) {
                  setSS(() {
                    pickClassId = v;
                    if (v != null) {
                      final cls = classList.firstWhere(
                        (c) => c['id']?.toString() == v,
                        orElse: () => <String, dynamic>{},
                      );
                      if (cls is Map && cls.isNotEmpty) {
                        pickClassName = cls['name']?.toString();
                      } else {
                        pickClassName = null;
                      }
                    } else {
                      pickClassName = null;
                    }
                    pickSubjectList = [];
                    pickSubjectId = null;
                    pickSubjectName = null;
                  });
                  if (v != null) {
                    _fetchTeacherSubjectsForClass(v).then((list) {
                      setSS(() {
                        pickSubjectList = list;
                      });
                    });
                  }
                },
                selectedColor: primaryColor,
              ),
              if (subjects.isNotEmpty)
                FilterChipGrid<String>(
                  title: lp.getTranslatedText({
                    'en': 'Select Subject',
                    'id': 'Pilih Mapel',
                  }),
                  options: subjects,
                  selectedValue: pickSubjectId,
                  onSelected: (v) {
                    setSS(() {
                      pickSubjectId = v;
                      if (v != null) {
                        final sub = pickSubjectList.firstWhere(
                          (s) => s['id']?.toString() == v,
                          orElse: () => <String, dynamic>{},
                        );
                        if (sub is Map && sub.isNotEmpty) {
                          pickSubjectName = sub['name']?.toString();
                        } else {
                          pickSubjectName = null;
                        }
                      } else {
                        pickSubjectName = null;
                      }
                    });
                  },
                  selectedColor: primaryColor,
                ),
            ],
          );
        },
      ),
    );
  }
}
