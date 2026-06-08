// Regression tests for the FCM-on-login fix.
//
// Bug: the app never re-registered the device's FCM token with the backend
// on login. FCM tokens are stable per app-install (they don't rotate on
// re-login/reopen), so whatever token sat in the DB went stale and the
// device silently stopped receiving pushes. The fix registers the current
// token on every login success; the backend dedupes on insert so stale
// rows self-heal.
//
// These tests assert the WIRING — that a login success fires the FCM
// registration hook — without standing up Firebase plugins. The actual
// network/plugin work lives behind `DataPersistenceHelper.registerFcmToken`,
// which we override here to observe invocation. The contract that matters:
// the registration MUST run on login success, and a failure inside it must
// never propagate out of the fire-and-forget path.
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/features/auth/presentation/controllers/helpers/data_persistence_helper.dart';

void main() {
  // Restore the production hook after each test so one test can't leak its
  // stub into another.
  final originalHook = DataPersistenceHelper.registerFcmToken;
  tearDown(() {
    DataPersistenceHelper.registerFcmToken = originalHook;
  });

  group('login success → FCM registration', () {
    test('sendFcmTokenAsync invokes the FCM registration hook', () async {
      var called = false;
      DataPersistenceHelper.registerFcmToken = () async {
        called = true;
        return true;
      };

      DataPersistenceHelper().sendFcmTokenAsync();

      // The hook runs on a microtask/event-loop turn (fire-and-forget), so
      // let the scheduled Future resolve before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(
        called,
        isTrue,
        reason: 'login success must re-register the current FCM token so the '
            'backend can dedupe away the stale one',
      );
    });

    test('a throwing hook never escapes the fire-and-forget path', () async {
      DataPersistenceHelper.registerFcmToken = () async {
        throw Exception('simulated backend/network failure');
      };

      // Must not throw synchronously...
      expect(DataPersistenceHelper().sendFcmTokenAsync, returnsNormally);

      // ...nor asynchronously (the error is caught + logged internally so the
      // login UX is never blocked or broken by FCM registration failures).
      await expectLater(
        Future<void>.delayed(const Duration(milliseconds: 10)),
        completes,
      );
    });

    test('default hook is set in production (not left null)', () {
      expect(originalHook, isNotNull);
    });
  });
}
