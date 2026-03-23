import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/error_utils.dart';

void main() {
  group('ErrorUtils Tests', () {
    test('Handles SocketException', () {
      final error = SocketException('Failed host lookup');
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('koneksi internet'));
    });

    test('Handles 401 Unauthorized', () {
      final error = 'Exception: 401 Unauthorized';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('Sesi Anda telah berakhir'));
    });

    test('Handles 403 Forbidden', () {
      final error = '403 Forbidden';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('Akses ditolak'));
    });

    test('Handles 404 Not Found', () {
      final error = 'Http status 404';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('tidak ditemukan'));
    });

    test('Handles 500 Internal Server Error', () {
      final error = '500 Internal Server Error';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('sistem server'));
    });

    test('Handles TimeoutException', () {
      final error = 'TimeoutException: Connection timed out';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('Koneksi terlalu lambat'));
    });

    test('Handles Unknown Error', () {
      final error = 'Some weird error that we dont know';
      final message = ErrorUtils.getFriendlyMessage(error);
      expect(message, contains('Gagal memproses permintaan'));
    });
  });
}
