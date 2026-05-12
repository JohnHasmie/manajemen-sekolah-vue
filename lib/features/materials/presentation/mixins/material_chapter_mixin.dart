// Mixin for chapter content loading and schedule
// auto-selection in TeacherMaterialScreen.
//
// Extracted from material_data_mixin.dart to keep
// each file under 400 lines.
import 'package:flutter/widgets.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';
import 'package:manajemensekolah/core/utils/cache_key_builder.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/core/utils/snackbar_utils.dart';
import 'package:manajemensekolah/core/di/service_locator.dart';
import 'package:manajemensekolah/features/subjects/data/subject_service.dart';
import 'package:manajemensekolah/features/materials/presentation/mixins/material_data_mixin.dart';
import 'package:manajemensekolah/features/materials/presentation/screens/teacher_material_screen.dart';
import 'package:manajemensekolah/features/teachers/domain/models/teacher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Mixin for chapter-loading and schedule auto-select.
///
/// Must be applied together with [MaterialDataMixin].
mixin MaterialChapterMixin
    on ConsumerState<TeacherMaterialScreen>, MaterialDataMixin {
  // ── Auto-select current schedule ──

  @override
  void autoSelectCurrentSchedule(
    List<dynamic> classes,
    List<dynamic> subjects,
  ) {
    if (schedules.isEmpty) return;
    if (widget.initialClassId != null) return;

    final match = _findCurrentScheduleMatch(classes, subjects);
    if (match == null) return;

    _applyScheduleMatch(match);
  }

  /// Finds a schedule matching current day+time.
  ({String cid, String cn, String sid})? _findCurrentScheduleMatch(
    List<dynamic> classes,
    List<dynamic> subjects,
  ) {
    final now = DateTime.now();
    final nowMin = now.hour * 60 + now.minute;
    final today = _todayName(now.weekday);

    for (final s in schedules) {
      final dn = (s['hari_nama'] ?? s['day_name'] ?? '')
          .toString()
          .toLowerCase();
      if (!dn.contains(today)) continue;
      if (!_isWithinTimeRange(s, nowMin)) continue;

      final result = _matchScheduleToData(s, classes, subjects);
      if (result != null) return result;
    }
    return null;
  }

  String _todayName(int weekday) {
    const wd = {
      1: 'senin',
      2: 'selasa',
      3: 'rabu',
      4: 'kamis',
      5: 'jumat',
      6: 'sabtu',
    };
    return wd[weekday] ?? '';
  }

  bool _isWithinTimeRange(dynamic s, int nowMin) {
    final st = (s['jam_mulai'] ?? s['start_time'])?.toString();
    final et = (s['jam_selesai'] ?? s['end_time'])?.toString();
    if (st == null || et == null) return false;
    return nowMin >= _timeToMin(st) && nowMin < _timeToMin(et);
  }

  int _timeToMin(String t) {
    final p = t.replaceAll('.', ':').split(':');
    if (p.length < 2) return 0;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  ({String cid, String cn, String sid})? _matchScheduleToData(
    dynamic s,
    List<dynamic> classes,
    List<dynamic> subjects,
  ) {
    final cid = (s['class_id'] ?? s['kelas_id'])?.toString();
    final sid = (s['subject_id'] ?? s['mata_pelajaran_id'])?.toString();
    if (cid == null || sid == null) return null;

    final hasClass = classes.any((c) => c['id']?.toString() == cid);
    final hasSub = subjects.any(
      (sub) => (sub['id'] ?? sub['mata_pelajaran_id'])?.toString() == sid,
    );
    if (!hasClass || !hasSub) return null;

    final cls = classes.firstWhere((c) => c['id']?.toString() == cid);
    final cn = (cls['name'] ?? cls['nama'] ?? '').toString();
    return (cid: cid, cn: cn, sid: sid);
  }

  void _applyScheduleMatch(({String cid, String cn, String sid}) match) {
    if (match.cid != selectedClassId?.toString()) {
      setState(() {
        selectedClassId = match.cid;
        selectedClassName = match.cn;
        selectedSubject = match.sid;
        chapterMaterialList = [];
        subChapterMaterialList = [];
        isLoadingBab = true;
      });
      loadChapterContent(match.sid);
    } else if (match.sid != selectedSubject?.toString()) {
      setState(() {
        selectedSubject = match.sid;
        chapterMaterialList = [];
        subChapterMaterialList = [];
        isLoadingBab = true;
      });
      loadChapterContent(match.sid);
    }
  }

  // ── Load chapter content (bab + sub-bab) ──

  @override
  Future<void> loadChapterContent(
    String subjectId, {
    bool useCache = true,
    String? search,
  }) async {
    if (chapterMaterialList.isEmpty && mounted) {
      setState(() => isLoadingBab = true);
    }

    // Skip cache when searching — always fetch fresh from API
    if (search != null && search.isNotEmpty) {
      await _fetchChaptersFromApi(subjectId, null, search: search);
      return;
    }

    final chapterCK = CacheKeyBuilder.custom(
      'materi_bab',
      Teacher.fromJson(widget.teacher).id,
      subjectId,
    );

    if (useCache && chapterMaterialList.isEmpty) {
      final hit = await _tryChapterCache(subjectId, chapterCK);
      if (hit) return;
    }

    await _fetchChaptersFromApi(subjectId, chapterCK);
  }

  /// Tries loading chapters from cache.
  Future<bool> _tryChapterCache(String subjectId, String cacheKey) async {
    try {
      final cached = await LocalCacheService.load(
        cacheKey,
        ttl: const Duration(hours: 3),
      );
      if (cached == null || !mounted) return false;

      final d = Map<String, dynamic>.from(cached);
      final chapters = List<dynamic>.from(d['chapterMaterials'] ?? []);
      if (chapters.isEmpty) return false;

      final subChapters = List<dynamic>.from(d['subChapterMaterials'] ?? []);
      final progress = await _loadCachedProgress(subjectId);

      setState(() {
        chapterMaterialList = chapters;
        subChapterMaterialList = subChapters;
        isLoadingBab = false;
        resetChapterMaps(chapters, subChapters);
        if (progress.isNotEmpty) {
          applyProgressToMaps(progress);
          isLoadingProgress = false;
        } else {
          isLoadingProgress = true;
        }
      });

      loadContentProgress(subjectId);
      _postFrameTour();
      return true;
    } catch (e) {
      AppLogger.error('material', 'Bab cache load error: $e');
      return false;
    }
  }

  Future<List<dynamic>> _loadCachedProgress(String subjectId) async {
    try {
      final pck = buildProgressCacheKey(subjectId);
      final cp = await LocalCacheService.load(
        pck,
        ttl: const Duration(minutes: 30),
      );
      if (cp != null) return List<dynamic>.from(cp);
    } catch (_) {}
    return [];
  }

  /// Fetches chapters from API.
  Future<void> _fetchChaptersFromApi(
    String subjectId,
    String? cacheKey, {
    String? search,
  }) async {
    try {
      final masterSubjectId = _resolveMasterSubjectId(subjectId);
      final chapters = await getIt<ApiSubjectService>().getChapterMaterials(
        subjectId: masterSubjectId,
        search: search,
      );
      if (!mounted) return;

      final allSubs = _extractSubChapters(chapters);
      setState(() {
        chapterMaterialList = chapters;
        subChapterMaterialList = allSubs;
        isLoadingBab = false;
        isLoadingProgress = true;
        resetChapterMaps(chapters, allSubs);
      });

      // Only cache when not searching
      if (cacheKey != null) {
        LocalCacheService.save(cacheKey, {
          'chapterMaterials': chapters,
          'subChapterMaterials': allSubs,
        });
      }

      loadContentProgress(subjectId);
      _postFrameTour();
    } catch (e) {
      AppLogger.error('material', 'Error loading bab: $e');
      if (!mounted) return;
      setState(() => isLoadingBab = false);
      if (chapterMaterialList.isEmpty) {
        SnackBarUtils.showInfo(context, ErrorUtils.getFriendlyMessage(e));
      }
    }
  }

  String _resolveMasterSubjectId(String subjectId) {
    final subject = subjectList.firstWhere(
      (s) => s['id'] == subjectId,
      orElse: () => null,
    );
    return subject?['subject_id']?.toString() ??
        subject?['id']?.toString() ??
        subjectId;
  }

  List<dynamic> _extractSubChapters(List<dynamic> chapters) {
    final allSubs = <dynamic>[];
    for (final ch in chapters) {
      final subs = ch['sub_chapters'];
      if (subs is List) allSubs.addAll(subs);
    }
    return allSubs;
  }

  void _postFrameTour() {}
}
