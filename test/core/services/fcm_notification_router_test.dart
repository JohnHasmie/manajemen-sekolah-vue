// Unit tests for the notification type→kind normalization that powers
// deep-linking. This is the pure mapping both entry points share — push
// taps (FCM `data`) and in-app list taps (rebuilt `{type: ...}` map).
//
// We assert the mapping covers EVERY backend variant, because the bug was
// precisely that the FCM push `data.type` and the persisted DB `type`
// diverge (e.g. finance push sends `bill_generated` while the DB row
// stores `finance`, and the class_activity push omits `type` entirely and
// only carries `screen: class_activity_detail`).
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/services/fcm_notification_router.dart';

void main() {
  group('FCMNotificationRouter.kindFor', () {
    NotificationKind kind(Map<String, dynamic> data) =>
        FCMNotificationRouter.kindFor(data);

    test('announcement variants → announcement', () {
      for (final t in const [
        'announcement',
        'pengumuman',
        'announcement_event',
        'announcement_event_personal',
        'ANNOUNCEMENT', // case-insensitive
      ]) {
        expect(
          kind({'type': t}),
          NotificationKind.announcement,
          reason: 'type=$t',
        );
      }
    });

    test('class activity variants → classActivity', () {
      for (final t in const [
        'class_activity',
        'class_activity_detail',
        'activity',
      ]) {
        expect(
          kind({'type': t}),
          NotificationKind.classActivity,
          reason: 'type=$t',
        );
      }
    });

    test('class_activity push without type falls back to screen hint', () {
      // Backend SendClassActivityNotificationJob omits `type` on the push
      // and only sends `screen: class_activity_detail` + activity_id.
      expect(
        kind({'screen': 'class_activity_detail', 'activity_id': '42'}),
        NotificationKind.classActivity,
      );
    });

    test('grade variants → grade', () {
      for (final t in const ['grade', 'nilai', 'exam_score']) {
        expect(kind({'type': t}), NotificationKind.grade, reason: 'type=$t');
      }
    });

    test('attendance variants → attendance', () {
      for (final t in const ['attendance', 'absensi']) {
        expect(
          kind({'type': t}),
          NotificationKind.attendance,
          reason: 'type=$t',
        );
      }
    });

    test('finance / billing variants → billing', () {
      // DB row type, legacy aliases, and every granular FCM push type.
      for (final t in const [
        'finance',
        'tagihan',
        'bill',
        'bill_generated',
        'payment_verified',
        'payment_rejected',
        'payment_confirmed',
        'payment_submitted',
      ]) {
        expect(kind({'type': t}), NotificationKind.billing, reason: 'type=$t');
      }
    });

    test('teaching reminder → teachingReminder', () {
      expect(
        kind({'type': 'reminder_teaching', 'date': '2026-06-08'}),
        NotificationKind.teachingReminder,
      );
    });

    test('unknown / missing type → unknown (graceful fallback)', () {
      expect(kind({}), NotificationKind.unknown);
      expect(kind({'type': 'something_new'}), NotificationKind.unknown);
      expect(kind({'type': null}), NotificationKind.unknown);
    });

    test('screen hint covers the remaining finance/screen-only payloads', () {
      expect(kind({'screen': 'finance_detail'}), NotificationKind.billing);
      expect(
        kind({'screen': 'finance_verification'}),
        NotificationKind.billing,
      );
    });

    test('type takes precedence over screen when both present', () {
      // A grade push should route to grade even if some stray screen hint
      // disagrees — explicit type wins.
      expect(
        kind({'type': 'grade', 'screen': 'finance_detail'}),
        NotificationKind.grade,
      );
    });
  });
}
