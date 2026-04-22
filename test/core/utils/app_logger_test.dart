/// Tests for AppLogger — smoke tests ensuring no method throws.
///
/// AppLogger methods only print in debug mode, so we just verify
/// they complete without exceptions (like testing a Laravel Log facade
/// doesn't blow up).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/app_logger.dart';

void main() {
  group('AppLogger', () {
    test('debug does not throw', () {
      expect(
        () => AppLogger.debug('TestTag', 'debug message'),
        returnsNormally,
      );
    });

    test('debug with tag only does not throw', () {
      expect(() => AppLogger.debug('TestTag'), returnsNormally);
    });

    test('info does not throw', () {
      expect(() => AppLogger.info('TestTag', 'info message'), returnsNormally);
    });

    test('info with tag only does not throw', () {
      expect(() => AppLogger.info('TestTag'), returnsNormally);
    });

    test('warning does not throw', () {
      expect(
        () => AppLogger.warning('TestTag', 'warning message'),
        returnsNormally,
      );
    });

    test('warning with tag only does not throw', () {
      expect(() => AppLogger.warning('TestTag'), returnsNormally);
    });

    test('error does not throw', () {
      expect(
        () => AppLogger.error('TestTag', 'some error', StackTrace.current),
        returnsNormally,
      );
    });

    test('error with error only does not throw', () {
      expect(
        () => AppLogger.error('TestTag', Exception('boom')),
        returnsNormally,
      );
    });

    test('error with tag only does not throw', () {
      expect(() => AppLogger.error('TestTag'), returnsNormally);
    });

    test('network does not throw', () {
      expect(() => AppLogger.network('GET', '/api/test', 200), returnsNormally);
    });

    test('network without status code does not throw', () {
      expect(() => AppLogger.network('POST', '/api/test'), returnsNormally);
    });
  });
}
