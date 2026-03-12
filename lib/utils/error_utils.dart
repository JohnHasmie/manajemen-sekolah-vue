import 'package:flutter/foundation.dart';

class ErrorUtils {
  /// Returns a user-friendly Indonesian error message based on the [error] object.
  static String getFriendlyMessage(dynamic error) {
    if (kDebugMode) {
      print('🔍 Raw Error: $error');
    }

    final String errorStr = error.toString().toLowerCase();

    // Connection errors
    if (errorStr.contains('socketexception') ||
        errorStr.contains('failed host lookup') ||
        errorStr.contains('connection failed') ||
        errorStr.contains('network') ||
        errorStr.contains('is not reachable')) {
      return 'Gagal terhubung ke server, silakan cek koneksi internet Anda.';
    }

    // Timeouts
    if (errorStr.contains('timeout') ||
        errorStr.contains('deadline exceeded')) {
      return 'Koneksi terlalu lambat atau waktu habis, silakan coba lagi.';
    }

    // Specific login errors - check BEFORE generic auth errors
    if (errorStr.contains('tidak mengembalikan token') ||
        errorStr.contains('gagal mendapatkan token google')) {
      return 'Login gagal. Silakan coba lagi.';
    }

    // Authentication/Authorization - only for actual session/auth issues
    if (errorStr.contains('re-login') ||
        errorStr.contains('401') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('session expired')) {
      return 'Sesi Anda telah berakhir, silakan login kembali.';
    }

    // School context mismatch (SEC-18) — specific and actionable message
    if (errorStr.contains('school_access_denied') ||
        errorStr.contains('tidak memiliki akses ke sekolah ini')) {
      return 'Sesi sekolah Anda tidak valid. Silakan pilih sekolah kembali atau login ulang.';
    }

    // Permission
    if (errorStr.contains('permission') ||
        errorStr.contains('403') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('akses ditolak')) {
      return 'Akses ditolak. Mohon hubungi admin sekolah Anda.';
    }

    // Not Found
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Data yang diminta tidak ditemukan di server.';
    }

    // Server Errors
    if (errorStr.contains('500') ||
        errorStr.contains('internal server error') ||
        errorStr.contains('server error')) {
      return 'Terjadi kesalahan pada sistem server, mohon hubungi admin.';
    }

    // Specific Business Logic / Backend Errors
    if (errorStr.contains('tidak terdaftar pada sekolah') ||
        errorStr.contains('no schools assigned')) {
      return 'Akun Anda belum terdaftar pada sekolah manapun, hubungi admin sekolah Anda.';
    }

    if (errorStr.contains('email atau password salah') ||
        errorStr.contains('wrong password') ||
        errorStr.contains('invalid credential')) {
      return 'Email atau password salah.';
    }

    // General exception or fallback
    if (errorStr.contains('429') ||
        errorStr.contains('too many requests') ||
        errorStr.contains('throttle')) {
      return 'Terlalu banyak permintaan. Silakan tunggu beberapa saat lagi.';
    }

    if (errorStr.contains('exception') || errorStr.contains('failed')) {
      return 'Terjadi kesalahan sistem, silakan hubungi admin.';
    }

    return 'Gagal memproses permintaan, silakan hubungi admin.';
  }
}
