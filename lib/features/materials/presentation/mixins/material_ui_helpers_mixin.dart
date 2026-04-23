// Mixin for UI helper methods in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Provides color resolution, text utilities, filtering, and chapter
// expansion logic.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/subjects/domain/models/subject.dart';

/// Mixin providing UI helper methods for [TeacherMaterialScreenState].
mixin MaterialUIHelpersMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  List<dynamic> get subjectList;
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  TextEditingController get searchController;
  Map<String, bool> get expandedChapter;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get usedChapter;
  Map<String, bool> get usedSubChapter;
  Map<String, bool> get generatedChapter;
  Map<String, bool> get generatedSubChapter;

  // ── Helpers ──

  /// Get the name of the selected subject.
  String getSelectedSubjectName() {
    if (selectedSubject == null) return '-';
    final mp = subjectList.firstWhere(
      (mp) =>
          (mp['id'] ?? mp['mata_pelajaran_id'])?.toString() ==
          selectedSubject?.toString(),
      orElse: () => {'nama': '-', 'name': '-'},
    );
    return Subject.fromJson(mp as Map<String, dynamic>).name;
  }

  /// Filter chapters by search term.
  /// Matches against chapter title, chapter number, sub-chapter title,
  /// and sub-chapter description.
  List<dynamic> getFilteredChapters() {
    final term = searchController.text.toLowerCase();
    if (term.isEmpty) return chapterMaterialList;
    return chapterMaterialList.where((ch) {
      final matchTitle =
          ch['judul_bab']?.toString().toLowerCase().contains(term) ?? false;
      final matchNumber =
          ch['urutan']?.toString().contains(term) ?? false;
      final matchDesc =
          ch['deskripsi_bab']?.toString().toLowerCase().contains(term) ??
              false;
      final matchSub = subChapterMaterialList
          .where((sc) => sc['bab_id'] == ch['id'])
          .any((sc) {
        final subTitle =
            sc['judul_sub_bab']?.toString().toLowerCase().contains(term) ??
                false;
        final subDesc =
            sc['deskripsi_sub_bab']
                ?.toString()
                .toLowerCase()
                .contains(term) ??
            false;
        return subTitle || subDesc;
      });
      return matchTitle || matchNumber || matchDesc || matchSub;
    }).toList();
  }

  /// Get checkbox color based on chapter/sub-chapter state.
  Color getCheckboxColor(String id, {bool isSubChapter = false}) {
    if (isSubChapter) {
      if (usedSubChapter[id] == true) return ColorUtils.info600;
      if (generatedSubChapter[id] == true) return ColorUtils.violet500;
      return ColorUtils.success600;
    }
    if (usedChapter[id] == true) return ColorUtils.info600;
    if (generatedChapter[id] == true) return ColorUtils.violet500;
    return ColorUtils.success600;
  }

  /// Auto-expand first unchecked chapter in embedded mode.
  void autoExpandToRelevant() {
    if (!widget.embedded || chapterMaterialList.isEmpty) return;
    String? target;
    for (final ch in chapterMaterialList) {
      final id = ch['id']?.toString();
      if (id != null && checkedChapter[id] != true) {
        target = id;
        break;
      }
    }
    target ??= chapterMaterialList.last['id']?.toString();
    if (target != null) setState(() => expandedChapter[target!] = true);
  }
}
