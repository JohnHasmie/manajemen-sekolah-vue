/// error_utils.dart - Converts raw exceptions/errors into user-friendly Indonesian messages.
/// Like a Laravel Helper function, or Laravel's exception handler
/// (`Handler.php`)
/// that maps exceptions to HTTP responses. In Vue terms, this is like an Axios
/// interceptor that translates API errors into localized toast messages.
library;

import 'package:manajemensekolah/core/utils/app_logger.dart';

/// Maps raw error objects to localized, user-friendly Indonesian error
/// messages.
/// Like a Laravel Helper function class, or the `render()` method in Laravel's
/// `App\Exceptions\Handler` that converts exceptions into readable responses.
///
/// Uses keyword matching on the error's string representation to categorize
/// errors
/// into groups: connection, timeout, auth, business logic, permissions, server
/// errors, etc.
///
/// Priority order matters: specific business-logic checks (e.g., "email tidak
/// terdaftar")
/// run before generic HTTP status code checks (e.g., "404") to avoid false
/// matches.
class ErrorUtils {
  /// Returns a user-friendly Indonesian error message based on the [error]
  /// object.
  /// Like Laravel's `Handler::render()` - converts any thrown error into a
  /// displayable string for the UI.
  ///
  /// [error] - Any error/exception object. Its `.toString()` is analyzed via
  ///   keyword matching to determine the appropriate message.
  ///
  /// Returns a localized Indonesian string suitable for showing in a SnackBar
  /// or dialog.
  static String getFriendlyMessage(dynamic error) {
    AppLogger.error('error', error);

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
      return 'Sesi sekolah Anda tidak valid. '
          'Silakan pilih sekolah kembali atau login ulang.';
    }

    // ── Specific Business Logic (check BEFORE generic status codes) ──

    // Unregistered email / account
    if (errorStr.contains('email tidak terdaftar') ||
        errorStr.contains('email not registered') ||
        errorStr.contains('user not found') ||
        errorStr.contains('user tidak ditemukan') ||
        errorStr.contains('no account found') ||
        errorStr.contains('akun tidak ditemukan') ||
        errorStr.contains('belum terdaftar') ||
        errorStr.contains('tidak memiliki akun')) {
      return 'Akun dengan email tersebut belum terdaftar. '
          'Silakan hubungi admin sekolah Anda untuk didaftarkan.';
    }

    // No schools assigned
    if (errorStr.contains('tidak terdaftar pada sekolah') ||
        errorStr.contains('no schools assigned')) {
      return 'Akun Anda belum terdaftar pada sekolah manapun, '
          'hubungi admin sekolah Anda.';
    }

    // Wrong credentials
    if (errorStr.contains('email atau password salah') ||
        errorStr.contains('wrong password') ||
        errorStr.contains('invalid credential') ||
        errorStr.contains('credentials do not match') ||
        errorStr.contains('kredensial tidak cocok')) {
      return 'Email atau password salah.';
    }

    // ── Generic status code handlers ──

    // Permission
    if (errorStr.contains('permission') ||
        errorStr.contains('403') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('akses ditolak')) {
      return 'Akses ditolak. Mohon hubungi admin sekolah Anda.';
    }

    // Not Found (generic — after specific business logic checks)
    if (errorStr.contains('not found') || errorStr.contains('404')) {
      return 'Data yang diminta tidak ditemukan di server.';
    }

    // Server Errors
    if (errorStr.contains('500') ||
        errorStr.contains('internal server error') ||
        errorStr.contains('server error')) {
      return 'Terjadi kesalahan pada sistem server, mohon hubungi admin.';
    }

    // General exception or fallback
    if (errorStr.contains('429') ||
        errorStr.contains('too many requests') ||
        errorStr.contains('throttle')) {
      return 'Terlalu banyak permintaan. Silakan tunggu beberapa saat lagi.';
    }

    // Validation Errors (Laravel)
    if (errorStr.contains(
      'the date field must be a date before or equal to today',
    )) {
      return 'Tanggal tidak boleh lebih dari hari ini.';
    }

    if (errorStr.contains('exception') || errorStr.contains('failed')) {
      return 'Terjadi kesalahan sistem, silakan hubungi admin.';
    }

    return 'Gagal memproses permintaan, silakan hubungi admin.';
  }
}
