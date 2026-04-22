// Mixin for filter logic in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Handles filter dialog display, filter application, and clearing
// filters across class, subject, and chapter selections.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/widgets/filter_bottom_sheet.dart';
import 'package:manajemensekolah/core/widgets/filter_chip_grid.dart';
import 'package:manajemensekolah/core/widgets/filter_section_header.dart';
import 'package:manajemensekolah/core/widgets/teacher_filter_content.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';

/// Mixin providing filter logic for [TeacherMaterialScreenState].
mixin MaterialFilterMixin on ConsumerState<TeacherMaterialScreen> {
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
  Future<void> loadChapterContent(String subjectId, {bool useCache = true, String? search});

  // ── Filter UI ──

  /// Opens filter dialog and applies filter result.
  Future<void> showFilterDialog(LanguageProvider lp) async {
    String? tClassId = selectedClassId;
    String? tClassName = selectedClassName;
    String? tSubjectId = selectedSubject;
    List<dynamic> tSubjectList = subjectList;

    if (!mounted) return;

    showFilterSheet(
      context: context,
      title: lp.getTranslatedText({'en': 'Filter Materials', 'id': 'Filter Materi'}),
      primaryColor: primaryColor,
      onApply: () => _applyFilter(context, tClassId, tClassName, tSubjectId, tSubjectList),
      onReset: () => setState(() {
        selectedClassId = null;
        selectedClassName = null;
        selectedSubject = null;
        subjectList = [];
        chapterMaterialList = [];
        subChapterMaterialList = [];
      }),
      content: StatefulBuilder(
        builder: (ctx, setSS) {
          final classes = classList
              .map((c) => FilterOption<String>(
                    value: c['id']?.toString() ?? '',
                    label: (c['name'] ?? c['nama'])?.toString() ?? '-',
                  ))
              .toList();

          final subjects = tSubjectList
              .map((s) => FilterOption<String>(
                    value: s['id']?.toString() ?? '',
                    label: (s['name'] ?? s['mata_pelajaran_name'])?.toString() ?? '-',
                  ))
              .toList();

          return TeacherFilterContent(
            sections: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FilterSectionHeader(
                    title:
                        lp.getTranslatedText({'en': 'Class', 'id': 'Kelas'}),
                    icon: Icons.class_outlined,
                    primaryColor: primaryColor,
                  ),
                  FilterChipGrid<String>(
                    options: classes,
                    selectedValue: tClassId,
                    onSelected: (v) {
                      setSS(() {
                        tClassId = v;
                        tSubjectId = null;
                        tSubjectList = [];
                      });
                      if (v != null) {
                        final sc = classList.firstWhere(
                          (c) => c['id']?.toString() == v,
                          orElse: () => <String, dynamic>{},
                        );
                        if ((sc as Map?)?.isNotEmpty ?? false) {
                          final scMap = sc as Map<String, dynamic>;
                          tClassName =
                              (scMap['name'] ?? scMap['nama'])?.toString();
                        } else {
                          tClassName = null;
                        }
                        getSubjectsForClass(v).then((subjects) {
                          setSS(() {
                            tSubjectList = subjects;
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
