// Mixin that holds checkbox/progress tracking logic for TeacherMaterialScreen.
//
// Extracted from teacher_material_screen.dart (~260 lines)
// Manages: check/uncheck chapters & sub-chapters, save to API,
// load progress from API, write progress snapshot to cache.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';

/// Mixin providing checkbox/progress management for
/// [TeacherMaterialScreenState].
mixin MaterialProgressMixin on ConsumerState<TeacherMaterialScreen> {
  // ── Getters the main state must expose ──
  String? get selectedSubject;
  String? get selectedClassId;
  List<dynamic> get chapterMaterialList;
  List<dynamic> get subChapterMaterialList;
  Map<String, bool> get checkedChapter;
  Map<String, bool> get checkedSubChapter;
  Map<String, bool> get generatedChapter;
  Map<String, bool> get generatedSubChapter;
  Map<String, bool> get usedChapter;
  Map<String, bool> get usedSubChapter;
  bool get isLoadingProgress;
  set isLoadingProgress(bool v);

  String buildProgressCacheKey(String subjectId);

  // ── Apply progress from API/cache into maps ──

  void applyProgressToMaps(List<dynamic> progress) {
    for (final item in progress) {
      final chapterId = item['bab_id'];
      final subChapterId = item['sub_bab_id'];
      final isChecked = item['is_checked'] == 1 || item['is_checked'] == true;
      final isGenerated =
          item['is_generated'] == 1 || item['is_generated'] == true;
      final isUsed = item['is_used'] == 1 || item['is_used'] == true;

      if (subChapterId != null) {
        checkedSubChapter[subChapterId.toString()] = isChecked;
        generatedSubChapter[subChapterId.toString()] = isGenerated;
        usedSubChapter[subChapterId.toString()] = isUsed;
      } else if (chapterId != null) {
        checkedChapter[chapterId.toString()] = isChecked;
        generatedChapter[chapterId.toString()] = isGenerated;
        usedChapter[chapterId.toString()] = isUsed;
      }
    }

    // Recalculate chapter checked state from sub-chapters
    for (final chapter in chapterMaterialList) {
      final chId = chapter['id'].toString();
      final subs = subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chId)
          .toList();
      if (subs.isNotEmpty) {
        checkedChapter[chId] = subs.every(
          (sb) => checkedSubChapter[sb['id'].toString()] == true,
        );
      }
    }
  }

  // ── Checked items helpers ──

  List<Map<String, dynamic>> getCheckedNotGeneratedChapters() {
    return chapterMaterialList
        .where((chapter) {
          final hasSubChapters = subChapterMaterialList.any(
            (sb) => sb['bab_id'].toString() == chapter['id'].toString(),
          );
          return checkedChapter[chapter['id']] == true &&
              generatedChapter[chapter['id']] != true &&
              usedChapter[chapter['id']] != true &&
              !hasSubChapters;
        })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>> getCheckedNotGeneratedSubChapters() {
    return subChapterMaterialList
        .where(
          (sc) =>
              checkedSubChapter[sc['id']] == true &&
              generatedSubChapter[sc['id']] != true &&
              usedSubChapter[sc['id']] != true,
        )
        .toList()
        .cast<Map<String, dynamic>>();
  }

  // ── Handle sub-chapter checkbox ──

  void handleSubChapterCheck(
    String subChapterId,
    String chapterId,
    bool? value,
  ) {
    // is_generated alone must NOT lock the checkbox — it's a display signal
    // (coloured vs grey badges) not a progress lock. Only is_used (material
    // assigned in a lesson/class) pins the row to checked. (#141)
    if (_usedSub(subChapterId) && value == false) {
      return;
    }

    setState(() {
      checkedSubChapter[subChapterId] = value ?? false;

      final subs = subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId)
          .toList();

      if (subs.isNotEmpty) {
        checkedChapter[chapterId] = subs.every(
          (sb) => checkedSubChapter[sb['id'].toString()] == true,
        );
      }
    });

    _saveProgress(chapterId, subChapterId, value ?? false);
  }

  // ── Handle chapter checkbox ──

  void handleChapterCheck(String chapterId, bool? value) {
    final subs = subChapterMaterialList
        .where((sc) => sc['bab_id'].toString() == chapterId)
        .toList();

    if (subs.isEmpty) {
      if (_usedCh(chapterId) && value == false) return;
      setState(() => checkedChapter[chapterId] = value ?? false);
      _saveChapterAndSubChaptersProgress(chapterId, value ?? false);
      return;
    }

    // Has sub-chapters: find next unchecked
    final unchecked = subs
        .where((sc) => checkedSubChapter[sc['id'].toString()] != true)
        .toList();

    if (unchecked.isNotEmpty) {
      handleSubChapterCheck(unchecked.first['id'].toString(), chapterId, true);
    } else {
      // All checked → uncheck all (except used-in-lesson sub-chapters).
      // is_generated does NOT participate in the lock anymore. (#141)
      if (_usedCh(chapterId)) return;
      setState(() {
        checkedChapter[chapterId] = false;
        for (final sc in subs) {
          final scId = sc['id'].toString();
          if (!_usedSub(scId)) {
            checkedSubChapter[scId] = false;
          }
        }
      });
      _saveChapterAndSubChaptersProgress(chapterId, false);
    }
  }

  // ── Load progress from API ──

  Future<void> loadContentProgress(String subjectId) async {
    try {
      final teacherId = Teacher.fromJson(widget.teacher).id;
      if (teacherId.isEmpty) return;

      final progress = await getIt<ApiSubjectService>().getMaterialProgress(
        teacherId: teacherId,
        subjectId: subjectId,
        classId: selectedClassId,
      );
      if (!mounted) return;

      if (kDebugMode) {
        AppLogger.debug('material', '=== LOADING MATERI PROGRESS ===');
        AppLogger.debug('material', 'API Response Items: ${progress.length}');
      }

      LocalCacheService.save(buildProgressCacheKey(subjectId), progress);

      setState(() {
        applyProgressToMaps(progress);
        isLoadingProgress = false;
      });
    } catch (e) {
      AppLogger.error('material', 'Error loading progress: $e');
      if (mounted) setState(() => isLoadingProgress = false);
    }
  }

  // ── Write in-memory progress snapshot to cache ──

  void writeProgressToCache(String subjectId) {
    final List<Map<String, dynamic>> snapshot = [];

    for (final chapter in chapterMaterialList) {
      final chId = chapter['id'].toString();
      final subs = subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chId)
          .toList();

      if (subs.isEmpty) {
        snapshot.add({
          'bab_id': chId,
          'sub_bab_id': null,
          'is_checked': checkedChapter[chId] == true ? 1 : 0,
          'is_generated': generatedChapter[chId] == true ? 1 : 0,
          'is_used': usedChapter[chId] == true ? 1 : 0,
        });
      } else {
        for (final sc in subs) {
          final scId = sc['id'].toString();
          snapshot.add({
            'bab_id': chId,
            'sub_bab_id': scId,
            'is_checked': checkedSubChapter[scId] == true ? 1 : 0,
            'is_generated': generatedSubChapter[scId] == true ? 1 : 0,
            'is_used': usedSubChapter[scId] == true ? 1 : 0,
          });
        }
      }
    }

    LocalCacheService.save(buildProgressCacheKey(subjectId), snapshot);
  }

  // ── Private helpers ──

  /// Only `is_used` (sub-chapter already assigned in a lesson/class) pins
  /// the checkbox to checked. `is_generated` is purely a display signal —
  /// see the three Materi/Kuis/Ref badges in `MaterialSubChapterList`. (#141)
  bool _usedSub(String id) => usedSubChapter[id] == true;

  bool _usedCh(String id) => usedChapter[id] == true;

  Future<void> _saveProgress(
    String chapterId,
    String? subChapterId,
    bool isChecked,
  ) async {
    try {
      final teacherId = Teacher.fromJson(widget.teacher).id;
      if (teacherId.isEmpty || selectedSubject == null) return;

      await getIt<ApiSubjectService>().saveMateriProgress({
        'teacher_id': teacherId,
        'subject_id': selectedSubject,
        'class_id': selectedClassId,
        'chapter_id': chapterId,
        'sub_chapter_id': subChapterId,
        'is_checked': isChecked ? 1 : 0,
      });

      writeProgressToCache(selectedSubject!);
    } catch (e) {
      AppLogger.error('material', 'Error saving progress: $e');
    }
  }

  Future<void> _saveChapterAndSubChaptersProgress(
    String chapterId,
    bool isChecked,
  ) async {
    try {
      final teacherId = Teacher.fromJson(widget.teacher).id;
      if (teacherId.isEmpty || selectedSubject == null) return;

      final List<Map<String, dynamic>> items = [];
      final subs = subChapterMaterialList
          .where((sb) => sb['bab_id'].toString() == chapterId)
          .toList();

      if (subs.isEmpty) {
        items.add({
          'bab_id': chapterId,
          'sub_bab_id': null,
          'is_checked': isChecked ? 1 : 0,
        });
      }

      for (final sc in subs) {
        // Skip uncheck only for sub-chapters currently used in a lesson —
        // already-generated-but-not-used sub-chapters can be unchecked. (#141)
        if (!isChecked && _usedSub(sc['id'].toString())) {
          continue;
        }
        items.add({
          'bab_id': chapterId,
          'sub_bab_id': sc['id'],
          'is_checked': isChecked ? 1 : 0,
        });
      }

      await getIt<ApiSubjectService>().batchSaveMateriProgress({
        'guru_id': teacherId,
        'mata_pelajaran_id': selectedSubject,
        'class_id': selectedClassId,
        'progress_items': items,
      });

      writeProgressToCache(selectedSubject!);
    } catch (e) {
      AppLogger.error('material', 'Error batch saving progress: $e');
    }
  }
}
