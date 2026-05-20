// Wrapper around GET /api/lesson-plans/admin-queue (Mockup #09).
// Returns the typed 3-tier review queue consumed by the admin RPP
// hub.

import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3.x moved `StateProvider` (and the other legacy providers)
// out of the main barrel into `legacy.dart`. The queue params slot
// is just a mutable holder for the admin's filter selections —
// migrating it to a full Notifier subclass would be a 30-line
// boilerplate detour, so we use the legacy alias to keep the call
// site (`ref.read(...notifier).state = ...`) unchanged.
import 'package:flutter_riverpod/legacy.dart' as legacy;

import 'package:manajemensekolah/core/services/api_service.dart';
import 'package:manajemensekolah/core/widgets/admin_lesson_plan_components.dart';

class QueueItem {
  final String id;
  final String title;
  final String subtitle;
  final String teacherName;
  final String status;
  final String? rejectionReason;
  final String? updatedAtHuman;
  /// Backend lesson_plans.format (k13 / rpp_1_halaman / modul_ajar /
  /// file). Defaults to 'k13' when missing so legacy rows render with
  /// the K13 pill instead of a blank space.
  final String format;

  const QueueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.teacherName,
    required this.status,
    this.rejectionReason,
    this.updatedAtHuman,
    this.format = 'k13',
  });
}

class QueueTier {
  final String key;
  final String label;
  final QueueTone tone;
  final int totalCount;
  final String? deltaLabel;
  final List<QueueItem> items;

  const QueueTier({
    required this.key,
    required this.label,
    required this.tone,
    required this.totalCount,
    this.deltaLabel,
    required this.items,
  });
}

class AdminLessonPlanQueue {
  final List<QueueTier> tiers;
  const AdminLessonPlanQueue({required this.tiers});

  QueueTier? tierByKey(String key) {
    for (final t in tiers) {
      if (t.key == key) return t;
    }
    return null;
  }
}

QueueTone _parseTone(String raw) {
  switch (raw) {
    case 'good':
      return QueueTone.good;
    case 'bad':
      return QueueTone.bad;
    default:
      return QueueTone.warn;
  }
}

class AdminLessonPlanQueueService {
  final ApiService _api;
  AdminLessonPlanQueueService(this._api);

