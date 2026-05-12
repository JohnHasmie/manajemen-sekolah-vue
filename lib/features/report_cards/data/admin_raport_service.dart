// Wrapper around GET /api/raports/admin-pipeline (Mockup #08).
// Returns the typed pipeline + per-tingkat aggregate consumed by the
// admin Raport hub.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_raport_components.dart';

class AdminRaportPipeline {
  final List<PipelineNode> pipeline;
  final List<TingkatGroup> tingkats;
  final int totalRaports;
  final int totalClasses;
  final String periodAcademicYearId;
  final String periodSemesterId;
  final String periodLabel;

  const AdminRaportPipeline({
    required this.pipeline,
    required this.tingkats,
    required this.totalRaports,
    required this.totalClasses,
    required this.periodAcademicYearId,
    required this.periodSemesterId,
    required this.periodLabel,
  });
}

class TingkatGroup {
  final int tingkat;
  final int classCount;
  final int studentCount;
  final int reviewedPct;
  final bool alert;
  final List<KelasMiniChipData> classes;

  const TingkatGroup({
    required this.tingkat,
    required this.classCount,
    required this.studentCount,
    required this.reviewedPct,
    required this.alert,
    required this.classes,
  });
}

KelasStatusTone _parseTone(String raw) {
  switch (raw) {
    case 'good':
      return KelasStatusTone.good;
    case 'bad':
      return KelasStatusTone.bad;
    default:
      return KelasStatusTone.warn;
  }
}

class AdminRaportService {
  final ApiService _api;
  AdminRaportService(this._api);

  /// GET /api/raports/admin-pipeline
  Future<AdminRaportPipeline> fetch({
    String? academicYearId,
    String? semesterId,
  }) async {
    final params = <String>[];
    if (academicYearId != null) {
      params.add('academic_year_id=$academicYearId');
    }
    if (semesterId != null) params.add('semester_id=$semesterId');
    final qs = params.isEmpty ? '' : '?${params.join('&')}';

    final raw = await _api.get('/raports/admin-pipeline$qs');
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final pipeline = (data['pipeline'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map(
          (m) => PipelineNode(
            key: (m['key'] ?? '').toString(),
            label: (m['label'] ?? '').toString(),
            count: (m['count'] as num?)?.toInt() ?? 0,
            active: (m['active'] as bool?) ?? false,
          ),
        )
        .toList();

    final tingkats = (data['tingkats'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) {
          final classes = (m['classes'] as List? ?? const [])
              .map((c) => Map<String, dynamic>.from(c as Map))
              .map(
                (c) => KelasMiniChipData(
                  id: (c['id'] ?? '').toString(),
                  label: (c['name'] ?? '').toString(),
                  statusLabel: (c['status_label'] ?? '').toString(),
                  tone: _parseTone((c['status_tone'] ?? 'warn').toString()),
                ),
              )
              .toList();

          return TingkatGroup(
            tingkat: (m['tingkat'] as num?)?.toInt() ?? 0,
            classCount: (m['class_count'] as num?)?.toInt() ?? 0,
            studentCount: (m['student_count'] as num?)?.toInt() ?? 0,
            reviewedPct: (m['reviewed_pct'] as num?)?.toInt() ?? 0,
            alert: (m['alert'] as bool?) ?? false,
            classes: classes,
          );
        })
        .toList();

    final period = Map<String, dynamic>.from(
      (data['period'] as Map?) ?? const {},
    );

    final ayLabel = (period['academic_year_label'] ?? '').toString();
    final semLabel = (period['semester_label'] ?? '').toString();
    final periodLabel = ayLabel.isNotEmpty && semLabel.isNotEmpty
        ? 'Periode $ayLabel · $semLabel'
        : 'Periode aktif';

    return AdminRaportPipeline(
      pipeline: pipeline,
      tingkats: tingkats,
      totalRaports: (data['total_raports'] as num?)?.toInt() ?? 0,
      totalClasses: (data['total_classes'] as num?)?.toInt() ?? 0,
      periodAcademicYearId: (period['academic_year_id'] ?? '').toString(),
      periodSemesterId: (period['semester_id'] ?? '').toString(),
      periodLabel: periodLabel,
    );
  }

  /// POST /api/raports/publish — bulk-flips all `final` raports for
  /// the given class to `published`. Wraps the existing endpoint so
  /// the hub's BulkActionBar "Terbit" button can call it once per
  /// selected class. Returns `published_count` from the backend.
  Future<int> publishClass({
    required String classId,
    required int academicYearId,
    required int semesterId,
  }) async {
    final raw = await _api.post('/raports/publish', {
      'class_id': classId,
      'academic_year_id': academicYearId,
      'semester_id': semesterId,
    });
    if (raw is Map && raw['published_count'] is num) {
      return (raw['published_count'] as num).toInt();
    }
    return 0;
  }
}

// =====================================================================
// Riverpod
// =====================================================================

final adminRaportServiceProvider = Provider<AdminRaportService>((ref) {
  return AdminRaportService(ApiService());
});

/// Long-lived FutureProvider for the admin Raport hub pipeline.
///
/// Note: the previous `.autoDispose` variant caused a tight refetch loop
/// when the screen was first opened. Each rebuild of the hub briefly
/// dropped the only listener (between widget tree update phases),
/// autoDispose then disposed the provider and cancelled the in-flight
/// request, and the next watch immediately kicked off a fresh fetch.
/// Six GETs would fire in a few seconds, none ever resolving because
/// each was cancelled before the response arrived. Dropping autoDispose
/// keeps the same Future across rebuilds — first fetch wins, the cached
/// AsyncValue feeds every later rebuild, and the screen flips out of
/// loading the moment the API responds.
///
/// Pull-to-refresh and the inline retry button still work via
/// `ref.invalidate(adminRaportPipelineProvider)`.
final adminRaportPipelineProvider = FutureProvider<AdminRaportPipeline>((
  ref,
) async {
  return ref.read(adminRaportServiceProvider).fetch();
});
