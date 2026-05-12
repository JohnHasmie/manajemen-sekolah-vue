import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/providers/riverpod_providers.dart';
import 'package:manajemensekolah/core/services/cache_service.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';
import 'package:manajemensekolah/features/grades/data/grade_service.dart';

mixin GradeRecapDataMixin {
  // Required from ConsumerState
  BuildContext get context;
  bool get mounted;
  WidgetRef get ref;
  void setState(VoidCallback fn);

  // State variables (declared in state class)
  late List<dynamic> groupedData;
  // Aggregated totals computed on the backend. Kept separate from
  // `groupedData` because the hero stats must survive future pagination —
  // if/when `data` gets sliced client-side, `recapSummary` still reflects
  // the full set of classes/subjects the teacher is responsible for.
  Map<String, dynamic> recapSummary = const {};
  late bool isLoading;
  late bool isHomeroomView;
  late TextEditingController searchController;
  late String? filterClassId;
  late String? filterSubjectId;
  String? recapErrorMessage;

  // Abstract getter - implementing class must provide access to teacher data
  Map<String, dynamic> get teacherData;

  String get teacherId =>
      (teacherData['teacher_id'] ?? teacherData['id'])?.toString() ?? '';

  Future<void> loadViewPref() async {
    try {
      final c = await LocalCacheService.load('rekap_nilai_view_preference');
      if (c is Map && mounted) setState(() {});
    } catch (_) {}
  }

  String _buildRecapCacheKey() {
    final ayId =
        ref
            .read(academicYearRiverpod)
            .selectedAcademicYear?['id']
            ?.toString() ??
        'default';
    final view = isHomeroomView ? 'wali_kelas' : 'mengajar';
    return 'rekap_nilai_${teacherId}_${view}_$ayId';
  }

  Future<void> loadData({bool useCache = true}) async {
    try {
      final cacheKey = _buildRecapCacheKey();

      // Cache-first: show cached data immediately. Handle both shapes —
      // the legacy List shape (from before the summary envelope was added)
      // and the new Map shape `{data, summary}` — so a cold-start after an
      // app upgrade doesn't blank the screen.
      if (useCache && groupedData.isEmpty) {
        try {
          final cached = await LocalCacheService.load(
            cacheKey,
            ttl: const Duration(hours: 1),
          );
          if (mounted) {
            if (cached is Map &&
                cached['data'] is List &&
                (cached['data'] as List).isNotEmpty) {
              setState(() {
                groupedData = cached['data'] as List;
                recapSummary = cached['summary'] is Map
                    ? Map<String, dynamic>.from(cached['summary'] as Map)
                    : const {};
                isLoading = false;
              });
            } else if (cached is List && cached.isNotEmpty) {
              setState(() {
                groupedData = cached;
                isLoading = false;
              });
            }
          }
        } catch (_) {}
      }

      if (groupedData.isEmpty && mounted) {
        setState(() => isLoading = true);
      }

      // ENSURE DEPENDENCIES ARE READY (Fix for race condition on cold start)
      final ayProvider = ref.read(academicYearRiverpod);
      if (ayProvider.selectedAcademicYear == null && ayProvider.isLoading) {
        int retries = 0;
        while (ref.read(academicYearRiverpod).selectedAcademicYear == null &&
            ref.read(academicYearRiverpod).isLoading &&
            mounted &&
            retries < 20) {
          await Future.delayed(const Duration(milliseconds: 500));
          retries++;
        }
      }

      final teacherProvider = ref.read(teacherRiverpod);
      if (teacherId.isEmpty || !teacherProvider.isLoaded) {
        await teacherProvider.ensureLoaded();
      }

      final ayId = ref
          .read(academicYearRiverpod)
          .selectedAcademicYear?['id']
          ?.toString();

      if (teacherId.isEmpty) {
        throw Exception('ID Guru tidak ditemukan. Silakan coba lagi.');
      }

      final envelope = await GradeService.getTeacherRecapSummaryEnvelope(
        teacherId: teacherId,
        academicYearId: ayId,
        view: isHomeroomView ? 'wali_kelas' : 'mengajar',
        classId: filterClassId,
        subjectId: filterSubjectId,
      );
      if (mounted) {
        setState(() {
          groupedData = envelope.data;
          recapSummary = envelope.summary;
          isLoading = false;
          recapErrorMessage = null;
        });
        // Store both pieces so the cache-first path can rehydrate the hero
        // card without a network round-trip. Older cached entries (pre-
        // summary) still work — they'll just show zeros in the hero until
        // the live fetch completes a moment later.
        await LocalCacheService.save(cacheKey, {
          'data': envelope.data,
          'summary': envelope.summary,
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
          recapErrorMessage = ErrorUtils.getFriendlyMessage(e);
        });
      }
    }
  }

  Future<void> refresh() async => loadData(useCache: false);

  List<dynamic> get filteredData {
    final q = searchController.text.toLowerCase();
    if (q.isEmpty) return groupedData;
    return groupedData.where((g) {
      if ((g['class_name'] ?? '').toString().toLowerCase().contains(q)) {
        return true;
      }
      return ((g['subjects'] as List?) ?? []).any(
        (s) => (s['name'] ?? '').toString().toLowerCase().contains(q),
      );
    }).toList();
  }

  /// Filter chip set for the Kelas section. Pulled from the
  /// pre-fetched roster (see filter_roster_provider.dart) so the
  /// chips stay constant regardless of which class the user filters
  /// to. Earlier this derived from `groupedData` (server-filtered)
  /// and collapsed to one chip on Apply — see filter_sheet_reset.dart
  /// for the brand rule.
  List<Map<String, String>> get availableClasses {
    final roster = ref.read(filterRosterRiverpod);
    final source = roster.classesForView(isHomeroomView: isHomeroomView);
    final seen = <String>{};
    final out = <Map<String, String>>[];
    for (final c in source) {
      if (c is! Map) continue;
      final id = c['id']?.toString() ?? '';
      if (id.isEmpty || !seen.add(id)) continue;
      out.add({'id': id, 'name': (c['name'] ?? c['nama'] ?? '-').toString()});
    }
    // Cold-open fallback while the provider hydrates.
    if (out.isEmpty) {
      for (final g in groupedData) {
        if (g is! Map) continue;
        final id = g['class_id']?.toString() ?? '';
        if (id.isEmpty || !seen.add(id)) continue;
        out.add({'id': id, 'name': g['class_name']?.toString() ?? '-'});
      }
    }
    return out;
  }
}
