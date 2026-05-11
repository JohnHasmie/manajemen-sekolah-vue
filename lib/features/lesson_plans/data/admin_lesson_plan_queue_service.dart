// Wrapper around GET /api/lesson-plans/admin-queue (Mockup #09).
// Returns the typed 3-tier review queue consumed by the admin RPP
// hub.

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  const QueueItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.teacherName,
    required this.status,
    this.rejectionReason,
    this.updatedAtHuman,
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
  Future<AdminLessonPlanQueue> fetch() async {
    final raw = await _api.get('/lesson-plans/admin-queue');
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
  Future<void> updateStatus(
    String id,
    String newStatus, {
    String? reason,
  }) async {
    final body = <String, dynamic>{'status': newStatus};
    if (reason != null && reason.isNotEmpty) {
      body['rejection_reason'] = reason;
    }
    await _api.post('/lesson-plans/$id/status', body);
  }
}

// =====================================================================
// Riverpod
// =====================================================================

final adminLessonPlanQueueServiceProvider =
    Provider<AdminLessonPlanQueueService>((ref) {
      return AdminLessonPlanQueueService(ApiService());
    });

final adminLessonPlanQueueProvider =
    FutureProvider.autoDispose<AdminLessonPlanQueue>((ref) async {
      return ref.read(adminLessonPlanQueueServiceProvider).fetch();
    });
