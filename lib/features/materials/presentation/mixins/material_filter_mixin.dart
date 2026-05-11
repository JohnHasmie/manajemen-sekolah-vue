// Mixin for filter logic in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Handles filter dialog display, filter application, and clearing
// filters across class, subject, and chapter selections.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/filter_sheet_reset.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';

/// Mixin providing filter logic for [TeacherMaterialScreenState].
mixin MaterialFilterMixin on ConsumerState<TeacherMaterialScreen> {
  /// Wali kelas vs mengajar — picks the right roster partition.
  bool get isHomeroomView;
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  set selectedSubject(String? v);
  String? get selectedClassId;
  set selectedClassId(String? v);
  String? get selectedClassName;
  set selectedClassName(String? v);
  List<dynamic> get subjectList;
  set subjectList(List<dynamic> v);
  List<dynamic> get classList;
  set classList(List<dynamic> v);
  List<dynamic> get chapterMaterialList;
  set chapterMaterialList(List<dynamic> v);
  List<dynamic> get subChapterMaterialList;
  set subChapterMaterialList(List<dynamic> v);
  TextEditingController get searchController;
  Color get primaryColor;

  /// Load subjects for a given class from API.
  Future<List<dynamic>> getSubjectsForClass(String classId);

  /// Load chapter content for a given subject.
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache = true,
    String? search,
  });

  // ── Filter UI ──

  /// Opens filter dialog and applies filter result.
  Future<void> showFilterDialog(LanguageProvider lp) async {
    String? tClassId = selectedClassId;
    String? tClassName = selectedClassName;
    String? tSubjectId = selectedSubject;

    if (!mounted) return;

    showFilterSheet(
      context: context,
      title: lp.getTranslatedText({
        'en': 'Filter Materials',
        'id': 'Filter Materi',
      }),
      primaryColor: primaryColor,
      onApply: () {
        // Resolve subject list at apply-time from the roster so the
        // screen's downstream `applyFilter` (which still stores
        // `subjectList` for non-filter UI) gets the right subset.
        final roster = ref.read(filterRosterRiverpod);
        final resolvedSubjects = roster.subjectsForClass(tClassId);
        _applyFilter(
          context,
          tClassId,
          tClassName,
          tSubjectId,
          resolvedSubjects,
        );
      },
      onReset: () => FilterSheetHelpers.reset(context, clearAllFilters),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          // Brand filter rule: source chips from the pre-fetched
          // roster + cross-axis maps. No on-tap fetches.
          final roster = ref.watch(filterRosterRiverpod);
          final rosterClasses = roster.classesForSubject(
            tSubjectId,
            isHomeroomView: isHomeroomView,
          );
          final rosterSubjects = roster.subjectsForClass(tClassId);
          final classes = rosterClasses
              .map(
                (c) => FilterOption<String>(
                  value: c['id']?.toString() ?? '',
                  label: (c['name'] ?? c['nama'])?.toString() ?? '-',
                ),
              )
              .toList();
          final subjects = rosterSubjects
              .map(
                (s) => FilterOption<String>(
                  value: s['id']?.toString() ?? '',
                  label:
                      (s['name'] ?? s['mata_pelajaran_name'] ?? s['nama'])
                              ?.toString() ??
                          '-',
                ),
              )
              .toList();

          return TeacherFilterContent(
            sections: [
              // Kelas section hides in wali kelas mode — the role
              // toggle in the page header already locked the class.
              if (!isHomeroomView)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FilterSectionHeader(
                      title: lp.getTranslatedText({
                        'en': 'Class',
                        'id': 'Kelas',
                      }),
                      icon: Icons.class_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: classes,
                      selectedValue: tClassId,
                      onSelected: (v) {
                        setSS(() {
                          tClassId = v;
                          tClassName = FilterSheetHelpers.labelForId(
                            rosterClasses,
                            v,
                          );
                          // Cross-axis: drop subject if new class
                          // doesn't teach it.
                          if (tSubjectId != null && v != null) {
                            final allowed = roster
                                .subjectsForClass(v)
                                .map((s) => (s as Map)['id']?.toString());
                            if (!allowed.contains(tSubjectId)) {
                              tSubjectId = null;
                            }
                          }
                          // Auto-select-on-single.
                          if (v != null && tSubjectId == null) {
                            final only = roster.subjectsForClass(v);
                            if (only.length == 1 && only.first is Map) {
                              tSubjectId =
                                  (only.first as Map)['id']?.toString();
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
                      title: lp.getTranslatedText({
                        'en': 'Subject',
                        'id': 'Mata Pelajaran',
                      }),
                      icon: Icons.book_outlined,
                      primaryColor: primaryColor,
                    ),
                    FilterChipGrid<String>(
                      options: subjects,
                      selectedValue: tSubjectId,
                      onSelected: (v) {
                        setSS(() {
                          tSubjectId = v;
                          // Cross-axis inverse: auto-select sole class.
                          if (v != null && tClassId == null) {
                            final only = roster.classesForSubject(
                              v,
                              isHomeroomView: isHomeroomView,
                            );
                            if (only.length == 1 && only.first is Map) {
                              tClassId =
                                  (only.first as Map)['id']?.toString();
                              tClassName = ((only.first as Map)['name'] ??
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
    List<dynamic> subjects,
  ) {
    Navigator.pop(ctx);
    applyFilter(classId, subjectId, subjects);
  }

  /// Apply filter selection.
  void applyFilter(String? classId, String? subjectId, List<dynamic> subjects) {
    setState(() {
      if (classId != selectedClassId) {
        selectedClassId = classId;
        final sc = classList.firstWhere(
          (c) => c['id'] == classId,
          orElse: () => <String, dynamic>{},
        );
        selectedClassName = sc['name'] ?? sc['nama'];
        subjectList = subjects;
        chapterMaterialList = [];
        subChapterMaterialList = [];
        if (subjectId == null) selectedSubject = null;
      }
      if (subjectId != selectedSubject) {
        selectedSubject = subjectId;
        chapterMaterialList = [];
        subChapterMaterialList = [];
        if (subjectId != null) {
          loadChapterContent(subjectId);
        }
      }
      searchController.clear();
    });
    if (classId != null && subjectId == null && subjects.isEmpty) {
      getSubjectsForClass(classId);
    }
  }

  /// Clear class filter (resets subject, chapters, sub-chapters).
  void clearClassFilter() => setState(() {
    selectedClassId = null;
    selectedClassName = null;
    selectedSubject = null;
    subjectList = [];
    chapterMaterialList = [];
    subChapterMaterialList = [];
  });

  /// Clear subject filter (keeps class, resets chapters).
  void clearSubjectFilter() => setState(() {
    selectedSubject = null;
    chapterMaterialList = [];
    subChapterMaterialList = [];
  });

  /// Clear all filters.
  void clearAllFilters() => setState(() {
    selectedClassId = null;
    selectedClassName = null;
    selectedSubject = null;
    subjectList = [];
    chapterMaterialList = [];
    subChapterMaterialList = [];
  });
}
