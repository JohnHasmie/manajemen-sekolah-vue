import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/network/dio_client.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/grades/presentation/screens/teacher_grade_input_screen.dart';

mixin GradeInputFilterDialogMixin on ConsumerState<GradePage> {
  String? get filterClassId;
  set filterClassId(String? value);

  String? get filterClassName;
  set filterClassName(String? value);

  String? get filterSubjectId;
  set filterSubjectId(String? value);

  String? get filterSubjectName;
  set filterSubjectName(String? value);

  Color get primaryColor;

  String get teacherId;

  List<Map<String, String>> getAvailableClasses();

  Future<void> loadData();

  /// Fetches only the subjects the current teacher teaches for the given
  /// class. Uses `/teacher/:id/subjects?class_id=` which merges pivot
  /// assignments with teaching schedule (see TeacherController@getSubjects)
  /// and returns `{success, data: [...]}`.
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

  Future<void> showFilterDialog(LanguageProvider lp) async {
    String? tClassId = filterClassId;
    // Mutable — the in-sheet class onSelected has to keep this in sync
    // with tClassId, otherwise Apply commits classId='7A-id' alongside
    // className=null and the outer header chip stays stuck on the
    // "+ Kelas" placeholder even though the filter is active.
    String? tClassName = filterClassName;
    String? tSubjectId = filterSubjectId;
    String? tSubjectName = filterSubjectName;
    List<dynamic> tSubjectList = [];

    // Once-flag for the in-builder prefetch below. Without this, the
    // fetch would re-fire on every StatefulBuilder rebuild.
    bool prefetchStarted = false;

    if (!mounted) return;

    showFilterSheet(
      context: context,
      title: 'Filter Nilai',
      primaryColor: primaryColor,
      onApply: () =>
          _applyFilter(context, tClassId, tClassName, tSubjectId, tSubjectName),
      onReset: () => FilterSheetHelpers.reset(context, () {
        setState(() {
          filterClassId = null;
          filterClassName = null;
          filterSubjectId = null;
          filterSubjectName = null;
        });
        loadData();
      }),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          // Run the subject prefetch on the first build only — the
          // outer `if (tClassId != null) { fetch.then(...) }` was the
          // original location, but at that point the StatefulBuilder
          // wasn't built yet so there was no setSS to capture. Doing
          // it here gives us a reliable setSS and the once-flag stops
          // it firing on every rebuild.
          if (!prefetchStarted && tClassId != null) {
            prefetchStarted = true;
            _fetchTeacherSubjectsForClass(tClassId!).then((list) {
              setSS(() {
                tSubjectList = list;
              });
            });
          }

          final availableClasses = getAvailableClasses();
          final classes = availableClasses
              .map(
                (c) => FilterOption<String>(value: c['id']!, label: c['name']!),
              )
              .toList();

          final subjects = tSubjectList.isNotEmpty
              ? tSubjectList
                    .map(
                      (s) => FilterOption<String>(
                        value: s['id']?.toString() ?? '',
                        label: s['name']?.toString() ?? '-',
                      ),
                    )
                    .toList()
              : <FilterOption<String>>[];

          return TeacherFilterContent(
            sections: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterSectionHeader(
                    title: 'Kelas',
                    icon: Icons.class_outlined,
                    primaryColor: primaryColor,
                  ),
                  FilterChipGrid<String>(
                    options: classes,
                    selectedValue: tClassId,
                    onSelected: (v) {
                      // Resolve the class name in the same setSS so
                      // Apply commits both classId AND className —
                      // otherwise the header chip stays stuck on its
                      // "+ Kelas" placeholder. See FilterSheetHelpers
                      // for the contract.
                      final pickedName = FilterSheetHelpers.labelForId(
                        availableClasses,
                        v,
                      );
                      setSS(() {
                        tClassId = v;
                        tClassName = pickedName;
                        tSubjectList = [];
                        tSubjectId = null;
                        tSubjectName = null;
                      });
                      if (v != null) {
                        _fetchTeacherSubjectsForClass(v).then((list) {
                          setSS(() {
                            tSubjectList = list;
                          });
                        });
                      }
                    },
                    selectedColor: primaryColor,
                  ),
                ],
              ),
              if (subjects.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: 'Mata Pelajaran',
                      icon: Icons.book_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: subjects,
                      selectedValue: tSubjectId,
                      onSelected: (v) {
                        setSS(() {
                          tSubjectId = v;
                          if (v != null) {
                            final sub = tSubjectList.firstWhere(
                              (s) => s['id']?.toString() == v,
                              orElse: () => <String, dynamic>{},
                            );
                            if (sub is Map && sub.isNotEmpty) {
                              tSubjectName = sub['name']?.toString();
                            } else {
                              tSubjectName = null;
                            }
                          } else {
                            tSubjectName = null;
                          }
                        });
                      },
                      selectedColor: primaryColor,
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }

  void _applyFilter(
    BuildContext ctx,
    String? classId,
    String? className,
    String? subjectId,
    String? subjectName,
  ) {
    Navigator.pop(ctx);
    setState(() {
      filterClassId = classId;
      filterClassName = className;
      filterSubjectId = subjectId;
      filterSubjectName = subjectName;
    });
    loadData();
  }
}
