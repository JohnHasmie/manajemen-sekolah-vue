import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
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

  /// True when the screen is in wali kelas view. Drives whether the
  /// Kelas chip set comes from `homeroomClasses` or `teachingClasses`.
  bool get isHomeroomView;

  Future<void> loadData();

  Future<void> showFilterDialog(LanguageProvider lp) async {
    String? tClassId = filterClassId;
    // Mutable — the in-sheet class onSelected has to keep this in sync
    // with tClassId, otherwise Apply commits classId='7A-id' alongside
    // className=null and the outer header chip stays stuck on the
    // "+ Kelas" placeholder even though the filter is active.
    String? tClassName = filterClassName;
    String? tSubjectId = filterSubjectId;
    String? tSubjectName = filterSubjectName;

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
          // Brand filter rule: source the chip set from the
          // pre-fetched roster, never from the page's displayed
          // list and never from per-tap network round-trips. The
          // roster is hydrated at dashboard init by
          // DashboardController. See filter_sheet_reset.dart for the
          // contract.
          final roster = ref.watch(filterRosterRiverpod);
          // Cross-axis Kelas: narrow to classes teaching the picked
          // subject when one is set.
          final rosterClasses = roster.classesForSubject(
            tSubjectId,
            isHomeroomView: isHomeroomView,
          );
          // Cross-axis Mapel: narrow to subjects of the picked class
          // when one is set; otherwise the global subjects roster.
          final rosterSubjects = roster.subjectsForClass(
            tClassId,
            isHomeroomView: isHomeroomView,
          );

          final classes = rosterClasses.map((c) {
            final id = (c is Map ? c['id'] : null)?.toString() ?? '';
            final name = c is Map
                ? ((c['name'] ?? c['nama'] ?? '-').toString())
                : '-';
            return FilterOption<String>(value: id, label: name);
          }).toList();

          final subjects = rosterSubjects.map((s) {
            final id = (s is Map ? s['id'] : null)?.toString() ?? '';
            final name = s is Map
                ? ((s['name'] ?? s['nama'] ?? '-').toString())
                : '-';
            return FilterOption<String>(value: id, label: name);
          }).toList();

          return TeacherFilterContent(
            sections: [
              // Kelas section is hidden in wali kelas mode — the
              // role toggle in the page header has already locked
              // the class to the homeroom, so a Kelas chip set
              // inside the sheet would just be a single non-actionable
              // chip. In mengajar mode the section renders normally.
              if (!isHomeroomView)
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
                        final pickedName = FilterSheetHelpers.labelForId(
                          rosterClasses,
                          v,
                        );
                        setSS(() {
                          tClassId = v;
                          tClassName = pickedName;
                          // Cross-axis: if the new class doesn't teach
                          // the currently-picked subject, drop the
                          // subject selection.
                          if (tSubjectId != null && v != null) {
                            final allowed = roster
                                .subjectsForClass(
                                  v,
                                  isHomeroomView: isHomeroomView,
                                )
                                .map((s) => (s as Map)['id']?.toString());
                            if (!allowed.contains(tSubjectId)) {
                              tSubjectId = null;
                              tSubjectName = null;
                            }
                          }
                          // Auto-select-on-single — if there's exactly
                          // one subject for this class, pick it.
                          if (v != null && tSubjectId == null) {
                            final only = roster.subjectsForClass(
                              v,
                              isHomeroomView: isHomeroomView,
                            );
                            if (only.length == 1 && only.first is Map) {
                              tSubjectId = (only.first as Map)['id']
                                  ?.toString();
                              tSubjectName =
                                  ((only.first as Map)['name'] ??
                                          (only.first as Map)['nama'])
                                      ?.toString();
                            }
                          }
                        });
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
                        final pickedName = FilterSheetHelpers.labelForId(
                          rosterSubjects,
                          v,
                        );
                        setSS(() {
                          tSubjectId = v;
                          tSubjectName = pickedName;
                          // Cross-axis inverse: if there's exactly one
                          // class teaching this subject, auto-select
                          // it. The user explicitly asked for this UX.
                          if (v != null && tClassId == null) {
                            final only = roster.classesForSubject(
                              v,
                              isHomeroomView: isHomeroomView,
                            );
                            if (only.length == 1 && only.first is Map) {
                              tClassId = (only.first as Map)['id']?.toString();
                              tClassName =
                                  ((only.first as Map)['name'] ??
                                          (only.first as Map)['nama'])
                                      ?.toString();
                            }
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