  /// GET /api/lesson-plans/admin-queue
  ///
  /// Optional query params narrow the queue to a subset of RPPs. The
  /// hub-screen filter sheet passes these as URL query params; the
  /// backend translates each into a where-clause on lesson_plans.
  ///
  /// Period accepts one of: week / month / semester / all. The
  /// backend turns that into a from_date / to_date range based on
  /// `today` at request time, so the client doesn't have to compute
  /// calendar arithmetic.
  Future<AdminLessonPlanQueue> fetch({
    String? format,
    String? subjectId,
    String? classId,
    String? teacherId,
    String? period,
  }) async {
    final qp = <String, dynamic>{};
    if (format != null) qp['format'] = format;
    if (subjectId != null) qp['subject_id'] = subjectId;
    if (classId != null) qp['class_id'] = classId;
    if (teacherId != null) qp['teacher_id'] = teacherId;
    if (period != null) qp['period'] = period;

    final raw = await _api.get('/lesson-plans/admin-queue', params: qp);
    final data = (raw is Map && raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'] as Map)
        : <String, dynamic>{};

    final tiers = (data['tiers'] as List? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .map((m) {
          final items = (m['items'] as List? ?? const [])
              .map((c) => Map<String, dynamic>.from(c as Map))
              .map(
                (c) => QueueItem(
                  id: (c['id'] ?? '').toString(),
                  title: (c['title'] ?? '').toString(),
                  subtitle: (c['subtitle'] ?? '').toString(),
                  teacherName: (c['teacher_name'] ?? '').toString(),
                  status: (c['status'] ?? '').toString(),
                  rejectionReason: c['rejection_reason']?.toString(),
                  updatedAtHuman: c['updated_at_human']?.toString(),
                  format: (c['format'] ?? 'k13').toString(),
                ),
              )
              .toList();
          return QueueTier(
            key: (m['key'] ?? '').toString(),
            label: (m['label'] ?? '').toString(),
            tone: _parseTone((m['tone'] ?? 'warn').toString()),
            totalCount: (m['total_count'] as num?)?.toInt() ?? 0,
            deltaLabel: m['delta_label']?.toString(),
            items: items,
          );
        })
        .toList();

    return AdminLessonPlanQueue(tiers: tiers);
  }

  /// POST /api/lesson-plans/{id}/status
  /// Used for inline approve/reject from the queue card.
  ///
  /// Pass [reason] to populate `catatan` (note_admin on the row) — for
  /// reject + send-back flows the catatan is what the guru sees on
  /// their revision banner.
  Future<void> updateStatus(
    String id,
    String newStatus, {
    String? reason,
  }) async {
    final body = <String, dynamic>{'status': newStatus};
    if (reason != null && reason.isNotEmpty) {
      // Backward-compat with older clients: rejection_reason is what
      // the v1 admin hub sent. The new updateStatus route also accepts
      // `catatan`, which is the canonical key.
      body['rejection_reason'] = reason;
      body['catatan'] = reason;
    }
    await _api.post('/lesson-plans/$id/status', body);
  }

  /// PUT /api/rpp/{id}/send-back
  ///
  /// Admin asks the guru to revise. Unlike Reject (which is final),
  /// the RPP stays Pending and shows up in the guru's "Perlu revisi"
  /// inbox. [areas] highlights specific sections that need attention.
  Future<void> sendBack(
    String id, {
    required String catatan,
    List<String>? areas,
  }) async {
    final body = <String, dynamic>{'catatan': catatan};
    if (areas != null && areas.isNotEmpty) {
      body['revision_areas'] = areas;
    }
    await _api.put('/rpp/$id/send-back', body);
  }
}

// =====================================================================
// Riverpod
// =====================================================================

final adminLessonPlanQueueServiceProvider =
    Provider<AdminLessonPlanQueueService>((ref) {
      return AdminLessonPlanQueueService(ApiService());
    });

/// Query parameters the admin hub passes to the queue endpoint.
/// Tracked as a Riverpod state so changes via the filter sheet
/// automatically refetch the queue.
///
/// Default = empty (= "no filter applied"). The hub screen owns the
/// LessonPlanAdminFilter wrapper; this provider only carries the
/// raw query keys to keep the data layer free of UI-tier types.
class AdminLessonPlanQueueParams {
  final String? format;
  final String? subjectId;
  final String? classId;
  final String? teacherId;
  final String? period;

  const AdminLessonPlanQueueParams({
    this.format,
    this.subjectId,
    this.classId,
    this.teacherId,
    this.period,
  });

  const AdminLessonPlanQueueParams.empty()
    : format = null,
      subjectId = null,
      classId = null,
      teacherId = null,
      period = null;

  @override
  bool operator ==(Object other) {
    return other is AdminLessonPlanQueueParams &&
        other.format == format &&
        other.subjectId == subjectId &&
        other.classId == classId &&
        other.teacherId == teacherId &&
        other.period == period;
  }

  @override
  int get hashCode => Object.hash(format, subjectId, classId, teacherId, period);
}

final adminLessonPlanQueueParamsProvider =
    legacy.StateProvider<AdminLessonPlanQueueParams>(
      (ref) => const AdminLessonPlanQueueParams.empty(),
    );

final adminLessonPlanQueueProvider =
    FutureProvider.autoDispose<AdminLessonPlanQueue>((ref) async {
      final params = ref.watch(adminLessonPlanQueueParamsProvider);
      return ref.read(adminLessonPlanQueueServiceProvider).fetch(
        format: params.format,
        subjectId: params.subjectId,
        classId: params.classId,
        teacherId: params.teacherId,
        period: params.period,
      );
    });
