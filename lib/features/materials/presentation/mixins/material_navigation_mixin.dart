// Mixin for navigation logic in TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart to keep main file under 400
// lines. Handles navigation to sub-chapter detail, activity generation,
// and chapter bottom sheets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/widgets/app_draggable_sheet.dart';
import 'package:manajemensekolah/features/class_activity/presentation/screens/embedded_activity_list_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/sub_chapter_detail_screen.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin providing navigation logic for [TeacherMaterialScreenState].
mixin MaterialNavigationMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  String? get selectedClassId;
  String? get selectedClassName;
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  Map<String, bool> get checkedSubChapter;
  Map<String, bool> get generatedSubChapter;
  String? get teacherProfileId;
  Color get primaryColor;

  /// Get checked but not generated chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedChapters();

  /// Get checked but not generated sub-chapters.
  List<Map<String, dynamic>> getCheckedNotGeneratedSubChapters();

  /// Handle sub-chapter check state change.
  void handleSubChapterCheck(String subChId, String babId, bool? checked);

  /// Get translated subject name for selected subject.
  String getSelectedSubjectName();

  /// Reload chapter content after activity generation.
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache,
    String? search,
  });

  // ── Navigation ──

  /// Push the sub-chapter detail as a full Material page route.
  ///
  /// Was a 92% AppDraggableSheet — switched to a full screen so the
  /// BrandPageHeader gets its full SafeArea (no clock / battery
  /// overlap), system-back / ESC behave predictably, and the tabbed
  /// content (Materi / Soal / Referensi) doesn't fight the sheet's
  /// inner scroll controller.
  void navigateToSubChapterDetail(
    Map<String, dynamic> subChapter,
    Map<String, dynamic> bab,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SubBabDetailPage(
          teacherId: teacherProfileId ?? Teacher.fromJson(widget.teacher).id,
          subjectId: selectedSubject ?? '',
          classId: selectedClassId,
          className: selectedClassName,
          subChapter: subChapter,
          chapter: bab,
          checked: checkedSubChapter[subChapter['id'].toString()] ?? false,
          onCheckChanged: (v) => handleSubChapterCheck(
            subChapter['id'].toString(),
            bab['id'].toString(),
            v,
          ),
          onGenerated: () {
            if (mounted) {
              setState(
                () => generatedSubChapter[subChapter['id'].toString()] = true,
              );
            }
          },
        ),
      ),
    );
  }

  /// Push the chapter content view as a full Material page route
  /// (Frame B of the Materi mockup).
  ///
  /// Was an `AppDraggableSheet` with `embedded: true` which rendered
  /// the legacy timeline view. Replaced with a full screen so the
  /// teacher sees the full brand chrome — BrandPageHeader, 4-cell
  /// KPI strip (Bab / Sub-Bab / Tercatat / AI Siap), search row,
  /// expandable cobalt chapter cards, and the violet "Generate AI"
  /// FAB. The screen auto-resolves `selectedSubject` /
  /// `selectedClassId` from the initial props on init via
  /// `material_data_load_mixin`.
  void openChapterSheet(
    String classId,
    String cn,
    String subjectId,
    String sn,
  ) {
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TeacherMaterialScreen(
          teacher: widget.teacher,
          initialClassId: classId,
          initialClassName: cn,
          initialSubjectId: subjectId,
          initialSubjectName: sn,
        ),
      ),
    );
  }

  /// Open activity generation sheet.
  void openGenerateActivitySheet() {
    final chs = getCheckedNotGeneratedChapters();
    final subs = getCheckedNotGeneratedSubChapters();
    final sel = _resolveGenerateSelection(chs, subs);
    _showActivitySheet(sel);
  }

  /// Resolve which chapter/sub-chapter to initially select in activity sheet.
  ({
    String? chId,
    String? subId,
    List<Map<String, dynamic>> additional,
    List<Map<String, dynamic>> toMark,
  })
  _resolveGenerateSelection(List<dynamic> chs, List<dynamic> subs) {
    String? selChId, selSubId;
    final additional = <Map<String, dynamic>>[];
    if (subs.isNotEmpty) {
      selSubId = subs.first['id']?.toString();
      selChId = subs.first['bab_id']?.toString();
      for (final s in subs) {
        additional.add({'chapter_id': s['bab_id'], 'sub_chapter_id': s['id']});
      }
    } else if (chs.isNotEmpty) {
      selChId = chs.first['id']?.toString();
    }
    final toMark = <Map<String, dynamic>>[
      for (final c in chs) {'bab_id': c['id'], 'sub_bab_id': null},
      for (final s in subs) {'bab_id': s['bab_id'], 'sub_bab_id': s['id']},
    ];
    return (
      chId: selChId,
      subId: selSubId,
      additional: additional,
      toMark: toMark,
    );
  }

  /// Show activity sheet with generation options.
  void _showActivitySheet(
    ({
      String? chId,
      String? subId,
      List<Map<String, dynamic>> additional,
      List<Map<String, dynamic>> toMark,
    })
    sel,
  ) {
    AppDraggableSheet.show<void>(
      context: context,
      onClose: () {
        if (mounted && selectedSubject != null) {
          loadChapterContent(selectedSubject!);
        }
      },
      builder: (_, _) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: EmbeddedActivityListScreen(
          teacherId: Teacher.fromJson(widget.teacher).id,
          teacherName: Teacher.fromJson(widget.teacher).name,
          classId: selectedClassId ?? widget.initialClassId ?? '',
          className: selectedClassName ?? widget.initialClassName ?? '',
          subjectId: selectedSubject ?? '',
          subjectName: getSelectedSubjectName(),
          initialChapterId: sel.chId,
          initialSubChapterId: sel.subId,
          initialAdditionalMaterials: sel.additional,
          materialsToMarkAsGenerated: sel.toMark,
          autoShowActivityDialog: true,
          showScaffold: true,
        ),
      ),
    );
  }
}
